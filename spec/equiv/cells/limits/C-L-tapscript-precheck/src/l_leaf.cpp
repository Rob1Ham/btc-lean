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
// The item-size loop is SCR-021 and is assumed satisfied here; EvalScript is
// the opaque outcome `inner_err`.  `items.length` is the decoded witness stack
// count, i.e. the main-stack depth with the alt stack empty.  The generated
// twin has no witness engine yet (runtime.inc returns TWIN_INVALID_UNSUPPORTED
// for the witness path, E4 scope), so this is a transliteration of the Lean
// definition rather than a twin handler.

extern "C" uint64_t cell_tap_precheck(uint32_t depth, uint8_t sv,
                                      uint8_t has_success, uint8_t discourage,
                                      uint8_t inner_err) {
  if (!lim_valid_sigversion(sv) || depth > 2000 || has_success > 1 ||
      discourage > 1 || inner_err > EQUIV_ERR_COUNT) {
    return lim_bad_input();
  }

  if (sv == LIM_SV_TAPSCRIPT) {
    // Defs.lean:1214-1215: OP_SUCCESSx (abstract `opSuccessScan exec`).
    if (has_success) {
      if (discourage) return lim_pack(0, EQUIV_ERR_DISCOURAGE_OP_SUCCESS, 0);
      return lim_pack(1, EQUIV_ERR_OK, 0);
    }
    // Defs.lean:1216: MAX_STACK_SIZE < items.length, before runExec/EvalScript.
    if (LIM_MAX_STACK_SIZE < depth) {
      return lim_pack(0, EQUIV_ERR_STACK_SIZE, 0);
    }
  }

  // runExec's item-size loop assumed satisfied (SCR-021), then EvalScript.
  if (inner_err == EQUIV_ERR_OK) return lim_pack(1, EQUIV_ERR_OK, 0);
  return lim_pack(0, inner_err, 0);
}
