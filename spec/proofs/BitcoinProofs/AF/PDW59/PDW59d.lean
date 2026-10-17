import Bitcoin.Interpreter.Defs

/-! # PDW59d.lean — TOP-321/323: disabled list + FindAndDelete no-match law

PDW59 (review RC29), claim v1.2. Route B, zero core writes.
INV-063: canonical disabled-opcode membership (interpreter.cpp:482).
INV-056: legacy FindAndDelete identity law — an empty needle and a
no-boundary-match scan both leave the script byte-for-byte unchanged
(interpreter.cpp:239-265).

INV-056 (re-audit): the *deletion* face is not claimed. In the core model
`fdLastPc2` returns the pre-match `pc2` at both terminal branches, so
`findAndDelete` re-appends `script.extract pc2 script.size`; a match that
reaches the end of the script is counted but the needle is put back
(whole-tail case). Core's `FindAndDelete` advances `pc2` past the match
before the final copy, so it removes the push. The divergence is pinned
below by `findAndDelete_self_whole_tail_not_removed` and its
`pushBytesWire` instance. Fixing it requires a core `fdLastPc2` change,
which is outside this file's write scope (F-PDW84-001). -/

namespace BitcoinProofs.AF.PDW59

open Bitcoin.Interpreter
open Bitcoin.Script.Parser Bitcoin.Numeric

/-- INV-056 (empty needle): FindAndDelete(script, ∅) = (0, script). -/
@[rule "INV-056"]
theorem findAndDelete_empty (script : ByteArray) :
    findAndDelete script ByteArray.empty = (0, script) := by
  simp [findAndDelete]

/-- INV-056 (no match): if the boundary scan finds nothing, the script is
returned unchanged (the legacy quirk deletes only full matches). -/
@[rule "INV-056"]
theorem findAndDelete_none_unchanged (script b : ByteArray)
    (h : (findAndDelete script b).1 = 0) :
    (findAndDelete script b).2 = script := by
  by_cases hb : b.size = 0
  · simp [findAndDelete, hb]
  · rw [findAndDelete, if_neg hb] at h ⊢
    cases hfa : findAndDeleteAux script b (script.size + 1) 0 0 ByteArray.empty 0 with
    | mk found acc =>
      simp only [hfa] at h ⊢
      split at h
      · next hpos => omega
      · next hneg => simp [hneg]

/-! ### INV-056: the matching-push deletion law is false (whole-tail case)

The core model cannot prove that a found matching push is removed. When
the greedy scan reaches the end of the script, `fdLastPc2` returns the
pre-match `pc2` (core `Interpreter/Defs.lean:548-557`) and `findAndDelete`
appends `script.extract pc2 script.size` (core `Defs.lean:564`), restoring
the bytes just counted as deleted. Core instead advances `pc2` to `pc`
before the loop test (`interpreter.cpp:239-265`), so `FindAndDelete(b, b)`
returns `(1, ∅)`, not `(1, b)`. -/

/-- ByteArray's `BEq` is `data.isEqv data`, which has no `ReflBEq`
instance in this toolchain; reflexivity is proved here. -/
private theorem bytearray_beq_self (b : ByteArray) : (b == b) = true := by
  show b.data.isEqv b.data BEq.beq = true
  simp

/-- The greedy scan at offset 0 matches the whole script when the needle
is the whole script: it consumes one copy and stops (the next window is
out of bounds). -/
private theorem findAndDeleteMatches_self (b : ByteArray) (hb : b.size ≠ 0) :
    findAndDeleteMatches b b 0 0 (b.size + 1) = (b.size, 1) := by
  rw [findAndDeleteMatches]
  rw [if_neg (by omega : ¬ b.size + 1 = 0)]
  rw [if_neg (by omega : ¬ b.size < 0 + b.size)]
  rw [if_pos (by
    have hext : b.extract 0 (0 + b.size) = b := by simp
    rw [hext]
    exact bytearray_beq_self b)]
  have h0 : (0 : Nat) + b.size = b.size := by omega
  have h1 : (0 : Nat) + 1 = 1 := by omega
  have h2 : b.size + 1 - 1 = b.size := by omega
  rw [h0, h1, h2]
  rw [findAndDeleteMatches]
  rw [if_neg hb]
  rw [if_pos (by omega : b.size < b.size + b.size)]

/-- **INV-056 (whole-tail non-removal)**: when the script is exactly the
nonempty needle, `findAndDelete` reports one match but returns the script
unchanged. This is the byte-level matching-push deletion law failing:
Core's `FindAndDelete` deletes the push and returns the empty script. -/
@[rule "INV-056"]
theorem findAndDelete_self_whole_tail_not_removed (b : ByteArray)
    (hb : b.size ≠ 0) : findAndDelete b b = (1, b) := by
  rw [findAndDelete]
  simp only [hb, ite_false]
  have haux : findAndDeleteAux b b (b.size + 1) 0 0 ByteArray.empty 0
      = (1, ByteArray.empty) := by
    rw [findAndDeleteAux]
    simp only [ByteArray.empty_append]
    rw [findAndDeleteMatches_self b hb]
    simp
  rw [haux]
  simp only [Nat.zero_lt_one, ite_true]
  have hlast : fdLastPc2 b b (b.size + 1) 0 0 = 0 := by
    rw [fdLastPc2]
    rw [findAndDeleteMatches_self b hb]
    simp
  rw [hlast]
  simp

/-- A serialized push is never empty (the length prefix is at least one
byte). -/
private theorem pushBytesWire_size_ne_zero (sig : ByteArray) :
    (pushBytesWire sig).size ≠ 0 := by
  have h := serializeOpcode_size (Opcode.pushBytes sig)
  have h1 : 1 ≤ (pushBytesWire sig).size := by simpa [serializeOpcode] using h
  omega

/-- **INV-056 (matching signature push not removed)**: the exact needle
used by the legacy checksig path, `pushBytesWire sig`, is not removed when
it is the whole scriptCode. Core deletes it. -/
@[rule "INV-056"]
theorem findAndDelete_pushBytesWire_self_not_removed (sig : ByteArray) :
    findAndDelete (pushBytesWire sig) (pushBytesWire sig)
      = (1, pushBytesWire sig) :=
  findAndDelete_self_whole_tail_not_removed (pushBytesWire sig)
    (pushBytesWire_size_ne_zero sig)

/-- INV-063: membership characterisation of the canonical disabled set. -/
@[rule "INV-063"]
theorem disabledWire_iff (w : Nat) :
    disabledWire w = true ↔
      w ∈ [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
           0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99] := by
  simp [disabledWire]

/-- INV-063 (positive boundary): 0x7e is disabled. -/
@[rule "INV-063"]
theorem disabledWire_0x7e : disabledWire 0x7e = true := rfl

/-- INV-063 (negative boundary): 0x51 (OP_1) is not disabled. -/
@[rule "INV-063"]
theorem disabledWire_enabled_example : disabledWire 0x51 = false := by decide

/-- INV-064: a scriptSig evaluation error is final — the scriptPubKey is
never concatenated into, nor evaluated with, the scriptSig bytes. -/
@[rule "INV-064"]
theorem verifyScriptFull_scriptSig_error
    (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : List ByteArray) (chk : ScriptChecker)
    (e : ExecError)
    (hpol : pol.sigPushOnly = false)
    (h : evalScriptBytes fuel flags pol ss [] chk .base default = .error e) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail e := by
  unfold verifyScriptFull
  simp [hpol, h]

/-- Proof-side mirror of the `VerifyScript` tail (interpreter.cpp:2027-2111)
*after* the scriptSig evaluation: the scriptPubKey bytes are evaluated on
the stack the scriptSig left (`stack1`), as a separate `evalScriptBytes`
call — the two scripts are never concatenated. Kept definitionally
identical to core's continuation so `verifyScriptFull_sequential_row` is
an unfolding law, not a re-modelling. -/
def verifyScriptAfterScriptSig (fuel : Nat)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : List ByteArray) (chk : ScriptChecker)
    (stack1 : Stack) : VerifyOutcome :=
  let stackCopy := stack1
  match evalScriptBytes fuel flags pol spk stack1 chk .base default with
  | .error e => .fail e
  | .ok stack =>
    if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
    else
      let bare : VerifyOutcome :=
        if flags.witness then
          match isWitnessProgram spk with
          | some (v, prog) =>
            if ss.size ≠ 0 then .fail .witnessMalleated
            else verifyWitnessProgram fuel witness v prog flags pol chk false
          | none => .ok
        else .ok
      match bare with
      | .fail e => .fail e
      | .unjudged => .unjudged
      | .ok =>
        let afterBare := if flags.witness ∧ (isWitnessProgram spk).isSome then
          (if stack = [] then [] else [stack[0]!])
        else stack
        if flags.p2sh ∧ isPayToScriptHash spk then
          match p2shInner fuel flags pol ss stackCopy witness chk with
          | .fail e => .fail e
          | .unjudged => .unjudged
          | .ok =>
            let finalLen : Nat :=
              if flags.witness ∧ (isWitnessProgram spk).isSome then 1
              else
                match parseWire ss with
                | none => 0
                | some ops =>
                  if !isPushOnlyWire ops then 0
                  else
                    match stackCopy with
                    | [] => 0
                    | _ :: rest =>
                      match evalScriptBytes fuel flags pol
                          (match stackCopy with
                           | [] => ByteArray.empty
                           | p :: _ => p) rest chk .base default with
                      | .error _ => 0
                      | .ok s2 => s2.length
            if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack
            else if flags.witness ∧ witness ≠ [] ∧
                ¬(flags.witness ∧ ((isWitnessProgram spk).isSome ∧ ss.size = 0) ∨
                  ((isWitnessProgram (match stackCopy with
                    | [] => ByteArray.empty
                    | p :: _ => p)).isSome ∧ ss == pushBytesWire
                      (match stackCopy with
                       | [] => ByteArray.empty
                       | p :: _ => p))) then
              .fail .witnessUnexpected
            else .ok
        else
          if pol.cleanstack ∧ afterBare.length ≠ 1 then .fail .cleanstack
          else if flags.witness ∧ witness ≠ [] ∧ ¬(flags.witness ∧ (isWitnessProgram spk).isSome) then
            .fail .witnessUnexpected
          else .ok

/-- INV-064 (full row): `VerifyScript` is two *separate* evaluations —
scriptSig on the empty stack, then scriptPubKey on the resulting stack.
There is no `scriptSig ++ scriptPubKey` concatenation anywhere in the
verdict: the second stage reads only `spk` and `stack1`, and the first
stage only `ss`. -/
@[rule "INV-064"]
theorem verifyScriptFull_sequential_row
    (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : List ByteArray) (chk : ScriptChecker)
    (hpol : pol.sigPushOnly = false) :
    verifyScriptFull fuel flags pol ss spk witness chk =
      (match evalScriptBytes fuel flags pol ss [] chk .base default with
       | .error e => VerifyOutcome.fail e
       | .ok stack1 => verifyScriptAfterScriptSig fuel flags pol ss spk
           witness chk stack1) := by
  unfold verifyScriptFull verifyScriptAfterScriptSig
  simp only [hpol, Bool.false_eq_true, if_false, reduceIte]
  rfl

/-- INV-056 (legacy checksig quirk, **conditional row face only**): in a
BASE spend, *if* the model's FindAndDelete scan reports a positive match
count and `constScriptCode = false`, the ECDSA checker is invoked on
`(findAndDelete …).2`. This is the call-site wiring, not a deletion law:
the model does not establish that the matching signature push was removed
(and indeed it is not removed in the whole-tail case — see
`findAndDelete_self_whole_tail_not_removed` /
`findAndDelete_pushBytesWire_self_not_removed`; Core deletes it at
interpreter.cpp:239-265, tracked as F-PDW84-001). -/
@[rule "INV-056"]
theorem evalChecksigPreTapscript_base_findAndDelete_sig
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sv : Bitcoin.Crypto.Seam.SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray)
    (hsv : sv = .base)
    (hfound : 0 < (findAndDelete (bytes.extract codeSep bytes.size)
      (pushBytesWire sig)).1)
    (hconst : pol.constScriptCode = false)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = none) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk =
      (let fSuccess := chk.base.checkECDSASignature sig pk
         (findAndDelete (bytes.extract codeSep bytes.size)
           (pushBytesWire sig)).2 sv ed
       if !fSuccess ∧ pol.nullFail ∧ sig.size ≠ 0 then .error .sigNullFail
       else .ok fSuccess) := by
  subst hsv
  simp [evalChecksigPreTapscript, hfound, hconst, henc, hpk]

/-- **INV-056 (checksig path, whole-tail divergence)**: if the BASE
scriptCode is exactly the serialized signature push, the model still hands
that push to the ECDSA checker. A correct FindAndDelete would hand it the
empty script; this corollary makes the residual reachable from the
checksig path rather than only from the bare `findAndDelete` definition. -/
@[rule "INV-056"]
theorem evalChecksigPreTapscript_base_findAndDelete_whole_tail_retained
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sv : Bitcoin.Crypto.Seam.SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray)
    (hsv : sv = .base)
    (hcode : bytes.extract codeSep bytes.size = pushBytesWire sig)
    (hconst : pol.constScriptCode = false)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = none) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk =
      (let fSuccess := chk.base.checkECDSASignature sig pk
         (pushBytesWire sig) sv ed
       if !fSuccess ∧ pol.nullFail ∧ sig.size ≠ 0 then .error .sigNullFail
       else .ok fSuccess) := by
  subst hsv
  have hf := findAndDelete_pushBytesWire_self_not_removed sig
  have hfound : 0 < (findAndDelete (bytes.extract codeSep bytes.size)
      (pushBytesWire sig)).1 := by
    rw [hcode, hf]
    simp
  have hres : (findAndDelete (bytes.extract codeSep bytes.size)
      (pushBytesWire sig)).2 = pushBytesWire sig := by
    rw [hcode, hf]
  simp [evalChecksigPreTapscript, hfound, hconst, henc, hpk, hres]

end BitcoinProofs.AF.PDW59
