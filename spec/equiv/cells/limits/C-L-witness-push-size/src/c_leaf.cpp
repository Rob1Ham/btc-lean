#include "limits_common.h"
// C leg — source-excerpt slice of Bitcoin Core cce32b168.
//
//   src/script/interpreter.cpp:1846-1874 (ExecuteWitnessScript):
//       if (sigversion == SigVersion::TAPSCRIPT) {
//           while (pc < exec_script.end()) { if (IsOpSuccess(opcode)) {
//               if (flags & SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS)
//                   return set_error(serror, SCRIPT_ERR_DISCOURAGE_OP_SUCCESS);
//               return set_success(serror); } }
//           if (stack.size() > MAX_STACK_SIZE) return set_error(serror, SCRIPT_ERR_STACK_SIZE);
//       }
//       for (const valtype& elem : stack) {
//           if (elem.size() > MAX_SCRIPT_ELEMENT_SIZE) return set_error(serror, SCRIPT_ERR_PUSH_SIZE);
//       }
//       if (!EvalScript(...)) return false;
//
// `max_item` is the maximum element size over the witness stack, so the loop
// predicate `any (elem.size() > 520)` is exactly `max_item > 520`.  The
// OP_SUCCESSx scan is an input flag (see spec.md: partial coverage, the scan
// itself is SCR-153).  `depth` is the initial item count.  EvalScript is
// assumed to admit the script here; this row is only the item-size check.

extern "C" uint64_t cell_witness_push_size(uint32_t depth, uint16_t max_item,
                                           uint8_t sv, uint8_t has_success,
                                           uint8_t discourage) {
  if (!lim_valid_sigversion(sv) || depth > 2000 || has_success > 1 ||
      discourage > 1) {
    return lim_bad_input();
  }

  if (sv == LIM_SV_TAPSCRIPT) {
    // interpreter.cpp:1846-1862: OP_SUCCESSx scan, abstracted.
    if (has_success) {
      if (discourage) return lim_pack(0, EQUIV_ERR_DISCOURAGE_OP_SUCCESS, 0);
      return lim_pack(1, EQUIV_ERR_OK, 0);
    }
    // interpreter.cpp:1864-1865: initial stack guard (SCR-031).
    if (depth > LIM_MAX_STACK_SIZE) {
      return lim_pack(0, EQUIV_ERR_STACK_SIZE, 0);
    }
  }

  // interpreter.cpp:1868-1871: witness-stack item size limit.
  if (max_item > LIM_MAX_SCRIPT_ELEMENT_SIZE) {
    return lim_pack(0, EQUIV_ERR_PUSH_SIZE, 0);
  }
  // EvalScript reached; the row stops at the item-size check.
  return lim_pack(1, EQUIV_ERR_OK, 0);
}
