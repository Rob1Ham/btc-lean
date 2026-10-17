import Bitcoin.Interpreter.Defs

/-! # PDW95c — SCR-001: sequential evaluation, not concatenation.

Two faces of `VerifyScript`'s two-stage composition:

* `verifyScriptFull_scriptSig_error_first` — a scriptSig failure is
  returned before scriptPubKey is looked at (the CVE-2010-5141 lesson:
  the second script is not part of the first's evaluation).
* `verifyScriptFull_sequential_ok` — on the plain non-P2SH /
  non-witness path, success factors through `EvalScript(ss)` and then
  `EvalScript(spk)` applied to *that* stack.
* `sequence_boundary_witness` — a concrete scriptSig whose evaluation
  fails as an unbalanced conditional, while the concatenation with the
  following `OP_ENDIF OP_1` validates: evaluation is per-script, so
  concatenation is not semantics-preserving.
-/

namespace BitcoinProofs.AF.PDW95
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Activation Bitcoin.Data Bitcoin.Crypto.Seam

/-- Lean 4.34 core ships no `DecidableEq (Except α β)`. -/
instance instDecEqExcept95c {α β : Type} [DecidableEq α] [DecidableEq β] :
    DecidableEq (Except α β)
  | .error e, .error e' =>
      match decEq e e' with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.error.inj h2))
  | .ok a, .ok b =>
      match decEq a b with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.ok.inj h2))
  | .error _, .ok _ => isFalse (by intro h; simp at h)
  | .ok _, .error _ => isFalse (by intro h; simp at h)

/-- SCR-001 (stage 1): scriptSig is evaluated first; its error is the
verdict, and scriptPubKey is never evaluated. -/
@[rule "SCR-001"]
theorem verifyScriptFull_scriptSig_error_first
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (e : ExecError) (hpush : pol.sigPushOnly = false)
    (h : evalScriptBytes fuel flags pol ss [] chk .base default = .error e) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail e := by
  unfold verifyScriptFull
  simp [hpush, h]

/-- SCR-001 (stage 2): on the plain path the scriptPubKey evaluation
consumes exactly the stack produced by the scriptSig evaluation, and
the verdict is success iff that final element is truthy. -/
@[rule "SCR-001"]
theorem verifyScriptFull_sequential_ok
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (stack1 stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htop : castToBool (stack[0]?.getD (default : ByteArray)) = true)
    (hnw : isWitnessProgram spk = none) (hp2sh : flags.p2sh = false)
    (hcl : pol.cleanstack = false)
    (hw : witness = [] ∨ flags.witness = false) :
    verifyScriptFull fuel flags pol ss spk witness chk = .ok := by
  unfold verifyScriptFull
  rcases hw with hw | hw <;> simp [hpush, hss, hspk, hne, htop, hnw, hp2sh, hcl, hw]

/-- SCR-001 (boundary): `OP_1 OP_IF` as scriptSig fails (unbalanced
conditional at the end of the scriptSig), while the concatenated script
`OP_1 OP_IF OP_ENDIF OP_1` — same bytes plus the boundary-crossing
`OP_ENDIF OP_1` — validates with an empty scriptPubKey. -/
@[rule "SCR-001"]
theorem sequence_boundary_witness :
    verifyScriptFull 100 {} {} (ByteArray.mk #[0x51, 0x63]) ByteArray.empty []
        default = .fail .unbalancedConditional ∧
      verifyScriptFull 100 {} {}
        (ByteArray.mk #[0x51, 0x63, 0x68, 0x51]) ByteArray.empty [] default = .ok := by
  decide

end BitcoinProofs.AF.PDW95
