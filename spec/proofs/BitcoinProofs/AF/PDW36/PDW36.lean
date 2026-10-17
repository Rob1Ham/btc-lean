import Bitcoin.Interpreter.Rules

/-! # PDW36.lean — proof-promotion review RC27, items TOP-176..180
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

/-- **SCR-033**: the count is exactly the sigop-opcode tally plus the
DecodeOP_N tail (only in ACCURATE mode). -/
@[rule "SCR-033"]
theorem sigOpCount_eq (ops : List WireOp) (accurate : Bool) :
    sigOpCount ops accurate =
      (ops.filter (fun o => isSigOpWire o.wire)).length +
        (if accurate then decodeOpN ops.getLast? else 0) := rfl

/-- A tail opcode outside OP_1..OP_16 contributes no DecodeOP_N value. -/
theorem decodeOpN_eq_zero_of_out_of_range (o : WireOp)
    (h : o.wire < 0x51 ∨ 0x60 < o.wire) : decodeOpN (some o) = 0 := by
  have hc : ¬ (0x51 ≤ o.wire ∧ o.wire ≤ 0x60) := by omega
  simp [decodeOpN, hc]

/-- **SCR-033** corollary: a non-OP_N tail makes accurate = plain. -/
theorem sigOpCount_no_tail (ops : List WireOp) (o : WireOp)
    (hlast : ops.getLast? = some o) (h : o.wire < 0x51 ∨ 0x60 < o.wire) :
    sigOpCount ops true = sigOpCount ops false := by
  unfold sigOpCount
  rw [hlast, decodeOpN_eq_zero_of_out_of_range o h]
  simp

/-! ## SCR-034: `p2shSigOpCount` (GetSigOpCount(scriptSig)) -/

/-- **SCR-034** malformed lane: an unparsable scriptSig counts 0
(Core's `pc != end` early return). -/
@[rule "SCR-034"]
theorem p2shSigOpCount_malformed (ss : ByteArray) (h : parseWire ss = none) :
    p2shSigOpCount ss = 0 := by
  simp [p2shSigOpCount, h]

/-- **SCR-034** empty lane: no last push ⇒ 0 (cleared `vchRet`). -/
@[rule "SCR-034"]
theorem p2shSigOpCount_empty (ss : ByteArray) (h : parseWire ss = some []) :
    p2shSigOpCount ss = 0 := by
  simp [p2shSigOpCount, h]

/-- **SCR-034** push lane: a pushBytes tail is the redeem script and is
counted with the ACCURATE convention. (This is the model's push-tail
rule; for Core fidelity it needs the all-ops guard below.) -/
@[rule "SCR-034"]
theorem p2shSigOpCount_push (ss : ByteArray) (ops : List WireOp)
    (last : WireOp) (d : ByteArray) (hparse : parseWire ss = some ops)
    (hlast : ops.getLast? = some last) (hast : last.ast = .pushBytes d) :
    p2shSigOpCount ss = sigOpCount ((parseWire (pushBytesWire d)).getD []) true := by
  simp [p2shSigOpCount, hparse, hlast, hast]

/-- **SCR-034** push-only lane (Core's all-ops guard): Core walks the
whole scriptSig and returns 0 as soon as it decodes an opcode
`> OP_16` (`script.cpp:183-205`). `isPushOnlyWire ops` is exactly
`every wire ≤ 0x60 = OP_16`, so under it the last push is the redeem
script and the accurate count is returned. -/
@[rule "SCR-034"]
theorem p2shSigOpCount_pushOnly (ss : ByteArray) (ops : List WireOp)
    (last : WireOp) (d : ByteArray) (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true)
    (hlast : ops.getLast? = some last) (hast : last.ast = .pushBytes d) :
    p2shSigOpCount ss = sigOpCount ((parseWire (pushBytesWire d)).getD []) true := by
  simp [p2shSigOpCount, hparse, hlast, hast]

/-! ### SCR-034 residual (FIX-P-DROWS re-audit)

`p2shSigOpCount` itself does NOT implement Core's early `opcode > OP_16`
return: it only inspects the last parsed op. Thus `OP_DUP <push redeem>`
is counted here and returns 0 in Core. The definition lives in
`Bitcoin/Interpreter/Rules.lean`, which is outside this lane; the row is
narrowed to the push-only (all ops ≤ OP_16) case proved by
`p2shSigOpCount_pushOnly`, and the non-push over-count is an explicit
residual, not claimed.

-/

/-! ## SCR-035: `witnessSigOps` (WitnessSigOps) -/

/-- SCR-035 (supplementary, row owned by PDW33): v0-32 lane: a 32-byte v0
program counts the ACCURATE sigops of the last witness item. -/
theorem witnessSigOps_v0_32 (prog script : ByteArray) (witness : WitnessStack)
    (ops : List WireOp) (h32 : prog.size = 32)
    (hlast : witness.getLast? = some script) (hparse : parseWire script = some ops) :
    witnessSigOps 0 prog witness = sigOpCount ops true := by
  unfold witnessSigOps
  rw [ite_eq_left rfl, ite_eq_right (by omega : ¬ prog.size = 20), ite_eq_left h32]
  simp [hlast, hparse]

/-- **SCR-035** other-size lane: neither 20 nor 32 ⇒ 0. -/
theorem witnessSigOps_v0_other (prog : ByteArray) (witness : WitnessStack)
    (h20 : prog.size ≠ 20) (h32 : prog.size ≠ 32) :
    witnessSigOps 0 prog witness = 0 := by
  unfold witnessSigOps
  rw [ite_eq_left rfl, ite_eq_right h20, ite_eq_right h32]

/-! ## SCR-036: `countWitnessSigOps` (CountWitnessSigOps) -/

/-- SCR-036 (supplementary, row owned by PDW33) non-witness, non-P2SH lane: no extension. -/
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
