// L leg — reviewed transliteration of the btc-lean model at
// spec/core model_rev 4d62a97e551082a69b13f495365bff0a903b0c99.
//
//   spec/core/Bitcoin/Interpreter/SigOps.lean:376-390  witnessSigOps
//   spec/core/Bitcoin/Interpreter/SigOps.lean:247-253  witnessScriptSigOps
//   spec/core/Bitcoin/Interpreter/SigOps.lean:132-155  parseWirePrefix / scriptSigOpCount
//   spec/core/Bitcoin/Interpreter/SigOps.lean:56-101   sigOpStep
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-230  getOpAux / getOp
//
// witnessSigOps v prog witness:
//   version = 0 and prog.size = 20            -> 1
//   version = 0 and prog.size = 32 and last?  -> accurate count of the last item
//   otherwise                                 -> 0
//
// Only `prog.size` is read, so the program is represented by its length.  The
// last witness item is a packed four-byte script; stack_size models the
// zero/non-zero test on the stack.  The count walk is unrolled.
#include "limits_common.h"

namespace {

enum Kind : uint8_t { PushBytes, PushNum, Op };

struct Decoded {
  bool ok;
  Kind kind;
  uint32_t num;
  uint32_t wire;
  uint32_t next;
};

CLINLINE bool lean_read_le(const LimitsScript& s, uint32_t base, uint32_t i,
                           uint32_t limit, uint32_t n, uint32_t& out) {
  if (static_cast<uint64_t>(i) + n > limit) return false;
  uint32_t v = limits_byte(s, base + i);
  if (n >= 2) v |= limits_byte(s, base + i + 1) << 8;
  if (n >= 4) {
    v |= limits_byte(s, base + i + 2) << 16;
    v |= limits_byte(s, base + i + 3) << 24;
  }
  out = v;
  return true;
}

CLINLINE bool lean_slice_ok(uint32_t limit, uint32_t i, uint32_t n) {
  return static_cast<uint64_t>(i) + n <= limit;
}

CLINLINE Decoded lean_get_op(const LimitsScript& s, uint32_t base,
                             uint32_t limit, uint32_t i) {
  Decoded d;
  d.ok = false;
  d.kind = Op;
  d.num = 0;
  d.wire = 0;
  d.next = i;
  if (i >= limit) return d;

  const uint32_t c = limits_byte(s, base + i);
  d.wire = c;
  if (c == 0) {
    d.ok = true;
    d.kind = PushBytes;
    d.next = i + 1;
    return d;
  }
  if (c > 0x4e) {
    d.ok = true;
    if (c == 0x4f) {
      d.kind = PushNum;
      d.num = 0;
    } else if (c <= 0x60) {
      d.kind = PushNum;
      d.num = c - 0x50;
    } else {
      d.kind = Op;
    }
    d.next = i + 1;
    return d;
  }

  uint32_t hdr = 0;
  uint32_t n = 0;
  if (c <= 0x4b) {
    n = c;
  } else if (c == 0x4c) {
    hdr = 1;
    if (!lean_read_le(s, base, i + 1, limit, 1, n)) return d;
  } else if (c == 0x4d) {
    hdr = 2;
    if (!lean_read_le(s, base, i + 1, limit, 2, n)) return d;
  } else {
    hdr = 4;
    if (!lean_read_le(s, base, i + 1, limit, 4, n)) return d;
  }
  if (!lean_slice_ok(limit, i + 1 + hdr, n)) return d;
  d.ok = true;
  d.kind = PushBytes;
  d.next = i + 1 + hdr + n;
  return d;
}

CLINLINE uint32_t lean_contrib(bool accurate, bool prev_ok, Kind prev_kind,
                               uint32_t prev_num, uint32_t wire) {
  if (wire == 0xac || wire == 0xad) return 1u;
  if (wire == 0xae || wire == 0xaf) {
    if (accurate && prev_ok && prev_kind == PushNum && prev_num >= 1 &&
        prev_num <= 16) {
      return prev_num;
    }
    return LIMITS_MAX_PUBKEYS_PER_MULTISIG;
  }
  return 0u;
}

struct CWalk {
  bool live;
  uint32_t i;
  uint32_t count;
  bool prev_ok;
  Kind prev_kind;
  uint32_t prev_num;
};

CLINLINE void lean_count_step(CWalk& st, const LimitsScript& s, uint32_t base,
                              uint32_t limit, bool accurate) {
  if (!st.live) return;
  if (st.i >= limit) {
    st.live = false;
    return;
  }
  const Decoded d = lean_get_op(s, base, limit, st.i);
  if (!d.ok) {
    st.live = false;
    return;
  }
  st.count += lean_contrib(accurate, st.prev_ok, st.prev_kind, st.prev_num,
                           d.wire);
  st.prev_ok = true;
  st.prev_kind = d.kind;
  st.prev_num = d.num;
  st.i = d.next;
}

CLINLINE uint32_t lean_count(const LimitsScript& s, uint32_t base,
                             uint32_t limit, bool accurate) {
  CWalk st;
  st.live = true;
  st.i = 0;
  st.count = 0;
  st.prev_ok = false;
  st.prev_kind = Op;
  st.prev_num = 0;
  lean_count_step(st, s, base, limit, accurate);
  lean_count_step(st, s, base, limit, accurate);
  lean_count_step(st, s, base, limit, accurate);
  lean_count_step(st, s, base, limit, accurate);
  return st.count;
}

CLINLINE uint32_t lean_witness_sigops(uint32_t version, uint32_t prog_len,
                                      uint32_t stack_size, uint64_t w,
                                      uint32_t wit_len) {
  if (version != 0) return 0;
  if (prog_len == 20) return 1;
  if (prog_len != 32) return 0;
  if (stack_size == 0) return 0;  // witness.getLast? = none
  if (wit_len > LIMITS_MAX_SCRIPT_BYTES) return LIMITS_OUT_OF_DOMAIN;
  const LimitsScript s = limits_script(w, wit_len);
  return lean_count(s, 0, wit_len, true);
}

}  // namespace

extern "C" uint32_t cell_witness_sigops(uint32_t version, uint32_t prog_len,
                                        uint32_t stack_size, uint64_t w,
                                        uint32_t wit_len) {
  return lean_witness_sigops(version, prog_len, stack_size, w, wit_len);
}
