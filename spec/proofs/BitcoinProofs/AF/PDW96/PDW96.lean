import Bitcoin.Interpreter.Defs
import Bitcoin.Activation.Flags

/-! # PDW96 — final promotion push, hard-tail row faces

Rows: SCR-051 / SCR-059 / SCR-078 / SCR-157 / SCR-182.
Route B: row-face theorems, zero core writes. -/

namespace BitcoinProofs.AF.PDW96
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData)

/-! ## SCR-051 — decodeNum is minimal iff MINIMALDATA is on -/

@[rule "SCR-051"]
theorem decodeNum_minimal_reject (pol : PolicyFlags) (b : ByteArray)
    (hpol : pol.minimalData = true)
    (h : 1 < b.size ∧ (b.get! (b.size - 1)).toNat = 0 ∧
         (b.get! (b.size - 2)).toNat < 128) :
    decodeNum pol b SCRIPT_NUM_DEFAULT_MAX_SIZE = .error .scriptNum := by
  unfold decodeNum
  rw [hpol, scriptNum_minimal_reject b h]

/-! ## SCR-157 — CHECKSIGADD's 4-byte numeric operand -/

/-- Width bound is checked before the minimal-encoding flag: any operand
strictly wider than `maxSize` decodes to `none`. -/
theorem decodeScriptNum_none_of_gt (b : ByteArray) (minimal : Bool) (maxSize : Nat)
    (h : maxSize < b.size) : decodeScriptNum b minimal maxSize = none := by
  unfold decodeScriptNum decodeBE
  have hlen : maxSize < (bytesOf b).reverse.length := by
    rw [List.length_reverse, bytesOf_length]; exact h
  rw [ite_eq_left hlen]

@[rule "SCR-157"]
theorem checksigAddStep_nonminimal (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (sig num pk : ByteArray) (vw : Option Int)
    (hpol : pol.minimalData = true)
    (h : 1 < num.size ∧ (num.get! (num.size - 1)).toNat = 0 ∧
         (num.get! (num.size - 2)).toNat < 128) :
    checksigAddStep pol chk ed sig num pk vw = .error .scriptNum := by
  unfold checksigAddStep
  have hdec : decodeNum pol num 4 = .error .scriptNum := by
    simpa only [SCRIPT_NUM_DEFAULT_MAX_SIZE] using
      decodeNum_minimal_reject pol num hpol h
  rw [hdec]

@[rule "SCR-157"]
theorem checksigAddStep_oversize (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (sig num pk : ByteArray) (vw : Option Int)
    (hsize : SCRIPT_NUM_DEFAULT_MAX_SIZE < num.size) :
    checksigAddStep pol chk ed sig num pk vw = .error .scriptNum := by
  unfold checksigAddStep
  have h4 : 4 < num.size := by simpa only [SCRIPT_NUM_DEFAULT_MAX_SIZE] using hsize
  have hdec : decodeNum pol num 4 = .error .scriptNum := by
    unfold decodeNum
    rw [decodeScriptNum_none_of_gt num pol.minimalData 4 h4]
  rw [hdec]

/-! ## SCR-059 — witness-v0 MINIMALIF under the policy flag -/

@[rule "SCR-059"]
theorem stepBody_minimalif_witnessv0 {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x63 ∨ op.wire = 0x64)
    (hsv : ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 1 ≤ st.stack.length)
    (hpol : ctx.pol.minimalIf = true)
    (hbad : 1 < (topAt st.stack 1).size ∨
      ((topAt st.stack 1).size = 1 ∧
        (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody ctx op st = .error .minimalIf := by
  rcases hw with hw | hw <;>
  · rw [stepBody]
    simp [ha, hw, hsv, hfe, hpol, hbad,
      Nat.not_lt.mpr hbudget, Nat.not_lt.mpr hstack,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]

/-! ## SCR-078 — pre-checked pop: OP_DROP on an empty stack -/

@[rule "SCR-078"]
theorem stepBody_drop_empty {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x75)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : st.stack = []) :
    stepBody ctx op st = .error .stackUnderflow := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hstack,
    Nat.not_lt.mpr hbudget, Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]

/-! ## SCR-182 — WITNESS_PUBKEYTYPE is policy-only -/

/-- The consensus flag view never selects WITNESS_PUBKEYTYPE (the
`FullFlags.policy` projection of `consensusFullFlags` is constantly
false). -/
@[rule "SCR-182"]
theorem witnessPubKeyType_not_in_consensus (f : ScriptFlags) :
    (consensusFullFlags f).policy .witnessPubKeyType = false := rfl

/-- With the consensus-default policy record (all policy bits off), the
WITNESS_PUBKEYTYPE encoding check never fires. -/
@[rule "SCR-182"]
theorem witnessPubKeyType_off_no_reject (flags : ScriptFlags)
    (sv : SigVersion) (pk : ByteArray) :
    checkPubKeyEncoding flags ({} : PolicyFlags) sv pk = none := by
  simp [checkPubKeyEncoding]

@[rule "SCR-182"]
theorem witnessPubKeyType_rejects_uncompressed (flags : ScriptFlags)
    (pol : PolicyFlags) (sv : SigVersion) (pk : ByteArray)
    (hpol : pol.witnessPubkeyType = true) (hsv : sv = .witnessV0)
    (hstrict : pol.strictEnc = false) (hcomp : isCompressedPubKey pk = false) :
    checkPubKeyEncoding flags pol sv pk = some .witnessPubkeyType := by
  simp [checkPubKeyEncoding, hpol, hsv, hstrict, hcomp]

@[rule "SCR-182"]
theorem witnessPubKeyType_distinct :
    PolicyFlag.witnessPubKeyType ≠ .minimalIfV0 ∧
    PolicyFlag.witnessPubKeyType ≠ .cleanStack ∧
    PolicyFlag.witnessPubKeyType ≠ .lowS := by
  decide

end BitcoinProofs.AF.PDW96

#print axioms BitcoinProofs.AF.PDW96.decodeNum_minimal_reject
#print axioms BitcoinProofs.AF.PDW96.checksigAddStep_nonminimal
#print axioms BitcoinProofs.AF.PDW96.checksigAddStep_oversize
#print axioms BitcoinProofs.AF.PDW96.stepBody_minimalif_witnessv0
#print axioms BitcoinProofs.AF.PDW96.stepBody_drop_empty
#print axioms BitcoinProofs.AF.PDW96.witnessPubKeyType_not_in_consensus
#print axioms BitcoinProofs.AF.PDW96.witnessPubKeyType_off_no_reject
#print axioms BitcoinProofs.AF.PDW96.witnessPubKeyType_rejects_uncompressed
#print axioms BitcoinProofs.AF.PDW96.witnessPubKeyType_distinct
