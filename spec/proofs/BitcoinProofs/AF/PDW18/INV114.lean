import Bitcoin.Invariants.RC10

/-! # PDW18 — INV-114 (route B: tag rides MY theorem, zero core writes)

Coin data model: spent ⇔ null out (coins.h:45-101 @cce32b168
`Coin::IsSpent` / `coinEmpty`). `UtxoSet = OutPoint → Option Coin`, so
`isSpent u o` is `true` exactly when the outpoint has no coin. Mirrors
the pre-existing `TXV-075`-tagged twin `Bitcoin.Invariants.RC10.isSpent_iff`
(RC10.lean:47); the core def/tag sites (RC10.lean:42, Utxo.lean:21) stay
untouched. -/

namespace BitcoinProofs.AF.PDW18

open Bitcoin.Invariants.RC10
open Bitcoin.Data (OutPoint)
open Bitcoin.Ledger (Coin UtxoSet)

@[rule "INV-114"]
theorem isSpent_true_iff_none (u : UtxoSet) (o : OutPoint) :
    isSpent u o = true ↔ u o = none :=
  Bitcoin.Invariants.RC10.isSpent_iff u o

theorem isSpent_false_iff_some (u : UtxoSet) (o : OutPoint) :
    isSpent u o = false ↔ ∃ c, u o = some c := by
  constructor
  · intro h
    cases hc : u o with
    | none =>
      have ht : isSpent u o = true := (isSpent_true_iff_none u o).mpr hc
      rw [ht] at h; exact Bool.noConfusion h
    | some c => exact ⟨c, rfl⟩
  · rintro ⟨c, hc⟩
    simp [isSpent, hc]

theorem isSpent_none (u : UtxoSet) (o : OutPoint) (h : u o = none) :
    isSpent u o = true :=
  (isSpent_true_iff_none u o).mpr h

theorem isSpent_some (u : UtxoSet) (o : OutPoint) (c : Coin)
    (h : u o = some c) : isSpent u o = false :=
  (isSpent_false_iff_some u o).mpr ⟨c, h⟩

end BitcoinProofs.AF.PDW18
