import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.AF.PDW62b — TOP-331..335 row faces (PDW62, own path)

Route B: no core writes; row-face theorems carry the `@[rule]` tags.
A duplicate PDW62 process was writing `AF/PDW62/PDW62.lean`; this bank
lives in `AF/PDW62b/` to avoid clobbering it. Pins ⊆ trio.
-/

namespace BitcoinProofs.AF.PDW62b

open Bitcoin.Interpreter
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Activation (ScriptFlags)
open Bitcoin.Numeric (decodeScriptNum decodeBE bytesOf bytesOf_length)

/-! ## SCR-081 — the maxSize width gate (5-byte CLTV/CSV bound) -/

/-- **SCR-081**: `decodeScriptNum` refuses every byte vector wider than
the caller's `maxSize` (the parameter that carries Core's 5-byte
CLTV/CSV corner; the default is 4). -/
@[rule "SCR-081"]
theorem decodeScriptNum_width_none (b : ByteArray) (minimal : Bool)
    (maxSize : Nat) (h : maxSize < b.size) :
    decodeScriptNum b minimal maxSize = none := by
  show decodeBE minimal maxSize (bytesOf b).reverse = none
  unfold decodeBE
  rw [ite_eq_left (show (bytesOf b).reverse.length > maxSize by
    rw [List.length_reverse, bytesOf_length]; exact h)]

/-! ## SWT-049 — FindAndDelete only on the BASE sigversion -/

/-- **SWT-049**: on a non-BASE sigversion the scriptCode is the plain
suffix from the last code separator: no FindAndDelete runs (BIP143
"§No FindAndDelete"). -/
@[rule "SWT-049"]
theorem evalChecksigPreTapscript_nonbase (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sv : SigVersion) (codeSep : Nat) (bytes sig pk : ByteArray)
    (hsv : sv ≠ SigVersion.base)
    (hsig : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = none) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk =
      (let f := chk.base.checkECDSASignature sig pk
          (bytes.extract codeSep bytes.size) sv ed
       if !f ∧ pol.nullFail ∧ sig.size ≠ 0 then .error .sigNullFail
       else .ok f) := by
  unfold evalChecksigPreTapscript
  simp [hsv, hsig, hpk]

/-! ## SCR-112 — invalid pubkey is a script error -/

/-- **SCR-112**: when the pubkey-encoding gate fires, the pre-tapscript
check returns that script error (not a false verdict). -/
@[rule "SCR-112"]
theorem evalChecksigPreTapscript_pk_invalid (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sv : SigVersion) (codeSep : Nat) (bytes sig pk : ByteArray)
    (e : ExecError) (hsv : sv ≠ SigVersion.base)
    (hsig : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = some e) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk =
      .error e := by
  unfold evalChecksigPreTapscript
  simp [hsv, hsig, hpk]

/-! ## INV-065 — SIGPUSHONLY pre-check -/

/-- **INV-065**: with the policy SIGPUSHONLY flag on, a parseable but
non-push-only scriptSig fails before any evaluation. -/
@[rule "INV-065"]
theorem verifyScriptFull_sigPushOnly_nonpush_fail (fuel : Nat)
    (flags : ScriptFlags) (pol : PolicyFlags) (ss spk : ByteArray)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker) (ops : List WireOp)
    (hsp : pol.sigPushOnly = true) (hp : parseWire ss = some ops)
    (hpo : isPushOnlyWire ops = false) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .sigPushOnly := by
  unfold verifyScriptFull
  simp [hsp, hp, hpo]

/-! ## SCR-017 — eval failure aborts the whole verify -/

/-- **SCR-017**: once the admission pre-check passes, an EvalScript
failure on the scriptSig is returned verbatim as the verification
failure (the whole input is invalid). -/
@[rule "SCR-017"]
theorem verifyScriptFull_first_eval_fail (fuel : Nat)
    (flags : ScriptFlags) (pol : PolicyFlags) (ss spk : ByteArray)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (e : ExecError)
    (hpre : pol.sigPushOnly = false ∨
      ∃ ops, parseWire ss = some ops ∧ isPushOnlyWire ops = true)
    (h : evalScriptBytes fuel flags pol ss [] chk SigVersion.base default =
      .error e) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail e := by
  unfold verifyScriptFull
  rcases hpre with hp | ⟨ops, hp, hpo⟩
  · simp [hp, h]
  · simp [hp, hpo, h]

/-- **SCR-017** (P2SH witness arm): once the redeemScript evaluation
succeeds truthfully, a `VerifyWitnessProgram` failure in the wrapped
witness branch is returned verbatim — the whole input is invalid.  This
is the witness-path counterpart of `verifyScriptFull_first_eval_fail`
(interpreter.cpp:VerifyScript structure). -/
@[rule "SCR-017"]
theorem p2shInner_witness_fail (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss : ByteArray) (stackCopy : Stack)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker) (e : ExecError)
    (ops : List WireOp) (pubKey2 : ByteArray) (rest : Stack)
    (stack : Stack) (v : Nat) (prog : ByteArray)
    (hp : parseWire ss = some ops)
    (hpo : isPushOnlyWire ops = true)
    (hsc : stackCopy = pubKey2 :: rest)
    (hev : evalScriptBytes fuel flags pol pubKey2 rest chk SigVersion.base
      default = .ok stack)
    (hne : stack ≠ [])
    (htrue : Bitcoin.Numeric.castToBool (stack[0]?.getD default) = true)
    (hw : flags.witness = true)
    (hwp : isWitnessProgram pubKey2 = some (v, prog))
    (hmal : (ss != Bitcoin.Script.Parser.pushBytesWire pubKey2) = false)
    (hvf : verifyWitnessProgram fuel witness v prog flags pol chk true = .fail e) :
    p2shInner fuel flags pol ss stackCopy witness chk = .fail e := by
  subst hsc
  unfold p2shInner
  rw [hp]
  simp [hpo, hev, hne, htrue, hw, hwp, hmal, hvf]

/-- **SCR-017** (bare witness arm): a `VerifyWitnessProgram` failure on a
native witness program is returned verbatim by `VerifyScript` — the whole
input is invalid. -/
@[rule "SCR-017"]
theorem verifyScriptFull_bare_witness_fail (fuel : Nat)
    (flags : ScriptFlags) (pol : PolicyFlags) (ss spk : ByteArray)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (e : ExecError) (stack1 stack : Stack) (v : Nat) (prog : ByteArray)
    (hpre : pol.sigPushOnly = false ∨
      ∃ ops, parseWire ss = some ops ∧ isPushOnlyWire ops = true)
    (hss : evalScriptBytes fuel flags pol ss [] chk SigVersion.base default
      = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk SigVersion.base default
      = .ok stack)
    (hne : stack ≠ []) (htrue : Bitcoin.Numeric.castToBool (stack[0]?.getD default) = true)
    (hw : flags.witness = true)
    (hwp : isWitnessProgram spk = some (v, prog))
    (hsize : ss.size = 0)
    (hf : verifyWitnessProgram fuel witness v prog flags pol chk false = .fail e) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail e := by
  unfold verifyScriptFull
  rcases hpre with hp | ⟨ops, hp, hpo⟩
  · simp [hp, hss, hspk, hne, htrue, hw, hwp, hsize, hf]
  · simp [hp, hpo, hss, hspk, hne, htrue, hw, hwp, hsize, hf]

/-- **SCR-017** (P2SH-wrapped witness arm): a `VerifyWitnessProgram`
failure propagating out of `p2shInner` aborts the whole `VerifyScript`
with the same error. -/
@[rule "SCR-017"]
theorem verifyScriptFull_p2sh_witness_fail (fuel : Nat)
    (flags : ScriptFlags) (pol : PolicyFlags) (ss spk : ByteArray)
    (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (e : ExecError) (stack1 stack : Stack)
    (hpre : pol.sigPushOnly = false ∨
      ∃ ops, parseWire ss = some ops ∧ isPushOnlyWire ops = true)
    (hss : evalScriptBytes fuel flags pol ss [] chk SigVersion.base default
      = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk SigVersion.base default
      = .ok stack)
    (hne : stack ≠ []) (htrue : Bitcoin.Numeric.castToBool (stack[0]?.getD default) = true)
    (hwpSpk : isWitnessProgram spk = none)
    (hp2sh : flags.p2sh = true)
    (hisp2sh : isPayToScriptHash spk = true)
    (hinner : p2shInner fuel flags pol ss stack1 witness chk = .fail e) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail e := by
  unfold verifyScriptFull
  rcases hpre with hp | ⟨ops, hp, hpo⟩
  · simp [hp, hss, hspk, hne, htrue, hwpSpk, hp2sh, hisp2sh, hinner]
  · simp [hp, hpo, hss, hspk, hne, htrue, hwpSpk, hp2sh, hisp2sh, hinner]

/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW62b.decodeScriptNum_width_none' depends on axioms: [propext] -/
#guard_msgs in #print axioms decodeScriptNum_width_none
/-- info: 'BitcoinProofs.AF.PDW62b.evalChecksigPreTapscript_nonbase' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms evalChecksigPreTapscript_nonbase
/-- info: 'BitcoinProofs.AF.PDW62b.evalChecksigPreTapscript_pk_invalid' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms evalChecksigPreTapscript_pk_invalid
/-- info: 'BitcoinProofs.AF.PDW62b.verifyScriptFull_sigPushOnly_nonpush_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyScriptFull_sigPushOnly_nonpush_fail
/-- info: 'BitcoinProofs.AF.PDW62b.verifyScriptFull_first_eval_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyScriptFull_first_eval_fail
/-- info: 'BitcoinProofs.AF.PDW62b.p2shInner_witness_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms p2shInner_witness_fail
/-- info: 'BitcoinProofs.AF.PDW62b.verifyScriptFull_bare_witness_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyScriptFull_bare_witness_fail
/-- info: 'BitcoinProofs.AF.PDW62b.verifyScriptFull_p2sh_witness_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyScriptFull_p2sh_witness_fail

end BitcoinProofs.AF.PDW62b
