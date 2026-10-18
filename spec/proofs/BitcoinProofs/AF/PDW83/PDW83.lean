import Bitcoin.Interpreter.Rules
import Bitcoin.Crypto.Taproot.Sighash

set_option maxHeartbeats 800000

/-! # BitcoinProofs.AF.PDW83 — TOP-436..440 hard-tail row faces

Route B: proofs-side row faces over the existing core definitions; zero
core writes. Axiom pins in `PDW83Guards.lean` target the charter subset
`[propext, Classical.choice, Quot.sound]`.
-/

namespace BitcoinProofs.AF.PDW83

open Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Numeric Bitcoin.Activation
open Bitcoin.Interpreter
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)

/-! ## SCR-098 — `FindAndDelete` byte-scan boundary laws -/

/-- **SCR-098 (empty needle)**: deleting the empty byte string is the
identity: Core's `FindAndDelete` returns immediately for `b.size()==0`. -/
@[rule "SCR-098"]
theorem findAndDelete_empty_needle (script : ByteArray) :
    findAndDelete script ByteArray.empty = (0, script) := by
  simp [findAndDelete]

/-- **SCR-098 (empty script)**: on an empty script no needle can occur at
an opcode boundary, so the scan reports zero and returns the script. -/
@[rule "SCR-098"]
theorem findAndDelete_empty_script (b : ByteArray) :
    findAndDelete ByteArray.empty b = (0, ByteArray.empty) := by
  by_cases h : b.size = 0
  · simp [findAndDelete, h]
  · have hpos : 0 < b.size := Nat.pos_of_ne_zero h
    simp [findAndDelete, findAndDeleteAux, findAndDeleteMatches, hpos, h]

/-! ## SCR-116 — `cmsLoop` signature/key order and early exit -/

/-- **SCR-116 (base)**: with no signatures left the CMS loop succeeds
without touching a key. -/
@[rule "SCR-116"]
theorem cmsLoop_zero_sigs (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sc : ByteArray) (st : Stack) (fuel nKeys isig ikey : Nat) :
    cmsLoop flags pol sv chk ed sc st fuel nKeys 0 isig ikey = .ok true := by
  unfold cmsLoop
  simp

/-- **SCR-116 (early exit)**: once the remaining signature count exceeds
the remaining key count, the very next iteration returns `false` after its
encoding checks — Core's `if (nSigsCount > nKeysCount) return false;`. -/
@[rule "SCR-116"]
theorem cmsLoop_sig_exceeds_keys (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sc : ByteArray) (st : Stack) (f nKeys nSigs isig ikey : Nat)
    (hn : nKeys < nSigs) (hk : 1 ≤ nKeys)
    (hse : checkSigEncoding flags pol st[isig-1]! = none)
    (hpe : checkPubKeyEncoding flags pol sv st[ikey-1]! = none) :
    cmsLoop flags pol sv chk ed sc st (f+1) nKeys nSigs isig ikey = .ok false := by
  have hn0 : nSigs ≠ 0 := by omega
  unfold cmsLoop
  rw [ite_eq_right hn0]
  simp only [hse, hpe]
  by_cases hf : chk.base.checkECDSASignature st[isig-1]! st[ikey-1]! sc sv ed = true
  · rw [ite_eq_left hf]
    have hlt : nKeys - 1 < nSigs - 1 := by omega
    simp [hlt]
  · rw [ite_eq_right hf]
    have hlt : nKeys - 1 < nSigs := by omega
    simp [hlt]

/-! ## SCR-145 — BIP341 control-block size lattice -/

/-- **SCR-145 (positive)**: a control block of size `33 + 32·k` with
`k ≤ 128` is inside the accepted lattice (33..4129, node-stride). -/
@[rule "SCR-145"]
theorem taprootControl_lattice_mem (c : ByteArray) (k : Nat) (hk : k ≤ 128)
    (h : c.size = TAPROOT_CONTROL_BASE_SIZE + TAPROOT_CONTROL_NODE_SIZE * k) :
    ¬(c.size < TAPROOT_CONTROL_BASE_SIZE ∨ TAPROOT_CONTROL_MAX_SIZE < c.size ∨
      (c.size - TAPROOT_CONTROL_BASE_SIZE) % TAPROOT_CONTROL_NODE_SIZE ≠ 0) := by
  simp only [TAPROOT_CONTROL_BASE_SIZE, TAPROOT_CONTROL_NODE_SIZE,
    TAPROOT_CONTROL_MAX_SIZE] at *
  have hm : (33 + 32 * k - 33) % 32 = 0 := by
    have hsub : 33 + 32 * k - 33 = 32 * k := by omega
    rw [hsub]
    exact Nat.mod_eq_zero_of_dvd (Nat.dvd_mul_right 32 k)
  omega

/-- **SCR-145 (negative)**: on the taproot script-path (`[script, control]`
with a non-empty, non-annex control item), an off-lattice control size is
`TAPROOT_WRONG_CONTROL_SIZE` — checked before the leaf/tweak lane. -/
@[rule "SCR-145"]
theorem verifyWitnessProgram_taproot_control_bad
    (fuel : Nat) (script control program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (htap : flags.taproot = true) (h32 : program.size = 32)
    (hne : control.size ≠ 0) (htag : (byteOr control 0).toNat ≠ ANNEX_TAG)
    (hbad : control.size < TAPROOT_CONTROL_BASE_SIZE ∨
      TAPROOT_CONTROL_MAX_SIZE < control.size ∨
      (control.size - TAPROOT_CONTROL_BASE_SIZE) % TAPROOT_CONTROL_NODE_SIZE ≠ 0) :
    verifyWitnessProgram fuel [script, control] 1 program flags pol chk false
      = VerifyOutcome.fail .taprootWrongControlSize := by
  simp [verifyWitnessProgram, htap, h32, hne, htag, hbad]

/-! ## SCR-169 — BIP341 `SigTaprootHash` shape -/

/-- **SCR-169**: the taproot sighash is the `TapSighash` tagged hash of
`0x00 ‖ SigMsg` — the epoch byte is first and hashed once. -/
@[rule "SCR-169"]
theorem sighashTaproot_epoch_row
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) :
    Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht sv d
      = (Bitcoin.Crypto.Taproot.sigMsgTaproot env inPos ht sv d).map
          (fun m => Bitcoin.Crypto.Schnorr.taggedHash
            Bitcoin.Crypto.Schnorr.tagTapSighash (serU8 0 ++ m)) := rfl

/-- **SCR-169**: a missing signature message is exactly the `none` case of
the sighash (the epoch/tagged-hash wrapper never invents a digest). -/
@[rule "SCR-169"]
theorem sighashTaproot_none_iff
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) :
    Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht sv d = none
      ↔ Bitcoin.Crypto.Taproot.sigMsgTaproot env inPos ht sv d = none := by
  unfold Bitcoin.Crypto.Taproot.sighashTaproot
  cases Bitcoin.Crypto.Taproot.sigMsgTaproot env inPos ht sv d <;> simp

/-! ## SCR-096 — executed `OP_CODESEPARATOR` records the next offset -/

/-- **SCR-096**: an executed `OP_CODESEPARATOR` (wire `0xab`) sets
`codeSep := op.next` (Core's `pbegincodehash = pc` after `GetOp`), while
the op budget is still charged as usual. -/
@[rule "SCR-096"]
theorem stepBody_codesep_records_next (ctx : Ctx) (op : WireOp) (st : State)
    (hw : op.wire = 0xab) (c : Fin 256) (hc : op.ast = .op c)
    (hfExec : st.vf.all id = true)
    (hsep : ¬(ctx.sv = .base ∧ ctx.pol.constScriptCode = true))
    (hbudget : ¬(((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire) ∧
      MAX_OPS_PER_SCRIPT < (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
        then st.opCount + 1 else st.opCount))) :
    stepBody ctx op st
      = .ok { st with
          opCount := (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
            then st.opCount + 1 else st.opCount),
          codeSep := op.next, codeSepPos := st.opcodeIndex } := by
  cases op with
  | mk ast wire next =>
    simp only at hc hw ⊢
    subst ast
    simp only [hw] at hbudget ⊢
    simp only [stepBody]
    simp only [Bool.not_true, Bool.false_eq_true, ite_false]
    rw [ite_eq_right hbudget]
    rw [ite_eq_right (by decide : ¬(disabledWire 0xab = true))]
    rw [ite_eq_right (by rintro ⟨_, hb, hc⟩; exact hsep ⟨hb, hc⟩)]
    simp only [hfExec]
    simp [stepBody.dispatchOp]

/-! ## SCR-099 — CONST_SCRIPTCODE rejects a FindAndDelete hit -/

/-- **SCR-099**: under `CONST_SCRIPTCODE` (policy), a BASE-signature
`FindAndDelete` hit aborts with `SIG_FINDANDDELETE` before any encoding
check or signature verdict. -/
@[rule "SCR-099"]
theorem evalChecksigPreTapscript_constScriptCode_row
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sv : SigVersion) (codeSep : Nat) (bytes sig pk : ByteArray)
    (hsv : sv = .base)
    (hfound : 0 < (findAndDelete (bytes.extract codeSep bytes.size)
      (pushBytesWire sig)).1)
    (hpol : pol.constScriptCode = true) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk
      = .error .sigFindAndDelete := by
  subst hsv
  unfold evalChecksigPreTapscript
  simp only [if_true]
  generalize hfd : findAndDelete (bytes.extract codeSep bytes.size)
    (pushBytesWire sig) = fd
  obtain ⟨found, sc'⟩ := fd
  rw [hfd] at hfound
  simp only at hfound
  rw [ite_eq_left (show 0 < found ∧ pol.constScriptCode = true from ⟨hfound, hpol⟩)]

end BitcoinProofs.AF.PDW83

/-! ## Axiom pins (charter subset `[propext, Classical.choice, Quot.sound]`) -/

/-- info: 'BitcoinProofs.AF.PDW83.findAndDelete_empty_needle' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.findAndDelete_empty_needle
/-- info: 'BitcoinProofs.AF.PDW83.findAndDelete_empty_script' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.findAndDelete_empty_script
/-- info: 'BitcoinProofs.AF.PDW83.cmsLoop_zero_sigs' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.cmsLoop_zero_sigs
/-- info: 'BitcoinProofs.AF.PDW83.cmsLoop_sig_exceeds_keys' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.cmsLoop_sig_exceeds_keys
/-- info: 'BitcoinProofs.AF.PDW83.taprootControl_lattice_mem' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.taprootControl_lattice_mem
/-- info: 'BitcoinProofs.AF.PDW83.verifyWitnessProgram_taproot_control_bad' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.verifyWitnessProgram_taproot_control_bad
/-- info: 'BitcoinProofs.AF.PDW83.sighashTaproot_epoch_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.sighashTaproot_epoch_row
/-- info: 'BitcoinProofs.AF.PDW83.sighashTaproot_none_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.sighashTaproot_none_iff
/-- info: 'BitcoinProofs.AF.PDW83.stepBody_codesep_records_next' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.stepBody_codesep_records_next
/-- info: 'BitcoinProofs.AF.PDW83.evalChecksigPreTapscript_constScriptCode_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW83.evalChecksigPreTapscript_constScriptCode_row
