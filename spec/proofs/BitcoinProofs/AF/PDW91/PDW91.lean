import Bitcoin.Interpreter.Defs

/-! # PDW91 — RC31 hard-tail faces: SCR-171 / SCR-174 / SCR-155 / SCR-158 / SCR-004

Row faces on `Bitcoin.Interpreter` (route B, zero core writes):

* SCR-171 disabled-opcode gate precedes the fExec gate;
* SCR-174 executed OP_INVALIDOPCODE (0xff) → BAD_OPCODE default;
* SCR-155 tapscript is outside the BASE/WITNESS_V0 MAX_OPS budget;
* SCR-158 tapscript pubkey-size rules (0 / 32 / upgradable);
* SCR-004 empty scriptPubKey spendable. -/

namespace BitcoinProofs.AF.PDW91
open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Crypto.Seam Bitcoin.Numeric

/-- SCR-171: the disabled-opcode gate sits after the op-count guard and
BEFORE the fExec gate — an unexecuted disabled opcode still fails. -/
@[rule "SCR-171"]
theorem stepBody_disabled_unexec {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : disabledWire op.wire = true)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = false) :
    stepBody ctx op st = .error .disabledOpcode := by
  simp [stepBody, ha, hw, hsv, hfe]

/-- SCR-174: an executed OP_INVALIDOPCODE (0xff) reaches dispatch's
default case: BAD_OPCODE (its wire byte is not disabled). -/
@[rule "SCR-174"]
theorem stepBody_invalidopcode {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0xff)
    (hdis : disabledWire 0xff = false)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true) :
    stepBody ctx op st = .error .badOpcode := by
  simp [stepBody, ha, hw, hdis, hsv, hfe, Bitcoin.Interpreter.stepBody.dispatchOp]

/-- SCR-155: on the tapscript path the BASE/WITNESS_V0 opcode budget is
not consulted — an already-over-budget tapscript OP_NOP still succeeds
(`opCount` untouched). -/
@[rule "SCR-155"]
theorem stepBody_nop_tapscript_overbudget {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x61)
    (hdis : disabledWire 0x61 = false)
    (hsv : ctx.sv = .tapscript) (hfe : st.vf.all id = true)
    (hover : MAX_OPS_PER_SCRIPT < st.opCount) :
    stepBody ctx op st = .ok st := by
  simp [stepBody, ha, hw, hdis, hsv, hfe, Bitcoin.Interpreter.stepBody.dispatchOp]

/-- SCR-158 (0-size pubkey): a non-empty tapscript signature against an
empty pubkey fails with TAPSCRIPT_EMPTY_PUBKEY (budget permitting). -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_empty_pubkey
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 0)
    (hvw : VALIDATION_WEIGHT_PER_SIGOP_PASSED ≤ vw.getD 0) :
    evalChecksigTapscript pol chk ed sig pk vw = .error .tapscriptEmptyPubkey := by
  simp [evalChecksigTapscript, hsig, hpk, hvw]

/-- SCR-158 (32-byte pubkey): a non-empty signature whose Schnorr check
passes is the SCHNORR branch (verdict TRUE, budget charged). -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_32_is_schnorr
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hvw : VALIDATION_WEIGHT_PER_SIGOP_PASSED ≤ vw.getD 0)
    (hchk : chk.base.checkSchnorrSignature sig pk .tapscript ed = true) :
    evalChecksigTapscript pol chk ed sig pk vw =
      .ok (true, some (vw.getD 0 - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk, hvw, hchk]

/-- SCR-158 (other sizes): with DISCOURAGE_UPGRADABLE_PUBKEYTYPE off the
spend succeeds (upgradable pubkey type), verdict TRUE and budget charged. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_upgradable
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hvw : VALIDATION_WEIGHT_PER_SIGOP_PASSED ≤ vw.getD 0)
    (hd : pol.discourageUpgradablePubkeyType = false) :
    evalChecksigTapscript pol chk ed sig pk vw =
      .ok (true, some (vw.getD 0 - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk0, hpk32, hvw, hd]

/-- SCR-158 (other sizes, policy on): the same upgradable pubkey type is
rejected under DISCOURAGE_UPGRADABLE_PUBKEYTYPE. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_upgradable_discouraged
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hvw : VALIDATION_WEIGHT_PER_SIGOP_PASSED ≤ vw.getD 0)
    (hd : pol.discourageUpgradablePubkeyType = true) :
    evalChecksigTapscript pol chk ed sig pk vw =
      .error .discourageUpgradablePubkeyType := by
  simp [evalChecksigTapscript, hsig, hpk0, hpk32, hvw, hd]

/-- SCR-158 suite: the four tapscript pubkey-size classes (non-empty
signature, budget permitting): 0 ⇒ TAPSCRIPT_EMPTY_PUBKEY; 32 ⇒ Schnorr
verdict with budget charged; any other non-empty size ⇒ upgradable
(accepted unless DISCOURAGE_UPGRADABLE_PUBKEYTYPE, in which case
DISCOURAGE_UPGRADABLE_PUBKEYTYPE). -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_pubkey_size_rules
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0)
    (hvw : VALIDATION_WEIGHT_PER_SIGOP_PASSED ≤ vw.getD 0) :
    (pk.size = 0 →
        evalChecksigTapscript pol chk ed sig pk vw = .error .tapscriptEmptyPubkey) ∧
    (pk.size = 32 → chk.base.checkSchnorrSignature sig pk .tapscript ed = true →
        evalChecksigTapscript pol chk ed sig pk vw =
          .ok (true, some (vw.getD 0 - VALIDATION_WEIGHT_PER_SIGOP_PASSED))) ∧
    (pk.size ≠ 0 → pk.size ≠ 32 → pol.discourageUpgradablePubkeyType = false →
        evalChecksigTapscript pol chk ed sig pk vw =
          .ok (true, some (vw.getD 0 - VALIDATION_WEIGHT_PER_SIGOP_PASSED))) ∧
    (pk.size ≠ 0 → pk.size ≠ 32 → pol.discourageUpgradablePubkeyType = true →
        evalChecksigTapscript pol chk ed sig pk vw =
          .error .discourageUpgradablePubkeyType) := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro hpk
    exact evalChecksigTapscript_empty_pubkey pol chk ed sig pk vw hsig hpk hvw
  · intro hpk hchk
    exact evalChecksigTapscript_32_is_schnorr pol chk ed sig pk vw hsig hpk hvw hchk
  · intro hpk0 hpk32 hd
    exact evalChecksigTapscript_upgradable pol chk ed sig pk vw hsig hpk0 hpk32 hvw hd
  · intro hpk0 hpk32 hd
    exact evalChecksigTapscript_upgradable_discouraged pol chk ed sig pk vw hsig hpk0 hpk32 hvw hd

/-- Empty-script helper: with positive fuel, evaluating the empty script
returns the incoming stack untouched. -/
theorem evalScriptBytes_empty (fuel : Nat) (hf : 0 < fuel) (flags : ScriptFlags)
    (pol : PolicyFlags) (st0 : Stack) (chk : ScriptChecker) (sv : SigVersion)
    (ed : ScriptExecutionData) :
    evalScriptBytes fuel flags pol ByteArray.empty st0 chk sv ed = .ok st0 := by
  unfold evalScriptBytes
  have hsize : ¬ ((sv = .base ∨ sv = .witnessV0) ∧
      MAX_SCRIPT_SIZE < ByteArray.empty.size) := by simp
  simp only [hsize, if_false]
  cases fuel with
  | zero => omega
  | succ f =>
    simp [parseWire, parseWireFrom, evalFrom, finalStack]

/-- SCR-004: an empty scriptPubKey is spendable — if the scriptSig leaves
a truthy stack (and WITNESS/P2SH/CLEANSTACK are off) VerifyScript returns
ok. -/
@[rule "SCR-004"]
theorem verifyScriptFull_empty_spk (fuel : Nat) (hf : 0 < fuel)
    (flags : ScriptFlags) (pol : PolicyFlags) (ss : ByteArray)
    (stack1 : Stack) (witness : Bitcoin.Data.WitnessStack) (chk : ScriptChecker)
    (hp : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (htruth : ¬ (stack1 = [] ∨ castToBool (stack1[0]?.getD default) = false))
    (hwit : flags.witness = false) (hp2sh : flags.p2sh = false)
    (hclean : pol.cleanstack = false) :
    verifyScriptFull fuel flags pol ss ByteArray.empty witness chk = .ok := by
  simp [verifyScriptFull, hp, hss, evalScriptBytes_empty fuel hf, htruth,
    hwit, hp2sh, hclean]

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/

/-- info: 'BitcoinProofs.AF.PDW91.stepBody_disabled_unexec' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms stepBody_disabled_unexec
/-- info: 'BitcoinProofs.AF.PDW91.stepBody_invalidopcode' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms stepBody_invalidopcode
/-- info: 'BitcoinProofs.AF.PDW91.stepBody_nop_tapscript_overbudget' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms stepBody_nop_tapscript_overbudget
/-- info: 'BitcoinProofs.AF.PDW91.evalChecksigTapscript_empty_pubkey' depends on axioms: [propext] -/
#guard_msgs in #print axioms evalChecksigTapscript_empty_pubkey
/-- info: 'BitcoinProofs.AF.PDW91.evalChecksigTapscript_32_is_schnorr' depends on axioms: [propext] -/
#guard_msgs in #print axioms evalChecksigTapscript_32_is_schnorr
/-- info: 'BitcoinProofs.AF.PDW91.evalChecksigTapscript_upgradable' depends on axioms: [propext] -/
#guard_msgs in #print axioms evalChecksigTapscript_upgradable
/-- info: 'BitcoinProofs.AF.PDW91.evalChecksigTapscript_upgradable_discouraged' depends on axioms: [propext] -/
#guard_msgs in #print axioms evalChecksigTapscript_upgradable_discouraged
/-- info: 'BitcoinProofs.AF.PDW91.evalChecksigTapscript_pubkey_size_rules' depends on axioms: [propext] -/
#guard_msgs in #print axioms evalChecksigTapscript_pubkey_size_rules
/-- info: 'BitcoinProofs.AF.PDW91.evalScriptBytes_empty' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms evalScriptBytes_empty
/-- info: 'BitcoinProofs.AF.PDW91.verifyScriptFull_empty_spk' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyScriptFull_empty_spk

end BitcoinProofs.AF.PDW91
