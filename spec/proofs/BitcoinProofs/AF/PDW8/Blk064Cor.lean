import Bitcoin.Block.Params

/-!
# Blk064Cor — BLK-064 promotion proof (PDW8, row TOP-37)

Row BLK-064 (`bad-prevblk`, validation.cpp:4246-4250 @cce32b168):
the parent must not be BLOCK_FAILED_VALID (and must be known).

Semantics port (route B): `prevNotFailed` (Params.lean:73) — the
`¬ e.failed` arm is a Prop (PDW8-2 probe pp.all:
`Not (Eq Bool (failed e) true)`) that in the `: Bool` match-arm
elaborates through the Prop→Bool decide-coercion (PDW8-2 probe
#print pp.all: `@Decidable.decide (Not (Eq Bool (failed e) true))
(instDecidableNot _ instDecidableEqBool)`), riding the shared
`:68`-site `prevHeaderKnown.match_1` (none-branch
`fun _ : Unit => false`); the accept verdict holds iff the lookup
yields an entry with `failed = false`. Two reject lanes (the
`bad-prevblk` taxonomy): a failed parent, and an unknown parent
(BLK-063 `prev-blk-not-found` is the sub-lane).
`cases hfl : e.failed` + `simp [hfl]` contra-tails (
gold); reject lanes by `rw`-substitution (P4-shape). PDW8-2 build
evidence: the tree file was clean FIRST-BUILD RC=0 (the w11
PerfectFinal assembly was the one good tree write; contrast
Blk063Cor which died with the :53/:54 errors).

Axiom-pinned in-file (D2 L3); zero sorryAx — pin-sets per theorem:
true_iff [propext, Quot.sound] (the `simp [hfl]`-herd),
failed_reject [propext], notFound_reject AXIOM-FREE (the
rw/rfl-iota route); all ⊆ the charter trio.
-/

namespace BitcoinProofs.AF.PDW8

/-- BLK-064 (accept dir): the parent is known and not failed iff
`prevNotFailed` returns the accept verdict. -/
@[rule "BLK-064"]
theorem prevNotFailed_true_iff (idx : Nat → Option Bitcoin.Block.Params.IndexEntry)
    (h : Nat) :
    Bitcoin.Block.Params.prevNotFailed idx h = true ↔
      ∃ e, idx h = some e ∧ e.failed = false := by
  unfold Bitcoin.Block.Params.prevNotFailed
  cases hh : idx h with
  | some e =>
    cases hfl : e.failed with
    | false =>
      constructor
      · intro _; exact ⟨e, rfl, hfl⟩
      · intro _; simp [hfl]
    | true =>
      constructor
      · intro he; simp [hfl] at he
      · intro he; simp [hfl] at he
  | none =>
    constructor
    · intro he; simp at he
    · intro he; simp at he

/-- BLK-064 (reject lane, `bad-prevblk`): a BLOCK_FAILED_VALID parent
yields the reject verdict. -/
@[rule "BLK-064"]
theorem prevNotFailed_failed_reject (idx : Nat → Option Bitcoin.Block.Params.IndexEntry)
    (h : Nat) (e : Bitcoin.Block.Params.IndexEntry)
    (hfound : idx h = some e) (hf : e.failed = true) :
    Bitcoin.Block.Params.prevNotFailed idx h = false := by
  unfold Bitcoin.Block.Params.prevNotFailed; rw [hfound]; simp [hf]

/-- BLK-064 (reject lane, unknown parent): a missed lookup yields the
reject verdict (complementary to BLK-063). -/
@[rule "BLK-064"]
theorem prevNotFailed_notFound_reject (idx : Nat → Option Bitcoin.Block.Params.IndexEntry)
    (h : Nat) (hn : idx h = none) :
    Bitcoin.Block.Params.prevNotFailed idx h = false := by
  unfold Bitcoin.Block.Params.prevNotFailed; rw [hn]

/-! ## L3 axiom pins (D2): drift on any of these fails the build.
All 3 theorems sorry-free; pin-sets (PDW8-2 probe pass):
true_iff [propext, Quot.sound] (the `simp [hfl]`-herd + the
decide-coercion arm),
failed_reject [propext] (the `rw`/`simp [hf]` route),
notFound_reject AXIOM-FREE (the `rw`/rfl-iota route). Every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio; zero
`sorryAx` (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW8.prevNotFailed_true_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.prevNotFailed_true_iff

/-- info: 'BitcoinProofs.AF.PDW8.prevNotFailed_failed_reject' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.prevNotFailed_failed_reject

/-- info: 'BitcoinProofs.AF.PDW8.prevNotFailed_notFound_reject' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.prevNotFailed_notFound_reject

end BitcoinProofs.AF.PDW8
