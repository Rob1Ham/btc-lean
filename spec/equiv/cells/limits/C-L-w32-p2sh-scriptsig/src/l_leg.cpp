// L leg — reviewed transliteration of the btc-lean model at
// spec/core model_rev 4d62a97e551082a69b13f495365bff0a903b0c99.
//
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-230  getOpAux / getOp
//   spec/core/Bitcoin/Script/Parser/Defs.lean:86-88    getOpt, readLE, sliceOpt
//   spec/core/Bitcoin/Interpreter/Defs.lean:421-431    parseWireFrom / parseWire
//   spec/core/Bitcoin/Interpreter/Defs.lean:496        isPushOnlyWire
//   spec/core/Bitcoin/Interpreter/SigOps.lean:132-155  parseWirePrefix, scriptSigOpCount
//   spec/core/Bitcoin/Interpreter/SigOps.lean:359-374  pushOnlyLastData, p2shScriptSigOps
//   spec/core/Bitcoin/Interpreter/SigOps.lean:56-101   sigOpStep and the counters
//
// p2shScriptSigOps is: parse the whole scriptSig (all-or-nothing), require
// every wire opcode <= 0x60, take the last op's pushBytes payload (empty for
// pushNum/op), then count that payload's valid prefix accurately.
//
// Both walks are unrolled to the four-byte bound with an explicit live flag;
// no loop survives at -O1 (Alive2 needs a loop-free function).
#include "limits_common.h"

namespace {

enum Kind : uint8_t { PushBytes, PushNum, Op };

struct Decoded {
  bool ok;
  Kind kind;
  uint32_t num;
  uint32_t wire;
  uint32_t next;
  uint32_t dstart;
  uint32_t dlen;
};

// readLE b i n over the virtual script [base, base + limit).
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

// getOp over the virtual script [base, base + limit).
CLINLINE Decoded lean_get_op(const LimitsScript& s, uint32_t base,
                             uint32_t limit, uint32_t i) {
  Decoded d;
  d.ok = false;
  d.kind = Op;
  d.num = 0;
  d.wire = 0;
  d.next = i;
  d.dstart = 0;
  d.dlen = 0;
  if (i >= limit) return d;

  const uint32_t c = limits_byte(s, base + i);
  d.wire = c;
  if (c == 0) {
    d.ok = true;
    d.kind = PushBytes;
    d.dstart = i + 1;
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
  d.dstart = i + 1 + hdr;
  d.dlen = n;
  d.next = i + 1 + hdr + n;
  return d;
}

// sigOpStep: contribution of one decoded opcode given the previous opcode.
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

// One accurate/inaccurate prefix-count loop body.
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

// One body of parseWire + the push-only filter + last-data tracking.
struct PWalk {
  bool live;
  bool ok;
  bool push_only;
  bool has_last;
  uint32_t i;
  uint32_t dstart;
  uint32_t dlen;
};

CLINLINE void lean_p2sh_step(PWalk& st, const LimitsScript& s, uint32_t limit) {
  if (!st.live) return;
  if (st.i >= limit) {
    st.live = false;
    return;
  }
  const Decoded d = lean_get_op(s, 0, limit, st.i);
  if (!d.ok) {  // parseWire returns none
    st.live = false;
    st.ok = false;
    return;
  }
  st.push_only = st.push_only && (d.wire <= 0x60);
  if (d.kind == PushBytes) {
    st.dstart = d.dstart;
    st.dlen = d.dlen;
  } else {
    st.dstart = 0;
    st.dlen = 0;
  }
  st.has_last = true;
  st.i = d.next;
}

// pushOnlyLastData + p2shScriptSigOps.
CLINLINE uint32_t lean_p2sh_sigops(uint64_t w, uint32_t len) {
  if (len > LIMITS_MAX_SCRIPT_BYTES) return LIMITS_OUT_OF_DOMAIN;
  const LimitsScript s = limits_script(w, len);

  PWalk st;
  st.live = true;
  st.ok = true;
  st.push_only = true;
  st.has_last = false;
  st.i = 0;
  st.dstart = 0;
  st.dlen = 0;
  lean_p2sh_step(st, s, s.len);
  lean_p2sh_step(st, s, s.len);
  lean_p2sh_step(st, s, s.len);
  lean_p2sh_step(st, s, s.len);
  if (!st.ok || st.i < s.len || !st.push_only || !st.has_last) return 0;
  return lean_count(s, st.dstart, st.dlen, true);
}

}  // namespace

extern "C" uint32_t cell_p2sh_sigops(uint64_t w, uint32_t len) {
  return lean_p2sh_sigops(w, len);
}
