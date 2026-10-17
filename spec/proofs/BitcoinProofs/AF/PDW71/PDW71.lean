import Bitcoin.Invariants.RC09

/-! # PDW71 — TOP-376..380: BIP30 / block-time invariant gates (route B)

Row-face theorems over in-tree core decls (`Bitcoin/Block/Pow.lean`,
`Bitcoin/Block/Params.lean`, `Bitcoin/Ledger/Interface.lean`,
`Bitcoin/Invariants/RC09.lean`). Zero core writes; tags ride THESE
theorems; pins ⊆ [propext, Classical.choice, Quot.sound]. -/

namespace BitcoinProofs.AF.PDW71

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Block
open Bitcoin.Invariants.RC09

/-! ## INV-099 — time-too-old is the strict `blockTime > MTP` gate -/

/-- INV-099 (validation.cpp:4100-4101): `ContextualCheckBlockHeader`
rejects iff the header time is not strictly greater than the previous
median-time-past. -/
@[rule "INV-099"]
theorem timeNotTooOld_row (blockTime mtp : UInt32) :
    Bitcoin.Block.Pow.timeNotTooOld blockTime mtp = true ↔ mtp < blockTime := by
  unfold Bitcoin.Block.Pow.timeNotTooOld
  exact decide_eq_true_iff

/-- INV-099 boundary: MTP itself is too old; one second above passes. -/
@[rule "INV-099"]
theorem timeNotTooOld_boundary_row :
    Bitcoin.Block.Pow.timeNotTooOld 100 100 = false ∧
    Bitcoin.Block.Pow.timeNotTooOld 101 100 = true := ⟨rfl, rfl⟩

/-! ## INV-105 / BLK-099 — the BIP30 91722/91812 disconnect carve-out -/

/-- INV-105/BLK-099: the relaxed-disconnect predicate holds at exactly
the two historical duplicate-coinbase heights. -/
@[rule "INV-105", rule "BLK-099"]
theorem bip30DisconnectRelaxed_row (h : UInt32) :
    Bitcoin.Block.Params.bip30DisconnectRelaxed h = true ↔
      h.toNat = 91722 ∨ h.toNat = 91812 := by
  simp [Bitcoin.Block.Params.bip30DisconnectRelaxed]

/-- INV-105/BLK-099 pins: the pair says true; the next height says false. -/
@[rule "INV-105", rule "BLK-099"]
theorem bip30DisconnectRelaxed_pair_row :
    Bitcoin.Block.Params.bip30DisconnectRelaxed 91722 = true ∧
    Bitcoin.Block.Params.bip30DisconnectRelaxed 91812 = true ∧
    Bitcoin.Block.Params.bip30DisconnectRelaxed 91723 = false :=
  ⟨by decide, by decide, by decide⟩

/-- BLK-099: every relaxed height sits strictly below BIP34 activation. -/
@[rule "BLK-099"]
theorem bip30DisconnectRelaxed_belowBIP34_row (h : UInt32)
    (hr : Bitcoin.Block.Params.bip30DisconnectRelaxed h = true) :
    h.toNat < Bitcoin.Ledger.BIP34_HEIGHT.toNat :=
  Bitcoin.Block.Params.bip30_relaxed_below_BIP34 h hr

/-! ## INV-104 — BIP30 collision iff an output outpoint is already present -/

/-- INV-104 (validation.cpp:2401-2475): a BIP30 collision is exactly an
output index whose `(null-txid, N)` key is already in the UTXO view. -/
@[rule "INV-104"]
theorem bip30Collision_row (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32) :
    bip30Collision u tx key height = true ↔
      ∃ o ∈ List.range tx.vout.length,
        (u (key OutPoint.null (UInt32.ofNat o))).isSome = true := by
  unfold bip30Collision
  exact List.any_eq_true

/-- INV-104 pass lane: the empty view admits every transaction. -/
@[rule "INV-104"]
theorem bip30Collision_emptyUtxo_row (tx : Tx) (key : Key) (height : UInt32) :
    bip30Collision emptyUtxo tx key height = false := by
  unfold bip30Collision
  exact listAny_false_intro _ _ (fun _ _ => rfl)

/-! ## INV-106 — the BIP34⇒BIP30 optimization window -/

/-- INV-106 (validation.cpp:2429,2458-2466): the skip window proper is
`227931 < h < 1983702` (the D2a-fixed half-open interval). -/
@[rule "INV-106"]
theorem bip30OptimizationWindow_row (h : UInt32) :
    bip30OptimizationWindow h = true ↔
      BIP34_HEIGHT < h ∧ h < BIP34_IMPLIES_BIP30_LIMIT := by
  simp [bip30OptimizationWindow]

/-- INV-106: inside the window BIP30 enforcement is off. -/
@[rule "INV-106"]
theorem bip30OptimizationWindow_disables_row (height : UInt32)
    (hw : bip30OptimizationWindow height = true) :
    Bitcoin.Ledger.bip30Enforced height = false :=
  inv106_window_disables_bip30 height hw

end BitcoinProofs.AF.PDW71

/-- info: 'BitcoinProofs.AF.PDW71.timeNotTooOld_row' depends on axioms: [propext] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW71.timeNotTooOld_row
/-- info: 'BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_row' depends on axioms: [propext] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_row
/-- info: 'BitcoinProofs.AF.PDW71.bip30Collision_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW71.bip30Collision_row
/-- info: 'BitcoinProofs.AF.PDW71.bip30OptimizationWindow_row' depends on axioms: [propext] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW71.bip30OptimizationWindow_row

/-- info: 'BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_belowBIP34_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_belowBIP34_row
/-- info: 'BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_pair_row' does not depend on any axioms -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW71.bip30DisconnectRelaxed_pair_row
