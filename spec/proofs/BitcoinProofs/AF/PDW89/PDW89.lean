import Bitcoin.Interpreter.Defs
import Bitcoin.Activation.Flags

/-! # PDW89 — final promotion push: decodeNum / MINIMALIF / NOP / pubkey-type row faces

Rows: SCR-051, SCR-059, SCR-078, SCR-071, SCR-157, SCR-182. Route B:
theorems over existing core definitions; zero core writes. Independently
reproduced row faces (peer probes PDW96/PDW98 used only as cross-checks). -/

namespace BitcoinProofs.AF.PDW89
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData)

/-! ## SCR-051 / SCR-157 — numeric operands and the minimal-encoding gate -/

/-- SCR-051: under MINIMALDATA a redundant sign/zero byte is rejected at
decode time (`CScriptNum` error → SCRIPTNUM). -/
@[rule "SCR-051"]
theorem decodeNum_minimal_reject (pol : PolicyFlags) (b : ByteArray)
    (hpol : pol.minimalData = true)
    (h : 1 < b.size ∧ (b.get! (b.size - 1)).toNat = 0 ∧
         (b.get! (b.size - 2)).toNat < 128) :
    decodeNum pol b SCRIPT_NUM_DEFAULT_MAX_SIZE = .error .scriptNum := by
  unfold decodeNum
  rw [hpol, scriptNum_minimal_reject b h]

/-- SCR-157: the width bound is checked before the minimal flag — any
operand wider than `maxSize` decodes to `none`. -/
theorem decodeScriptNum_none_of_gt (b : ByteArray) (minimal : Bool) (maxSize : Nat)
    (h : maxSize < b.size) : decodeScriptNum b minimal maxSize = none := by
  unfold decodeScriptNum decodeBE
  have hlen : maxSize < (bytesOf b).reverse.length := by
    rw [List.length_reverse, bytesOf_length]; exact h
  rw [ite_eq_left hlen]

/-- SCR-157: CHECKSIGADD's 4-byte numeric operand rejects a non-minimal
encoding before the signature is evaluated. -/
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

/-- SCR-157: an oversize (≥5-byte) CHECKSIGADD operand fails regardless
of the policy flag. -/
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
  simp [ha, hw, hsv, hfe, hbudget, hstack,
    Nat.not_lt.mpr hbudget, Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]

/-! ## SCR-071 — DISCOURAGE_UPGRADABLE_NOPS policy gate (OP_NOP1/4..10) -/

/-- SCR-071: an executed OP_NOP1 / OP_NOP4..OP_NOP10 under the policy
flag fails with DISCOURAGE_UPGRADABLE_NOPS; without the flag it is a
no-op. -/
@[rule "SCR-071"]
theorem stepBody_discourage_nops {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o)
    (hw : op.wire = 0xb0 ∨ (0xb3 ≤ op.wire ∧ op.wire ≤ 0xb9))
    (hfe : st.vf.all id = true)
    (hpol : ctx.pol.discourageUpgradableNops = true)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx op st = .error .discourageUpgradableNops := by
  rcases hw with h | ⟨h1, h2⟩
  · rw [stepBody, h]
    by_cases hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0
    · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
        intro hc; exact hbudget ⟨hsv, hc⟩
      simp [ha, hfe, hpol, hsv, hb, disabledWire,
        Bitcoin.Interpreter.stepBody.dispatchOp]
    · simp [ha, hfe, hpol, hsv, disabledWire,
        Bitcoin.Interpreter.stepBody.dispatchOp]
  · have hw' : op.wire = 0xb3 ∨ op.wire = 0xb4 ∨ op.wire = 0xb5 ∨
        op.wire = 0xb6 ∨ op.wire = 0xb7 ∨ op.wire = 0xb8 ∨ op.wire = 0xb9 := by omega
    rcases hw' with h | h | h | h | h | h | h
    all_goals
      rw [stepBody, h]
      by_cases hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0
      · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
          intro hc; exact hbudget ⟨hsv, hc⟩
        simp [ha, hfe, hpol, hsv, hb, disabledWire,
          Bitcoin.Interpreter.stepBody.dispatchOp]
      · simp [ha, hfe, hpol, hsv, disabledWire,
          Bitcoin.Interpreter.stepBody.dispatchOp]

/-! ## SCR-182 — WITNESS_PUBKEYTYPE is policy-only -/

@[rule "SCR-182"]
theorem witnessPubKeyType_not_in_consensus (f : ScriptFlags) :
    (consensusFullFlags f).policy .witnessPubKeyType = false := rfl

/-- SCR-182: consensus-default policy never rejects an uncompressed
witness-v0 key on WITNESS_PUBKEYTYPE grounds. -/
@[rule "SCR-182"]
theorem witnessPubKeyType_off_no_reject (flags : ScriptFlags)
    (sv : SigVersion) (pk : ByteArray) :
    checkPubKeyEncoding flags ({} : PolicyFlags) sv pk = none := by
  simp [checkPubKeyEncoding]

/-- SCR-182: with the policy bit on, an uncompressed witness-v0 key is
rejected with WITNESS_PUBKEYTYPE. -/
@[rule "SCR-182"]
theorem witnessPubKeyType_rejects_uncompressed (flags : ScriptFlags)
    (pol : PolicyFlags) (sv : SigVersion) (pk : ByteArray)
    (hpol : pol.witnessPubkeyType = true) (hsv : sv = .witnessV0)
    (hstrict : pol.strictEnc = false) (hcomp : isCompressedPubKey pk = false) :
    checkPubKeyEncoding flags pol sv pk = some .witnessPubkeyType := by
  simp [checkPubKeyEncoding, hpol, hsv, hstrict, hcomp]

end BitcoinProofs.AF.PDW89

#print axioms BitcoinProofs.AF.PDW89.decodeNum_minimal_reject
#print axioms BitcoinProofs.AF.PDW89.checksigAddStep_nonminimal
#print axioms BitcoinProofs.AF.PDW89.checksigAddStep_oversize
#print axioms BitcoinProofs.AF.PDW89.stepBody_minimalif_witnessv0
#print axioms BitcoinProofs.AF.PDW89.stepBody_drop_empty
#print axioms BitcoinProofs.AF.PDW89.stepBody_discourage_nops
#print axioms BitcoinProofs.AF.PDW89.witnessPubKeyType_not_in_consensus
#print axioms BitcoinProofs.AF.PDW89.witnessPubKeyType_off_no_reject
#print axioms BitcoinProofs.AF.PDW89.witnessPubKeyType_rejects_uncompressed
