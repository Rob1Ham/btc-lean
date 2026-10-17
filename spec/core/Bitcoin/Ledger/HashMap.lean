import Bitcoin.Ledger.Interface
import Std.Data.HashMap

/-!
# Bitcoin.Ledger.HashMap — the M1 UTXO instance (X13 U1)

C1's M1 design (report 10 §2 option 2): `Std.HashMap OutPoint Coin` behind
the SAME abstract interface `UtxoSet := OutPoint → Option Coin`, with an
abstraction lemma mirroring W12's assoc-list one exactly:

  `viewOfM (updateCoinsM m tx key height) = updateCoins (viewOfM m) tx key height`

and lifted through the block fold (`applyBlockM_abstract`), plus the
transfer theorem `applyBlockL_applyBlockM_agree` handing every W12
scenario through the HashMap instance unchanged.

Design note (the one semantic subtlety): W12's assoc-list rep resolves
duplicate keys FIRST-match-wins (`coinLookup` prepends `addedCoins`).
`Std.HashMap.insert` is last-write-wins, so the insert fold runs over
`xs.reverse` — the FIRST entry of `xs` is inserted LAST and wins. With
that single twist the abstraction lemma needs NO key-injectivity
hypothesis and holds for the fully generic `Key`, exactly like
`updateCoinsL_abstract`. (For the canonical keys — `txidPreimageKey`,
`txidKey` — `addedCoins` keys are pairwise distinct anyway, so the two
replications agree on every real block; `mapOfL_viewOf` pins the
list→map bridge.)

Everything reuses W12's frozen surface (`addedCoins`, `coinLookup`,
`updateCoins`, `applyTxStepU`, `applyBlockU`, the BIP30/maturity
predicates) — this file only adds the second concrete representation,
per charter §6 [W12] ("HashMap deferred to X13").
-/

namespace Bitcoin.Ledger

open Bitcoin.Data Bitcoin.TxValidation

/-! ## LawfulBEq + Hashable for `OutPoint`

`OutPoint`'s BEq (Data/Tx.lean:41) is `bytesBEq hash hash && n == n`.
W12 already proved `outPointBEq_eq`; reflexivity is immediate. With
`LawfulBEq` in place, core derives `EquivBEq` and `LawfulHashable`
(Init/Data/BEq.lean:66, Init/Data/LawfulHashable.lean) — exactly what
`Std.HashMap`'s lemma API requires. -/

instance : LawfulBEq OutPoint where
  rfl {a} := by
    show (a == a) = true
    simp [BEq.beq, bytesBEq, List.all_eq_true]
  eq_of_beq := by
    intro a b h
    exact outPointBEq_eq a b h

/-- Hash = the 32-byte txid hash mixed with the output index. Any total
function is lawful here (lawfulness flows through `eq_of_beq`), but this
is a real, cheap, well-distributed hash for the wire shape. -/
instance : Hashable OutPoint where
  hash o := mixHash o.hash.hash o.n.toUInt64

/-! ## The map-backed representation -/

/-- Executable representation, milestone M1: `Std.HashMap` (C1 option 2). -/
abbrev UtxoMap := Std.HashMap OutPoint Coin

/-- The abstraction map, map edition (mirror of `viewOf`). -/
def viewOfM (m : UtxoMap) : UtxoSet := fun o => m.get? o

/-- Insert `xs`'s coins, FIRST-match-wins (reverse fold — see module
docstring). This is the map twin of prepending `xs` in `updateCoinsL`. -/
def insertCoinsM (m : UtxoMap) (xs : List (OutPoint × Coin)) : UtxoMap :=
  xs.reverse.foldl (fun acc p => acc.insert p.1 p.2) m

/-- Spend `tx`'s prevouts (`CCoinsViewCache::SpendCoin`); the coinbase
skips the removal loop (INV-110 — its single input is the null prevout). -/
def erasePrevoutsM (m : UtxoMap) (tx : Tx) : UtxoMap :=
  if tx.isCoinBase then m
  else tx.vin.foldl (fun acc i => acc.erase i.prevout) m

/-- Executable `updateCoins`, map edition: drop spent prevouts, then
insert the non-unspendable output coins (`AddCoins` — new wins). -/
def updateCoinsM (m : UtxoMap) (tx : Tx) (key : Key) (height : UInt32) : UtxoMap :=
  insertCoinsM (erasePrevoutsM m tx) (addedCoins tx key height)

/-! ## The abstraction lemmas -/

/-- Insert fold computes first-match-wins lookup over `xs`, falling back
to `m`. (Reverse fold ⇒ first match's coin is inserted last.) -/
theorem get?_insertCoinsM (m : UtxoMap) (xs : List (OutPoint × Coin)) (o : OutPoint) :
    (insertCoinsM m xs).get? o =
      match coinLookup xs o with | some c => some c | none => m.get? o := by
  unfold insertCoinsM
  induction xs generalizing m with
  | nil => simp [coinLookup]
  | cons p rest ih =>
    simp only [List.reverse_cons, List.foldl_append, List.foldl_cons, List.foldl_nil]
    cases hp : (p.1 == o) with
    | true =>
      rw [Std.HashMap.get?_insert, if_pos hp]
      simp only [coinLookup, hp]
      rfl
    | false =>
      rw [Std.HashMap.get?_insert, if_neg (by rw [hp]; simp : ¬((p.1 == o) = true)), ih]
      simp only [coinLookup, hp, Bool.false_eq_true, if_false]

/-- Spend fold over the vin list: exactly the spent prevouts are gone. -/
theorem get?_eraseVins (vins : List TxIn) (m : UtxoMap) (o : OutPoint) :
    (vins.foldl (fun acc i => acc.erase i.prevout) m).get? o =
      if vins.any (fun i => i.prevout == o) then none else m.get? o := by
  induction vins generalizing m with
  | nil => simp [List.any_nil]
    | cons i rest ih =>
      rw [List.foldl_cons, ih (m.erase i.prevout)]
      simp only [List.any_cons]
      by_cases h : (i.prevout == o) = true
      · rw [Std.HashMap.get?_erase, if_pos h]
        have hc : ((i.prevout == o) || rest.any (fun j => j.prevout == o)) = true := by
          rw [h, Bool.true_or]
        simp only [hc]
        split <;> rfl
      · rw [Std.HashMap.get?_erase, if_neg h]
        have hf : (i.prevout == o) = false := Bool.eq_false_iff.mpr h
        simp only [hf, Bool.false_or]
        try rfl

/-- Spend fold: after erasing `tx`'s prevouts, exactly the spent
prevouts are gone (mirror of W12's filter discipline). -/
theorem get?_erasePrevoutsM (m : UtxoMap) (tx : Tx) (o : OutPoint) :
    (erasePrevoutsM m tx).get? o =
      if tx.isCoinBase then m.get? o
      else if tx.vin.any (fun i => i.prevout == o) then none
      else m.get? o := by
  unfold erasePrevoutsM
  split
  · rfl
  · rw [get?_eraseVins]

/-- THE ABSTRACTION LEMMA (X13 U1): lookup over the updated map computes
the pointwise `updateCoins` — mirror of W12's `updateCoinsL_abstract`,
with NO extra hypotheses (first-match-wins by the reverse fold). -/
theorem updateCoinsM_abstract (m : UtxoMap) (tx : Tx) (key : Key) (height : UInt32) :
    viewOfM (updateCoinsM m tx key height) = updateCoins (viewOfM m) tx key height := by
  funext o
  unfold updateCoinsM viewOfM updateCoins
  rw [get?_insertCoinsM]
  cases ha : coinLookup (addedCoins tx key height) o with
  | some c => rfl
  | none =>
    dsimp only
    rw [get?_erasePrevoutsM]

/-- One step over the map (mirror of `applyTxStepL`; identical gate
order — coinbase shortcut, HaveInputs, maturity). Post-D4c-2
(BIP30R): NO BIP30 branch — the duplicate check is the block-level
pre-loop gate in `applyBlockM` (the `applyTxStepU/L` surgery
mirrored here). -/
def applyTxStepM (m : UtxoMap) (tx : Tx) (key : Key) (height : UInt32) :
    Except BlockError UtxoMap :=
  if tx.isCoinBase then
    Except.ok (updateCoinsM m tx key height)
  else if !inputsAvailable (viewOfM m) tx then
    Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent)
  else if !maturityOk (viewOfM m) tx height then
    Except.error (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase)
  else
    Except.ok (updateCoinsM m tx key height)

/-- `applyBlock`'s fold over the map (mirror of
`applyBlockFoldL`/`applyBlockFoldU`; the same sequential order — B3
same-block spend ordering). Post-D4c-2: the BIP30-free inner fold;
`applyBlockM` is its pre-loop-gated wrapper. -/
def applyBlockFoldM (m : UtxoMap) (kf : Tx → Key) :
    List Tx → UInt32 → Except BlockError UtxoMap
  | [], _ => Except.ok m
  | tx :: rest, height =>
    (applyTxStepM m tx (kf tx) height).bind
      (fun m' => applyBlockFoldM m' kf rest height)

/-- The block apply over the map (mirror of `applyBlockL`;
post-D4c-2 = the L-mirror of `applyBlockU`: the same pre-loop BIP30
gate (2466-2475, pristine `viewOfM m`, ONCE) in front of
`applyBlockFoldM`. -/
def applyBlockM (m : UtxoMap) (kf : Tx → Key) (txs : List Tx) (height : UInt32) :
    Except BlockError UtxoMap :=
  if bip30BlockCollision (viewOfM m) kf txs height && bip30Enforced height then
    Except.error BlockError.badTxnsBIP30
  else applyBlockFoldM m kf txs height

/-- The step commutes with the abstraction map (mirror of
`applyTxStepL_abstract`; post-D4c-2: no BIP30 case). -/
theorem applyTxStepM_abstract (m : UtxoMap) (tx : Tx) (key : Key) (height : UInt32) :
    (applyTxStepM m tx key height).map viewOfM =
      applyTxStepU (viewOfM m) tx key height := by
  unfold applyTxStepM applyTxStepU
  by_cases hc : tx.isCoinBase = true
  · rw [if_pos hc, if_pos hc]
    show Except.ok (viewOfM (updateCoinsM m tx key height)) =
      Except.ok (updateCoins (viewOfM m) tx key height)
    rw [updateCoinsM_abstract]
  · rw [if_neg hc, if_neg hc]
    by_cases hi : (!inputsAvailable (viewOfM m) tx) = true
    · rw [if_pos hi, if_pos hi]
      rfl
    · rw [if_neg hi, if_neg hi]
      by_cases hm : (!maturityOk (viewOfM m) tx height) = true
      · rw [if_pos hm, if_pos hm]
        rfl
      · rw [if_neg hm, if_neg hm]
        show Except.ok (viewOfM (updateCoinsM m tx key height)) =
          Except.ok (updateCoins (viewOfM m) tx key height)
        rw [updateCoinsM_abstract]

/-- The whole gate-free fold commutes with the abstraction map
(mirror of `applyBlockFoldL_abstract`; X13 U1 exit criterion). -/
theorem applyBlockFoldM_abstract (m : UtxoMap) (kf : Tx → Key) (txs : List Tx)
    (height : UInt32) :
    (applyBlockFoldM m kf txs height).map viewOfM =
      applyBlockFoldU (viewOfM m) kf txs height := by
  induction txs generalizing m with
  | nil => rfl
  | cons tx rest ih =>
    unfold applyBlockFoldM applyBlockFoldU
    rw [← applyTxStepM_abstract]
    have mapBind : ∀ (x : Except BlockError UtxoMap)
        (g : UtxoSet → Except BlockError UtxoSet),
        (x.map viewOfM).bind g = x.bind (fun a => g (viewOfM a)) := by
      intro x g
      cases x with
      | error e => rfl
      | ok v => rfl
    rw [mapBind]
    have mapBind2 : ∀ (x : Except BlockError UtxoMap)
        (g : UtxoMap → Except BlockError UtxoMap),
        Except.map viewOfM (x.bind g) = x.bind (fun a => Except.map viewOfM (g a)) := by
      intro x g
      cases x with
      | error e => rfl
      | ok v => rfl
    rw [mapBind2]
    simp only [ih]

/-- The whole fold commutes with the abstraction map (mirror of
`applyBlockL_abstract`). Post-D4c-2 wrapper: the pristine
`bip30BlockCollision` gate either rejects the block outright (both
sides the same `badTxnsBIP30` error) or the equation lands in the
fold. -/
theorem applyBlockM_abstract (m : UtxoMap) (kf : Tx → Key) (txs : List Tx)
    (height : UInt32) :
    (applyBlockM m kf txs height).map viewOfM =
      applyBlockU (viewOfM m) kf txs height := by
  by_cases hbp : (bip30BlockCollision (viewOfM m) kf txs height && bip30Enforced height) = true
  · unfold applyBlockM applyBlockU
    rw [if_pos hbp, if_pos hbp]
    rfl
  · unfold applyBlockM applyBlockU
    rw [if_neg hbp, if_neg hbp]
    exact applyBlockFoldM_abstract m kf txs height

/-! ## The list → map bridge (handing W12's scenarios through) -/

/-- Build a map from a W12-style assoc list, first-match-wins (same
resolution as `coinLookup`). -/
def mapOfL (l : List (OutPoint × Coin)) : UtxoMap := insertCoinsM (Std.HashMap.emptyWithCapacity l.length) l

/-- The bridge: `mapOfL`'s view IS the assoc list's view. -/
theorem mapOfL_viewOf (l : List (OutPoint × Coin)) : viewOfM (mapOfL l) = viewOf l := by
  funext o
  unfold mapOfL viewOfM viewOf
  rw [get?_insertCoinsM]
  have hempty : (Std.HashMap.emptyWithCapacity l.length : UtxoMap).get? o = none :=
    Std.HashMap.get?_emptyWithCapacity
  rw [hempty]
  cases coinLookup l o with
  | some c => rfl
  | none => rfl

/-- TRANSFER THEOREM (U1): any W12 assoc-list scenario runs identically
through the HashMap instance — both folds land on the same abstract
view. Every `Test/Ledger` scenario transfers through this for free. -/
theorem applyBlockL_applyBlockM_agree (l : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    (applyBlockL l kf txs height).map viewOf =
      (applyBlockM (mapOfL l) kf txs height).map viewOfM := by
  rw [applyBlockL_abstract, applyBlockM_abstract, mapOfL_viewOf]

/-! ## Axiom pins (L3) -/

/-- info: 'Bitcoin.Ledger.updateCoinsM_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoinsM_abstract

/-- info: 'Bitcoin.Ledger.applyTxStepM_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTxStepM_abstract

/-- info: 'Bitcoin.Ledger.applyBlockM_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlockM_abstract

/-- info: 'Bitcoin.Ledger.applyBlockL_applyBlockM_agree' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlockL_applyBlockM_agree

/-- info: 'Bitcoin.Ledger.mapOfL_viewOf' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms mapOfL_viewOf

end Bitcoin.Ledger
