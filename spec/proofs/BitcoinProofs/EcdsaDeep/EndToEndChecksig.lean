import Bitcoin.Interpreter.Defs
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Ecdsa.Verify
import BitcoinProofs.EcdsaDeep.VerifyEquation
import Bitcoin.Crypto.EcdsaDeep.EntryWiredDisUncond

/-!
# EndToEndChecksig — script CHECKSIG semantics ⇒ the E06/E11/E16 crown

ETOWER1. Unit 1: the BASE/WITNESS_V0 `CHECKSIG` step
(`Defs.evalChecksigPreTapscript`) reduced to the checker's ECDSA verdict,
then that verdict identified with E06's `VerifyEqRaw` for the production
wiring (`verifyImpl`) and with the E11 structural crown (`verifyStruct`,
hypothesis-free via E16B's `verifyStructEq'_uncond`).

No `sorry`, no new axiom. `hsc` is the *script-structure* premise
(FindAndDelete result, exactly as the interpreter computes it); the
`CheckSignatureEncoding`/`CheckPubKeyEncoding` gates are model-level
script rules, not crown hypotheses. Residuals are named in ETOWER1.md.
-/

namespace BitcoinProofs.EcdsaDeep.EndToEndChecksig

open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Numeric
open Bitcoin.Crypto.Seam.Entry
open BitcoinProofs.EcdsaDeep.VerifyEquation

/-- Pre-tapscript CHECKSIG with passing encoding gates and a passing
`scriptCode` resolution returns exactly the checker's verdict. -/
theorem evalChecksigPreTapscript_ok
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData) (sv : Bitcoin.Crypto.Seam.SigVersion) (codeSep : Nat)
    (bytes sig pk scriptCode : ByteArray)
    (hsc : (if sv = Bitcoin.Crypto.Seam.SigVersion.base then
        (let r := findAndDelete (bytes.extract codeSep bytes.size)
            (Bitcoin.Script.Parser.pushBytesWire sig)
         if 0 < r.1 ∧ pol.constScriptCode then Except.error ExecError.sigFindAndDelete
         else Except.ok r.2)
      else Except.ok (bytes.extract codeSep bytes.size)) = Except.ok scriptCode)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = none)
    (hV : chk.base.checkECDSASignature sig pk scriptCode sv ed = true)
    (hne : sig.size ≠ 0) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk = .ok true := by
  unfold evalChecksigPreTapscript
  simp [hsc, henc, hpk, hV, hne]

/-- The same step under NULLFAIL: a nonempty signature the checker rejects
terminates the script with `SCRIPT_ERR_SIG_NULLFAIL` (invalid ⇒ FAILS). -/
theorem evalChecksigPreTapscript_nullfail
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData) (sv : Bitcoin.Crypto.Seam.SigVersion) (codeSep : Nat)
    (bytes sig pk scriptCode : ByteArray)
    (hsc : (if sv = Bitcoin.Crypto.Seam.SigVersion.base then
        (let r := findAndDelete (bytes.extract codeSep bytes.size)
            (Bitcoin.Script.Parser.pushBytesWire sig)
         if 0 < r.1 ∧ pol.constScriptCode then Except.error ExecError.sigFindAndDelete
         else Except.ok r.2)
      else Except.ok (bytes.extract codeSep bytes.size)) = Except.ok scriptCode)
    (henc : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = none)
    (hfalse : chk.base.checkECDSASignature sig pk scriptCode sv ed = false)
    (hnf : pol.nullFail = true) (hne : sig.size ≠ 0) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk
      = .error ExecError.sigNullFail := by
  unfold evalChecksigPreTapscript
  simp [hsc, henc, hpk, hfalse, hnf, hne]

/-- Production wiring: the interpreter's ECDSA entry accepts **iff** E06's
verify equation holds (crown, no hypothesis beyond the checker's own
preconditions — valid pubkey encoding, nonempty sig, amount present for V0). -/
theorem ecdsaEntry_checksig_iff
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : Bitcoin.Crypto.Seam.SigVersion) (d : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (hpk : Bitcoin.Crypto.Seam.Der.isValidPubKey pk = true) (hne : 0 < sig.size)
    (ham : v = Bitcoin.Crypto.Seam.SigVersion.witnessV0 → hasAmount = true) :
    (ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount).checkECDSASignature
      sig pk code v d = true
      ↔ VerifyEqRaw (sig.extract 0 (sig.size - 1)) pk
          (sighash code sig[sig.size - 1]! v) := by
  rw [ecdsaEntry_pops_hashtype Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount
    sig pk code v d hpk hne ham]
  exact verifyImpl_iff _ _ _

/-- The same through E11's structural mirror, hypothesis-free (E16B). -/
theorem ecdsaEntryStruct_checksig_iff
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : Bitcoin.Crypto.Seam.SigVersion) (d : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (hpk : Bitcoin.Crypto.Seam.Der.isValidPubKey pk = true) (hne : 0 < sig.size)
    (ham : v = Bitcoin.Crypto.Seam.SigVersion.witnessV0 → hasAmount = true) :
    (ecdsaEntry Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct sighash hasAmount).checkECDSASignature
      sig pk code v d = true
      ↔ VerifyEqRaw (sig.extract 0 (sig.size - 1)) pk
          (sighash code sig[sig.size - 1]! v) := by
  rw [ecdsaEntry_pops_hashtype Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct sighash
      hasAmount sig pk code v d hpk hne ham,
    Bitcoin.Crypto.EcdsaDeep.EntryWiredDisUncond.verifyStructEq'_uncond]
  exact verifyImpl_iff _ _ _


/-! ## Unit 2 — the P2PK script path: `<sig> <pk> CHECKSIG` evaluates to
the CHECKSIG verdict.

`evalFrom` operates on `List WireOp`; the two pushes and the CHECKSIG need
only their AST shape and wire class (`wire ≤ 0x60` for pushes, `0xac` for
CHECKSIG). Lifting through `evalScriptBytes` (byte-string entry) needs the
parser bridge, residual ETOWER1-R1. -/

/-- Disabled opcodes are all ≥ 0x7e; a push-class wire (≤ 0x60) is never
disabled. -/
theorem disabledWire_false_of_le {w : Nat} (h : w ≤ 96) : disabledWire w = false := by
  interval_cases w <;> decide

/-- Running the P2PK program from the empty stack: CHECKSIG with a passing
encoding gate pair and a `true` checker verdict leaves `[0x01]`. -/
theorem evalFrom_p2pk_ok
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (bytes sig pk scriptCode : ByteArray) (o1 o2 o3 : WireOp)
    (ha1 : o1.ast = .pushBytes sig) (hw1 : o1.wire ≤ 96)
    (ha2 : o2.ast = .pushBytes pk) (hw2 : o2.wire ≤ 96)
    (ha3 : o3.ast = .op ⟨0xac, by decide⟩) (hw3 : o3.wire = 0xac)
    (hmin : pol.minimalData = false) (hsig : sig.size ≤ 520) (hpk : pk.size ≤ 520)
    (henc : checkSigEncoding flags pol sig = none)
    (hpkenc : checkPubKeyEncoding flags pol Bitcoin.Crypto.Seam.SigVersion.base pk = none)
    (hsc : (let r := findAndDelete bytes (Bitcoin.Script.Parser.pushBytesWire sig)
         if 0 < r.1 ∧ pol.constScriptCode then Except.error ExecError.sigFindAndDelete
         else Except.ok r.2) = Except.ok scriptCode)
    (hV : chk.base.checkECDSASignature sig pk scriptCode .base ed = true) :
    finalStack (evalFrom ⟨flags, pol, chk, .base, bytes, ed⟩ 4 [o1, o2, o3]
      { stack := [], alt := [], vf := [], opCount := 0, codeSep := 0, vwLeft := none })
    = .ok [pushBoolV (chk.base.checkECDSASignature sig pk scriptCode .base ed)] := by
  have hw1' : ¬ 96 < o1.wire := by omega
  have hw2' : ¬ 96 < o2.wire := by omega
  have hd1 : disabledWire o1.wire = false := disabledWire_false_of_le hw1
  have hd2 : disabledWire o2.wire = false := disabledWire_false_of_le hw2
  have hne1 : o1.wire ≠ 171 := by omega
  have hne2 : o2.wire ≠ 171 := by omega
  rcases o1 with ⟨a1, w1, n1⟩
  rcases o2 with ⟨a2, w2, n2⟩
  rcases o3 with ⟨a3, w3, n3⟩
  simp only at ha1 ha2 ha3
  subst ha1
  subst ha2
  subst ha3
  dsimp only at hw1 hw2 hw3 hw1' hw2' hd1 hd2 hne1 hne2
  simp (config := { decide := true }) [finalStack, evalFrom, stepChecked, stepBody,
    stepBody.dispatchOp, hmin, MAX_SCRIPT_ELEMENT_SIZE, MAX_STACK_SIZE, MAX_OPS_PER_SCRIPT,
    hsig, hpk, hw1', hw2', hd1, hd2, hne1, hne2, hw3, henc, hpkenc,
    topAt, signatureExecutionData, evalChecksigDispatch, evalChecksigPreTapscript, hsc, hV]


/-! ## Unit 3 — lifting to `evalScriptBytes` (byte-string entry)

The parser bridge itself (`parseWire` of the concrete P2PK bytes) stays
residual ETOWER1-R1; these two lemmas take the parse as a premise and
prove the exact stack results the `verifyScriptFull` envelope consumes. -/

/-- scriptSig `<sig>` (single push) from the empty stack. -/
theorem evalScriptBytes_push_ok
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData) (ss sig : ByteArray) (o : WireOp)
    (hsize : ss.size ≤ 10000) (hparse : parseWire ss = some [o])
    (ha : o.ast = .pushBytes sig) (hw : o.wire ≤ 96)
    (hmin : pol.minimalData = false) (hsig : sig.size ≤ 520) :
    evalScriptBytes (fuel+2) flags pol ss [] chk .base ed = .ok [sig] := by
  have hw' : ¬ 96 < o.wire := by omega
  have hsz : ¬ 10000 < ss.size := by omega
  have hd : disabledWire o.wire = false := disabledWire_false_of_le hw
  have hne : o.wire ≠ 171 := by omega
  rcases o with ⟨a, w, n⟩
  simp only at ha
  subst ha
  dsimp only at hw hw' hd hne
  simp [finalStack, evalScriptBytes, MAX_SCRIPT_SIZE, hparse, evalFrom, stepChecked,
    stepBody, hmin, MAX_SCRIPT_ELEMENT_SIZE, MAX_STACK_SIZE, MAX_OPS_PER_SCRIPT,
    hsz, hsig, hw', hd, hne]

/-- scriptPubKey `<pk> CHECKSIG` on the scriptSig stack `[sig]`. -/
theorem evalScriptBytes_p2pk_ok
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData) (spk sig pk scriptCode : ByteArray)
    (o2 o3 : WireOp)
    (hsize : spk.size ≤ 10000) (hparse : parseWire spk = some [o2, o3])
    (ha2 : o2.ast = .pushBytes pk) (hw2 : o2.wire ≤ 96)
    (ha3 : o3.ast = .op ⟨0xac, by decide⟩) (hw3 : o3.wire = 0xac)
    (hmin : pol.minimalData = false) (hpk : pk.size ≤ 520)
    (henc : checkSigEncoding flags pol sig = none)
    (hpkenc : checkPubKeyEncoding flags pol Bitcoin.Crypto.Seam.SigVersion.base pk = none)
    (hsc : (let r := findAndDelete spk (Bitcoin.Script.Parser.pushBytesWire sig)
         if 0 < r.1 ∧ pol.constScriptCode then Except.error ExecError.sigFindAndDelete
         else Except.ok r.2) = Except.ok scriptCode)
    (hV : chk.base.checkECDSASignature sig pk scriptCode .base ed = true) :
    evalScriptBytes (fuel+3) flags pol spk [sig] chk .base ed
      = .ok [pushBoolV (chk.base.checkECDSASignature sig pk scriptCode .base ed)] := by
  have hw2' : ¬ 96 < o2.wire := by omega
  have hsz : ¬ 10000 < spk.size := by omega
  have hd2 : disabledWire o2.wire = false := disabledWire_false_of_le hw2
  have hne2 : o2.wire ≠ 171 := by omega
  have hd3 : disabledWire 172 = false := by decide
  rcases o2 with ⟨a2, w2, n2⟩
  rcases o3 with ⟨a3, w3, n3⟩
  simp only at ha2 ha3
  subst ha2
  subst ha3
  dsimp only at hw2 hw2' hd2 hne2 hw3
  simp [finalStack, evalScriptBytes, MAX_SCRIPT_SIZE, hparse, evalFrom, stepChecked,
    stepBody, stepBody.dispatchOp, hmin, MAX_SCRIPT_ELEMENT_SIZE, MAX_STACK_SIZE,
    MAX_OPS_PER_SCRIPT, hsz, hpk, hw2', hd2, hne2, hw3, hd3,
    henc, hpkenc, topAt, signatureExecutionData, evalChecksigDispatch, evalChecksigPreTapscript, hsc, hV]


/-! ## Unit 4 — the input-verdict envelope

`verifyScriptFull`'s bare, non-P2SH, non-witness, non-cleanstack branch:
the input ACCEPTS iff the CHECKSIG verdict left on the stack is `true`.
This is the transaction-input level, parameterized by the crown verdict
(units 1–3 identify it with `VerifyEqRaw`); the byte-level parse of the
two scripts is residual ETOWER1-R1. -/

/-- The stack encoding of a Boolean is truthy exactly when it is `true`. -/
theorem castToBool_pushBoolV (v : Bool) : castToBool (pushBoolV v) = v := by
  cases v <;> decide

/-- The P2PK input verdict: ACCEPT ⇔ the CHECKSIG verdict is `true`. -/
theorem p2pk_verifyScriptFull_iff
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (witness : Bitcoin.Data.WitnessStack) (ss spk sig : ByteArray) (V : Bool)
    (hSigPush : pol.sigPushOnly = false)
    (hss : evalScriptBytes (fuel+3) flags pol ss [] chk .base default = .ok [sig])
    (hspk : evalScriptBytes (fuel+3) flags pol spk [sig] chk .base default = .ok [pushBoolV V])
    (hprog : isWitnessProgram spk = none) (hp2sh : isPayToScriptHash spk = false)
    (hwit : flags.witness = false) (hclean : pol.cleanstack = false) :
    verifyScriptFull (fuel+3) flags pol ss spk witness chk = .ok ↔ V = true := by
  constructor
  · intro hok
    have hcb := castToBool_pushBoolV V
    simp [verifyScriptFull, hSigPush, hss, hspk, hprog, hp2sh, hwit, hclean] at hok
    simpa [hcb] using hok
  · intro hV
    have htruth : castToBool (pushBoolV V) = true := by rw [hV]; exact castToBool_pushBoolV true
    simp [verifyScriptFull, hSigPush, hss, hspk, hprog, hp2sh, hwit, hclean, htruth]


/-- **END-TO-END (production wiring)**: a P2PK input whose script path
evaluates to CHECKSIG ACCEPTS **iff the E06 crown equation holds** — the
script interpreter's signature semantics and the crown are the same
predicate on this path. Converse included: a false crown verdict makes
the input fail. -/
theorem p2pk_verifyScriptFull_crown
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (witness : Bitcoin.Data.WitnessStack) (ss spk sig pk : ByteArray)
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray)
    (hasAmount : Bool)
    (hSigPush : pol.sigPushOnly = false)
    (hss : evalScriptBytes (fuel+3) flags pol ss [] ⟨ecdsaEntry
        Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount, default, none⟩ .base default
      = .ok [sig])
    (hspk : evalScriptBytes (fuel+3) flags pol spk [sig] ⟨ecdsaEntry
        Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount, default, none⟩ .base default
      = .ok [pushBoolV ((ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount).checkECDSASignature
          sig pk spk .base default)])
    (hprog : isWitnessProgram spk = none) (hp2sh : isPayToScriptHash spk = false)
    (hwit : flags.witness = false) (hclean : pol.cleanstack = false)
    (hpk : Bitcoin.Crypto.Seam.Der.isValidPubKey pk = true) (hne : 0 < sig.size)
    (ham : Bitcoin.Crypto.Seam.SigVersion.base = Bitcoin.Crypto.Seam.SigVersion.witnessV0 →
      hasAmount = true) :
    verifyScriptFull (fuel+3) flags pol ss spk witness ⟨ecdsaEntry
        Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount, default, none⟩ = .ok
      ↔ VerifyEqRaw (sig.extract 0 (sig.size - 1)) pk
          (sighash spk sig[sig.size - 1]! .base) := by
  rw [p2pk_verifyScriptFull_iff (chk := ⟨ecdsaEntry
      Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount, default, none⟩)
    fuel flags pol witness ss spk sig _ hSigPush hss hspk hprog hp2sh hwit hclean]
  exact ecdsaEntry_checksig_iff sighash hasAmount sig pk spk .base default hpk hne ham

section AxiomPins

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.evalChecksigPreTapscript_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms evalChecksigPreTapscript_ok

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.evalChecksigPreTapscript_nullfail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms evalChecksigPreTapscript_nullfail

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.disabledWire_false_of_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms disabledWire_false_of_le

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.evalFrom_p2pk_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms evalFrom_p2pk_ok

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.evalScriptBytes_push_ok' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms evalScriptBytes_push_ok

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.evalScriptBytes_p2pk_ok' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms evalScriptBytes_p2pk_ok

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.castToBool_pushBoolV' does not depend on any axioms -/
#guard_msgs in #print axioms castToBool_pushBoolV

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.p2pk_verifyScriptFull_iff' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms p2pk_verifyScriptFull_iff

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.p2pk_verifyScriptFull_crown' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms p2pk_verifyScriptFull_crown

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.ecdsaEntry_checksig_iff' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntry_checksig_iff

/-- info: 'BitcoinProofs.EcdsaDeep.EndToEndChecksig.ecdsaEntryStruct_checksig_iff' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryStruct_checksig_iff

end AxiomPins

end BitcoinProofs.EcdsaDeep.EndToEndChecksig
