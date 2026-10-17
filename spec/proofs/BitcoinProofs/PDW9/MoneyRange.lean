import Bitcoin.Numeric.Amount

/-!
# PDW9/MoneyRange — INV-024 promotion (route B)

PDW9 (proof-promotion review 5), recovery review 5 (RC5), 2026-10-17.
Row INV-024 (TOP-41..45 claim `1c53f09`): `` `0 ≤ v ≤ MAX_MONEY` ``
(consensus/amount.h:27 @cce32b168, CVE-2010-5139-adjacent money fence).

Route B (RC03-4 B-vehicle, PDW10Guards/PDW11Check conventions): the
row's tag sits on the core *definition* `Bitcoin.Data.MoneyRange`
(Data/Basic.lean:117, `@[rule "INV-024"]`, RC02) — a Bool-valued
predicate, `status: implemented` = tag-on-def tagdebt. Promotion =
this file's sorry-free theorems over the exact gate, my
`@[rule "INV-024"]` on the iff-vehicle `moneyRange_spec` (the def's
propositional content), zero core edits. W04's frozen
`moneyRange_intro`/`_elim`/`_iff` (Numeric/Amount.lean:31-39) stay
untagged; the `_spec` twins below are the PDW9 vehicles.

- `moneyRange_spec` (THE vehicle, `@[rule "INV-024"]`): the def
  unfolds to the amount.h:27 conjunction (`simp [MoneyRange]`).
- `moneyRange_intro_spec` / `moneyRange_elim_spec`: W04 twins
  (intro = `decide_eq_true_iff` + pair; elim = `moneyRange_elim`).
- `moneyRange_reject_spec`: the reject-face — `n < 0 ∨ MAX_MONEY < n`
  ⇒ `MoneyRange n = false` (kernel `Int.lt_of_le_of_lt` /
  `Int.lt_irrefl`; `decide_eq_false_iff` is unknown in v4.35, and
  `omega` is blind to the `Amount := Int` abbrev in `n < 0` —
  both probe2-discovered, recorded in PDW9.md F-PDW9-001).

Core-only imports (root-env elaborable, `cd spec && lake env lean
proofs/BitcoinProofs/PDW9/MoneyRange.lean`, direct-lean RC05/PDW11Check
route). NOT imported by anything (additive module, cannot break the
root `lake build`, which covers `core` only).

Axiom pins (house style: bare `#print axioms`, info-level only,
B07/RC03/PDW10Guards discipline). Footprints recorded in
findings-af/PDW9.md v2; all ⊆ the charter trio
`[propext, Classical.choice, Quot.sound]`, zero `sorryAx`.
-/

namespace BitcoinProofs.PDW9
open Bitcoin.Data Bitcoin.Numeric

/-- **INV-024 vehicle**: `MoneyRange` is exactly the amount.h:27
positive-ray conjunction `0 ≤ n ≤ MAX_MONEY` (definitionally, by
`simp [MoneyRange]` through the `decide`). -/
@[rule "INV-024"]
theorem moneyRange_spec {n : Amount} :
    MoneyRange n = true ↔ (0 ≤ n ∧ n ≤ MAX_MONEY) := by
  simp [MoneyRange]

/-- `MoneyRange` introduction (W04 `moneyRange_intro` twin, PDW9
`_spec` vehicle; the tag stays on the iff above). -/
theorem moneyRange_intro_spec {n : Amount} (h1 : 0 ≤ n) (h2 : n ≤ MAX_MONEY) :
    MoneyRange n = true := by
  simp only [MoneyRange, decide_eq_true_iff]
  exact ⟨h1, h2⟩

/-- `MoneyRange` elimination (W04 `moneyRange_elim` twin). -/
theorem moneyRange_elim_spec {n : Amount} (h : MoneyRange n = true) :
    0 ≤ n ∧ n ≤ MAX_MONEY :=
  moneyRange_elim h

/-- **INV-024 reject-face**: outside the ray (negative, or above
`MAX_MONEY`) the gate is exactly `false` — the CVE-2010-5139 money
fence's failing side. Kernel route (`Int.lt_of_le_of_lt` +
`Int.lt_irrefl`, no `omega`: it does not see through the
`Amount := Int` abbrev). -/
theorem moneyRange_reject_spec {n : Amount} (h : n < 0 ∨ MAX_MONEY < n) :
    MoneyRange n = false := by
  have hn : ¬ (0 ≤ n ∧ n ≤ MAX_MONEY) := by
    rintro ⟨h1, h2⟩
    cases h with
    | inl h => exact absurd (Int.lt_of_le_of_lt h1 h) (Int.lt_irrefl 0)
    | inr h => exact absurd (Int.lt_of_le_of_lt h2 h) (Int.lt_irrefl n)
  cases hb : MoneyRange n with
  | true => exact absurd (moneyRange_elim hb) hn
  | false => rfl

end BitcoinProofs.PDW9

#print axioms BitcoinProofs.PDW9.moneyRange_spec
#print axioms BitcoinProofs.PDW9.moneyRange_intro_spec
#print axioms BitcoinProofs.PDW9.moneyRange_elim_spec
#print axioms BitcoinProofs.PDW9.moneyRange_reject_spec
