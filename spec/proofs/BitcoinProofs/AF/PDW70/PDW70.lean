import Bitcoin.Ledger.Interface

/-! # PDW70.lean — TOP-371..373: D-UTXO ledger row faces (BLK-092/093/095)
Claim `d6e28e7`. Route B: zero core writes; row-face theorems on my own
`@[rule]` tags, reusing W12's sorry-free helper theorems. BLK-110 is
yielded to the concurrent PDW68 claim; BLK-095 takes its slot. -/

namespace BitcoinProofs.AF.PDW70

open Bitcoin.Ledger Bitcoin.Data

/-- **BLK-092**: executable `updateCoinsL` computes the pointwise
`updateCoins` (SpendCoin-all, then AddCoins; `validation.cpp:1998-2011`). -/
@[rule "BLK-092"]
theorem updateCoinsL_row (l : List (OutPoint × Coin)) (tx : Tx) (key : Key)
    (height : UInt32) (o : OutPoint) :
    coinLookup (updateCoinsL l tx key height) o =
      updateCoins (viewOf l) tx key height o :=
  congrFun (updateCoinsL_abstract l tx key height) o

/-- **BLK-092 (spend-then-add stages)**: in the non-coinbase lane the
executable update first drops exactly the coins `tx` spends — the ones its
undo payload `spentUndo` records — and then prepends all of `tx`'s added
output coins (`AddCoins`). This is the stage decomposition the row names,
not merely lookup equivalence with the pointwise view. -/
@[rule "BLK-092"]
theorem updateCoinsL_spend_then_add (l : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32) (hcb : tx.isCoinBase = false) :
    updateCoinsL l tx key height =
      addedCoins tx key height ++
        l.filter (fun p => (coinLookup (spentUndo (viewOf l) tx) p.1).isNone) := by
  rw [updateCoinsL, hcb]
  simp only [Bool.false_or]
  congr 1
  apply List.filter_congr
  intro p hp
  by_cases hany : tx.vin.any (fun i => i.prevout == p.1) = true
  · have hne : (coinLookup (spentUndo (viewOf l) tx) p.1).isNone = false := by
      obtain ⟨i, hi, hpi⟩ := List.any_eq_true.mp hany
      have hpo : i.prevout = p.1 := outPointBEq_eq _ _ hpi
      have hsome : (coinLookup l p.1).isSome = true := coinLookup_isSome_of_mem l p hp
      cases hl : coinLookup l p.1 with
      | none => simp [hl] at hsome
      | some c =>
        have hmem : (p.1, c) ∈ spentUndo (viewOf l) tx :=
          mem_spentUndo_of_input (viewOf l) tx i hi p.1 c hpo hl
        have his : (coinLookup (spentUndo (viewOf l) tx) p.1).isSome = true :=
          coinLookup_isSome_of_mem (spentUndo (viewOf l) tx) (p.1, c) hmem
        cases hcl : coinLookup (spentUndo (viewOf l) tx) p.1 with
        | none => simp [hcl] at his
        | some c' => simp [hcl]
    simp [hany, hne]
  · have hanyf : tx.vin.any (fun i => i.prevout == p.1) = false := by
      simpa [Bool.not_eq_true] using hany
    have hnone : coinLookup (spentUndo (viewOf l) tx) p.1 = none :=
      spentUndo_lookup_none_of_any_false (viewOf l) tx p.1 hanyf
    simp [hanyf, hnone]

/-- **BLK-093** (insert side): every stored coin comes from a spendable
in-range output; unspendable scriptPubKeys are never inserted. -/
@[rule "BLK-093"]
theorem addedCoins_spendable_row (tx : Tx) (key : Key) (height : UInt32)
    (p : OutPoint × Coin) (hmem : p ∈ addedCoins tx key height) :
    scriptUnspendable p.2.scriptPubKey = false := by
  obtain ⟨j, hj, hp1, hus, hp2⟩ := addedCoins_inv tx key height p hmem
  rw [hp2]
  exact hus

/-- **BLK-093** (converse): every spendable in-range output is inserted. -/
@[rule "BLK-093"]
theorem addedCoins_mem_row (tx : Tx) (key : Key) (height : UInt32) (j : Nat)
    (hj : j < tx.vout.length)
    (hus : scriptUnspendable (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey = false) :
    (key OutPoint.null (UInt32.ofNat j),
      ⟨(tx.vout.getD j ⟨0, Script.empty⟩).value, height, tx.isCoinBase,
        (tx.vout.getD j ⟨0, Script.empty⟩).scriptPubKey⟩) ∈ addedCoins tx key height :=
  addedCoins_mem tx key height j hj hus

/-- **BLK-095** (coinbase lane): the spend filter is fully bypassed, so the
new coinbase outputs are simply prepended and may overwrite older coins
(pre-BIP30 duplicate semantics, `validation.cpp:1998-2011`). -/
@[rule "BLK-095"]
theorem updateCoinsL_coinbase_row (l : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32) (hcb : tx.isCoinBase = true) :
    updateCoinsL l tx key height = addedCoins tx key height ++ l := by
  simp [updateCoinsL, hcb]

/-- **BLK-095** (non-coinbase lane): every spent prevout is filtered out of
the old view, so an overwrite needs the explicit BIP30 check. -/
@[rule "BLK-095"]
theorem updateCoinsL_noncoinbase_row (l : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32) (hcb : tx.isCoinBase = false) :
    updateCoinsL l tx key height =
      addedCoins tx key height ++
        l.filter (fun p => !(tx.vin.any (fun i => i.prevout == p.1))) := by
  simp [updateCoinsL, hcb]

/-- **BLK-095 (non-coinbase explicit-check arm)**: if a non-coinbase output
reuses the key of a coin already in the view and the spend stage does not
remove that coin (`hnotspent`), then Core's explicit BIP30 duplicate check
`bip30Collision` is true for the transaction — the overwrite is not silent.
The coinbase lane bypasses this via `updateCoinsL_coinbase_row`. -/
@[rule "BLK-095"]
theorem updateCoinsL_noncoinbase_overwrite_requires_check
    (l : List (OutPoint × Coin)) (tx : Tx) (key : Key) (height : UInt32)
    (hcb : tx.isCoinBase = false) (p : OutPoint × Coin)
    (hp : p ∈ addedCoins tx key height)
    (hnotspent : tx.vin.any (fun i => i.prevout == p.1) = false)
    (hold : (viewOf l p.1).isSome = true) :
    bip30Collision (viewOf l) tx key height = true
      ∧ (coinLookup (spentUndo (viewOf l) tx) p.1).isNone = true := by
  constructor
  · obtain ⟨j, hj, hp1, _hus, _hp2⟩ := addedCoins_inv tx key height p hp
    unfold bip30Collision
    rw [List.any_eq_true]
    refine ⟨j, List.mem_range.mpr hj, ?_⟩
    simpa [hp1] using hold
  · have hnone := spentUndo_lookup_none_of_any_false (viewOf l) tx p.1 hnotspent
    simp [hnone]

end BitcoinProofs.AF.PDW70

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/
#print axioms BitcoinProofs.AF.PDW70.updateCoinsL_row
#print axioms BitcoinProofs.AF.PDW70.addedCoins_spendable_row
#print axioms BitcoinProofs.AF.PDW70.addedCoins_mem_row
#print axioms BitcoinProofs.AF.PDW70.updateCoinsL_coinbase_row
#print axioms BitcoinProofs.AF.PDW70.updateCoinsL_noncoinbase_row
#print axioms BitcoinProofs.AF.PDW70.updateCoinsL_spend_then_add
#print axioms BitcoinProofs.AF.PDW70.updateCoinsL_noncoinbase_overwrite_requires_check
