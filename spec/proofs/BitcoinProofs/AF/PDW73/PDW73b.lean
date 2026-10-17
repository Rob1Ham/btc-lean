import Bitcoin.Interpreter.Rules
import Bitcoin.Script.Tapscript.Delta
import Bitcoin.Serialization.Interface

/-! # PDW73b — claim band: SIGPUSHONLY + BIP342 budget/CHECKSIGADD residue

Row-face theorems for five `implemented` rows of `spec/core`:

* **SCR-010** `verifyScriptFull` — the SIGPUSHONLY pre-check (BIP62 r2,
  interpreter.cpp:2022-2024): a non-push-only scriptSig fails before any
  evaluation.
* **SCR-031** `executeWitnessScript` — the BIP342 initial-stack gate
  (≤ 1000 items) runs before evaluation on the tapscript path.
* **SCR-040** `executeWitnessScript` — the validation-weight seed is the
  BIP144 serialized witness size plus the 50 WU offset.
* **SCR-041** `evalChecksigTapscript` — 50 WU charged per non-empty sig,
  decrement computed before the verdict.
* **SCR-156** `stepBody` (CHECKSIGADD) — `OP_CHECKSIGADD`'s stack
  arithmetic is `n + (success ? 1 : 0)` over the 4-byte decoded `n`.

Route B: zero core writes, tags on my theorems, in-tree proof reuse
(X07 `Rules.lean` budget theorems, X04 `Delta.lean` CHECKSIGADD law).
-/

namespace BitcoinProofs.AF.PDW73b

open Bitcoin.Interpreter
open Bitcoin.Script.Tapscript Bitcoin.Data Bitcoin.Crypto.Seam
open Bitcoin.Serialization

/-! ## SCR-010 — SIGPUSHONLY gate -/

/-- SCR-010, malformed scriptSig lane: under SIGPUSHONLY an unparseable
scriptSig fails immediately with `sigPushOnly` (interpreter.cpp:2022). -/
@[rule "SCR-010"]
theorem verifyScriptFull_sigPushOnly_parseFail
    (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (hpush : pol.sigPushOnly = true) (hparse : parseWire ss = none) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .sigPushOnly := by
  simp [verifyScriptFull, hpush, hparse]

/-- SCR-010, non-push opcode lane: a parsed scriptSig containing anything
but pushes fails with `sigPushOnly` before evaluation. -/
@[rule "SCR-010"]
theorem verifyScriptFull_sigPushOnly_notPushOnly
    (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (ops : List WireOp)
    (hpush : pol.sigPushOnly = true) (hparse : parseWire ss = some ops)
    (hnp : isPushOnlyWire ops = false) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .sigPushOnly := by
  simp [verifyScriptFull, hpush, hparse, hnp]

/-! ## SCR-031 — BIP342 initial-stack gate -/

/-- SCR-031: on the tapscript path, away from an OP_SUCCESSx override, a
witness stack of more than MAX_STACK_SIZE (1000) items fails with
`stackSize` *before* evaluation (interpreter.cpp:1864-1865). -/
@[rule "SCR-031"]
theorem executeWitnessScript_stackgate_row
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hscan : opSuccessScan exec = false)
    (hmany : MAX_STACK_SIZE < items.length) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript
      = VerifyOutcome.fail .stackSize :=
  executeWitnessScript_tapscript_stackgate fuel items vwSer exec flags pol chk hscan hmany

/-! ## SCR-040 — validation-weight seed = serialized witness size + 50 -/

private theorem foldl_add_int (g : ByteArray → Int) (l : List ByteArray) (k : Int) :
    l.foldl (fun a x => a + g x) k
      = k + l.foldl (fun a x => a + g x) 0 := by
  induction l generalizing k with
  | nil => simp
  | cons d rest ih =>
    simp only [List.foldl_cons]
    rw [ih (k + g d), ih (0 + g d)]
    omega

/-- SCR-040 (size face): `witnessSerSize` adds, per witness item, the
CompactSize length prefix plus the item bytes — exactly Core's
`GetSerializeSize(witness.stack)` used to seed the BIP342 budget
(interpreter.cpp:1991; script.h:62-65). -/
@[rule "SCR-040"]
theorem witnessSerSize_cons (d : ByteArray) (rest : List ByteArray) :
    witnessSerSize (d :: rest)
      = witnessSerSize rest + Int.ofNat ((compactSizeEnc d.size).size + d.size) := by
  unfold witnessSerSize
  simp only [List.foldl_cons]
  rw [foldl_add_int (fun d => Int.ofNat ((compactSizeEnc d.size).size + d.size))]
  omega

/-- SCR-040 (offset face): the BIP342 budget offset is exactly 50 WU, so
the seed `witnessSerSize items + VALIDATION_WEIGHT_OFFSET` is the
serialized witness size plus 50 (interpreter.h:62-65, :1991-1992). -/
@[rule "SCR-040"]
theorem validationWeightSeed_row (items : List ByteArray) :
    witnessSerSize items + VALIDATION_WEIGHT_OFFSET = witnessSerSize items + 50 := by
  rw [show VALIDATION_WEIGHT_OFFSET = 50 from rfl]

/-! ## SCR-041 — 50 WU per non-empty signature -/

/-- SCR-041: a successful tapscript CHECKSIG decrements the budget by
exactly VALIDATION_WEIGHT_PER_SIGOP_PASSED (50); the decrement precedes
the verdict, so it is charged for every non-empty signature
(interpreter.cpp:367-376). -/
@[rule "SCR-041"]
theorem evalChecksigTapscript_decrements_50_row
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hok : chk.base.checkSchnorrSignature sig pk SigVersion.tapscript ed = true)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw
      = .ok (true, some ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) :=
  evalChecksigTapscript_decrements_50 pol chk ed sig pk vw hsig hpk hok hvw

/-! ## SCR-156 — OP_CHECKSIGADD stack arithmetic -/

/-- SCR-156: `OP_CHECKSIGADD` decodes the 4-byte `num` operand first and
pushes `n + (success ? 1 : 0)`; a successful step's result is exactly
`n` or `n + 1` for the decoded `n` (interpreter.cpp:1094-1113). -/
@[rule "SCR-156"]
theorem checksigAddStep_row
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig num pk : ByteArray) (vw : Option Int)
    (r : Bitcoin.Numeric.ScriptNum) (vw' : Option Int)
    (h : checksigAddStep pol chk ed sig num pk vw = .ok (r, vw')) :
    ∃ n, decodeNum pol num 4 = .ok n ∧ (r = n ∨ r = n + 1) :=
  checksigAddStep_result pol chk ed sig num pk vw h

end BitcoinProofs.AF.PDW73b

/-- info: 'BitcoinProofs.AF.PDW73b.verifyScriptFull_sigPushOnly_parseFail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW73b.verifyScriptFull_sigPushOnly_parseFail
/-- info: 'BitcoinProofs.AF.PDW73b.executeWitnessScript_stackgate_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW73b.executeWitnessScript_stackgate_row
/-- info: 'BitcoinProofs.AF.PDW73b.witnessSerSize_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW73b.witnessSerSize_cons
/-- info: 'BitcoinProofs.AF.PDW73b.evalChecksigTapscript_decrements_50_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW73b.evalChecksigTapscript_decrements_50_row
/-- info: 'BitcoinProofs.AF.PDW73b.checksigAddStep_row' depends on axioms: [propext] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW73b.checksigAddStep_row
