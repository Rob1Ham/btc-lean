#include "negzero_common.h"

// C leg: source-excerpt slice of Bitcoin Core at the pin cce32b168.
//
//   src/script/script.h:246-271  CScriptNum(vch, fRequireMinimal, 4)
//       the width guard `vch.size() > nMaxNumSize` is the only guard in
//       this slice: the numeric operand path of the cell sets
//       fRequireMinimal = false (the minimality rule is SCR-084).
//   src/script/script.h:376-391  set_vch
//       little-endian accumulation, sign bit 0x80 on the most-significant
//       (wire-last) byte; 0x80 is *negative zero*, i.e. it decodes to 0
//       (the `-((int64_t)(result & ~sign))` arm).
//   src/script/interpreter.cpp:46-61  CastToBool
//       false for the empty vector and for a lone 0x80 in the top
//       position (`i == vch.size()-1 && vch[i] == 0x80`).
//
// SCRIPT_ERR_SCRIPTNUM = 4 is the error EvalScript's catch block sets for
// scriptnum_error (contract/error_kind.h; interpreter.cpp:432-437).
//
// Bound: the default four-byte CScriptNum operand.  Both loops have a
// constant four-iteration bound with an `i < n` guard and are fully
// unrolled, so the emitted leaf is loop-free and every byte access has a
// constant index.  The `~(0x80 << 8*(n-1))` mask keeps the shift amount
// symbolic, exactly as in the source; n <= 4 is established by the guard.

NZ_INLINE int64_t core_set_vch(const uint8_t vch[4], uint32_t n) {
  if (n == 0) return 0;                              // script.h:378-379
  int64_t result = 0;
#pragma clang loop unroll(full)
  for (uint32_t i = 0; i < 4; ++i) {
    if (i < n) result |= static_cast<int64_t>(vch[i]) << (8 * i);  // :381-383
  }
  if ((vch[n - 1] & 0x80u) != 0) {                   // :386-389
    return -static_cast<int64_t>(static_cast<uint64_t>(result) &
                                 ~(0x80ULL << (8 * (n - 1))));
  }
  return result;                                     // :390
}

NZ_INLINE bool core_cast_to_bool(const uint8_t vch[4], uint32_t n) {
#pragma clang loop unroll(full)
  for (uint32_t i = 0; i < 4; ++i) {
    if (i < n && vch[i] != 0) {
      if (i == n - 1 && vch[i] == 0x80) return false;  // negative zero
      return true;
    }
  }
  return false;
}

extern "C" uint64_t cell_negzero(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3,
                                 uint32_t len) {
  if (len > 4) return nz_pack(4, 0, false);          // scriptnum_error
  const uint8_t vch[4] = {b0, b1, b2, b3};
  const int64_t v = core_set_vch(vch, len);
  return nz_pack(0, v, core_cast_to_bool(vch, len));
}
