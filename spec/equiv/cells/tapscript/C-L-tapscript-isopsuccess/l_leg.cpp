#include "cell_common.h"

// L leg: REVIEWED TRANSLITERATION, not generated from the twin.
//
// Exact Verified Lean definition
//   Bitcoin.Interpreter.Defs.isOpSuccessWire
//     (spec/core/Bitcoin/Interpreter/Defs.lean:463-466):
//
//   def isOpSuccessWire (w : Nat) : Bool :=
//     w = 80 ∨ w = 98 ∨ (126 ≤ w ∧ w ≤ 129) ∨ (131 ≤ w ∧ w ≤ 134) ∨
//     (137 ≤ w ∧ w ≤ 138) ∨ (141 ≤ w ∧ w ≤ 142) ∨ (149 ≤ w ∧ w ≤ 153) ∨
//     (187 ≤ w ∧ w ≤ 254)
//
// The Nat domain is total, matching the C leg's total 64-bit input.
TAP_INLINE uint64_t l_is_op_success(uint64_t w) {
  const bool r = w == 80u || w == 98u || (126u <= w && w <= 129u) ||
                 (131u <= w && w <= 134u) || (137u <= w && w <= 138u) ||
                 (141u <= w && w <= 142u) || (149u <= w && w <= 153u) ||
                 (187u <= w && w <= 254u);
  return tap_bool(r);
}

extern "C" uint64_t cell_is_op_success(uint64_t opcode) {
  return l_is_op_success(opcode);
}
