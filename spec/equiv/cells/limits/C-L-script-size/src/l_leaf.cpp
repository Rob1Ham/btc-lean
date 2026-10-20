#include "limits_common.h"
// L leg — reviewed transliteration of the Lean twin.
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:1163-1166
//     def evalScriptBytes ... :=
//       if (sv = .base ∨ sv = .witnessV0) ∧ MAX_SCRIPT_SIZE < b.size
//         then .error .scriptSize
//         else match parseWire b with ...
//
// The same guard appears structurally in the generated twin at
// spec/equiv/twin/runtime.inc:594-597:
//       if ((ctx.sv == SigVersion::Base || ctx.sv == SigVersion::WitnessV0) &&
//           size > MAX_SCRIPT_SIZE) {
//         return TWIN_SCRIPT_SIZE;
//       }
// There is no per-opcode twin handler for this row; the guard lives in the
// EvalScript prologue.  This cell therefore models the prologue predicate
// directly, with the Lean shape (MAX_SCRIPT_SIZE < b.size) rather than
// Core's (> MAX_SCRIPT_SIZE); the two are the same for unsigned lengths.
// The harness (domain guard, packing) is shared with the C leg.

extern "C" uint64_t cell_script_size(uint64_t script_len, uint8_t sv) {
  if (!lim_valid_sigversion(sv)) return lim_bad_input();

  // Defs.lean:1163-1164: the guard is scoped to base/witnessV0 and uses a
  // strict `<` on the constant side.
  if ((sv == LIM_SV_BASE || sv == LIM_SV_WITNESS_V0) &&
      LIM_MAX_SCRIPT_SIZE < script_len) {
    return lim_pack(0, EQUIV_ERR_SCRIPT_SIZE, 0);
  }
  return lim_pack(1, EQUIV_ERR_OK,
                  static_cast<uint32_t>(script_len & 0x00ffffffu));
}
