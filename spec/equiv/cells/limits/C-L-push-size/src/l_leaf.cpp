#include "limits_common.h"
// L leg — reviewed transliteration of the Lean twin.
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:817-826 (stepBody):
//     let sizeOk : Bool :=
//       match op.ast with
//       | .pushBytes d => d.size ≤ MAX_SCRIPT_ELEMENT_SIZE
//       | _ => true
//     if !sizeOk then .error .pushSize
//     else ...
//
//   Lean's `op.ast` is the decoded instruction: `.pushBytes d` carries the
//   push value, `.pushNum` and `.op` carry no push value.  The generated twin
//   has the same check structurally at spec/equiv/twin/runtime.inc:603-606:
//       if (d.kind == Kind::PushBytes && d.dlen > MAX_SCRIPT_ELEMENT_SIZE) {
//         return TWIN_PUSH_SIZE;
//       }
//   It is placed before the opCount/disabled/fExec-dependent code, exactly as
//   Lean stepBody (1).  There is no per-opcode handler for this limit.

extern "C" uint64_t cell_push_size(uint16_t dlen, uint8_t fExec, uint8_t kind) {
  if (kind > 2 || fExec > 1) return lim_bad_input();

  // Defs.lean:817-824: sizeOk is computed from the AST, never from fExec.
  const bool size_ok = !(kind == 0 && dlen > LIM_MAX_SCRIPT_ELEMENT_SIZE);
  if (!size_ok) return lim_pack(0, EQUIV_ERR_PUSH_SIZE, 0);

  // The bounded post-check push effect, matching Core's `if (fExec && push)`.
  const uint32_t depth = (kind != 2 && fExec == 1) ? 1u : 0u;
  return lim_pack(1, EQUIV_ERR_OK, depth);
}
