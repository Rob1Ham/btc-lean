import Bitcoin.Block.Index

/-! # PDW30b.lean — TOP-146..150, part 2 (D-INDEX residue)
(PDW30, RC26, 2026-10-17; claim 011ae09).

Row-face theorems for BLK-118 / BLK-119 (X08-B3, `Block/Index.lean`).

* **BLK-118** `reorgPlan` — DisconnectTip count + fork = old tip,
  ConnectTip count + fork = candidate tip; same tip at the fork ⇒ (0,0).
* **BLK-119** `prunedCandidates` — pruning is a pure filter (subset of
  the candidate set) and any descendant at the same fuel is removed.
-/

namespace BitcoinProofs.AF.PDW30

open Bitcoin.Block.Index

@[rule "BLK-118"]
theorem reorgPlan_disconnect (tip cand fork : Nat) (h : fork ≤ tip) :
    (reorgPlan tip cand fork).1 + fork = tip :=
  Nat.sub_add_cancel h

theorem reorgPlan_connect (tip cand fork : Nat) (h : fork ≤ cand) :
    (reorgPlan tip cand fork).2 + fork = cand :=
  Nat.sub_add_cancel h

theorem reorgPlan_at_fork (tip : Nat) :
    reorgPlan tip tip tip = (0, 0) := by
  unfold reorgPlan
  simp

@[rule "BLK-119"]
theorem prunedCandidates_subset {parentOf : Nat → Option Nat} {failed fuel : Nat}
    {cands : List Nat} {d : Nat}
    (hd : d ∈ prunedCandidates parentOf failed fuel cands) : d ∈ cands := by
  unfold prunedCandidates at hd
  exact (List.mem_filter.mp hd).1

theorem descendant_not_pruned {parentOf : Nat → Option Nat} {failed fuel : Nat}
    {cands : List Nat} {d : Nat}
    (hd : isDescendantOf parentOf fuel failed d = true) :
    d ∉ prunedCandidates parentOf failed fuel cands := by
  intro hm
  unfold prunedCandidates at hm
  have hk := (List.mem_filter.mp hm).2
  rw [hd] at hk
  simp at hk

/-! ## BLK-118 — the disconnect/connect composition with per-block undo

`reorgPlan` above is only the count pair. The row's text also claims the
*tip walk* (DisconnectTip down to the fork, then ConnectTip up to the
candidate) and **undo data per block**. `ReorgStep` adds exactly those two
pieces: the current tip, the fork point, the candidate tip, and one undo
payload per height (read while disconnecting, written while connecting).
The theorems characterize both walks extensionally: the disconnected
heights are precisely `(fork, tip]`, the connected heights precisely
`(fork, cand]`, so each has one payload per block and the counts are the
`reorgPlan` pair. -/

/-- One two-tip switch at `fork`, carrying Core's per-block undo channel:
`undo k` is the undo record consumed when block height `k` is disconnected;
`connected k` is the undo record produced when height `k` is connected. -/
structure ReorgStep (Undo : Type) where
  /-- Last common block (both tips share it). -/
  fork : Nat
  /-- Current active tip height. -/
  tip : Nat
  /-- Candidate tip height. -/
  cand : Nat
  /-- Undo payload stored for each disconnected block. -/
  undo : Nat → Undo
  /-- Undo payload produced for each connected block. -/
  connected : Nat → Undo

/-- `DisconnectTip` walk: `tip, tip-1, …, fork+1` (reverse height order). -/
def disconnectOrder {Undo : Type} (s : ReorgStep Undo) : List Nat :=
  (List.range (s.tip - s.fork)).map (fun i => s.tip - i)

/-- `ConnectTip` walk: `fork+1, …, cand` (forward height order). -/
def connectOrder {Undo : Type} (s : ReorgStep Undo) : List Nat :=
  (List.range (s.cand - s.fork)).map (fun i => s.fork + 1 + i)

/-- The exact disconnected height set — no height is skipped or repeated. -/
theorem disconnectOrder_mem_iff {Undo : Type} (s : ReorgStep Undo)
    (h : s.fork ≤ s.tip) (k : Nat) :
    k ∈ disconnectOrder s ↔ s.fork < k ∧ k ≤ s.tip := by
  unfold disconnectOrder
  rw [List.mem_map]
  constructor
  · rintro ⟨i, hi, rfl⟩
    rw [List.mem_range] at hi
    omega
  · rintro ⟨hfk, hkt⟩
    exact ⟨s.tip - k, by rw [List.mem_range]; omega, by omega⟩

/-- The exact connected height set — no height is skipped or repeated. -/
theorem connectOrder_mem_iff {Undo : Type} (s : ReorgStep Undo)
    (h : s.fork ≤ s.cand) (k : Nat) :
    k ∈ connectOrder s ↔ s.fork < k ∧ k ≤ s.cand := by
  unfold connectOrder
  rw [List.mem_map]
  constructor
  · rintro ⟨i, hi, rfl⟩
    rw [List.mem_range] at hi
    omega
  · rintro ⟨hfk, hkc⟩
    exact ⟨k - (s.fork + 1), by rw [List.mem_range]; omega, by omega⟩

/-- Disconnect count = `reorgPlan`'s first component. -/
theorem disconnectOrder_length {Undo : Type} (s : ReorgStep Undo) :
    (disconnectOrder s).length = (reorgPlan s.tip s.cand s.fork).1 := by
  simp [disconnectOrder, reorgPlan]

/-- Connect count = `reorgPlan`'s second component. -/
theorem connectOrder_length {Undo : Type} (s : ReorgStep Undo) :
    (connectOrder s).length = (reorgPlan s.tip s.cand s.fork).2 := by
  simp [connectOrder, reorgPlan]

/-- Undo payloads consumed by the disconnect walk: exactly one per
disconnected block, in reverse height order. -/
def disconnectUndo {Undo : Type} (s : ReorgStep Undo) : List Undo :=
  (disconnectOrder s).map s.undo

/-- Undo payloads produced by the connect walk: exactly one per connected
block, in forward height order. -/
def connectUndo {Undo : Type} (s : ReorgStep Undo) : List Undo :=
  (connectOrder s).map s.connected

/-- **BLK-118** (composition + undo): a switch consists of `tip − fork`
DisconnectTip steps over exactly `(fork, tip]` (each consuming one stored
undo record) followed by `cand − fork` ConnectTip steps over exactly
`(fork, cand]` (each producing one undo record). The block counts are
`reorgPlan`'s pair, so the count model is the length projection of the
full walk. -/
@[rule "BLK-118"]
theorem reorgStep_disconnect_connect {Undo : Type} (s : ReorgStep Undo)
    (ht : s.fork ≤ s.tip) (hc : s.fork ≤ s.cand) :
    (disconnectOrder s).length = (reorgPlan s.tip s.cand s.fork).1 ∧
    (connectOrder s).length = (reorgPlan s.tip s.cand s.fork).2 ∧
    (∀ k, k ∈ disconnectOrder s ↔ s.fork < k ∧ k ≤ s.tip) ∧
    (∀ k, k ∈ connectOrder s ↔ s.fork < k ∧ k ≤ s.cand) ∧
    (disconnectUndo s).length = s.tip - s.fork ∧
    (connectUndo s).length = s.cand - s.fork := by
  refine ⟨disconnectOrder_length s, connectOrder_length s,
    fun k => disconnectOrder_mem_iff s ht k,
    fun k => connectOrder_mem_iff s hc k, ?_, ?_⟩
  · simp [disconnectUndo, disconnectOrder]
  · simp [connectUndo, connectOrder]

/-- Nothing is disconnected or connected when both tips are the fork. -/
theorem reorgStep_at_fork {Undo : Type} (s : ReorgStep Undo)
    (ht : s.tip = s.fork) (hc : s.cand = s.fork) :
    disconnectOrder s = [] ∧ connectOrder s = [] := by
  constructor
  · apply List.eq_nil_iff_forall_not_mem.mpr
    intro k hk
    have := (disconnectOrder_mem_iff s (by omega) k).mp hk
    omega
  · apply List.eq_nil_iff_forall_not_mem.mpr
    intro k hk
    have := (connectOrder_mem_iff s (by omega) k).mp hk
    omega

/-! ## BLK-118 — instantiation against the real tip engine

`ReorgStep` above is the count/order projection. The **actual** transition
model now lives in `Bitcoin.Block.Index`: `TipState` carries the active
chain and each block's stored undo payload, `TipState.disconnectTip` pops
the tip and consumes exactly that payload, `TipState.connectTip` appends a
child and writes exactly its payload, and `TipState.reorgTo` is the
`ActivateBestChainStep` composition. The theorem below is the row-level
face: it runs the real operations, shows the terminal chain and the
consumed/produced undo lists, and identifies the transition counts with
`reorgPlan`. -/

/-- **BLK-118** (real DisconnectTip/ConnectTip composition): for an active
chain `pre ++ [fork] ++ suffix`, `reorgTo` disconnects exactly the blocks
above the fork — consuming one stored undo record per block in reverse
height order — then connects the consecutive candidate suffix, producing
one undo record per block in forward height order. The terminal active
chain is `pre ++ [fork] ++ candSuffix`, and the transition counts are
`reorgPlan tip cand fork`'s pair. -/
@[rule "BLK-118"]
theorem reorgTo_reorgPlan {Undo : Type} (s : TipState Undo)
    (fork : BlockRecord Undo) (pre suffix candSuffix : List (BlockRecord Undo))
    (tip cand : Nat)
    (hs : s.active = pre ++ fork :: suffix)
    (hgt : ∀ b ∈ suffix, fork.height < b.height)
    (hc : ConsecutiveHeights (fork.height + 1) candSuffix)
    (htip : tip = fork.height + suffix.length)
    (hcand : cand = fork.height + candSuffix.length) :
    ∃ s', s.reorgTo fork.height candSuffix = some s' ∧
      s'.active = pre ++ [fork] ++ candSuffix ∧
      (s.disconnectTo fork.height).active = pre ++ [fork] ∧
      s'.consumed = s.consumed ++ suffix.reverse.map BlockRecord.undo ∧
      s'.produced = s.produced ++ candSuffix.map BlockRecord.undo ∧
      (reorgPlan tip cand fork.height).1 = suffix.length ∧
      (reorgPlan tip cand fork.height).2 = candSuffix.length := by
  have hne : ∀ b ∈ suffix, b.height ≠ fork.height := by
    intro b hb
    have := hgt b hb
    omega
  obtain ⟨s', hreorg, hact, hcons, hprod⟩ :=
    reorgTo_active_consumed_produced s fork pre suffix candSuffix hs hne hc
  have hdis : (s.disconnectTo fork.height).active = pre ++ [fork] :=
    (disconnectTo_active_consumed s fork pre suffix hs hne).1
  refine ⟨s', hreorg, hact, hdis, hcons, hprod, ?_, ?_⟩
  · rw [htip]; simp [reorgPlan]
  · rw [hcand]; simp [reorgPlan]

/-! ## BLK-119 — failure marking and descendant pruning

Core `InvalidBlockFound` (validation.cpp:1987-1996) sets
`BLOCK_FAILED_VALID` only when the validation result is **not**
`BLOCK_MUTATED`, erases the failed block from `setBlockIndexCandidates`,
and marks its **proper descendants** `BLOCK_FAILED_CHILD`.  The failed
block itself is therefore dropped and marked `BLOCK_FAILED_VALID`, not
`BLOCK_FAILED_CHILD`.  The model below makes all of that explicit over a
bit-projection of `nStatus`: `markFailedValid` is
`nStatus |= BLOCK_FAILED_VALID`, `markFailedChild` is
`nStatus |= BLOCK_FAILED_CHILD`, and the pruning filter remains the
existing `prunedCandidates` (which is reflexive, so it drops the failed
block too).  The theorem set proves (1) the failed block is marked VALID
and no valid block is mutated (pure memoization), (2) every *proper
descendant* dropped by the filter is marked `BLOCK_FAILED_CHILD`, and
(3) survivors keep their status unchanged. -/

/-- Bit-projection model of the consensus-relevant `nStatus` flags
(chain.h `BlockStatus`): validity-level `BLOCK_VALID_SCRIPTS` plus the
data/undo and failure bits. The projection is deliberately lossless for
the five predicates this row uses. -/
structure IndexStatus where
  /-- `BLOCK_VALID_SCRIPTS` reached. -/
  validScripts : Bool := false
  /-- `BLOCK_HAVE_DATA`. -/
  haveData : Bool := false
  /-- `BLOCK_HAVE_UNDO`. -/
  haveUndo : Bool := false
  /-- `BLOCK_FAILED_VALID` (`nStatus |= 32`). -/
  failedValid : Bool := false
  /-- `BLOCK_FAILED_CHILD` (`nStatus |= 64`). -/
  failedChild : Bool := false
deriving DecidableEq, Repr

/-- `nStatus & BLOCK_FAILED_MASK != 0`. -/
def IndexStatus.failed (s : IndexStatus) : Bool :=
  s.failedValid || s.failedChild

/-- `nStatus |= BLOCK_FAILED_VALID` (validation.cpp:1990). -/
def markFailedValid (s : IndexStatus) : IndexStatus :=
  { s with failedValid := true }

/-- `nStatus |= BLOCK_FAILED_CHILD` (descendant invalidation). -/
def markFailedChild (s : IndexStatus) : IndexStatus :=
  { s with failedChild := true }

theorem markFailedValid_failed (s : IndexStatus) :
    (markFailedValid s).failed = true := by
  simp [markFailedValid, IndexStatus.failed]

theorem markFailedValid_preserves_valid (s : IndexStatus) :
    (markFailedValid s).validScripts = s.validScripts ∧
    (markFailedValid s).haveData = s.haveData ∧
    (markFailedValid s).haveUndo = s.haveUndo ∧
    (markFailedValid s).failedChild = s.failedChild := by
  simp [markFailedValid]

theorem markFailedValid_idempotent (s : IndexStatus) :
    markFailedValid (markFailedValid s) = markFailedValid s := by
  simp [markFailedValid]

/-- **BLK-119** (non-mutated marking): `InvalidBlockFound` on a
non-`BLOCK_MUTATED` failure sets `BLOCK_FAILED_VALID` on the failed block
and leaves every other index entry untouched. A `BLOCK_MUTATED` result is
a no-op (Core:1990 guard). -/
def invalidBlockFound (mutated : Bool)
    (status : Nat → IndexStatus) (bad : Nat) : Nat → IndexStatus :=
  if mutated then status
  else fun k => if k = bad then markFailedValid (status k) else status k

/-- A mutated failure marks nothing. -/
theorem invalidBlockFound_mutated (status : Nat → IndexStatus) (bad : Nat) :
    invalidBlockFound true status bad = status := by
  unfold invalidBlockFound; rw [if_pos rfl]

/-- **BLK-119**: the failed block is marked `BLOCK_FAILED_VALID`. -/
@[rule "BLK-119"]
theorem invalidBlockFound_bad (status : Nat → IndexStatus) (bad : Nat) :
    (invalidBlockFound false status bad bad).failedValid = true := by
  unfold invalidBlockFound
  rw [if_neg (by decide : ¬ (false = true))]
  simp [markFailedValid]

/-- **BLK-119** (pure memoization): every OTHER index entry is untouched by
a non-mutated failure marking. -/
@[rule "BLK-119"]
theorem invalidBlockFound_other (status : Nat → IndexStatus) (bad k : Nat)
    (hne : k ≠ bad) :
    invalidBlockFound false status bad k = status k := by
  unfold invalidBlockFound
  rw [if_neg (by decide : ¬ (false = true))]
  simp [hne]

theorem invalidBlockFound_idempotent (status : Nat → IndexStatus) (bad : Nat) :
    invalidBlockFound false (invalidBlockFound false status bad) bad =
      invalidBlockFound false status bad := by
  funext k
  unfold invalidBlockFound
  rw [if_neg (by decide : ¬ (false = true))]
  by_cases hk : k = bad
  · subst hk; simp [markFailedValid_idempotent]
  · simp [hk]

/-- Status after InvalidateBlock-style propagation: the failed block gets
`BLOCK_FAILED_VALID`, its descendants `BLOCK_FAILED_CHILD`, everything
else is untouched. `mutated` preserves Core's non-mutated guard. -/
def failedStatusOf (parentOf : Nat → Option Nat) (mutated : Bool)
    (fuel bad : Nat) (status : Nat → IndexStatus) : Nat → IndexStatus :=
  fun k =>
    if mutated then status k
    else if k = bad then markFailedValid (status k)
    else if isDescendantOf parentOf fuel bad k = true then markFailedChild (status k)
    else status k

/-- The failed block itself carries `BLOCK_FAILED_VALID`. -/
@[rule "BLK-119"]
theorem failedStatusOf_bad (parentOf : Nat → Option Nat) (fuel bad : Nat)
    (status : Nat → IndexStatus) :
    (failedStatusOf parentOf false fuel bad status bad).failedValid = true := by
  unfold failedStatusOf
  simp [markFailedValid]

/-- A pruned descendant carries `BLOCK_FAILED_CHILD` (and no valid-chain
flag is cleared). -/
@[rule "BLK-119"]
theorem failedStatusOf_descendant (parentOf : Nat → Option Nat) (fuel bad k : Nat)
    (status : Nat → IndexStatus) (hne : k ≠ bad)
    (hd : isDescendantOf parentOf fuel bad k = true) :
    (failedStatusOf parentOf false fuel bad status k).failedChild = true := by
  unfold failedStatusOf
  simp [hne, hd, markFailedChild]

/-- **BLK-119** (failed block drops as VALID, not CHILD): the failed block
itself is removed from the candidate set by the reflexive prune filter,
keeps `BLOCK_FAILED_VALID`, and does not acquire `BLOCK_FAILED_CHILD`
unless that bit was already set. -/
@[rule "BLK-119"]
theorem failedStatusOf_bad_dropped_valid (parentOf : Nat → Option Nat)
    (fuel bad : Nat) (status : Nat → IndexStatus) (cands : List Nat)
    (_hbad : bad ∈ cands) :
    bad ∉ prunedCandidates parentOf bad (fuel + 1) cands ∧
      (failedStatusOf parentOf false (fuel + 1) bad status bad).failedValid = true ∧
      (failedStatusOf parentOf false (fuel + 1) bad status bad).failedChild =
        (status bad).failedChild := by
  refine ⟨?_, failedStatusOf_bad parentOf (fuel + 1) bad status, ?_⟩
  · intro hm
    unfold prunedCandidates at hm
    have hk := (List.mem_filter.mp hm).2
    rw [isDescendantOf_refl] at hk
    simp at hk
  · unfold failedStatusOf
    rw [if_neg (by decide : ¬ (false = true))]
    simp [markFailedValid]

/-- **BLK-119** (pure memoization, pruning face): a surviving candidate
(not the failed block and not a proper descendant, hence not pruned) keeps
its status exactly. -/
@[rule "BLK-119"]
theorem survivorStatus_unchanged (parentOf : Nat → Option Nat) (fuel bad : Nat)
    (status : Nat → IndexStatus) (cands : List Nat) (d : Nat)
    (hm : d ∈ prunedCandidates parentOf bad fuel cands) (hne : d ≠ bad) :
    failedStatusOf parentOf false fuel bad status d = status d := by
  have hd : isDescendantOf parentOf fuel bad d = false := by
    unfold prunedCandidates at hm
    have := (List.mem_filter.mp hm).2
    simpa using this
  unfold failedStatusOf
  simp [hne, hd]

/-- Exact filter semantics of pruning: survivors are precisely the
candidates that are NOT descendants of the failed block. -/
@[rule "BLK-119"]
theorem prunedCandidates_iff (parentOf : Nat → Option Nat) (failed fuel : Nat)
    (cands : List Nat) (d : Nat) :
    d ∈ prunedCandidates parentOf failed fuel cands ↔
      d ∈ cands ∧ isDescendantOf parentOf fuel failed d = false := by
  unfold prunedCandidates
  rw [List.mem_filter]
  constructor
  · rintro ⟨hm, hk⟩
    exact ⟨hm, by simpa using hk⟩
  · rintro ⟨hm, hk⟩
    exact ⟨hm, by simp [hk]⟩

/-- **BLK-119** (descendant marking): every *proper descendant* candidate
dropped by the prune filter is marked `BLOCK_FAILED_CHILD` in the
post-failure status.  The failed block itself is also dropped, but it is
marked `BLOCK_FAILED_VALID` (see `failedStatusOf_bad_dropped_valid`). -/
@[rule "BLK-119"]
theorem prunedStatus_marked (parentOf : Nat → Option Nat) (fuel bad : Nat)
    (status : Nat → IndexStatus) (cands : List Nat) (d : Nat)
    (hm : d ∈ cands) (hpr : d ∉ prunedCandidates parentOf bad fuel cands)
    (hne : d ≠ bad) :
    (failedStatusOf parentOf false fuel bad status d).failedChild = true := by
  have hdesc : isDescendantOf parentOf fuel bad d = true := by
    by_cases hb : isDescendantOf parentOf fuel bad d = true
    · exact hb
    · have hf : isDescendantOf parentOf fuel bad d = false := by
        cases h' : isDescendantOf parentOf fuel bad d <;> simp_all
      exact absurd ((prunedCandidates_iff parentOf bad fuel cands d).mpr ⟨hm, hf⟩) hpr
  unfold failedStatusOf
  simp [hne, hdesc, markFailedChild]

#print axioms reorgPlan_disconnect
#print axioms reorgPlan_connect
#print axioms reorgPlan_at_fork
#print axioms prunedCandidates_subset
#print axioms descendant_not_pruned
#print axioms failedStatusOf_bad_dropped_valid
#print axioms reorgTo_reorgPlan

end BitcoinProofs.AF.PDW30
