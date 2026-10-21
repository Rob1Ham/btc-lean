#include <cstdint>
#include "twin.cpp"

// L leg: the Lean model's numeric-operand path, transcribed from
// spec/core/Bitcoin/Interpreter/Defs.lean and spec/core/Bitcoin/Numeric, with
// the decode body taken from the generated twin's `decode_num`
// (twin/runtime.inc:167-188), the canonical encoder from the generated twin's
// `encode_num` (twin/runtime.inc:139-158) and the policy/activation bit values
// from the generated twin's constants (twin/runtime.inc:348-352).
//
//   Defs.lean:629-632  decodeNum pol b maxSize =
//       match decodeScriptNum b pol.minimalData maxSize with
//       | some n => .ok n | none => .error .scriptNum
//   Numeric/Interface.lean:45-47  decodeScriptNum b minimal maxSize =
//       decodeBE minimal maxSize (bytesOf b).reverse
//   Numeric/Interface.lean:55-56  encodeScriptNum n minimal =
//       bytesFromLE (scriptNumBE n).reverse        (canonical, ignores flag)
//   Defs.lean:857-875  OP_CHECKLOCKTIMEVERIFY / OP_CHECKSEQUENCEVERIFY
//   Defs.lean:1069-1090 stepBody.checkMultiSig
//   Defs.lean:803-811, :1048-1059  OP_CHECKSIGADD / checksigAddStep
//
// The minimality predicate is the Lean `minimalOkBE` byte-level form
// (PDW80.minimalOkBE_reverse_iff): non-minimal iff len > 0, the top byte
// modulo its sign bit is zero, and either the operand is one byte or the
// second-to-top byte's high bit is clear.
//
// TRUST NOTE.  The shared generated twin has no CLTV/CSV decode and no
// CHECKMULTISIG handler (ops_ir.py:42-61 returns TWIN_INVALID_UNSUPPORTED with
// the activation flag on; gen.py:222-225 lists CHECKMULTISIG unsupported), so
// the handler arms are a reviewed transcription of the pinned Defs.lean
// equations.  The decoder (`decode_num`) and encoder (`encode_num`) bodies are
// generated twin code, copied verbatim except for the loop shapes: the decode
// loop is specialised on the concrete operand length (<= 5 after the width
// guard) and the encode loop is bounded at five magnitude steps (|value| <
// 2^39 on this domain, one extra sign/pad byte).  This is the README section 3
// fallback; the L link is a reviewed transliteration, not generated handler
// code.
//
// OPERAND DOMAIN.  `len` is a full 32-bit length.  Every stack element that
// can reach these decodes has size <= 520 (interpreter.cpp:457-458 rejects a
// larger push), and both caps are <= 5, so the width guard at script.h:249 or
// its Lean counterpart (decodeBE) returns before the value path for len > 5.
// The five bytes are packed into a register word, so no operand memory is
// read at any index; indices > 4 are never reached for len <= 5.
//
// Observable identical to the C leg (see c_leaf.cpp):
//   predicate functions
//     bit 0 accept, bit 1 width reject, bit 2 non-minimal,
//     bit 3 roundtrip (serialize(set_vch(operand)) == operand),
//     bit 4 decoded value < 0, bit 5 decoded value == 0, bit 6 fRequireMinimal,
//     bits 8..63 low 56 bits of the decoded value (0 when rejected)
//   handler functions
//     result(2) | error_kind(6) << 2.

namespace {

static inline __attribute__((always_inline)) uint64_t cell_pack(uint32_t res,
                                                                uint32_t err) {
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2);
}

static inline __attribute__((always_inline)) uint32_t ord(twin::TwinErr e) {
  return (uint32_t)twin::core_ordinal(e);
}

// The five-byte element, little-endian, packed into a register (identical
// harness to the C leg).
static inline __attribute__((always_inline)) uint64_t
pack5(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4) {
  return (uint64_t)b0 | ((uint64_t)b1 << 8) | ((uint64_t)b2 << 16) |
         ((uint64_t)b3 << 24) | ((uint64_t)b4 << 32);
}

struct NumDec {
  bool ok;
  int64_t v;
};

// twin::decode_num's value path (runtime.inc:175-188), unrolled over the five
// possible byte positions: every byte below the top contributes eight bits,
// the top byte contributes seven (its 0x80 is the sign), and the sign is the
// top byte's high bit.
static inline __attribute__((always_inline)) int64_t
ldecode_value(uint64_t p, uint32_t len) {
  if (len == 0) return 0;
  uint64_t v = 0;
  {
    uint64_t byte = p & 0xffu;
    if (1u == len) byte &= 0x7fu;
    v |= byte;
  }
  if (len > 1) {
    uint64_t byte = (p >> 8) & 0xffu;
    if (2u == len) byte &= 0x7fu;
    v |= byte << 8;
  }
  if (len > 2) {
    uint64_t byte = (p >> 16) & 0xffu;
    if (3u == len) byte &= 0x7fu;
    v |= byte << 16;
  }
  if (len > 3) {
    uint64_t byte = (p >> 24) & 0xffu;
    if (4u == len) byte &= 0x7fu;
    v |= byte << 24;
  }
  if (len > 4) {
    uint64_t byte = (p >> 32) & 0xffu;
    if (5u == len) byte &= 0x7fu;
    v |= byte << 32;
  }
  const bool neg = (((uint8_t)((p >> (8u * (len - 1u))) & 0xffu)) & 0x80u) != 0;
  return neg ? -static_cast<int64_t>(v) : static_cast<int64_t>(v);
}

// twin::decode_num (runtime.inc:167-188): width guard, minimality test in
// Core/Lean order, then the value path.  The body is the generated twin's,
// with the byte loop specialised as ldecode_value.
static inline __attribute__((always_inline)) NumDec
l_scriptnum(uint64_t p, uint32_t len, bool minimal, uint32_t maxSize) {
  if (len > maxSize) return {false, 0};
  if (minimal && len > 0) {
    const uint8_t last = (uint8_t)((p >> (8u * (len - 1u))) & 0xffu);
    if ((last & 0x7fu) == 0) {
      if (len <= 1) return {false, 0};
      const uint8_t prev = (uint8_t)((p >> (8u * (len - 2u))) & 0xffu);
      if ((prev & 0x80u) == 0) return {false, 0};
    }
  }
  return {true, ldecode_value(p, len)};
}

// twin::encode_num (runtime.inc:139-158), unrolled.  |value| < 2^39 on this
// domain (five operand bytes), so at most five magnitude bytes and one
// sign/pad byte.  The canonical bytes are packed little-endian into the
// returned word; `n` receives the length.
static inline __attribute__((always_inline)) uint64_t
lean_encode(int64_t v, uint32_t& n) {
  n = 0;
  if (v == 0) return 0;
  const bool neg = v < 0;
  uint64_t a = neg ? (static_cast<uint64_t>(-(v + 1)) + 1u)
                   : static_cast<uint64_t>(v);
  uint64_t p = 0;
  if (a != 0) { p |= (a & 0xffu) << 0;  a >>= 8; n = 1; }
  if (a != 0) { p |= (a & 0xffu) << 8;  a >>= 8; n = 2; }
  if (a != 0) { p |= (a & 0xffu) << 16; a >>= 8; n = 3; }
  if (a != 0) { p |= (a & 0xffu) << 24; a >>= 8; n = 4; }
  if (a != 0) { p |= (a & 0xffu) << 32; a >>= 8; n = 5; }
  const uint8_t top = (uint8_t)((p >> (8u * (n - 1u))) & 0xffu);
  if ((top & 0x80u) != 0) {
    p |= (uint64_t)(neg ? 0x80u : 0x00u) << (8u * n);
    n = n + 1;
  } else if (neg) {
    p |= 0x80ull << (8u * (n - 1u));
  }
  return p;
}

// Independent characterisation of the minimal-encoding predicate:
//   operand is minimal  <=>  serialize(set_vch(operand)) == operand.
// Computed by re-encoding with the twin's encode_num, never by the two-byte
// test at script.h:259-268 / minimalOkBE.
static inline __attribute__((always_inline)) bool
roundtrip_eq(uint64_t p, uint32_t len, int64_t value) {
  if (value == 0) return len == 0;
  uint32_t n = 0;
  const uint64_t cv = lean_encode(value, n);
  if (n != len) return false;
  const uint64_t pm = p & ((1ull << (8u * len)) - 1u);
  return cv == pm;
}

static inline __attribute__((always_inline)) uint64_t
pred_body(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4,
          uint32_t len, uint64_t flags, uint32_t cap) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  const bool md = (flags & twin::F_MINIMALDATA) != 0;
  const bool width = len > cap;
  bool nonmin = false;
  bool rt = false;
  bool accept = false;
  bool neg = false;
  bool zero = true;
  int64_t value = 0;
  if (!width) {
    if (len > 0 && ((uint8_t)((p >> (8u * (len - 1u))) & 0xffu) & 0x7fu) == 0) {
      if (len <= 1 ||
          ((uint8_t)((p >> (8u * (len - 2u))) & 0xffu) & 0x80u) == 0)
        nonmin = true;
    }
    value = ldecode_value(p, len);
    neg = value < 0;
    zero = value == 0;
    rt = roundtrip_eq(p, len, value);
    accept = !(md && nonmin);
  }
  uint64_t r = (uint64_t)accept | ((uint64_t)width << 1) |
               ((uint64_t)nonmin << 2) | ((uint64_t)rt << 3) |
               ((uint64_t)neg << 4) | ((uint64_t)zero << 5) |
               ((uint64_t)md << 6);
  if (accept) r |= ((uint64_t)value & 0x00FFFFFFFFFFFFFFull) << 8;
  return r;
}

}  // namespace

extern "C" __attribute__((flatten)) uint64_t
pred_cap5(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4,
          uint32_t len, uint64_t flags) {
  return pred_body(b0, b1, b2, b3, b4, len, flags, 5u);
}

extern "C" __attribute__((flatten)) uint64_t
pred_cap4(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4,
          uint32_t len, uint64_t flags) {
  return pred_body(b0, b1, b2, b3, b4, len, flags, 4u);
}

extern "C" __attribute__((flatten)) uint64_t
cell_cltv(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4,
          uint32_t len, uint64_t flags, uint16_t depth) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  if ((flags & twin::F_CLTV) == 0) return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
  if ((int32_t)depth < 1)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  const bool md = (flags & twin::F_MINIMALDATA) != 0;
  const NumDec d = l_scriptnum(p, len, md, 5u);
  if (!d.ok) return cell_pack(0, ord(twin::TWIN_SCRIPTNUM));
  if (d.v < 0) return cell_pack(0, ord(twin::TWIN_NEGATIVE_LOCKTIME));
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}

extern "C" __attribute__((flatten)) uint64_t
cell_csv(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4,
         uint32_t len, uint64_t flags, uint16_t depth) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  if ((flags & twin::F_CSV) == 0) return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
  if ((int32_t)depth < 1)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  const bool md = (flags & twin::F_MINIMALDATA) != 0;
  const NumDec d = l_scriptnum(p, len, md, 5u);
  if (!d.ok) return cell_pack(0, ord(twin::TWIN_SCRIPTNUM));
  if (d.v < 0) return cell_pack(0, ord(twin::TWIN_NEGATIVE_LOCKTIME));
  if (((uint64_t)d.v & 0x80000000ull) != 0)
    return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}

extern "C" __attribute__((flatten)) uint64_t
cell_cms(uint8_t k0, uint8_t k1, uint8_t k2, uint8_t k3, uint8_t k4,
         uint32_t klen, uint8_t s0, uint8_t s1, uint8_t s2, uint8_t s3,
         uint8_t s4, uint32_t slen, uint64_t flags, uint16_t depth,
         uint16_t opcount, uint8_t sigversion) {
  const uint64_t kp = pack5(k0, k1, k2, k3, k4);
  const uint64_t sp = pack5(s0, s1, s2, s3, s4);
  if (sigversion == 2u)
    return cell_pack(0, ord(twin::TWIN_TAPSCRIPT_CHECKMULTISIG));
  if ((int32_t)depth < 1)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  const bool md = (flags & twin::F_MINIMALDATA) != 0;
  const NumDec k = l_scriptnum(kp, klen, md, 4u);
  if (!k.ok) return cell_pack(0, ord(twin::TWIN_SCRIPTNUM));
  if (k.v < 0 || k.v > 20) return cell_pack(0, ord(twin::TWIN_PUBKEY_COUNT));
  const int32_t op2 = (int32_t)opcount + (int32_t)k.v;
  if (op2 > 201) return cell_pack(0, ord(twin::TWIN_OP_COUNT));
  if ((int32_t)depth < (int32_t)k.v + 2)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  const NumDec s = l_scriptnum(sp, slen, md, 4u);
  if (!s.ok) return cell_pack(0, ord(twin::TWIN_SCRIPTNUM));
  if (s.v < 0 || k.v < s.v) return cell_pack(0, ord(twin::TWIN_SIG_COUNT));
  if ((int32_t)depth < (int32_t)k.v + (int32_t)s.v + 3)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}

extern "C" __attribute__((flatten)) uint64_t
cell_checksigadd(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4,
                 uint32_t len, uint64_t flags, uint16_t depth,
                 uint8_t sigversion) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  if (sigversion == 0u || sigversion == 1u)
    return cell_pack(0, ord(twin::TWIN_BAD_OPCODE));
  if ((int32_t)depth < 3)
    return cell_pack(0, ord(twin::TWIN_INVALID_STACK_OPERATION));
  const bool md = (flags & twin::F_MINIMALDATA) != 0;
  const NumDec d = l_scriptnum(p, len, md, 4u);
  if (!d.ok) return cell_pack(0, ord(twin::TWIN_SCRIPTNUM));
  return cell_pack(1, (uint32_t)EQUIV_ERR_OK);
}
