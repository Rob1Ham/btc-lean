import Bitcoin.Activation.Interface
import Bitcoin.Activation.Bip9

/-!
# Z17 dark-corner audit — BIP9 version-bits masking + lock-in-on-timeout ordering

2026-10-16. Python3 probes:
`probe_c1_condition.py`,
`probe_c2_lockin.py`).

Ground truth: Bitcoin Core @ `cce32b168` (header `git log -1` =
`c50817f Merge bitcoin/bitcoin#36535`); cross-checked against live
`master` `src/versionbits.cpp` / `versionbits_impl.h` fetched 2026-10-16
(STARTED case unchanged: count test :93 precedes timeout test :95).

## C1 — version bits: 0x20000000 top-bits rule + version masking

Core `Condition` (versionbits_impl.h:78-82):
`(nVersion & VERSIONBITS_TOP_MASK) == VERSIONBITS_TOP_BITS && (nVersion & (1<<bit)) != 0`
with `VERSIONBITS_TOP_BITS = 0x20000000` (versionbits.h:21),
`VERSIONBITS_TOP_MASK = 0xE0000000` (versionbits.h:23).
Lean: `Bitcoin.Activation.versionBitsSignals` (Bip9.lean:33-34, BLK-073/INV-122).

VERIFIED here (all `decide`, python-cross-checked on 641,664 (version,bit)
pairs, 0 mismatches):
* the top-bits rule rejects a bit-set version with top bits ≠ `001`
  (`0x70000000` bit 28) — a naive bit-only predicate diverges there, so
  the mask is load-bearing;
* the count wiring is exercised end-to-end: a synthetic period whose
  signal count is a literal fold of `versionBitsSignals` over the period
  blocks drives the real machine to LOCKED_IN — predicate → count →
  threshold (the BLK-073 → BLK-075 seam the tree otherwise leaves
  abstract via the free `Bip9Params.count` field).

## C2 — BIP9 lock-in-on-timeout ordering (versionbits.cpp:83-97 @cce32b168)

Core's STARTED case tests `count >= nThreshold` (:93) BEFORE the timeout
test (:95), so the period whose boundary MTP equals `nTimeout` still
locks in when threshold is reached (the 2017 BIP9 erratum, BLK-077).
Lean: `Bitcoin.Activation.bip9Transition` STARTED arm
(Interface.lean:313-316) + `count_beats_timeout` (Bip9.lean:78-84).

VERIFIED here on a concrete deployment (period 3, threshold 2, start 5,
deadline 8 = boundary 2's height, count from an actual
`versionBitsSignals` fold):
* the real machine returns `lockedIn` at the timeout boundary;
* a pre-erratum (timeout-test-first) twin of the transition returns
  `failed` on the identical input — the ordering is pinned, not
  incidental.
-/

namespace Bitcoin.Proofs.Audit.Z17

open Bitcoin.Activation

/-! ## C1: top-bits rule + masking (BLK-073 / INV-122) -/

/-- VERIFIED vs Core `Condition` (versionbits_impl.h:78-82 @c50817f;
python probe `probe_c1_condition.py`, 641,664 pairs, 0 mismatches). -/
theorem z17_topbits_vectors :
    versionBitsSignals 0x30000000 28 = true ∧     -- top 001 + bit28 → SIGNALS
    versionBitsSignals 0x70000000 28 = false ∧    -- top 011 + bit28 → masked out
    versionBitsSignals 0x00000001 0 = false ∧     -- top 000 + bit0 → pre-BIP9 semantics
    versionBitsSignals 0x22000000 29 = true ∧     -- top 001 + bit29 → SIGNALS
    versionBitsSignals 0x20000002 1 = true := by  -- low bits carry the deployment bit
  decide

/-- The naive "deployment bit set" predicate WITHOUT the top-bits mask —
the exact mistake the rule exists to prevent (a pre-BIP9 style version
like `0x70000000` must not count as a BIP9 signal). -/
def naiveSignals (v : UInt32) (bit : Nat) : Bool := ((v >>> Nat.toUInt32 bit) &&& 1) == 1

/-- The mask is load-bearing: the naive predicate says `true` where Core
(and the tree) say `false`. -/
theorem z17_mask_load_bearing :
    naiveSignals 0x70000000 28 = true ∧ versionBitsSignals 0x70000000 28 = false := by
  decide

/-- Signal count over the `period` blocks ending at boundary height `h`,
folded from the REAL predicate `versionBitsSignals` (Core
versionbits.cpp:87-91 counts exactly those blocks via `Condition`). -/
def sigCount (ver : Nat → UInt32) (bit period h : Nat) : Nat :=
  (List.range period).countP fun i => versionBitsSignals (ver (h - i)) bit

/-- Synthetic chain: blocks 7 and 8 signal bit 1 (`0x20000002`), block 6
does not (`0x20000000`). Deployment: start 5, timeoutPeriods 1 (deadline
= 5 + 1·3 = 8 = `bip9BoundaryHeight P 2`), threshold 2, period 3. -/
def P17 : Bip9Params :=
  { start := 5, timeoutPeriods := 1, threshold := 2, period := 3,
    minActivation := 0, count := sigCount (fun h => if h = 7 ∨ h = 8 then 0x20000002 else 0x20000000) 1 3 }

/-- The BLK-073 → BLK-075 seam: the count is *literally* a
`versionBitsSignals` fold and still drives the real machine to LOCKED_IN
at the deadline boundary (python probe `probe_c2_lockin.py`, Core-order
column). -/
theorem z17_fold_count_locks_in : bip9StateByPeriod P17 2 = .lockedIn := by
  decide

/-- Boundary bookkeeping of the instance above, pinned so the example is
self-describing. -/
theorem z17_P17_geometry :
    bip9BoundaryHeight P17 1 = 5 ∧ bip9BoundaryHeight P17 2 = 8 ∧
    bip9Deadline P17 = 8 ∧ P17.count 8 = 2 ∧ P17.count 5 = 0 := by
  decide

/-! ## C2: lock-in-on-timeout ordering (BLK-077, versionbits.cpp:93 vs :95) -/

/-- Pre-erratum twin of `bip9Transition`: the timeout test FIRST (the
2017 erratum's mistaken order). Identical to the tree's transition on
every non-STARTED arm. -/
def buggyTransition (P : Bip9Params) : ThresholdState → Nat → ThresholdState
  | .started, h =>
      if bip9Deadline P ≤ h then .failed
      else if P.threshold ≤ P.count h then .lockedIn else .started
  | s, h => bip9Transition P s h

/-- DECISIVE (C2): on the same input — STARTED, count 2 ≥ threshold 2 at
boundary height 8 whose MTP equals the timeout — Core's order locks in
… -/
theorem z17_core_order_locks_in : bip9Transition P17 .started 8 = .lockedIn := by
  decide

/-- … while the pre-erratum order FAILS the deployment. The two orderings
are observably different exactly at the timeout boundary. -/
theorem z17_buggy_order_fails : buggyTransition P17 .started 8 = .failed := by
  decide

/-- Full-machine corollary of `count_beats_timeout` (Bip9.lean:78-84,
BLK-077): the state at the timeout boundary itself is LOCKED_IN, hence
(python probe, h=11 row) the deployment goes ACTIVE one period later —
the 2017 erratum behavior end-to-end. -/
theorem z17_lockin_at_timeout_boundary : bip9StateByPeriod P17 2 = .lockedIn := by
  exact z17_fold_count_locks_in

end Bitcoin.Proofs.Audit.Z17
