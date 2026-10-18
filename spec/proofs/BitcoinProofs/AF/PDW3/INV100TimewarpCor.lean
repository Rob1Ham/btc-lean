import Bitcoin.Block.Pow

/-!
# INV100TimewarpCor — T15/INV-100 promotion proof (P19)

Row INV-100 (BIP94 timewarp guard, validation.cpp:4105-4113 +
consensus.h:35 @cce32b168): on a period boundary (testnet4/regtest,
`enforce_BIP94`) the first-block-of-period time must be at least the
previous block's time minus one target spacing
(`time-timewarp-attack`, blockTime ≥ prevTime − 600).

Statement P19 = `timewarpOk_reject` (PD03.md §T15 sketch,
"3-way-Bool-`||` ¬-push-De-Morgan + omega" — here the stronger
**false-determination** form): under `enforce = true` AND
`atBoundary = true`, a violation of the 600-second spacing makes
`timewarpOk` (= BLK-055) **equal false** (not merely ≠ true).
The def is `timewarpOk en atB bt p := !en || !atB ||
decide (bt.toNat + 600 ≥ p.toNat)` (Pow.lean:209-212); the proof is
pure gate-herding: rewrite the two Bool guards to their `true`
literals, `decide_eq_false` the violated spacing, `simp`. No mathlib,
no induction.

Axiom-pinned in-file (RC03 L3 / PDW10Guards house style):
[propext] — sorry-free.
-/

namespace BitcoinProofs.AF.PDW3

/-- INV-100 (reject dir): BIP94 enforced + period boundary + violated
spacing ⇒ `timewarpOk` is false (the block is rejected). -/
@[rule "INV-100"]
theorem timewarpOk_reject (enforce atBoundary : Bool) (blockTime prevTime : UInt32)
    (hen : enforce = true) (hab : atBoundary = true)
    (hviol : ¬(blockTime.toNat + 600 ≥ prevTime.toNat)) :
    Bitcoin.Block.Pow.timewarpOk enforce atBoundary blockTime prevTime = false := by
  have hd : decide (blockTime.toNat + 600 ≥ prevTime.toNat) = false :=
    decide_eq_false hviol
  rw [Bitcoin.Block.Pow.timewarpOk, hen, hab, hd]
  simp

/--
info: 'BitcoinProofs.AF.PDW3.timewarpOk_reject' depends on axioms: [propext]
-/
#guard_msgs in #print axioms timewarpOk_reject

/-! ## REM-10: the complete gate (both networks)

The audit's residual: `timewarpOk_reject` fixes `enforce = true` and
never states the mainnet face. The gate is `!enforce || !atBoundary ||
spacing-ok`, so these faces pin BOTH settings: with `enforce = false`
(mainnet, `enforce_BIP94 = false`) the gate is unconditionally true;
with `enforce = true` it is false exactly on a boundary whose block
violates the 600-second spacing. -/

/-- Full true characterization: every accepting setting. -/
@[rule "INV-100"]
theorem timewarpOk_eq_true_iff (enforce atBoundary : Bool)
    (blockTime prevTime : UInt32) :
    Bitcoin.Block.Pow.timewarpOk enforce atBoundary blockTime prevTime = true ↔
      enforce = false ∨ atBoundary = false ∨
        (blockTime.toNat + 600 ≥ prevTime.toNat) := by
  simp [Bitcoin.Block.Pow.timewarpOk, Bool.or_eq_true, or_assoc]

/-- Full false characterization: rejected iff enforced, on a period
boundary, and spacing-violating (`time-timewarp-attack`). -/
@[rule "INV-100"]
theorem timewarpOk_eq_false_iff (enforce atBoundary : Bool)
    (blockTime prevTime : UInt32) :
    Bitcoin.Block.Pow.timewarpOk enforce atBoundary blockTime prevTime = false ↔
      enforce = true ∧ atBoundary = true ∧
        ¬(blockTime.toNat + 600 ≥ prevTime.toNat) := by
  simp [Bitcoin.Block.Pow.timewarpOk, Bool.or_eq_false_iff, and_assoc]

/-- Mainnet face: with `enforce_BIP94 = false` the gate never rejects,
whatever the boundary status or timestamps. -/
@[rule "INV-100"]
theorem timewarpOk_mainnet_off (atBoundary : Bool)
    (blockTime prevTime : UInt32) :
    Bitcoin.Block.Pow.timewarpOk false atBoundary blockTime prevTime = true := by
  simp [Bitcoin.Block.Pow.timewarpOk]

end BitcoinProofs.AF.PDW3
