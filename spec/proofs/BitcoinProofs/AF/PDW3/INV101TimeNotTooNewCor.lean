import Bitcoin.Block.Pow

/-!
# INV101TimeNotTooNewCor — T9/INV-101 promotion proof (P13)

PDW3 (proof-promotion review 3), recovery review 3, 2026-10-17.
Row INV-101 (`time-too-new`, Satoshi; validation.cpp:4116-4118 @cce32b168):
block time ≤ node-now + 7200 (MAX_FUTURE_BLOCK_TIME).

Statement P13 = `timeNotTooNew_le`, restated 1:1 verbatim from the
PD03 statement registry (`spec/db/findings-af/PD03-stmtcheck.lean`,
statement P13) — the only PDW3 item in the T9 score row (V=54, d2,
CV08 ×8 timewarp-CVE-class audit row). Semantics: acceptance of
`Bitcoin.Block.Pow.timeNotTooNew` (BLK-058) bounds `blockTime.toNat`
by `now.toNat + 7200`. The def is
`timeNotTooNew bt now := decide (bt.toNat ≤ now.toNat + 7200)`
(Pow.lean:245-247); the proof is the pure `decide`-extraction:
`decide_eq_true_eq` (Lean 4.35: `(decide p = true) = p`). No mathlib,
no decide-macro, no induction.

Core anchor note: `+7200` never wraps in the Prop (Nat-valued
`toNat` sides), i.e. the Lean statement carries the intended bound
exactly (Core compares uint32 ptime vs now+7200 with its own
wrap-semantics; the `toNat` model is the honest reading, matching
`timeNotTooNew`'s own def = zero day-0 divergence).

Axiom-pinned in-file (RC03 L3 / PDW10Guards house style):
[propext] — sorry-free.
-/

namespace BitcoinProofs.AF.PDW3

/-- INV-101 (bound dir): `time-too-new` bounds the block time by
node-now + 7200 (MAX_FUTURE_BLOCK_TIME). -/
@[rule "INV-101"]
theorem timeNotTooNew_le {bt now : UInt32}
    (h : Bitcoin.Block.Pow.timeNotTooNew bt now = true) :
    bt.toNat ≤ now.toNat + 7200 := by
  simp only [Bitcoin.Block.Pow.timeNotTooNew, decide_eq_true_eq] at h
  exact h

/--
info: 'BitcoinProofs.AF.PDW3.timeNotTooNew_le' depends on axioms: [propext]
-/
#guard_msgs in #print axioms timeNotTooNew_le

end BitcoinProofs.AF.PDW3
