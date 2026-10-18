import Bitcoin.Interpreter.Defs

/-!
# INV041ScriptSizeCor — T11/INV-041 promotion proof (P15)

Row INV-041 (`len(script) ≤ 10000`, Satoshi; core anchor
interpreter.cpp:EvalScript:437-439 + the pre-parse gate 419-421
@cce32b168): reject direction.

Statement P15 = `evalScriptBytes_scriptSize_reject`, restated 1:1
verbatim, INCLUDING the F-PDW2-001(ii) repair:
`{fuel : Nat}` as a binder — `PD03-stmtcheck.lean`'s P15 (line 68)
omits it (ill-elaborating as written there).

Semantics: an over-`MAX_SCRIPT_SIZE` (= 10000) script in a
`.base`/`.witnessV0` context fails `evalScriptBytes`' pre-parse
`scriptSize` gate. The gate is the leading `if` of `evalScriptBytes`
(Defs.lean:1125), so the proof is pure gate-herding: unfold, discharge
the guard conjunction (`if_pos`), done. No mathlib, no decide,
no induction.

Axiom-pinned in-file (D2 L3); zero sorryAx expected.
-/

namespace BitcoinProofs.AF.PDW2

/-- INV-041 (reject dir): over-10,000-byte BASE/WITNESS_V0 script
fails `evalScriptBytes`' pre-parse gate (`scriptSize`). -/
@[rule "INV-041"]
theorem evalScriptBytes_scriptSize_reject {fuel : Nat}
    {flags : Bitcoin.Activation.ScriptFlags}
    {pol : Bitcoin.Interpreter.PolicyFlags} {b : ByteArray}
    {st0 : Bitcoin.Interpreter.Stack}
    {chk : Bitcoin.Interpreter.ScriptChecker}
    {sv : Bitcoin.Crypto.Seam.SigVersion}
    {ed : Bitcoin.Crypto.Seam.ScriptExecutionData}
    (hsv : sv = .base ∨ sv = .witnessV0)
    (hs : Bitcoin.Interpreter.MAX_SCRIPT_SIZE < b.size) :
    Bitcoin.Interpreter.evalScriptBytes fuel flags pol b st0 chk sv ed
      = Except.error Bitcoin.Interpreter.ExecError.scriptSize := by
  rw [Bitcoin.Interpreter.evalScriptBytes]
  exact ite_eq_left ⟨hsv, hs⟩

end BitcoinProofs.AF.PDW2
