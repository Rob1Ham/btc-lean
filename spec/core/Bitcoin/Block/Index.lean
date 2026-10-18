import Bitcoin.Block.Pow
import Bitcoin.Chain.Basic
import Bitcoin.RuleAttr

/-!
# Bitcoin.Block.Index — chainwork accumulation + tip selection (the block-validation module)

The `CBlockIndex` chain-score layer, at rule-DB fidelity:

* `workOf` — **BLK-113**: `GetBlockProof` (chain.cpp:70-85),
  `work(nBits) = (~target / (target+1)) + 1` over 256-bit two's
  complement (`~t = 2^256 − 1 − t`); 0 for an out-of-range decode (the
  rule text pins the gated form — Core's `nChainWork` only accumulates
  over validated blocks in practice).
* `chainWork` — **BLK-114**: `nChainWork` = fold of per-block work from
  genesis; genesis = own work (accumulator starts at 0).
* `Tip`/`mostWork?` — **BLK-115/BLK-116**: `CBlockIndexWorkComparator`
  (chain.h:174-189): higher work first, ties by lower `nSequenceId`
  (earlier-received/active-chain); the residual pointer order is
  non-consensus and modeled as "later candidate loses ties".
* `switchTip` — **BLK-117**: the tip changes only to a STRICTLY
  better-work candidate (validation.cpp:3263, 3508).
* `reorgPlan` — **BLK-118**: a switch = disconnect `tip − fork` blocks
  then connect `cand − fork` (ActivateBestChainStep shape).
* `isDescendantOf`/`prunedCandidates` — **BLK-119**: a non-mutated
  failure marks the block failed and prunes its descendants from the
  candidate set (pure memoization).
* `submitVerdict` — **BLK-120**: a cached-failed hash re-submits as
  `duplicate-invalid` without re-validation.
* `bestInvalidWork` — **BLK-121**: highest-work invalid-chain bookkeeping
  (warning/UI only).
* `connectHeight` — **BLK-059**: height = pindexPrev.height + 1.

Every theorem is sorry-free; axiom pins at the bottom (axiom-pin discipline).
-/

namespace Bitcoin.Block.Index

open Bitcoin.Chain

/-! ## BLK-113: the work function -/

/-- Mainnet-class `powLimit` (the gating decode bound; same constant as
`Bitcoin.Block.Pow.powLimitMainnet`). -/
def powLimit : Nat := Bitcoin.Block.Pow.powLimitMainnet

/-- Share the exact chain parameter used by the retarget machinery. -/
theorem powLimit_eq_mainnet : powLimit = Bitcoin.Block.Pow.powLimitMainnet := rfl

/-- **BLK-113**: `GetBlockProof` — `(~target / (target+1)) + 1`; 0 when
the decode is out of the consensus range (zero or above powLimit). -/
@[rule "BLK-113", rule "INV-141"]
def workOf (bits : UInt32) : Nat :=
  if compactTarget bits = 0 ∨ powLimit < compactTarget bits then 0
  else (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1

/-- Difficulty-1 (genesis, nBits 0x1d00ffff) carries positive work. -/
theorem workOf_difficulty_one_pos : 0 < workOf 0x1d00ffff := by decide

/-- An in-range nonzero decode always carries positive work (the
division's successor always clears zero). -/
theorem workOf_pos_of_valid (bits : UInt32) (h : 0 < compactTarget bits)
    (hl : compactTarget bits ≤ powLimit) : 0 < workOf bits := by
  unfold workOf
  rw [if_neg (by omega)]
  exact Nat.succ_le_succ (Nat.zero_le _)

/-! ## BLK-114: chainwork accumulation -/

/-- **BLK-114**: `nChainWork(B) = nChainWork(prev) + work(B.nBits)` as a
genesis-first fold; the empty chain (pre-genesis) carries 0. -/
@[rule "BLK-114"]
def chainWork : List UInt32 → Nat
  | [] => 0
  | b :: rest => workOf b + chainWork rest

/-- Genesis = own work (the fold's base). -/
theorem chainWork_singleton (b : UInt32) : chainWork [b] = workOf b := by
  simp [chainWork]

/-- The fold is additive over concatenation (the lemma behind
incremental `nChainWork` updates and undo/re-add symmetry). -/
theorem chainWork_append (xs ys : List UInt32) :
    chainWork (xs ++ ys) = chainWork xs + chainWork ys := by
  induction xs with
  | nil => simp [chainWork]
  | cons b rest ih => simp only [List.cons_append, chainWork, ih, Nat.add_assoc]

/-- Appending a block adds exactly its own work (BLK-114, connect
direction). -/
theorem chainWork_snoc (xs : List UInt32) (b : UInt32) :
    chainWork (xs ++ [b]) = chainWork xs + workOf b := by
  rw [chainWork_append]
  simp [chainWork]

/-! ## BLK-115/116/117: tip selection -/

/-- A chain tip as the work comparator sees it. -/
structure Tip where
  hash : ByteArray
  chainWork : Nat
  /-- `nSequenceId`: lower = earlier-received / active chain. -/
  sequence : Nat
deriving Repr

/-- **BLK-115/116**: `CBlockIndexWorkComparator`'s "a beats b": higher
chainwork; on EQUAL work, the lower `nSequenceId` (earlier-received /
active chain) wins. Residual pointer-order ties are non-consensus
(modeled: the later candidate loses). -/
def betterThan (a b : Tip) : Bool :=
  decide (a.chainWork > b.chainWork) ||
    decide (a.chainWork = b.chainWork && a.sequence < b.sequence)

/-- The comparator's winner never has less work than the loser. -/
theorem betterThan_work_ge (a b : Tip) (h : betterThan a b = true) :
    b.chainWork ≤ a.chainWork := by
  simp only [betterThan, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true] at h
  rcases h with hg | ⟨heq, _⟩
  · exact Nat.le_of_lt hg
  · rw [heq]; exact Nat.le_refl _

/-- The fold step: keep the better tip. -/
def betterTip (a b : Tip) : Tip := if betterThan a b = true then a else b

/-- **BLK-115**: the most-work candidate (`FindMostWorkChain`'s max over
valid, data-complete tips), BLK-116's tie-break folded in. -/
@[rule "BLK-115", rule "BLK-116", rule "INV-140"]
def mostWork? : List Tip → Option Tip
  | [] => none
  | t :: rest =>
    match mostWork? rest with
    | none => some t
    | some b => some (betterTip t b)

/-- The fold equation, as a rewrite lemma. -/
theorem mostWork?_cons (u : Tip) (rest : List Tip) :
    mostWork? (u :: rest) =
      match mostWork? rest with
      | none => some u
      | some b => some (betterTip u b) := rfl

/-- `mostWork?` is `none` only on the empty candidate set. -/
theorem mostWork?_none_nil {rest : List Tip} (h : mostWork? rest = none) :
    rest = [] := by
  cases rest with
  | nil => rfl
  | cons u r =>
    rw [mostWork?_cons] at h
    cases hmr : mostWork? r with
    | none => simp [hmr] at h
    | some b => simp [hmr] at h

/-- **BLK-115** (maximality): the selected tip's work is ≥ every
candidate's work. -/
theorem mostWork_work_ge :
    ∀ (tips : List Tip) (t : Tip), t ∈ tips →
      ∀ sel : Tip, mostWork? tips = some sel → t.chainWork ≤ sel.chainWork := by
  intro tips
  induction tips with
  | nil => intro t ht; cases ht
  | cons u rest ih =>
    intro t ht sel hsel
    rw [mostWork?_cons] at hsel
    split at hsel
    · rename_i hnone
      simp only [Option.some.injEq] at hsel
      subst hsel
      rcases List.mem_cons.mp ht with heq | hrest
      · subst heq; exact Nat.le_refl _
      · have : rest = [] := mostWork?_none_nil hnone
        subst this
        exact absurd hrest (by simp)
    · rename_i b hb
      simp only [Option.some.injEq] at hsel
      unfold betterTip at hsel
      split at hsel
      · rename_i hbt
        subst hsel
        rcases List.mem_cons.mp ht with heq | hrest
        · subst heq; exact Nat.le_refl _
        · exact Nat.le_trans (ih t hrest b hb) (betterThan_work_ge u b hbt)
      · rename_i hbt
        subst hsel
        rcases List.mem_cons.mp ht with heq | hrest
        · subst heq
          have hn : ¬(t.chainWork > b.chainWork) := by
            intro hc
            apply hbt
            show decide (t.chainWork > b.chainWork) ||
                 decide (t.chainWork = b.chainWork && t.sequence < b.sequence) = true
            rw [decide_eq_true hc]
            rfl
          omega
        · exact ih t hrest b hb

/-! ## BLK-117: strict-improvement switching -/

/-- **BLK-117**: the tip switches ONLY to a strictly better-work
candidate; equal work keeps the current tip (validation.cpp:3263). -/
@[rule "BLK-117"]
def switchTip (current candidate : Tip) : Tip :=
  if decide (candidate.chainWork > current.chainWork) = true then candidate else current

/-- Switching to the incumbent is the identity. -/
theorem switchTip_self (t : Tip) : switchTip t t = t := by
  unfold switchTip
  rw [if_neg (by simp only [decide_eq_true_eq]; omega)]

/-- No strictly-better candidate ⇒ no switch. -/
theorem switchTip_not_better (current candidate : Tip)
    (h : candidate.chainWork ≤ current.chainWork) :
    switchTip current candidate = current := by
  unfold switchTip
  rw [if_neg (by simp only [decide_eq_true_eq]; omega)]

/-! ## BLK-118: reorg shape -/

/-- **BLK-118**: a switch at fork point `f` between tips at heights
`tip` (current) and `cand` (candidate) = disconnect `tip − f` blocks,
then connect `cand − f` (ActivateBestChainStep's DisconnectTip/ConnectTip
pairing). -/
@[rule "BLK-118"]
def reorgPlan (tip cand fork : Nat) : Nat × Nat := (tip - fork, cand - fork)

/-- Same tip ⇒ zero disconnects. -/
theorem reorgPlan_self_disconnect (h fork : Nat) : (reorgPlan h h fork).1 = h - fork := rfl

/-! ## BLK-118: the concrete DisconnectTip / ConnectTip transitions

`reorgPlan` above is only the count projection. The transition model below
is the actual tip engine Core runs in `ActivateBestChainStep`:

* `BlockRecord` carries a block's height, hash and stored per-block undo
  payload (the `CTxUndo` batch that `WriteBlockUndo` persists);
* `TipState.disconnectTip` pops the active tip and **consumes** exactly
  that block's stored undo payload (Core `DisconnectTip` → `DisconnectBlock`
  → `ApplyTxInUndo`);
* `TipState.connectTip` appends a child and **produces** exactly its undo
  payload (Core `ConnectTip` → `ConnectBlock` → `WriteBlockUndo`);
* `disconnectUntil` / `connectWalk` iterate those real transitions, and
  `reorgTo` is the ActivateBestChainStep composition (disconnect to the
  fork, then connect the candidate suffix forward).

The proofs below show that the heights visited are exactly `(fork, tip]`
and `(fork, cand]`, that each visited block contributes exactly one undo
payload on the correct side, and that the transition counts are the
`reorgPlan` pair. -/

/-- One indexed block as the tip engine sees it. `undo` is the per-block
`CTxUndo` payload stored by `WriteBlockUndo`. -/
structure BlockRecord (Undo : Type) where
  /-- Block height (`CBlockIndex::nHeight`). -/
  height : Nat
  /-- Block hash (identity used by the active tip). -/
  hash : ByteArray
  /-- Stored undo payload for this block (`CTxUndo` batch). -/
  undo : Undo

/-- Active-chain state. `active` is ascending genesis→tip; `consumed`
logs the undo payloads read by disconnects and `produced` the payloads
written by connects (both in execution order). -/
structure TipState (Undo : Type) where
  /-- Active chain, genesis first. -/
  active : List (BlockRecord Undo)
  /-- Undo payloads consumed by `DisconnectTip`, in execution order. -/
  consumed : List Undo := []
  /-- Undo payloads produced by `ConnectTip`, in execution order. -/
  produced : List Undo := []

/-- Current tip height, if the active chain is nonempty. -/
def TipState.tipHeight? {Undo : Type} (s : TipState Undo) : Option Nat :=
  s.active.reverse.head?.map BlockRecord.height

/-- **BLK-118**: `DisconnectTip` — pop the active tip and consume exactly
its stored undo payload. `none` on the empty chain (Core asserts a
nonempty tip before calling). -/
@[rule "BLK-118"]
def TipState.disconnectTip {Undo : Type} (s : TipState Undo) :
    Option (TipState Undo) :=
  match s.active.getLast? with
  | none => none
  | some b =>
      some { active := s.active.dropLast
             consumed := s.consumed ++ [b.undo]
             produced := s.produced }

/-- **BLK-118**: `ConnectTip` — append a child at the parent's successor
height and write exactly its undo payload. A height mismatch aborts. -/
@[rule "BLK-118"]
def TipState.connectTip {Undo : Type} (s : TipState Undo)
    (b : BlockRecord Undo) : Option (TipState Undo) :=
  match s.tipHeight? with
  | none =>
      if b.height = 0 then
        some { active := [b], consumed := s.consumed,
               produced := s.produced ++ [b.undo] }
      else none
  | some h =>
      if b.height = h + 1 then
        some { active := s.active ++ [b], consumed := s.consumed,
               produced := s.produced ++ [b.undo] }
      else none

/-- Reverse-order walk used by `disconnectTo`: consume blocks from the
tip down to the block at `forkHeight`, stopping at that block. -/
def disconnectUntil {Undo : Type} (forkHeight : Nat) :
    List (BlockRecord Undo) → List Undo →
      List (BlockRecord Undo) × List Undo
  | [], acc => ([], acc)
  | b :: rest, acc =>
      if b.height = forkHeight then (b :: rest, acc)
      else disconnectUntil forkHeight rest (acc ++ [b.undo])

/-- **BLK-118**: run `disconnectTip` down to the fork block. -/
@[rule "BLK-118"]
def TipState.disconnectTo {Undo : Type} (s : TipState Undo)
    (forkHeight : Nat) : TipState Undo :=
  let (rev, consumed) :=
    disconnectUntil (Undo := Undo) forkHeight s.active.reverse s.consumed
  { active := rev.reverse, consumed := consumed, produced := s.produced }

/-- **BLK-118**: run `connectTip` forward over a candidate suffix. Any
height mismatch aborts, matching `ConnectTip`'s system-error return. -/
@[rule "BLK-118"]
def TipState.connectWalk {Undo : Type} (s : TipState Undo) :
    List (BlockRecord Undo) → Option (TipState Undo)
  | [] => some s
  | b :: rest =>
      match s.connectTip b with
      | none => none
      | some s' => s'.connectWalk rest

/-- **BLK-118**: the full switch — disconnect to the fork block, then
connect the candidate suffix forward. -/
@[rule "BLK-118"]
def TipState.reorgTo {Undo : Type} (s : TipState Undo) (forkHeight : Nat)
    (candSuffix : List (BlockRecord Undo)) : Option (TipState Undo) :=
  (s.disconnectTo forkHeight).connectWalk candSuffix

/-- Consecutive heights starting at `start`; the shape of a `ConnectTip`
suffix. -/
def ConsecutiveHeights {Undo : Type} (start : Nat) :
    List (BlockRecord Undo) → Prop
  | [] => True
  | b :: rest => b.height = start ∧ ConsecutiveHeights (start + 1) rest

/-- Processing a block whose height is not the fork consumes exactly its
undo payload and continues. -/
theorem disconnectUntil_cons_ne {Undo : Type} (forkHeight : Nat)
    (b : BlockRecord Undo) (rest : List (BlockRecord Undo))
    (acc : List Undo) (h : b.height ≠ forkHeight) :
    disconnectUntil forkHeight (b :: rest) acc =
      disconnectUntil forkHeight rest (acc ++ [b.undo]) := by
  cases rest with
  | nil => simp [disconnectUntil, h]
  | cons c cs => simp [disconnectUntil, h]

/-- The reverse suffix walk consumes every payload above the fork, in
reverse height order, and leaves the fork as the new tip. -/
theorem disconnectUntil_reverse_append_fork {Undo : Type}
    (fork : BlockRecord Undo) (pre revSuffix : List (BlockRecord Undo))
    (acc : List Undo)
    (hne : ∀ b ∈ revSuffix, b.height ≠ fork.height) :
    disconnectUntil fork.height (revSuffix ++ (fork :: pre)) acc =
      (fork :: pre, acc ++ revSuffix.map BlockRecord.undo) := by
  induction revSuffix generalizing acc with
  | nil => simp [disconnectUntil]
  | cons b rest ih =>
      have hb : b.height ≠ fork.height := hne b (by simp)
      have hrest : ∀ x ∈ rest, x.height ≠ fork.height := by
        intro x hx; exact hne x (by simp [hx])
      rw [List.cons_append, disconnectUntil_cons_ne fork.height b
        (rest ++ fork :: pre) acc hb]
      rw [ih (acc ++ [b.undo]) hrest]
      simp [List.append_assoc]

/-- `disconnectTo` on a chain `pre ++ [fork] ++ suffix`: the resulting
active chain is exactly `pre ++ [fork]`, no height below the fork is
touched, and the consumed payload list is exactly the suffix's payloads in
reverse height order (one per disconnected block). -/
@[rule "BLK-118"]
theorem disconnectTo_active_consumed {Undo : Type} (s : TipState Undo)
    (fork : BlockRecord Undo) (pre suffix : List (BlockRecord Undo))
    (hs : s.active = pre ++ fork :: suffix)
    (hne : ∀ b ∈ suffix, b.height ≠ fork.height) :
    (s.disconnectTo fork.height).active = pre ++ [fork] ∧
    (s.disconnectTo fork.height).consumed =
      s.consumed ++ suffix.reverse.map BlockRecord.undo ∧
    (s.disconnectTo fork.height).produced = s.produced := by
  unfold TipState.disconnectTo
  rw [hs]
  simp only [List.reverse_append, List.reverse_cons, List.reverse_reverse,
    List.nil_append]
  rw [show suffix.reverse ++ [fork] ++ pre.reverse =
      suffix.reverse ++ (fork :: pre.reverse) by simp]
  rw [disconnectUntil_reverse_append_fork fork pre.reverse suffix.reverse
    s.consumed (by
      intro b hb
      exact hne b (by simpa using hb))]
  simp [List.reverse_reverse]

/-- `tipHeight? = none` exactly on the empty active chain. -/
theorem tipHeight?_eq_none_iff {Undo : Type} (s : TipState Undo) :
    s.tipHeight? = none ↔ s.active = [] := by
  unfold TipState.tipHeight?
  cases h : s.active.reverse with
  | nil =>
      have hactive : s.active = [] := by simpa using h
      simp [hactive]
  | cons b rest =>
      have hne : s.active ≠ [] := by
        intro hactive
        rw [hactive] at h
        simp at h
      simp [hne]

/-- If the active chain ends in `b`, the tip height is `b.height`. -/
theorem tipHeight?_of_active_eq_append {Undo : Type} (s : TipState Undo)
    (pre : List (BlockRecord Undo)) (b : BlockRecord Undo)
    (h : s.active = pre ++ [b]) : s.tipHeight? = some b.height := by
  unfold TipState.tipHeight?
  rw [h]
  simp

/-- A successful `connectTip` appends exactly the block and writes
exactly its payload. -/
theorem connectTip_active_produced {Undo : Type} (s : TipState Undo)
    (b : BlockRecord Undo) (s' : TipState Undo)
    (h : s.connectTip b = some s') :
    s'.active = s.active ++ [b] ∧
    s'.consumed = s.consumed ∧
    s'.produced = s.produced ++ [b.undo] := by
  unfold TipState.connectTip at h
  split at h
  · rename_i hnone
    have hempty : s.active = [] := (tipHeight?_eq_none_iff s).mp hnone
    split at h
    · simp only [Option.some.injEq] at h
      subst h; simp [hempty]
    · simp at h
  · split at h
    · simp only [Option.some.injEq] at h
      subst h; simp
    · simp at h

/-- **BLK-118**: `connectWalk` over a consecutive suffix appends exactly
that suffix, consumes nothing, and produces exactly one payload per
connected block in forward height order. -/
@[rule "BLK-118"]
theorem connectWalk_active_produced {Undo : Type} (s : TipState Undo)
    (start : Nat) (suffix : List (BlockRecord Undo))
    (hs : s.tipHeight? = some start)
    (hc : ConsecutiveHeights (start + 1) suffix) :
    ∃ s', s.connectWalk suffix = some s' ∧
      s'.active = s.active ++ suffix ∧
      s'.consumed = s.consumed ∧
      s'.produced = s.produced ++ suffix.map BlockRecord.undo := by
  induction suffix generalizing start s with
  | nil =>
      exact ⟨s, by simp [TipState.connectWalk], by simp, by simp, by simp⟩
  | cons b rest ih =>
      obtain ⟨hb, hrest⟩ := hc
      let s₁ : TipState Undo :=
        { active := s.active ++ [b], consumed := s.consumed,
          produced := s.produced ++ [b.undo] }
      have hs₁ : s.connectTip b = some s₁ := by
        unfold TipState.connectTip
        rw [hs, hb]
        simp [s₁]
      obtain ⟨hact, hcons, hprod⟩ :=
        connectTip_active_produced s b s₁ hs₁
      have htip : s₁.tipHeight? = some (start + 1) := by
        have h := tipHeight?_of_active_eq_append s₁ s.active b hact
        rwa [hb] at h
      obtain ⟨s₂, hwalk, hact₂, hcons₂, hprod₂⟩ :=
        ih (start := start + 1) (s := s₁) htip hrest
      refine ⟨s₂, ?_, ?_, ?_, ?_⟩
      · unfold TipState.connectWalk
        rw [hs₁]
        exact hwalk
      · rw [hact₂, hact]
        simp [List.append_assoc]
      · rw [hcons₂, hcons]
      · rw [hprod₂, hprod]
        simp [List.map_cons, List.append_assoc]

/-- **BLK-118** (the real composition): on a chain
`pre ++ [fork] ++ suffix`, `reorgTo` disconnects exactly the blocks
above the fork — consuming one stored undo record per block in reverse
height order — and then connects the consecutive candidate suffix,
producing one undo record per block in forward height order. The terminal
active chain is `pre ++ [fork] ++ candSuffix`. -/
@[rule "BLK-118"]
theorem reorgTo_active_consumed_produced {Undo : Type} (s : TipState Undo)
    (fork : BlockRecord Undo) (pre suffix candSuffix : List (BlockRecord Undo))
    (hs : s.active = pre ++ fork :: suffix)
    (hne : ∀ b ∈ suffix, b.height ≠ fork.height)
    (hc : ConsecutiveHeights (fork.height + 1) candSuffix) :
    ∃ s', s.reorgTo fork.height candSuffix = some s' ∧
      s'.active = pre ++ [fork] ++ candSuffix ∧
      s'.consumed = s.consumed ++ suffix.reverse.map BlockRecord.undo ∧
      s'.produced = s.produced ++ candSuffix.map BlockRecord.undo := by
  obtain ⟨hact, hcons, hprod⟩ :=
    disconnectTo_active_consumed s fork pre suffix hs hne
  have htip : (s.disconnectTo fork.height).tipHeight? = some fork.height :=
    tipHeight?_of_active_eq_append _ pre fork hact
  obtain ⟨s', hwalk, hact', hcons', hprod'⟩ :=
    connectWalk_active_produced (s.disconnectTo fork.height) fork.height
      candSuffix htip hc
  refine ⟨s', ?_, ?_, ?_, ?_⟩
  · unfold TipState.reorgTo; exact hwalk
  · rw [hact', hact]
  · rw [hcons', hcons]
  · rw [hprod', hprod]

/-! ## BLK-119/120/121: invalid-block memoization -/

/-- **BLK-119**: ancestor test with fuel (the parent walk of
`InvalidateBlock`'s descendant pruning; fuel = the candidate's height).
Height-keyed: pruning only consults the parent-HEIGHT map. -/
def isDescendantOf (parentOf : Nat → Option Nat) :
    Nat → Nat → Nat → Bool
  | 0, _, _ => false
  | fuel+1, anc, t =>
    decide (anc == t) ||
      match parentOf t with
      | none => false
      | some p => isDescendantOf parentOf fuel anc p

theorem isDescendantOf_refl (parentOf : Nat → Option Nat) :
    ∀ (fuel : Nat) (t : Nat), isDescendantOf parentOf (fuel + 1) t t = true := by
  intro fuel t
  induction fuel with
  | zero => simp [isDescendantOf]
  | succ n ih => simp [isDescendantOf, ih]

/-- **BLK-119**: after a non-mutated failure, every descendant of the
failed block is pruned from the candidate set — a pure filter (the
memoization reading of `InvalidateBlock` + `SetBlockFailed`). -/
@[rule "BLK-119", rule "INV-143"]
def prunedCandidates (parentOf : Nat → Option Nat)
    (failedHeight : Nat) (fuel : Nat) (candidates : List Nat) :
    List Nat :=
  candidates.filter (fun h => !isDescendantOf parentOf fuel failedHeight h)

/-- Filter membership's projection (core-twin of `List.mem_filter`). -/
theorem of_mem_filter {α : Type} {p : α → Bool} {a : α} {l : List α}
    (h : a ∈ l.filter p) : p a = true := by
  induction l with
  | nil => cases h
  | cons x r ih =>
    by_cases hx : p x = true
    · rw [List.filter_cons_of_pos hx] at h
      rcases List.mem_cons.mp h with e | hm
      · subst e; exact hx
      · exact ih hm
    · rw [List.filter_cons_of_neg (by simp [hx])] at h
      exact ih h

/-- The failed block itself is always pruned. -/
theorem failedHash_not_in_pruned (parentOf : Nat → Option Nat)
    (failedHeight : Nat) (fuel : Nat) (candidates : List Nat) :
    ¬(failedHeight ∈ prunedCandidates parentOf failedHeight (fuel + 1) candidates) := by
  intro hm
  unfold prunedCandidates at hm
  have hkeep : (!isDescendantOf parentOf (fuel + 1) failedHeight failedHeight) = true :=
    of_mem_filter (α := Nat)
      (p := fun h => !isDescendantOf parentOf (fuel + 1) failedHeight h)
      (a := failedHeight) (l := candidates) hm
  rw [isDescendantOf_refl] at hkeep
  simp at hkeep

/-- **BLK-120**: a cached-failed hash re-submits as `duplicate-invalid`
— no re-validation (validation.cpp:4205-4219). -/
@[rule "BLK-120", rule "INV-144"]
def submitVerdict (failedCache : ByteArray → Bool) (h : ByteArray) : Option String :=
  if failedCache h then some "duplicate-invalid" else none

theorem submitVerdict_failed (failedCache : ByteArray → Bool) (h : ByteArray)
    (hf : failedCache h = true) : submitVerdict failedCache h = some "duplicate-invalid" := by
  unfold submitVerdict; rw [if_pos hf]

/-- **BLK-121**: `nChainWork`-max over the invalid chain set (the
`best_invalid` bookkeeping — warning/UI only). -/
@[rule "BLK-121"]
def bestInvalidWork (invalid : List (ByteArray × Nat)) : Nat :=
  invalid.foldl (fun acc p => Nat.max acc p.2) 0

theorem foldl_max_ge_init (xs : List (ByteArray × Nat)) (m : Nat) :
    m ≤ xs.foldl (fun acc p => Nat.max acc p.2) m := by
  induction xs generalizing m with
  | nil => exact Nat.le_refl _
  | cons p rest ih =>
    simp only [List.foldl_cons]
    exact Nat.le_trans (Nat.le_max_left m p.2) (ih (Nat.max m p.2))

theorem foldl_max_ge_mem (xs : List (ByteArray × Nat)) (m : Nat) :
    ∀ p ∈ xs, p.2 ≤ xs.foldl (fun acc q => Nat.max acc q.2) m := by
  induction xs generalizing m with
  | nil => intro p hp; cases hp
  | cons q rest ih =>
    intro p hp
    simp only [List.foldl_cons]
    rcases List.mem_cons.mp hp with heq | hrest
    · rw [heq]
      exact Nat.le_trans (Nat.le_max_right m q.2) (foldl_max_ge_init rest (Nat.max m q.2))
    · exact ih (Nat.max m q.2) p hrest

/-- BLK-121's bound: every recorded invalid chain's work is ≤ the max. -/
theorem bestInvalidWork_ge (invalid : List (ByteArray × Nat)) (p : ByteArray × Nat)
    (hp : p ∈ invalid) : p.2 ≤ bestInvalidWork invalid :=
  foldl_max_ge_mem invalid 0 p hp

/-! ## BLK-059: height derivation -/

/-- **BLK-059**: the connect height is the parent's height + 1 — there
is no separate rule (validation.cpp:4092-4093). -/
@[rule "BLK-059"]
def connectHeight (prevHeight : Nat) : Nat := prevHeight + 1

/-- The derivation is literally the successor. -/
theorem connectHeight_succ (h : Nat) : connectHeight h = h + 1 := rfl

/-! ## Axiom pins -/

#print axioms workOf_difficulty_one_pos
#print axioms workOf_pos_of_valid
#print axioms chainWork_append
#print axioms chainWork_snoc
#print axioms mostWork_work_ge
#print axioms switchTip_self
#print axioms switchTip_not_better
#print axioms failedHash_not_in_pruned
#print axioms submitVerdict_failed
#print axioms bestInvalidWork_ge
#print axioms connectHeight_succ

end Bitcoin.Block.Index

-- R07c exact footprint guards.
/-- info: 'Bitcoin.Block.Index.powLimit_eq_mainnet' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Block.Index.powLimit_eq_mainnet
