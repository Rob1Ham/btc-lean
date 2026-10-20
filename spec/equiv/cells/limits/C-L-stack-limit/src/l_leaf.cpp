#include "limits_common.h"
// L leg — reviewed transliteration of the Lean twin.
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:1131-1136 (stepChecked):
//     match stepBody ctx op st with
//     | .ok st' =>
//         if MAX_STACK_SIZE < st'.stack.length + st'.alt.length then .error .stackSize
//         else .ok st'
//     | .error e => .error e
//
// The same guard appears structurally in the generated twin at
// spec/equiv/twin/runtime.inc:642-643:
//       if (st.stack.n + st.alt.n > MAX_STACK_SIZE) return TWIN_STACK_SIZE;
// It is the terminal check of every executed opcode, and the sum is the
// combined main+alt depth (SCR-030).  There is no per-opcode handler for it.

extern "C" uint64_t cell_stack_limit(uint32_t depth, uint32_t alt) {
  if (depth > 2000 || alt > 2000) return lim_bad_input();

  // Defs.lean:1133-1134: strict `<` with the constant on the left.
  if (LIM_MAX_STACK_SIZE < depth + alt) {
    return lim_pack(0, EQUIV_ERR_STACK_SIZE, 0);
  }
  return lim_pack(1, EQUIV_ERR_OK, depth + alt);
}
