import Bitcoin.Ledger.Interface

/-! # PDW58C.lean — TOP-313: INV-117 disconnect (reverse transition)
(PDW58, RC29). Row face for `Bitcoin.Ledger.undoCoins`
(validation.cpp:DisconnectBlock:2178-2247 @ cce32b168).
Route B: zero core writes. -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Data Bitcoin.Ledger

/-- INV-117 (restore): every coin in the undo payload reappears unchanged. -/
@[rule "INV-117"]
theorem undoCoins_restore (uAfter : UtxoSet) (spent : List (OutPoint × Coin))
    (tx : Tx) (key : Key) (height : UInt32) (o : OutPoint) (c : Coin)
    (h : coinLookup spent o = some c) :
    undoCoins uAfter spent tx key height o = some c := by
  unfold undoCoins
  rw [h]

/-- INV-117 (blank): a key the disconnected tx added, and which is not
restored from the undo payload, is removed from the view. -/
@[rule "INV-117"]
theorem undoCoins_blank_added (uAfter : UtxoSet) (spent : List (OutPoint × Coin))
    (tx : Tx) (key : Key) (height : UInt32) (o : OutPoint)
    (hs : coinLookup spent o = none)
    (ha : (coinLookup (addedCoins tx key height) o).isSome = true) :
    undoCoins uAfter spent tx key height o = none := by
  unfold undoCoins
  rw [hs]
  simp [ha]

/-- INV-117 (keep): an untouched key keeps its post-state value. -/
@[rule "INV-117"]
theorem undoCoins_keep (uAfter : UtxoSet) (spent : List (OutPoint × Coin))
    (tx : Tx) (key : Key) (height : UInt32) (o : OutPoint)
    (hs : coinLookup spent o = none)
    (ha : (coinLookup (addedCoins tx key height) o).isSome = false) :
    undoCoins uAfter spent tx key height o = uAfter o := by
  unfold undoCoins
  rw [hs]
  simp [ha]

/-- INV-117 (priority — the exact reverse of `updateCoins`'s new-wins
discipline): when `o` is both re-spent and re-added, the restored coin
wins over the insert. -/
@[rule "INV-117"]
theorem undoCoins_restore_wins (uAfter : UtxoSet) (spent : List (OutPoint × Coin))
    (tx : Tx) (key : Key) (height : UInt32) (o : OutPoint) (c : Coin)
    (h : coinLookup spent o = some c) :
    undoCoins uAfter spent tx key height o = some c :=
  undoCoins_restore uAfter spent tx key height o c h

/-- INV-117 (added-key corollary): a coin this tx created (present in
`addedCoins`) and which no input restored is blanked — membership form. -/
@[rule "INV-117"]
theorem undoCoins_blank_added_mem (uAfter : UtxoSet) (spent : List (OutPoint × Coin))
    (tx : Tx) (key : Key) (height : UInt32) (o : OutPoint) (c : Coin)
    (hs : coinLookup spent o = none)
    (hmem : (o, c) ∈ addedCoins tx key height) :
    undoCoins uAfter spent tx key height o = none :=
  undoCoins_blank_added uAfter spent tx key height o hs
    (coinLookup_isSome_of_mem _ _ hmem)

/-- INV-117 (disconnect is the reverse of connect): the existing
round-trip law `updateCoins_undo` instantiated at the row's own `undoCoins`
(the INV-116 theorem, restated as this row's face). -/
@[rule "INV-117"]
theorem undoCoins_roundtrip (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32)
    (h5 : ∀ q ∈ addedKeys tx key height,
      u q = none ∨ tx.vin.any (fun i => i.prevout == q) = true) :
    undoCoins (updateCoins u tx key height) (spentUndo u tx) tx key height = u :=
  updateCoins_undo u tx key height h5

end BitcoinProofs.AF.PDW58
