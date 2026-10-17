import Bitcoin.Interpreter.Rules

/-! # PDW33b.lean — TOP-161..165, part 2 (SCR-035/036 witness sigops, SCR-038 budget)
(PDW33, review RC27, 2026-10-17; claim a904643).

Route B (zero core writes): row faces on the sorry-free core defs of
`Bitcoin/Interpreter/Rules.lean`.

* **SCR-035** `witnessSigOps` — BIP141 WitnessSigOps
  (interpreter.cpp:2133-2147): v0-20 = 1, v0-32 = accurate sigop count
  of the witness script, every other version/length = 0.
* **SCR-036** `countWitnessSigOps` — CountWitnessSigOps (:2162-2173):
  bare witness program ⇒ `witnessSigOps`; P2SH-wrapped push-only last
  push that IS a witness program ⇒ `witnessSigOps`; else 0.
* **SCR-038** `MAX_BLOCK_SIGOPS_COST` — the 80,000 per-block budget
  (consensus.h:18) and the `blockSigOpsCostOk` boundary.
-/

namespace BitcoinProofs.AF.PDW33

open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Numeric Bitcoin.Data

@[rule "SCR-035"]
theorem witnessSigOps_v0_20_one_row (witness : WitnessStack) (prog : ByteArray)
    (h20 : prog.size = 20) : witnessSigOps 0 prog witness = 1 :=
  witnessSigOps_v0_20_one witness prog h20

theorem witnessSigOps_v1_zero_row (v : Nat) (program : ByteArray)
    (witness : WitnessStack) (hv : v ≠ 0) : witnessSigOps v program witness = 0 :=
  witnessSigOps_v1_zero v program witness hv

theorem witnessSigOps_v0_32 (witness : WitnessStack) (prog script : ByteArray)
    (ops : List WireOp) (h32 : prog.size = 32)
    (hlast : witness.getLast? = some script) (hparse : parseWire script = some ops) :
    witnessSigOps 0 prog witness = sigOpCount ops true := by
  unfold witnessSigOps
  simp [h32, hlast, hparse]

theorem witnessSigOps_v0_other_zero (witness : WitnessStack) (prog : ByteArray)
    (h20 : prog.size ≠ 20) (h32 : prog.size ≠ 32) :
    witnessSigOps 0 prog witness = 0 := by
  unfold witnessSigOps
  simp [h20, h32]

@[rule "SCR-036"]
theorem countWitnessSigOps_bare_row (ss spk : ByteArray) (witness : WitnessStack)
    (v : Nat) (prog : ByteArray) (hbare : isWitnessProgram spk = some (v, prog)) :
    countWitnessSigOps ss spk witness = witnessSigOps v prog witness :=
  countWitnessSigOps_bare ss spk witness v prog hbare

theorem countWitnessSigOps_p2sh_wrapped (ss spk : ByteArray) (witness : WitnessStack)
    (ops : List WireOp) (last : WireOp) (d : ByteArray) (v : Nat) (prog : ByteArray)
    (hnone : isWitnessProgram spk = none) (hp2sh : isPayToScriptHash spk = true)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = true)
    (hlast : ops.getLast? = some last) (hast : last.ast = .pushBytes d)
    (hd : isWitnessProgram d = some (v, prog)) :
    countWitnessSigOps ss spk witness = witnessSigOps v prog witness := by
  unfold countWitnessSigOps
  simp [hnone, hp2sh, hparse, hpush, hlast, hast, hd]

theorem countWitnessSigOps_nonp2sh_zero (ss spk : ByteArray) (witness : WitnessStack)
    (hnone : isWitnessProgram spk = none) (hp : isPayToScriptHash spk = false) :
    countWitnessSigOps ss spk witness = 0 := by
  unfold countWitnessSigOps
  simp [hnone, hp]

@[rule "SCR-038"]
theorem MAX_BLOCK_SIGOPS_COST_row : MAX_BLOCK_SIGOPS_COST = 80000 := rfl

theorem blockSigOpsCostOk_iff (n : Nat) :
    blockSigOpsCostOk n = true ↔ n ≤ MAX_BLOCK_SIGOPS_COST := by
  unfold blockSigOpsCostOk
  simp

theorem blockSigOpsCostOk_reject (n : Nat) (h : MAX_BLOCK_SIGOPS_COST < n) :
    blockSigOpsCostOk n = false := by
  unfold blockSigOpsCostOk
  simp [Nat.not_le.mpr h]

#print axioms witnessSigOps_v0_20_one_row
#print axioms witnessSigOps_v1_zero_row
#print axioms witnessSigOps_v0_32
#print axioms witnessSigOps_v0_other_zero
#print axioms countWitnessSigOps_bare_row
#print axioms countWitnessSigOps_p2sh_wrapped
#print axioms countWitnessSigOps_nonp2sh_zero
#print axioms MAX_BLOCK_SIGOPS_COST_row
#print axioms blockSigOpsCostOk_iff
#print axioms blockSigOpsCostOk_reject

end BitcoinProofs.AF.PDW33
