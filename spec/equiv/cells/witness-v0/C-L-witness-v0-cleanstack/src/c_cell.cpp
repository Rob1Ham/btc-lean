#include "wv_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66,
// the tail of ExecuteWitnessScript (interpreter.cpp:1874-1879):
//
//   // Run the script interpreter.
//   if (!EvalScript(stack, exec_script, ...)) return false;
//
//   // Scripts inside witness implicitly require cleanstack behaviour
//   if (stack.size() != 1) return set_error(serror, SCRIPT_ERR_CLEANSTACK);
//   if (!CastToBool(stack.back())) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);
//   return true;
//
// The post-state is the observable: `stack_size` is stack.size() after
// EvalScript and `top_truthy` is CastToBool(stack.back()).  CastToBool itself
// is a separate ledger row (SCR-057) and is not re-implemented here; the cell
// proves the cleanstack/truthy dispatch over every stack size and both
// truthiness values.  EvalScript is not run (SCR-001/138 boundary).
//
// Error ordinals: 30 SCRIPT_ERR_CLEANSTACK, 2 SCRIPT_ERR_EVAL_FALSE.

extern "C" uint64_t cell_v0_cleanstack(uint64_t stack_size, uint64_t top_truthy) {
    if (stack_size != 1) return wv_pack(0, 30);   // SCRIPT_ERR_CLEANSTACK
    if (!top_truthy) return wv_pack(0, 2);        // SCRIPT_ERR_EVAL_FALSE
    return wv_pack(1, 0);
}
