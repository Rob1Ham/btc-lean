// L leg — reviewed transliteration of the btc-lean model at
// spec/core model_rev 4d62a97e551082a69b13f495365bff0a903b0c99.
//
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-230  getOpAux / getOp
//   spec/core/Bitcoin/Script/Parser/Defs.lean:86-88    getOpt
//   spec/core/Bitcoin/Interpreter/SigOps.lean:56-101   isCheckSigWire,
//       isCheckMultiSigWire, opNumberOf, sigOpStep, accurateSigOpCountFrom,
//       inaccurateSigOpCount, sigOpCount
//   spec/core/Bitcoin/Interpreter/SigOps.lean:109-121  getOpCount (the
//       520-byte push bound: unreachable for a four-byte script, since a
//       PUSHDATA2/4 payload cannot fit in the remaining script bytes)
//   spec/core/Bitcoin/Interpreter/SigOps.lean:132-155  parseWirePrefixFrom,
//       parseWirePrefix, scriptSigOpCount
//   spec/core/Bitcoin/Interpreter/Defs.lean:76         MAX_PUBKEYS_PER_MULTISIG
//
// The ByteArray is the packed cell script (first four bytes in domain);
// sliceOpt/readLE are bounds-checked exactly as the Lean definitions are.
#include "limits_common.h"

namespace {

enum Kind : uint8_t { PushBytes, PushNum, Op };

struct Decoded {
  bool ok;
  Kind kind;
  uint32_t num;   // pushNum n
  uint32_t wire;  // opcode byte, i.e. `b[i]!`
  uint32_t next;
};

// readLE b i n: little-endian n-byte read, none if the field is truncated.
CLINLINE bool lean_read_le(const LimitsScript& s, uint32_t i, uint32_t n,
                           uint32_t& out) {
  if (static_cast<uint64_t>(i) + n > s.len) return false;
  uint32_t v = limits_byte(s, i);
  if (n >= 2) v |= limits_byte(s, i + 1) << 8;
  if (n >= 4) {
    v |= limits_byte(s, i + 2) << 16;
    v |= limits_byte(s, i + 3) << 24;
  }
  out = v;
  return true;
}

// sliceOpt b i n: the payload exists iff i + n <= b.size.
CLINLINE bool lean_slice_ok(uint32_t len, uint32_t i, uint32_t n) {
  return static_cast<uint64_t>(i) + n <= len;
}

// getOpAux / getOp, verbatim case order:
//   c = 0            -> pushBytes empty
//   c <= 0x4b        -> pushBytes (direct push of c bytes)
//   c = 0x4c/4d/4e   -> pushBytes with a 1/2/4-byte little-endian length
//   c = 0x4f         -> pushNum 0
//   c = 0x50         -> op 0x50 (OP_RESERVED is not a push)
//   0x51 <= c <= 0x60-> pushNum (c - 0x50)
//   otherwise        -> op c
CLINLINE Decoded lean_get_op(const LimitsScript& s, uint32_t i) {
  Decoded d;
  d.ok = false;
  d.kind = Op;
  d.num = 0;
  d.wire = 0;
  d.next = i;
  if (i >= s.len) return d;  // getOpt b i = none

  const uint32_t c = limits_byte(s, i);
  d.wire = c;
  if (c == 0) {
    d.ok = true;
    d.kind = PushBytes;
    d.next = i + 1;
    return d;
  }
  if (c > 0x4e) {
    // Not a push opcode.
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

  uint32_t hdr = 0;  // length-prefix width after the opcode
  uint32_t n = 0;    // payload length
  if (c <= 0x4b) {
    n = c;
  } else if (c == 0x4c) {
    hdr = 1;
    if (!lean_read_le(s, i + 1, 1, n)) return d;
  } else if (c == 0x4d) {
    hdr = 2;
    if (!lean_read_le(s, i + 1, 2, n)) return d;
  } else {
    hdr = 4;
    if (!lean_read_le(s, i + 1, 4, n)) return d;
  }
  // sliceOpt b (i + 1 + hdr) n
  if (!lean_slice_ok(s.len, i + 1 + hdr, n)) return d;
  d.ok = true;
  d.kind = PushBytes;
  d.next = i + 1 + hdr + n;
  return d;
}

// opNumberOf: only a pushNum 1..16 contributes its value.
CLINLINE bool lean_op_number(bool prev_ok, Kind prev_kind, uint32_t prev_num,
                             uint32_t& out) {
  if (!prev_ok) return false;
  if (prev_kind != PushNum) return false;
  if (prev_num < 1 || prev_num > 16) return false;
  out = prev_num;
  return true;
}

// sigOpStep prev op / accurateSigOpCountFrom / inaccurateSigOpCount.
CLINLINE uint32_t lean_contrib(bool accurate, bool prev_ok, Kind prev_kind,
                               uint32_t prev_num, const Decoded& op) {
  if (op.wire == 0xac || op.wire == 0xad) return 1u;
  if (op.wire == 0xae || op.wire == 0xaf) {
    if (accurate) {
      uint32_t n = 0;
      if (lean_op_number(prev_ok, prev_kind, prev_num, n)) return n;
    }
    return LIMITS_MAX_PUBKEYS_PER_MULTISIG;
  }
  return 0u;
}

struct Walk {
  bool live;
  uint32_t i;
  uint32_t n;
  bool prev_ok;
  Kind prev_kind;
  uint32_t prev_num;
};

// parseWirePrefixFrom one step + the sigOpStep of the parsed opcode.  The
// Lean walk stops at the first malformed push and keeps the count of the
// prefix already parsed.
CLINLINE void lean_sigop_step(Walk& st, const LimitsScript& s, bool accurate) {
  if (!st.live) return;
  if (st.i >= s.len) {  // if b.size <= i then []
    st.live = false;
    return;
  }
  const Decoded d = lean_get_op(s, st.i);
  if (!d.ok) {  // | none => []
    st.live = false;
    return;
  }
  st.n += lean_contrib(accurate, st.prev_ok, st.prev_kind, st.prev_num, d);
  st.prev_ok = true;
  st.prev_kind = d.kind;
  st.prev_num = d.num;
  st.i = d.next;
}

// scriptSigOpCount, unrolled to the four-byte cell bound (harness only).
CLINLINE uint32_t lean_script_sigop_count(uint64_t w, uint32_t len,
                                          bool accurate) {
  if (len > LIMITS_MAX_SCRIPT_BYTES) return LIMITS_OUT_OF_DOMAIN;
  const LimitsScript s = limits_script(w, len);
  Walk st;
  st.live = true;
  st.i = 0;
  st.n = 0;
  st.prev_ok = false;  // accurateSigOpCountFrom none
  st.prev_kind = Op;
  st.prev_num = 0;
  lean_sigop_step(st, s, accurate);
  lean_sigop_step(st, s, accurate);
  lean_sigop_step(st, s, accurate);
  lean_sigop_step(st, s, accurate);
  return st.n;
}

}  // namespace

extern "C" uint32_t cell_sigop_accurate(uint64_t w, uint32_t len) {
  return lean_script_sigop_count(w, len, true);
}

extern "C" uint32_t cell_sigop_inaccurate(uint64_t w, uint32_t len) {
  return lean_script_sigop_count(w, len, false);
}
