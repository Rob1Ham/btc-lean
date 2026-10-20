#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the verified Lean definition
//   spec/core/Bitcoin/Interpreter/Defs.lean:1207-1241
// (`Bitcoin.Interpreter.executeWitnessScript`), post-state branch:
//
//   match evalScriptBytes ... with
//   | .ok st =>
//     if st.length ≠ 1 then .fail .cleanstack
//     else if castToBool st[0]! then .ok else .fail .evalFalse
//
// `stack_size` is st.length and `top_truthy` is castToBool st[0]!.  The
// EvalScript result is an input to this cell (the Lean function's `match`
// subject); it is not re-run.  Error ordinals are the shared values:
// cleanstack=30, evalFalse=2.

extern "C" uint64_t cell_v0_cleanstack(uint64_t stack_size, uint64_t top_truthy) {
    if (stack_size != 1) return wv_pack(0, 30);   // .cleanstack
    if (!top_truthy) return wv_pack(0, 2);        // .evalFalse
    return wv_pack(1, 0);                         // .ok
}
