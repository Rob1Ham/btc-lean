#include "limits_common.h"
// C leg — source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:1231-1233
//       // Size limits
//       if (stack.size() + altstack.size() > MAX_STACK_SIZE)
//           return set_error(serror, SCRIPT_ERR_STACK_SIZE);
//   src/script/script.h:44   MAX_STACK_SIZE = 1000
//
// The guard runs after every executed opcode (inside the `for` body, after
// the opcode switch), over the combined main+alt depth.  This cell models
// that predicate with both depths symbolic; the per-opcode placement is the
// loop structure around the guard, which the row states and this predicate
// does not alter.  `depth`/`alt` are bounded to [0, 2000] so the unsigned sum
// cannot wrap and the whole interesting range (> 1000) is covered.

extern "C" uint64_t cell_stack_limit(uint32_t depth, uint32_t alt) {
  if (depth > 2000 || alt > 2000) return lim_bad_input();

  // interpreter.cpp:1232: the combined check, altstack counts.
  if (depth + alt > LIM_MAX_STACK_SIZE) {
    return lim_pack(0, EQUIV_ERR_STACK_SIZE, 0);
  }
  return lim_pack(1, EQUIV_ERR_OK, depth + alt);
}
