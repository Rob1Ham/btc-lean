#include "negzero_common.h"

// L leg: reviewed transliteration of the pinned Lean model, not mk_leaf
// output (mk_leaf's bounded decode is two-byte-only).  The wire vector is
// little-endian; Lean's lists are big-endian, so the wire is reversed.
//
//   Bitcoin.Numeric.setVchBE        spec/core/Bitcoin/Numeric/ScriptNum.lean:449-458
//     | [] => 0
//     | d :: t => if d < 128
//                 then d * 256 ^ t.length + magOfBE t
//                 else -((d - 128) * 256 ^ t.length + magOfBE t)
//   Bitcoin.Numeric.castToBoolList  spec/core/Bitcoin/Numeric/ScriptNum.lean:648-652
//     | [] => false
//     | d :: t => t.any (e != 0) || (d != 0 && d != 128)
//
// Here d is the wire-last byte and t is the reversed wire prefix, so
// magOfBE t is `lower` (vch[0] is the least-significant digit).  The
// Python-style `256 ^ t.length` is the place value of d and is written as
// a constant select; lengths 0..4 are in domain.
//
// The width guard is the CScriptNum constructor's `l.length > maxSize`
// (script.h:246-249) with maxSize = 4; failure is scriptnum_error = 4.

NZ_INLINE int64_t lean_setVchBE(const uint8_t vch[4], uint32_t n) {
  if (n == 0) return 0;                                  // setVchBE [] = 0
  uint32_t lower = 0;                                    // magOfBE t
  if (n >= 2) lower |= static_cast<uint32_t>(vch[0]);
  if (n >= 3) lower |= static_cast<uint32_t>(vch[1]) << 8;
  if (n >= 4) lower |= static_cast<uint32_t>(vch[2]) << 16;
  const uint32_t d = n == 1 ? vch[0] : n == 2 ? vch[1]
                     : n == 3 ? vch[2] : vch[3];          // most-significant
  const uint32_t place = n == 1 ? 1u : n == 2 ? 256u
                         : n == 3 ? 65536u : 16777216u;   // 256 ^ t.length
  if (d < 128) {
    return static_cast<int64_t>(d * place + lower);
  }
  return -static_cast<int64_t>((d - 128) * place + lower);
}

NZ_INLINE bool lean_castToBoolList(const uint8_t vch[4], uint32_t n) {
  if (n == 0) return false;                              // [] => false
  bool lowerAny = false;                                 // t.any (e != 0)
  if (n >= 2 && vch[0] != 0) lowerAny = true;
  if (n >= 3 && vch[1] != 0) lowerAny = true;
  if (n >= 4 && vch[2] != 0) lowerAny = true;
  const uint32_t d = n == 1 ? vch[0] : n == 2 ? vch[1]
                     : n == 3 ? vch[2] : vch[3];
  return lowerAny || (d != 0 && d != 128);               // decide (d != 0 ∧ d != 128)
}

extern "C" uint64_t cell_negzero(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                                 uint32_t len) {
  if (len > 4) return nz_pack(4, 0, false);              // decodeBE => none
  const uint8_t vch[4] = {b0, b1, b2, b3};
  const int64_t v = lean_setVchBE(vch, len);
  return nz_pack(0, v, lean_castToBoolList(vch, len));
}
