import Bitcoin.Block.Params

/-!
# Blk063Cor — BLK-063 promotion proof (PDW8, row TOP-36)

Row BLK-063 (`prev-blk-not-found`, validation.cpp:4237-4245 @cce32b168):
the parent must be a known header.

Semantics port (route B, PDW2-AF pattern): `prevHeaderKnown`
(Params.lean:68) is the header-index verdict interface; the theorems
here pin its exact `Option`-index semantics — the accept verdict
(`= true`) holds iff the parent is found in the index, and the reject
verdict (`= false`, the `prev-blk-not-found` lane) holds iff the
lookup misses. No mathlib, no decide, no induction; pure
`cases hh : idx h`-substitution + `nomatch` contradiction + `rfl`
(iota) — PDW8-2 fix: the two reference halves of the false-iff
none-case (PDW8's `intro _; exact hh` / `intro he; exact he` at
:53/:54 both die on the `cases`-substituted goal — `hh : idx h =
none` stays in the context while the goal-RHS becomes `none = none`
and the goal-LHS `(match none …) = false` closes by `rfl` via the
matcher reduction, cf. the `rw [hn]`-closes-theorem-3 evidence).

Axiom-pinned in-file (D2 L3); zero sorryAx — all 3 theorems
AXIOM-FREE (PDW8-2 probe: the cases/nomatch/rfl-iota route never
enters the axiom-backed match-motive machinery that gives PDW7's
INV010 `show`/`rw`-herd its [propext, Classical.choice,
Quot.sound] set).
-/

namespace BitcoinProofs.AF.PDW8

/-- BLK-063 (accept dir): the prev-header is known iff the index lookup
yields an entry. -/
@[rule "BLK-063"]
theorem prevHeaderKnown_true_iff (idx : Nat → Option Bitcoin.Block.Params.IndexEntry)
    (h : Nat) :
    Bitcoin.Block.Params.prevHeaderKnown idx h = true ↔
      ∃ e, idx h = some e := by
  unfold Bitcoin.Block.Params.prevHeaderKnown
  cases hh : idx h with
  | some e => exact ⟨fun _ => ⟨e, rfl⟩, fun _ => rfl⟩
  | none =>
    constructor
    · intro he; nomatch he
    · intro he; cases he with | intro n hn => nomatch hn

/-- BLK-063 (reject dir, `prev-blk-not-found`): the reject verdict
holds iff the index lookup is a miss. -/
@[rule "BLK-063"]
theorem prevHeaderKnown_false_iff (idx : Nat → Option Bitcoin.Block.Params.IndexEntry)
    (h : Nat) :
    Bitcoin.Block.Params.prevHeaderKnown idx h = false ↔
      idx h = none := by
  unfold Bitcoin.Block.Params.prevHeaderKnown
  cases hh : idx h with
  | some e =>
    constructor
    · intro he; nomatch he
    · intro hf; nomatch hf
  | none =>
    constructor
    · intro _; rfl
    · intro _; rfl

/-- BLK-063 (reject lane): an unknown parent yields the reject
verdict outright. -/
@[rule "BLK-063"]
theorem prevHeaderKnown_notFound (idx : Nat → Option Bitcoin.Block.Params.IndexEntry)
    (h : Nat) (hn : idx h = none) :
    Bitcoin.Block.Params.prevHeaderKnown idx h = false := by
  unfold Bitcoin.Block.Params.prevHeaderKnown; rw [hn]

/-! ## L3 axiom pins (D2): drift on any of these fails the build.
All 3 theorems sorry-free AXIOM-FREE (PDW8-2 probe) — the
`cases hh : idx h` + `nomatch` + `rfl`-iota route never enters the
axiom-backed match-motive machinery (PDW2 F-PDW2-002 class) that
gives PDW7's INV010 `show`/`rw`-herd its full legal pin-set. Every
pin ⊆ [propext, Classical.choice, Quot.sound] = the charter trio;
zero `sorryAx` (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW8.prevHeaderKnown_true_iff' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.prevHeaderKnown_true_iff

/-- info: 'BitcoinProofs.AF.PDW8.prevHeaderKnown_false_iff' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.prevHeaderKnown_false_iff

/-- info: 'BitcoinProofs.AF.PDW8.prevHeaderKnown_notFound' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.prevHeaderKnown_notFound

end BitcoinProofs.AF.PDW8

