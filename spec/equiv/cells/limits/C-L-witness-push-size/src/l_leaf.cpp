#include "limits_common.h"
// L leg — reviewed transliteration of the Lean twin.
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:1207-1239 (executeWitnessScript):
//     if sv = .tapscript then
//       if opSuccessScan exec then
//         if pol.discourageOpSuccess then .fail .discourageOpSuccess else .ok
//       else if MAX_STACK_SIZE < items.length then .fail .stackSize
//       else runExec items
//     else runExec items
//   where runExec items :=
//       if items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) then .fail .pushSize
//       else match evalScriptBytes ... with ...
//
// `items.any (fun d => 520 < d.size)` is modelled by `max_item > 520`; the
// predicate is exact for the item-size check even though the loop is not
// unrolled.  `opSuccessScan` stays an abstract boolean.  The generated twin
// has no witness engine yet, so this is a transliteration of the Lean
// definition rather than a twin handler.

extern "C" uint64_t cell_witness_push_size(uint32_t depth, uint16_t max_item,
                                           uint8_t sv, uint8_t has_success,
                                           uint8_t discourage) {
  if (!lim_valid_sigversion(sv) || depth > 2000 || has_success > 1 ||
      discourage > 1) {
    return lim_bad_input();
  }

  if (sv == LIM_SV_TAPSCRIPT) {
    // Defs.lean:1214-1215.
    if (has_success) {
      if (discourage) return lim_pack(0, EQUIV_ERR_DISCOURAGE_OP_SUCCESS, 0);
      return lim_pack(1, EQUIV_ERR_OK, 0);
    }
    // Defs.lean:1214.
    if (LIM_MAX_STACK_SIZE < depth) {
      return lim_pack(0, EQUIV_ERR_STACK_SIZE, 0);
    }
  }

  // Defs.lean:1220-1222 (runExec item-size loop).
  if (LIM_MAX_SCRIPT_ELEMENT_SIZE < max_item) {
    return lim_pack(0, EQUIV_ERR_PUSH_SIZE, 0);
  }
  return lim_pack(1, EQUIV_ERR_OK, 0);
}
