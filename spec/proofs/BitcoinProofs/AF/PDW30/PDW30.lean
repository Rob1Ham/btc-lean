import Bitcoin.Block.Index

/-! # PDW30.lean — TOP-146..150, part 1 (D-INDEX residue)
(PDW30, review RC26, 2026-10-17; claim 011ae09).

Row-face theorems for BLK-059 / BLK-116 / BLK-117 on the sorry-free
core defs of `Bitcoin/Block/Index.lean` (X08-B3). Route B: zero core
writes; tags ride these theorems; lean_target flips to them at promotion.

* **BLK-059** `connectHeight` — height is the parent's successor.
* **BLK-116** `mostWork?` — the work-comparator tie law: equal work ⇒
  lower nSequenceId (earlier) wins; equal work and not-earlier ⇒ loses.
* **BLK-117** `switchTip` — strict improvement switches; otherwise the
  incumbent stays (ties never flip the tip).
-/

namespace BitcoinProofs.AF.PDW30

open Bitcoin.Block.Index

@[rule "BLK-059"]
theorem connectHeight_row (prevHeight : Nat) :
    connectHeight prevHeight = prevHeight + 1 := rfl

@[rule "BLK-116"]
theorem betterThan_tie_earlier (a b : Tip) (hw : a.chainWork = b.chainWork)
    (hs : a.sequence < b.sequence) : betterThan a b = true := by
  unfold betterThan
  rw [hw, decide_eq_false (by omega), Bool.false_or]
  simp [hs]

theorem betterThan_tie_later (a b : Tip) (hw : a.chainWork = b.chainWork)
    (hs : ¬ a.sequence < b.sequence) : betterThan a b = false := by
  unfold betterThan
  rw [hw, decide_eq_false (by omega), Bool.false_or]
  simp [hs]

/-- **BLK-116** (equal-work tie law): with equal chainwork the comparator
is exactly the lower-`nSequenceId` order — earlier-received wins. -/
@[rule "BLK-116"]
theorem betterThan_tie_iff (a b : Tip) (hw : a.chainWork = b.chainWork) :
    betterThan a b = true ↔ a.sequence < b.sequence := by
  unfold betterThan
  rw [hw, decide_eq_false (by omega), Bool.false_or]
  simp

/-- **BLK-116** (pointer-order residual, non-consensus): when both work
and `nSequenceId` tie, the comparator says "not better"; the fold keeps
the candidate at the later list position. Core's raw pointer order is not
modeled further, which is exactly the non-consensus detail in the row. -/
@[rule "BLK-116"]
theorem betterTip_tie_pointer (a b : Tip) (hw : a.chainWork = b.chainWork)
    (hs : a.sequence = b.sequence) : betterTip a b = b := by
  unfold betterTip
  have hnot : ¬ a.sequence < b.sequence := by omega
  have hfalse : betterThan a b = false := betterThan_tie_later a b hw hnot
  rw [ite_eq_right (by simp [hfalse])]

/-! ## BLK-116 — the pointer/address tie and `nSequenceId` assignment

The core `Tip` has no pointer/address field, so `betterTip_tie_pointer`
can only describe list order.  The following model carries the missing
`addr` field and mirrors Core's `CBlockIndexWorkComparator`
(node/blockstorage.h:174-189): work first, then lower `nSequenceId`
(earlier received), then pointer address.  `assignSequence` mirrors
`ReceivedBlockTransactions`' `pindex->nSequenceId = nBlockSequenceId++`
(validation.cpp:3817): earlier receive order receives the lower id. -/

/-- A chain tip with the pointer/address tie field Core's comparator
reads.  `addr` stands for `CBlockIndex*`'s address; it is only a
non-consensus tie-break. -/
structure TipPtr where
  hash : ByteArray
  chainWork : Nat
  /-- `nSequenceId`: lower = earlier-received / active chain. -/
  sequence : Nat
  /-- Pointer address stand-in (Core compares `CBlockIndex*` directly). -/
  addr : Nat
deriving Repr

/-- Core's `CBlockIndexWorkComparator` as a "sorts-before" (worse)
relation: higher work first, then lower `nSequenceId`, then lower
pointer address (node/blockstorage.h:174-189). -/
def beforeThan (a b : TipPtr) : Bool :=
  if a.chainWork > b.chainWork then false
  else if a.chainWork < b.chainWork then true
  else if a.sequence < b.sequence then false
  else if a.sequence > b.sequence then true
  else if a.addr < b.addr then false
  else if a.addr > b.addr then true
  else false

/-- `a` strictly beats `b` in the comparator order (`b` sorts before
`a`). -/
def betterThanPtr (a b : TipPtr) : Bool := beforeThan b a

/-- **BLK-116** (equal work, first tie key): the lower `nSequenceId`
(earlier received / active chain) wins. -/
@[rule "BLK-116"]
theorem betterThanPtr_tie_earlier (a b : TipPtr)
    (hw : a.chainWork = b.chainWork) (hs : a.sequence < b.sequence) :
    betterThanPtr a b = true := by
  unfold betterThanPtr beforeThan
  rw [hw]
  have hnot : ¬ b.sequence < a.sequence := by omega
  simp [hnot, hs]

/-- The comparator after the equal-work work-key is dropped. -/
theorem beforeThan_tie (a b : TipPtr) (hw : a.chainWork = b.chainWork) :
    beforeThan a b =
      (if a.sequence < b.sequence then false
       else if a.sequence > b.sequence then true
       else if a.addr < b.addr then false
       else if a.addr > b.addr then true
       else false) := by
  unfold beforeThan
  rw [hw]
  simp only [Nat.lt_irrefl, ite_false]

/-- **BLK-116** (full equal-work tie law): with equal chainwork, the
comparator is exactly the lexicographic `(nSequenceId, pointer address)`
order — lower sequence first, then pointer address. -/
@[rule "BLK-116"]
theorem betterThanPtr_tie_iff (a b : TipPtr)
    (hw : a.chainWork = b.chainWork) :
    betterThanPtr a b = true ↔
      a.sequence < b.sequence ∨
        (a.sequence = b.sequence ∧ a.addr < b.addr) := by
  unfold betterThanPtr
  rw [beforeThan_tie b a hw.symm]
  by_cases hlt : a.sequence < b.sequence
  · have h1 : ¬ b.sequence < a.sequence := by omega
    have h2 : b.sequence > a.sequence := hlt
    rw [if_neg h1, if_pos h2]
    simp [hlt]
  · by_cases heq : a.sequence = b.sequence
    · have h1 : ¬ b.sequence < a.sequence := by omega
      have h2 : ¬ b.sequence > a.sequence := by omega
      rw [if_neg h1, if_neg h2, heq]
      simp only [true_and]
      by_cases hp : a.addr < b.addr
      · have h3 : ¬ b.addr < a.addr := by omega
        have h4 : b.addr > a.addr := hp
        rw [if_neg h3, if_pos h4]
        simp [hp]
      · by_cases hlt2 : b.addr < a.addr
        · rw [if_pos hlt2]
          simp [hp]
        · have heq2 : b.addr = a.addr := by omega
          rw [if_neg hlt2, if_neg (by omega : ¬ b.addr > a.addr)]
          simp [hp]
    · have hgt : b.sequence < a.sequence := by omega
      rw [if_pos hgt]
      simp [hlt, heq]

/-- **BLK-116** (pointer-order tie): when work and `nSequenceId` both
tie, Core's `pa < pb` branch means the lower pointer address wins. -/
@[rule "BLK-116"]
theorem betterThanPtr_tie_pointer (a b : TipPtr)
    (hw : a.chainWork = b.chainWork) (hs : a.sequence = b.sequence) :
    betterThanPtr a b = true ↔ a.addr < b.addr := by
  rw [betterThanPtr_tie_iff a b hw]
  simp [hs]

/-- The fold step over the pointer-aware comparator. -/
def betterTipPtr (a b : TipPtr) : TipPtr :=
  if betterThanPtr a b = true then a else b

/-- **BLK-116** (pointer fold): on a complete work/sequence tie the fold
keeps the lower-address candidate, exactly Core's final pointer branch. -/
@[rule "BLK-116"]
theorem betterTipPtr_tie_pointer (a b : TipPtr)
    (hw : a.chainWork = b.chainWork) (hs : a.sequence = b.sequence) :
    betterTipPtr a b = if a.addr < b.addr then a else b := by
  unfold betterTipPtr
  by_cases h : a.addr < b.addr <;>
    simp [betterThanPtr_tie_pointer a b hw hs, h]

/-- `ReceivedBlockTransactions`' assignment: the first block processed
gets `next`, the next `next + 1`, ... (validation.cpp:3817
`pindex->nSequenceId = nBlockSequenceId++`). -/
@[rule "BLK-116"]
def assignSequence (next : Nat) : List TipPtr → List TipPtr
  | [] => []
  | b :: rest => { b with sequence := next } :: assignSequence (next + 1) rest

/-- **BLK-116** (assignment order): the first two blocks of a receive
batch get consecutive increasing ids, so the earlier block has the lower
`nSequenceId`. -/
@[rule "BLK-116"]
theorem assignSequence_pair (next : Nat) (a b : TipPtr) :
    assignSequence next [a, b] =
      [{ a with sequence := next }, { b with sequence := next + 1 }] := rfl

/-- **BLK-116** (earlier-received wins): composing the Core assignment
with the equal-work tie law, the earlier-received block of a two-block
batch beats the later one on a work tie. -/
@[rule "BLK-116"]
theorem assignSequence_pair_earlier_wins (next : Nat) (a b : TipPtr)
    (hw : a.chainWork = b.chainWork) :
    betterThanPtr { a with sequence := next }
      { b with sequence := next + 1 } = true := by
  apply betterThanPtr_tie_earlier
  · simpa using hw
  · show next < next + 1
    omega

@[rule "BLK-117"]
theorem switchTip_strict (current candidate : Tip)
    (h : current.chainWork < candidate.chainWork) :
    switchTip current candidate = candidate := by
  unfold switchTip
  simp [h]

/-- **BLK-117** (tie face): a non-strictly-better candidate never
changes the tip — in particular equal work keeps the incumbent. -/
@[rule "BLK-117"]
theorem switchTip_tie (current candidate : Tip)
    (h : candidate.chainWork ≤ current.chainWork) :
    switchTip current candidate = current :=
  switchTip_not_better current candidate h

#print axioms connectHeight_row
#print axioms betterThan_tie_earlier
#print axioms betterThan_tie_later
#print axioms switchTip_strict
#print axioms switchTip_tie

end BitcoinProofs.AF.PDW30
