#include <cstdint>
#include "error_kind.h"

// C leg: source-excerpt slices of Bitcoin Core cce32b168 (src/script/script.h
// and src/script/interpreter.cpp) for the five numeric-operand decode sites
// named by SCR-051.
//
//   script.h:246-271   CScriptNum(vch, fRequireMinimal, nMaxNumSize)
//       :249-251  if (vch.size() > nMaxNumSize) throw scriptnum_error;
//       :252-269  if (fRequireMinimal && vch.size() > 0)
//                     if ((vch.back() & 0x7f) == 0)
//                         if (vch.size() <= 1 || (vch[vch.size()-2] & 0x80) == 0)
//                             throw scriptnum_error;
//       :270      m_value = set_vch(vch);
//   script.h:342-373   serialize(value): canonical LE sign-magnitude; 0 is
//                      the empty vector; one extra sign/pad byte when the
//                      magnitude's top byte has bit 7 set.
//   script.h:376-391   set_vch: LE sign-magnitude, 0x80 in the top byte is
//                      the sign bit; negative zero decodes to 0.
//   interpreter.cpp:442  fRequireMinimal = (flags & SCRIPT_VERIFY_MINIMALDATA)
//   interpreter.cpp:1233-1238  catch (scriptnum_error) => SCRIPT_ERR_SCRIPTNUM
//   interpreter.cpp:534-571   OP_CHECKLOCKTIMEVERIFY (:556, cap 5)
//   interpreter.cpp:574-602   OP_CHECKSEQUENCEVERIFY (:584, cap 5)
//   interpreter.cpp:1092-1109 OP_CHECKSIGADD (:1103, default cap 4)
//   interpreter.cpp:1113-1152 OP_CHECKMULTISIG counts (:1126, :1140, cap 4)
//
// OPERAND DOMAIN.  `len` is a full 32-bit length, not a truncated field: every
// stack element that can reach these decodes has size <= MAX_SCRIPT_ELEMENT_SIZE
// (520), because EvalScript rejects a larger push at interpreter.cpp:457-458 and
// every other element entered the stack through a push.  The five bytes pack the
// low five bytes of the element into `p`.  Both caps are <= 5, so the width guard
// at script.h:249 returns before the value path is entered for len > 5, and for
// len <= 5 only byte indices len-1 and len-2 (<= 4) are consulted.  Proving the
// functions for the full 32-bit length therefore covers every legal operand
// length, 0..520, and the unreachable >520 ones.
//
// The vector byte loop of set_vch is specialised to the five-byte domain (the
// pack/unpack below); this is the same specialisation the family's other
// numeric cells use.
//
// OBSERVABLE (identical on both legs):
//   predicate functions
//     bit 0     accept (1 = the constructor would return a value)
//     bit 1     width reject (len > cap)
//     bit 2     non-minimal under the script.h:252-269 test
//     bit 3     roundtrip: serialize(set_vch(operand)) == operand
//     bit 4     decoded value < 0
//     bit 5     decoded value == 0
//     bit 6     fRequireMinimal (bit 6 of the flags word)
//     bits 8..63 low 56 bits of the decoded value (0 when rejected)
//   handler functions
//     result(2) | error_kind(6) << 2, as every cell in this family.

namespace {

constexpr uint64_t F_MINIMALDATA = 0x000040ull;  // SCRIPT_VERIFY_MINIMALDATA
constexpr uint64_t F_CLTV = 0x000200ull;         // SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY
constexpr uint64_t F_CSV = 0x000400ull;          // SCRIPT_VERIFY_CHECKSEQUENCEVERIFY
constexpr int32_t MAX_PUBKEYS_PER_MULTISIG = 20;  // interpreter.h
constexpr int32_t MAX_OPS_PER_SCRIPT = 201;       // interpreter.h

static inline __attribute__((always_inline)) uint64_t cell_pack(uint32_t res,
                                                                uint32_t err) {
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2);
}

// The five-byte element, little-endian, packed into a register.
static inline __attribute__((always_inline)) uint64_t
pack5(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4) {
  return (uint64_t)b0 | ((uint64_t)b1 << 8) | ((uint64_t)b2 << 16) |
         ((uint64_t)b3 << 24) | ((uint64_t)b4 << 32);
}

struct NumDec {
  bool ok;
  int64_t v;
};

// script.h:376-391 (set_vch), specialised to len <= 5: the byte loop becomes a
// mask, the top byte's 0x80 is the sign bit, and negative zero decodes to 0.
static inline __attribute__((always_inline)) int64_t set_vch5(uint64_t p,
                                                              uint32_t len) {
  if (len == 0) return 0;
  const uint64_t pm = p & ((1ull << (8u * len)) - 1u);
  const uint64_t sbit = 0x80ull << (8u * (len - 1u));
  if ((pm & sbit) != 0) return -(int64_t)(pm & ~sbit);
  return (int64_t)pm;
}

// script.h:246-271, with the width guard (:249) exactly before the
// minimality test (:252) and the tests in Core's order.
static inline __attribute__((always_inline)) NumDec
cs_scriptnum(uint64_t p, uint32_t len, bool minimal, uint32_t maxsize) {
  if (len > maxsize) return {false, 0};
  if (minimal && len > 0) {
    const uint8_t last = (uint8_t)((p >> (8u * (len - 1u))) & 0xffu);
    if ((last & 0x7fu) == 0) {
      if (len <= 1) return {false, 0};
      const uint8_t prev = (uint8_t)((p >> (8u * (len - 2u))) & 0xffu);
      if ((prev & 0x80u) == 0) return {false, 0};
    }
  }
  return {true, set_vch5(p, len)};
}

// script.h:342-373 (serialize), transcribed with the unbounded `while
// (absvalue)` closed: |value| < 2^40 on this domain, so the magnitude has at
// most five bytes and at most one sign/pad byte follows.  Returns the length;
// the canonical bytes are written to `out[0..n)`.
static inline __attribute__((always_inline)) uint32_t
encode_canonical(int64_t value, uint8_t* out) {
  if (value == 0) return 0;
  const bool neg = value < 0;
  const uint64_t a = neg ? ~(uint64_t)value + 1u : (uint64_t)value;
  uint32_t n;
  if (a < 0x100ull) n = 1;
  else if (a < 0x10000ull) n = 2;
  else if (a < 0x1000000ull) n = 3;
  else if (a < 0x100000000ull) n = 4;
  else n = 5;
  out[0] = (uint8_t)(a & 0xffu);
  out[1] = (uint8_t)((a >> 8) & 0xffu);
  out[2] = (uint8_t)((a >> 16) & 0xffu);
  out[3] = (uint8_t)((a >> 24) & 0xffu);
  out[4] = (uint8_t)((a >> 32) & 0xffu);
  if ((out[n - 1] & 0x80u) != 0) {
    out[n] = neg ? 0x80u : 0x00u;
    n = n + 1;
  } else if (neg) {
    out[n - 1] = (uint8_t)(out[n - 1] | 0x80u);
  }
  return n;
}

// Independent characterisation of the minimal-encoding predicate:
//   operand is minimal  <=>  serialize(set_vch(operand)) == operand.
// Computed by re-encoding, never by the two-byte test at script.h:259-268.
static inline __attribute__((always_inline)) bool
roundtrip_eq(uint64_t p, uint32_t len, int64_t value) {
  const uint64_t pm = p & ((1ull << (8u * len)) - 1u);
  if (value == 0) return len == 0;
  const bool neg = value < 0;
  const uint64_t a = neg ? ~(uint64_t)value + 1u : (uint64_t)value;
  uint32_t n;
  if (a < 0x100ull) n = 1;
  else if (a < 0x10000ull) n = 2;
  else if (a < 0x1000000ull) n = 3;
  else if (a < 0x100000000ull) n = 4;
  else n = 5;
  uint64_t cv = a & 0xffffffffffull;
  uint32_t cn = n;
  if ((((uint8_t)((a >> (8u * (n - 1u))) & 0xffu)) & 0x80u) != 0) {
    cv |= (uint64_t)(neg ? 0x80u : 0x00u) << (8u * n);
    cn = n + 1;
  } else if (neg) {
    cv |= 0x80ull << (8u * (n - 1u));
  }
  return cn == len && cv == (uint64_t)pm;
}

// The shared predicate/observable body for both caps.
static inline __attribute__((always_inline)) uint64_t
pred_body(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4,
          uint32_t len, uint64_t flags, uint32_t cap) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  const bool md = (flags & F_MINIMALDATA) != 0;
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
    value = set_vch5(p, len);
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

// The minimal-encoding predicate for an arbitrary numeric operand, cap 5
// (the OP_CHECKLOCKTIMEVERIFY / OP_CHECKSEQUENCEVERIFY constructor).
extern "C" uint64_t pred_cap5(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                              uint8_t b4, uint32_t len, uint64_t flags) {
  return pred_body(b0, b1, b2, b3, b4, len, flags, 5u);
}

// The same predicate at the 4-byte default cap (OP_CHECKSIGADD's number and
// the two OP_CHECKMULTISIG counts).
extern "C" uint64_t pred_cap4(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                              uint8_t b4, uint32_t len, uint64_t flags) {
  return pred_body(b0, b1, b2, b3, b4, len, flags, 4u);
}

// interpreter.cpp:534-571.  Order: activation flag (:536-539), stack floor
// (:541-542), decode cap 5 (:556), NEGATIVE_LOCKTIME (:561-562).  The
// CheckLockTime comparison follows and belongs to SCR-122..SCR-126.
extern "C" uint64_t cell_cltv(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                              uint8_t b4, uint32_t len, uint64_t flags,
                              uint16_t depth) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  if ((flags & F_CLTV) == 0) return cell_pack(1, EQUIV_ERR_OK);
  if ((int32_t)depth < 1)
    return cell_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  const bool md = (flags & F_MINIMALDATA) != 0;
  const NumDec d = cs_scriptnum(p, len, md, 5u);
  if (!d.ok) return cell_pack(0, EQUIV_ERR_SCRIPTNUM);
  if (d.v < 0) return cell_pack(0, EQUIV_ERR_NEGATIVE_LOCKTIME);
  return cell_pack(1, EQUIV_ERR_OK);
}

// interpreter.cpp:574-602.  Order: activation flag (:573-576), stack floor
// (:578-579), decode cap 5 (:584), NEGATIVE_LOCKTIME (:589-590), the
// SEQUENCE_LOCKTIME_DISABLE_FLAG NOP (:594-596).  Both post-decode branches
// are OK in this observable; CheckSequence is SCR-129.
extern "C" uint64_t cell_csv(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                             uint8_t b4, uint32_t len, uint64_t flags,
                             uint16_t depth) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  if ((flags & F_CSV) == 0) return cell_pack(1, EQUIV_ERR_OK);
  if ((int32_t)depth < 1)
    return cell_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  const bool md = (flags & F_MINIMALDATA) != 0;
  const NumDec d = cs_scriptnum(p, len, md, 5u);
  if (!d.ok) return cell_pack(0, EQUIV_ERR_SCRIPTNUM);
  if (d.v < 0) return cell_pack(0, EQUIV_ERR_NEGATIVE_LOCKTIME);
  if (((uint64_t)d.v & 0x80000000ull) != 0) return cell_pack(1, EQUIV_ERR_OK);
  return cell_pack(1, EQUIV_ERR_OK);
}

// interpreter.cpp:1113-1152.  Order: tapscript rejection (:1118), stack floor
// (:1122-1124), key-count decode cap 4 (:1126), PUBKEY_COUNT (:1127-1128),
// the nOpCount accumulation and OP_COUNT (:1129-1131), key arity (:1136-1138),
// sig-count decode cap 4 (:1140), SIG_COUNT (:1141-1142), sig arity
// (:1144-1146).  `opcount`/`depth` are 16-bit so Core's `int` arithmetic is
// exact over a superset of the reachable values (<= 201 and <= 1000).
extern "C" uint64_t cell_cms(uint8_t k0, uint8_t k1, uint8_t k2, uint8_t k3,
                             uint8_t k4, uint32_t klen, uint8_t s0, uint8_t s1,
                             uint8_t s2, uint8_t s3, uint8_t s4, uint32_t slen,
                             uint64_t flags, uint16_t depth, uint16_t opcount,
                             uint8_t sigversion) {
  const uint64_t kp = pack5(k0, k1, k2, k3, k4);
  const uint64_t sp = pack5(s0, s1, s2, s3, s4);
  if (sigversion == 2u) return cell_pack(0, EQUIV_ERR_TAPSCRIPT_CHECKMULTISIG);
  if ((int32_t)depth < 1)
    return cell_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  const bool md = (flags & F_MINIMALDATA) != 0;
  const NumDec k = cs_scriptnum(kp, klen, md, 4u);
  if (!k.ok) return cell_pack(0, EQUIV_ERR_SCRIPTNUM);
  if (k.v < 0 || k.v > (int64_t)MAX_PUBKEYS_PER_MULTISIG)
    return cell_pack(0, EQUIV_ERR_PUBKEY_COUNT);
  int32_t nOpCount = (int32_t)opcount + (int32_t)k.v;
  if (nOpCount > MAX_OPS_PER_SCRIPT) return cell_pack(0, EQUIV_ERR_OP_COUNT);
  if ((int32_t)depth < (int32_t)k.v + 2)
    return cell_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  const NumDec s = cs_scriptnum(sp, slen, md, 4u);
  if (!s.ok) return cell_pack(0, EQUIV_ERR_SCRIPTNUM);
  if (s.v < 0 || k.v < s.v) return cell_pack(0, EQUIV_ERR_SIG_COUNT);
  if ((int32_t)depth < (int32_t)k.v + (int32_t)s.v + 3)
    return cell_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  return cell_pack(1, EQUIV_ERR_OK);
}

// interpreter.cpp:1092-1109.  Order: base/witnessV0 rejection (:1097), stack
// floor (:1100), number decode cap 4 (:1103).  EvalChecksig and the pushed
// value follow; they are the E4 crypto seam.
extern "C" uint64_t cell_checksigadd(uint8_t b0, uint8_t b1, uint8_t b2,
                                     uint8_t b3, uint8_t b4, uint32_t len,
                                     uint64_t flags, uint16_t depth,
                                     uint8_t sigversion) {
  const uint64_t p = pack5(b0, b1, b2, b3, b4);
  if (sigversion == 0u || sigversion == 1u)
    return cell_pack(0, EQUIV_ERR_BAD_OPCODE);
  if ((int32_t)depth < 3)
    return cell_pack(0, EQUIV_ERR_INVALID_STACK_OPERATION);
  const bool md = (flags & F_MINIMALDATA) != 0;
  const NumDec d = cs_scriptnum(p, len, md, 4u);
  if (!d.ok) return cell_pack(0, EQUIV_ERR_SCRIPTNUM);
  return cell_pack(1, EQUIV_ERR_OK);
}
