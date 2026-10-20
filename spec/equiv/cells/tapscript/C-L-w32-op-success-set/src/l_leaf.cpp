#include "w32_common.h"

// L leg: REVIEWED TRANSLITERATION of
//   spec/core/Bitcoin/Interpreter/Defs.lean:463-468 (`isOpSuccessWire`):
//
//   w = 80 ∨ w = 98 ∨ (126 ≤ w ∧ w ≤ 129) ∨ (131 ≤ w ∧ w ≤ 134) ∨
//   (137 ≤ w ∧ w ≤ 138) ∨ (141 ≤ w ∧ w ≤ 142) ∨ (149 ≤ w ∧ w ≤ 153) ∨
//   (187 ≤ w ∧ w ≤ 254)
//
// The twin has no `IsOpSuccess` handler of its own (it is a model predicate,
// not a stepBody case), so mk_leaf.py emits nothing for it.  The set is written
// in the Lean disjunction order, not in Core's operator order, so the two legs
// are independent formulations of the same BIP342 table.

W32INLINE bool l_is_op_success(uint32_t w) {
    if (w == 80 || w == 98) return true;
    if (126 <= w && w <= 129) return true;
    if (131 <= w && w <= 134) return true;
    if (137 <= w && w <= 138) return true;
    if (141 <= w && w <= 142) return true;
    if (149 <= w && w <= 153) return true;
    if (187 <= w && w <= 254) return true;
    return false;
}

extern "C" uint32_t cell_is_op_success(uint8_t opcode) {
    return l_is_op_success((uint32_t)opcode) ? 1u : 0u;
}
