#include "limits_common.h"
// C leg — source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:1842-1874 (ExecuteWitnessScript):
//       std::vector<valtype> stack{stack_span.begin(), stack_span.end()};
//       if (sigversion == SigVersion::TAPSCRIPT) {
//           // OP_SUCCESSx processing overrides everything, including stack
//           // element size limits
//           while (pc < exec_script.end()) { ... if (IsOpSuccess(opcode)) {
//               if (flags & SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS)
//                   return set_error(serror, SCRIPT_ERR_DISCOURAGE_OP_SUCCESS);
//               return set_success(serror); } }
//           // Tapscript enforces initial stack size limits (altstack is empty here)
//           if (stack.size() > MAX_STACK_SIZE) return set_error(serror, SCRIPT_ERR_STACK_SIZE);
//       }
//       for (const valtype& elem : stack) { /* SCR-021 item size, separate row */ }
//       if (!EvalScript(stack, exec_script, ...)) return false;
//
// This cell models the pre-EvalScript ordering and the initial-stack guard:
//   - the OP_SUCCESSx scan over the tapscript is an OP_SUCCESS boolean input
//     (the scan itself over script bytes is SCR-153 and is not modelled);
//   - the item-size loop is SCR-021 and is assumed satisfied here;
//   - EvalScript is an opaque outcome `inner_err` (a Core ScriptError ordinal;
//     0 means it returned true).  The row is the guard *placement*.
// `altstack is empty here` means the pre-check sees the main stack only; the
// model has no alt stack, i.e. alt depth 0.

extern "C" uint64_t cell_tap_precheck(uint32_t depth, uint8_t sv,
                                      uint8_t has_success, uint8_t discourage,
                                      uint8_t inner_err) {
  if (!lim_valid_sigversion(sv) || depth > 2000 || has_success > 1 ||
      discourage > 1 || inner_err > EQUIV_ERR_COUNT) {
    return lim_bad_input();
  }

  if (sv == LIM_SV_TAPSCRIPT) {
    // interpreter.cpp:1846-1862 scan outcome, abstracted to has_success.
    if (has_success) {
      if (discourage) return lim_pack(0, EQUIV_ERR_DISCOURAGE_OP_SUCCESS, 0);
      return lim_pack(1, EQUIV_ERR_OK, 0);
    }
    // interpreter.cpp:1864-1865: main-stack only, altstack empty.
    if (depth > LIM_MAX_STACK_SIZE) {
      return lim_pack(0, EQUIV_ERR_STACK_SIZE, 0);
    }
  }

  // interpreter.cpp:1868-1871 item-size loop assumed satisfied (SCR-021),
  // then interpreter.cpp:1874 EvalScript returns `inner_err`.
  if (inner_err == EQUIV_ERR_OK) return lim_pack(1, EQUIV_ERR_OK, 0);
  return lim_pack(0, inner_err, 0);
}
