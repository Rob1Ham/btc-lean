import Bitcoin.Interpreter.Rules

/-! # PDW36.lean — RC27, items TOP-176..180
(PDW36, 2026-10-17; claim 8f82321).

R-SIDE accounting/gate belt of `Bitcoin/Interpreter/Rules.lean`:
SCR-033/034/037 sigop counting + cost, SCR-014 flag-combination gate,
SCR-043 `MAX_PUBKEYS_PER_MULTI_A` (script.cpp:173-205,
interpreter.cpp:2113-2124/2133-2173, tx_verify.cpp:149-168, script.h:37-38).
Route B: zero core writes, tags ride THESE theorems, pins ⊆
[propext, Classical.choice, Quot.sound]. The `witnessSigOps` /
`countWitnessSigOps` faces stay here as un-tagged auxiliaries: those two
rows are YIELDED to PDW33 (later claim a904643, TOP-162/163). -/

namespace BitcoinProofs.AF.PDW36

open Bitcoin.Data
open Bitcoin.Interpreter
open Bitcoin.Script.Parser (pushBytesWire)

/-! ## SCR-014: `flagsComboOk` (VerifyScript flag-combination assert) -/

/-- **SCR-014**: the exact conjunction Core asserts — CLEANSTACK needs
P2SH∧WITNESS, and WITNESS needs P2SH (interpreter.cpp:2113-2124). -/
@[rule "SCR-014"]
theorem flagsComboOk_iff (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags) :
    flagsComboOk flags pol = true ↔
      (pol.cleanstack = false ∨ (flags.p2sh = true ∧ flags.witness = true)) ∧
      (flags.witness = false ∨ flags.p2sh = true) := by
  unfold flagsComboOk
  simp [Bool.and_eq_true, Bool.or_eq_true]

/-- **SCR-014** check face: a passing flag pair with WITNESS on has P2SH
on (the `assert(nFlags & SCRIPT_VERIFY_P2SH)` obligation). -/
theorem flagsComboOk_witness_requires_p2sh (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (h : flagsComboOk flags pol = true) (hw : flags.witness = true) :
    flags.p2sh = true := by
  have h' := h
  unfold flagsComboOk at h'
  rw [decide_eq_true_eq] at h'
  rcases h'.2 with hf | hp
  · rw [hw] at hf
    cases hf
  · exact hp

/-! ## SCR-033: `sigOpCount` (GetSigOpCount) -/

/-- **SCR-033**: the rule layer delegates to the shared two-mode counter. -/
@[rule "SCR-033"]
theorem sigOpCount_eq (ops : List WireOp) (accurate : Bool) :
    sigOpCount ops accurate =
      if accurate then SigOps.accurateSigOpCount ops else SigOps.inaccurateSigOpCount ops := rfl

/-- A lone opcode has no preceding OP_N; trailing numbers are not charged. -/
theorem sigOpCount_single (op : WireOp) :
    sigOpCount [op] true = sigOpCount [op] false :=
  Bitcoin.Interpreter.sigOpCount_single op

/-- Each CHECKMULTISIG uses its own immediately preceding OP_N. -/
@[rule "SCR-033"]
theorem sigOpCount_accurate_multisig (op : WireOp) (rest : List WireOp) (n : Nat)
    (hm : SigOps.isCheckMultiSigWire op.wire = true)
    (hn : SigOps.isCheckSigWire op.wire = false) (h1 : 1 ≤ n) (h16 : n ≤ 16) :
    SigOps.accurateSigOpCountFrom (some (.pushNum n)) (op :: rest) =
      n + SigOps.accurateSigOpCountFrom (some op.ast) rest := by
  simp [SigOps.accurateSigOpCountFrom, SigOps.sigOpStep, hn, hm,
    SigOps.opNumberOf, h1, h16]

/-! ## SCR-034: `p2shSigOpCount` (GetSigOpCount(scriptSig)) -/

/-- **SCR-034** malformed lane: an unparsable scriptSig counts 0
(Core's `pc != end` early return). -/
@[rule "SCR-034"]
theorem p2shSigOpCount_malformed (ss : ByteArray) (h : parseWire ss = none) :
    p2shSigOpCount ss = 0 := by
  simp [p2shSigOpCount, SigOps.p2shScriptSigOps, SigOps.pushOnlyLastData, h]

/-- **SCR-034** empty lane: no last push ⇒ 0 (cleared `vchRet`). -/
@[rule "SCR-034"]
theorem p2shSigOpCount_empty (ss : ByteArray) (h : parseWire ss = some []) :
    p2shSigOpCount ss = 0 := by
  simp [p2shSigOpCount, SigOps.p2shScriptSigOps, SigOps.pushOnlyLastData, h]

/-- **SCR-034**: require every scriptSig opcode to be at most OP_16,
then count the redeem script bytes directly (including a valid prefix). -/
@[rule "SCR-034"]
theorem p2shSigOpCount_push (ss : ByteArray) (ops : List WireOp)
    (last : WireOp) (d : ByteArray) (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true)
    (hlast : ops.getLast? = some last) (hast : last.ast = .pushBytes d) :
    p2shSigOpCount ss = SigOps.witnessScriptSigOps d := by
  simp [p2shSigOpCount, SigOps.p2shScriptSigOps, SigOps.pushOnlyLastData,
    hparse, hpush, hlast, hast]

@[rule "SCR-034"]
theorem p2shSigOpCount_pushOnly (ss : ByteArray) (ops : List WireOp)
    (last : WireOp) (d : ByteArray) (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true)
    (hlast : ops.getLast? = some last) (hast : last.ast = .pushBytes d) :
    p2shSigOpCount ss = SigOps.witnessScriptSigOps d :=
  p2shSigOpCount_push ss ops last d hparse hpush hlast hast

/-- A non-push opcode anywhere in the scriptSig prevents P2SH counting. -/
@[rule "SCR-034"]
theorem p2shSigOpCount_nonpush (ss : ByteArray) (ops : List WireOp)
    (hp : parseWire ss = some ops) (hn : isPushOnlyWire ops = false) :
    p2shSigOpCount ss = 0 := by
  simp [p2shSigOpCount, SigOps.p2shScriptSigOps, SigOps.pushOnlyLastData, hp, hn]

/-! ## SCR-035: `witnessSigOps` (WitnessSigOps) -/

/-- SCR-035 (supplementary, PDW33 row): v0-32 lane: a 32-byte v0
program counts the ACCURATE sigops of the last witness item. -/
theorem witnessSigOps_v0_32 (prog script : ByteArray) (witness : WitnessStack)
    (ops : List WireOp) (h32 : prog.size = 32)
    (hlast : witness.getLast? = some script) (hparse : parseWire script = some ops) :
    witnessSigOps 0 prog witness = sigOpCount ops true := by
  unfold witnessSigOps
  rw [ite_eq_left rfl, ite_eq_right (by omega : ¬ prog.size = 20), ite_eq_left h32]
  simp [hlast, SigOps.witnessScriptSigOps_of_parse _ _ hparse, sigOpCount, SigOps.sigOpCount]

/-- **SCR-035** other-size lane: neither 20 nor 32 ⇒ 0. -/
theorem witnessSigOps_v0_other (prog : ByteArray) (witness : WitnessStack)
    (h20 : prog.size ≠ 20) (h32 : prog.size ≠ 32) :
    witnessSigOps 0 prog witness = 0 := by
  unfold witnessSigOps
  rw [ite_eq_left rfl, ite_eq_right h20, ite_eq_right h32]

/-! ## SCR-036: `countWitnessSigOps` (CountWitnessSigOps) -/

/-- SCR-036 (supplementary, PDW33 row) non-witness, non-P2SH lane: no extension. -/
theorem countWitnessSigOps_nonwitness (ss spk : ByteArray) (witness : WitnessStack)
    (hw : isWitnessProgram spk = none) (hp : isPayToScriptHash spk = false) :
    countWitnessSigOps ss spk witness = 0 := by
  simp [countWitnessSigOps, hw, hp]

/-- **SCR-036** malformed scriptSig lane under P2SH: 0. -/
theorem countWitnessSigOps_malformed (ss spk : ByteArray) (witness : WitnessStack)
    (hw : isWitnessProgram spk = none) (hp : isPayToScriptHash spk = true)
    (h : parseWire ss = none) : countWitnessSigOps ss spk witness = 0 := by
  simp [countWitnessSigOps, hw, hp, h]

/-- **SCR-036** non-push-only scriptSig lane: 0 (Core's IsPushOnly gate). -/
theorem countWitnessSigOps_nonpush (ss spk : ByteArray) (witness : WitnessStack)
    (ops : List WireOp) (hw : isWitnessProgram spk = none)
    (hp : isPayToScriptHash spk = true) (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = false) :
    countWitnessSigOps ss spk witness = 0 := by
  simp [countWitnessSigOps, hw, hp, hparse, hpush]

/-- **SCR-036** P2SH-wrapped non-program redeem: 0 extra sigops. -/
theorem countWitnessSigOps_p2sh_nonprogram (ss spk : ByteArray) (witness : WitnessStack)
    (ops : List WireOp) (last : WireOp) (d : ByteArray)
    (hw : isWitnessProgram spk = none) (hp : isPayToScriptHash spk = true)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = true)
    (hlast : ops.getLast? = some last) (hast : last.ast = .pushBytes d)
    (hd : isWitnessProgram d = none) :
    countWitnessSigOps ss spk witness = 0 := by
  simp [countWitnessSigOps, hw, hp, hparse, hpush, hlast, hast, hd]

/-- **SCR-036** P2SH-wrapped witness program: the redeem's WitnessSigOps. -/
theorem countWitnessSigOps_p2sh_program (ss spk : ByteArray) (witness : WitnessStack)
    (ops : List WireOp) (last : WireOp) (d : ByteArray) (v : Nat) (prog : ByteArray)
    (hw : isWitnessProgram spk = none) (hp : isPayToScriptHash spk = true)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = true)
    (hlast : ops.getLast? = some last) (hast : last.ast = .pushBytes d)
    (hd : isWitnessProgram d = some (v, prog)) :
    countWitnessSigOps ss spk witness = witnessSigOps v prog witness := by
  simp [countWitnessSigOps, hw, hp, hparse, hpush, hlast, hast, hd]

/-! ## SCR-037: `sigOpCost` (GetTransactionSigOpCost) -/

/-- **SCR-037**: every legacy/P2SH sigop weighs 4, every witness sigop 1. -/
@[rule "SCR-037"]
theorem sigOpCost_eq (legacy p2sh witness : Nat) :
    sigOpCost legacy p2sh witness = legacy * 4 + p2sh * 4 + witness := rfl

/-- **SCR-037** budget face: the 80,000 block limit in factored form. -/
theorem sigOpCost_budget_iff (legacy p2sh witness : Nat) :
    sigOpCost legacy p2sh witness ≤ MAX_BLOCK_SIGOPS_COST ↔
      (legacy + p2sh) * 4 + witness ≤ 80000 := by
  unfold sigOpCost MAX_BLOCK_SIGOPS_COST
  omega

/-- **SCR-037** lower bound: a legacy sigop costs at least one unit. -/
theorem sigOpCost_ge_legacy (legacy p2sh witness : Nat) :
    legacy ≤ sigOpCost legacy p2sh witness := by
  unfold sigOpCost
  omega

/-- **SCR-043**: the miniscript `multi_a` pubkey bound is 999
(script.h:37-38, construction-side; the interpreter never reads it). -/
@[rule "SCR-043"]
theorem MAX_PUBKEYS_PER_MULTI_A_eq : MAX_PUBKEYS_PER_MULTI_A = 999 := rfl

/-- **SCR-043** bound face: the 999 cap is strictly below 1000, so any
`multi_a` script family stays under the 1000-pubkey resource tier. -/
theorem MAX_PUBKEYS_PER_MULTI_A_lt_thousand :
    MAX_PUBKEYS_PER_MULTI_A < 1000 := by
  rw [MAX_PUBKEYS_PER_MULTI_A_eq]
  decide

end BitcoinProofs.AF.PDW36
