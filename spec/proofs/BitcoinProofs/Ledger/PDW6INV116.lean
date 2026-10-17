import Bitcoin.Ledger.Interface

/-!
# PDW6INV116 — INV-116 promotion proofs (reorg undo, disconnect
# round-trip)

PDW6 (proof-promotion review 6, TOP-26..30), recovery review 3,
2026-10-17. Row INV-116 (d=3, D-LEDGER; PD01 ledger; PDW5's landed
claim 5ad2d00 names it the PDW6 tier): `Bitcoin.Ledger
.updateCoins_undo` (Ledger/Interface.lean:1129), the reorg-undo /
disconnect round-trip — undoling the effect of `tx` on the
post-state restores the original view, given the no-clobber
side-condition `h5` (every added key was either fresh in `u` or
itself re-spent by `tx`'s own inputs). Core anchors:
validation.cpp `DisconnectBlock` / `ApplyTxInUndo` /
`SpendCoin`, the UpdateCoins/UndoCoins mirror pair (W12 update
D-RC02 fold laws; INV-113 family, BLK-105 spentUndo CTxUndo
layout, INV-117 undoCoins restore-wins discipline).

The vehicle is a THM-on-target row: `updateCoins_undo` is an
in-tree THEOREM (W12, sorry-free, 40-line funext case analysis
over `coinLookup`/`spentUndo`/`addedCoins`) carrying the
`@[rule "INV-116"]` tag. Promotion = PD02-22 THM-on-target class
(PDW5's SWT-011 `witnessScriptSizeOk_spec` pattern): read-verify
the in-tree proof (done — Interface.lean:1131-1172, the `h5`
hypothesis is used exactly once, in the payload-miss /
no-input-references / added-some case), pin its axioms in-file
(`#guard_msgs`), and add the two usable corollary faces as
same-tagged decls (PDW5's SGN-107 same-id-2-decls precedent):

- `updateCoins_undo_noadd` — the no-overwrite specialization:
  `h5`'s left disjunct only (`u q = none` for every added key).
  Weaker hypothesis = strictly stronger statement; one-line
  derivation into the main theorem via `Or.inl`.
- `updateCoins_undo_vacuous` — the empty-`addedKeys` face:
  a tx that adds no keys undoes unconditionally (`h5` vacuous).

Axiom-pinned in-file (D2 L3), zero sorryAx; every footprint ⊆
[propext, Classical.choice, Quot.sound]. Unregistered in
BitcoinProofs.lean (warzone convention: direct-lean verified,
invisible to the default build).
-/

namespace BitcoinProofs.Ledger.PDW6

/-- INV-116 (no-overwrite face): if no key `tx` adds carries a
live coin in the pre-state (the `h5`-left case — added keys are
fresh), the disconnect round-trip restores the view exactly.
`updateCoins_undo`'s own `h5` or-conditional is needed only when
an added key could be re-spent by `tx`'s own inputs; under the
all-fresh reading that disjunct is never taken. -/
@[rule "INV-116"]
theorem updateCoins_undo_noadd (u : Bitcoin.Ledger.UtxoSet)
    (tx : Bitcoin.Data.Tx) (key : Bitcoin.Ledger.Key)
    (height : UInt32)
    (h5 : ∀ q ∈ Bitcoin.Ledger.addedKeys tx key height,
      u q = none) :
    Bitcoin.Ledger.undoCoins (Bitcoin.Ledger.updateCoins u tx key height)
      (Bitcoin.Ledger.spentUndo u tx) tx key height = u :=
  Bitcoin.Ledger.updateCoins_undo u tx key height
    (fun q hq => Or.inl (h5 q hq))

/-- INV-116 (vacuous face): a tx that adds no keys at all (e.g.
no outputs at this key tier) undoes unconditionally — `h5` holds
vacuously, nothing was inserted that could clobber a restored
coin. -/
@[rule "INV-116"]
theorem updateCoins_undo_vacuous (u : Bitcoin.Ledger.UtxoSet)
    (tx : Bitcoin.Data.Tx) (key : Bitcoin.Ledger.Key)
    (height : UInt32)
    (hl : Bitcoin.Ledger.addedKeys tx key height = []) :
    Bitcoin.Ledger.undoCoins (Bitcoin.Ledger.updateCoins u tx key height)
      (Bitcoin.Ledger.spentUndo u tx) tx key height = u :=
  Bitcoin.Ledger.updateCoins_undo u tx key height
    (fun q hq => by rw [hl] at hq; exact absurd hq (by simp))

/-! ### Axiom pins (D2 L3)

Expected messages as docstrings on the guards; every footprint ⊆
[propext, Classical.choice, Quot.sound], zero sorryAx. -/

/-- info: 'Bitcoin.Ledger.updateCoins_undo' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Ledger.updateCoins_undo

/-- info: 'BitcoinProofs.Ledger.PDW6.updateCoins_undo_noadd' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms updateCoins_undo_noadd

/-- info: 'BitcoinProofs.Ledger.PDW6.updateCoins_undo_vacuous' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms updateCoins_undo_vacuous

end BitcoinProofs.Ledger.PDW6
