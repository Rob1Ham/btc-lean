#include "cell.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: direct transcription of the Lean model of OP_ELSE / OP_ENDIF and the
// loop-exit check, spec/core/Bitcoin/Interpreter/Defs.lean:893-900 and the
// pre-dispatch gate at Defs.lean:851-853 (which cites interpreter.cpp:493),
// plus the final `if !vf.isEmpty` check (Defs.lean; interpreter.cpp:1245-1246).
//
//   | .op _ =>
//       if !(fExec ∨ (0x63 ≤ w ∧ w ≤ 0x68)) then .ok st₁
//       else dispatchOp ctx op w fExec st₁
//   ...
//   else if w = 0x67 then                                   -- OP_ELSE
//     match st.vf with
//     | [] => .error .unbalancedConditional
//     | v :: rest => .ok { st with vf := (!v) :: rest }
//   else if w = 0x68 then                                   -- OP_ENDIF
//     match st.vf with
//     | [] => .error .unbalancedConditional
//     | _ :: rest => .ok { st with vf := rest }
//
// The bounded condition stack (n, v0, v1) is cell harness; the error ordinal
// comes from core_ord(TWIN_UNBALANCED_CONDITIONAL).

BINLINE uint32_t l_wire(uint32_t op) {
  if (op == 0) return 0x67;   // OP_ELSE
  if (op == 1) return 0x68;   // OP_ENDIF
  return 0x61;                // OP_NOP
}

BINLINE uint32_t l_step(uint32_t op, uint32_t fexec, uint32_t n, uint32_t v0,
                        uint32_t v1, CSt& out) {
  out = CSt{n, v0, v1, 0};
  const uint32_t w = l_wire(op);
  const bool fExec = fexec != 0;
  uint32_t err = 0;
  if (!(fExec || (0x63u <= w && w <= 0x68u))) {
    // skipped: .ok st (no handler ran)
  } else if (w == 0x67) {                       // OP_ELSE
    if (n == 0)
      err = (uint32_t)core_ord(TWIN_UNBALANCED_CONDITIONAL);
    else
      out.v0 = (v0 == 0) ? 1u : 0u;             // vf := !v :: rest
  } else if (w == 0x68) {                       // OP_ENDIF
    if (n == 0)
      err = (uint32_t)core_ord(TWIN_UNBALANCED_CONDITIONAL);
    else {
      out.n = n - 1;                            // vf := rest
      out.v0 = v1;
      out.v1 = 0;
    }
  } else {                                      // OP_NOP
    out.executed = 1;
  }
  if (err == 0 && out.n != 0)                   // loop exit: !vf.isEmpty
    err = (uint32_t)core_ord(TWIN_UNBALANCED_CONDITIONAL);
  return err;
}

extern "C" uint64_t cell_cond(uint32_t op, uint32_t fexec, uint32_t n,
                               uint32_t v0, uint32_t v1) {
  CSt st{n, v0, v1, 0};
  const uint32_t e = l_step(op, fexec, n, v0, v1, st);
  return cond_pack(e, st);
}
