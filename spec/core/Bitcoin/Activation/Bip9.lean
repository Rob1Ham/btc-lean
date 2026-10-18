import Bitcoin.Activation.Interface

/-!
# Bitcoin.Activation.Bip9 — BIP9 signalling + mainnet deployment table

## Interface contract

Core counterpart files: src/versionbits.cpp:79-131 (Condition,
GetStateFor), src/kernel/chainparams.cpp:128-134 (mainnet deployment
table), BIP9 (+ the 2017 lock-in-on-timeout erratum)
Status: implemented + proved 2026-10-16.

The state MACHINE itself lives in `Bitcoin.Activation.Interface`
(`bip9State`, `bip9Transition`, `lockin_then_active`); this module adds
the miner-facing half: the version-bit signal predicate, the
threshold/timeout ordering lemmas with Core's load-bearing test order
(count test BEFORE timeout test — versionbits.cpp:93 vs :95), the
min_activation_height gate, and the mainnet deployment table (exactly
one entry, testdummy, dormant forever).
-/

namespace Bitcoin.Activation

/-! ## Version-bit signal predicate (BLK-073) -/

/-- BIP9 `Condition()` (versionbits.cpp:79-82 @master, fetched
2026-10-16): a block signals for a deployment using bit `bit` iff the
top three version bits are `001` AND bit `bit` is set. `bit` is a plain
`Nat`; Core's deployment table guarantees `bit < 32`. -/
@[rule "BLK-073", rule "INV-122"] def versionBitsSignals (v : UInt32) (bit : Nat) : Bool :=
  (v &&& 0xE0000000) == 0x20000000 && ((v >>> Nat.toUInt32 bit) &&& 1) == 1

/-- Signal-predicate vectors: `001`-prefixed versions signal; versions
with top bits `000`/`011`/`101` do not; an unset bit does not signal. -/
theorem versionBitsSignals_vectors :
    versionBitsSignals 0x20000001 0 = true ∧
    versionBitsSignals 0x20000000 0 = false ∧
    versionBitsSignals 0x10000001 0 = false ∧
    versionBitsSignals 0xA0000001 0 = false ∧
    versionBitsSignals 0x22000000 29 = true ∧
    versionBitsSignals 0x20000000 28 = false := by
  decide

/-! ## Transition lemmas at period boundaries (versionbits.cpp:83-124) -/

/-- BLK-075: from STARTED, `count ≥ threshold` at the closing boundary
locks the deployment in — versionbits.cpp:93-94. -/
@[rule "BLK-075", rule "INV-123"] theorem bip9_threshold_locks_in (P : Bip9Params) (k : Nat)
    (hnb : ¬ (bip9BoundaryHeight P (k + 1) < P.start))
    (hprev : bip9StateByPeriod P k = .started)
    (hcount : P.threshold ≤ P.count (bip9BoundaryHeight P (k + 1))) :
    bip9StateByPeriod P (k + 1) = .lockedIn := by
  simp only [bip9StateByPeriod]
  rw [if_neg hnb, hprev]
  simp only [bip9Transition]
  rw [if_pos hcount]

/-- BLK-076: from STARTED, `count < threshold` at/after the timeout
deadline fails the deployment — versionbits.cpp:95-97. -/
@[rule "BLK-076", rule "INV-124"] theorem bip9_timeout_fails (P : Bip9Params) (k : Nat)
    (hnb : ¬ (bip9BoundaryHeight P (k + 1) < P.start))
    (hprev : bip9StateByPeriod P k = .started)
    (hcount : P.count (bip9BoundaryHeight P (k + 1)) < P.threshold)
    (hto : bip9Deadline P ≤ bip9BoundaryHeight P (k + 1)) :
    bip9StateByPeriod P (k + 1) = .failed := by
  simp only [bip9StateByPeriod]
  rw [if_neg hnb, hprev]
  simp only [bip9Transition]
  rw [if_neg (by omega : ¬ (P.threshold ≤ P.count (bip9BoundaryHeight P (k + 1)))),
      if_pos hto]

/-- BLK-077 (the 2017 BIP9 erratum): the count test PRECEDES the timeout
test (versionbits.cpp:93 before :95), so a deployment that reaches
threshold in the period ending exactly at its timeout still locks in. -/
@[rule "BLK-077"] theorem count_beats_timeout (P : Bip9Params) (k : Nat)
    (hnb : ¬ (bip9BoundaryHeight P (k + 1) < P.start))
    (hprev : bip9StateByPeriod P k = .started)
    (hcount : P.threshold ≤ P.count (bip9BoundaryHeight P (k + 1)))
    (_hat : bip9BoundaryHeight P (k + 1) = bip9Deadline P) :
    bip9StateByPeriod P (k + 1) = .lockedIn :=
  bip9_threshold_locks_in P k hnb hprev hcount

/-- BLK-078: LOCKED_IN → ACTIVE only when the closing boundary is at or
after min_activation_height; below it the deployment stays LOCKED_IN
(versionbits.cpp:100-104). -/
@[rule "BLK-078", rule "INV-125"] theorem bip9_min_activation (P : Bip9Params) (h : Nat)
    (hP : 0 < P.period) (hk : P.period ≤ h + 1)
    (hlocked : bip9State P h = .lockedIn)
    (hmin : bip9BoundaryHeight P ((h + 1) / P.period) + 1 < P.minActivation) :
    bip9State P (h + P.period) = .lockedIn := by
  have hP0 : P.period ≠ 0 := by omega
  have hk1 : 0 < (h + 1) / P.period := Nat.div_pos hk hP
  have e1' : bip9StateByPeriod P ((h + 1) / P.period - 1) = .lockedIn := by
    rw [← bip9State_eq P hP0 h hk]; exact hlocked
  have hbstart : ¬ (bip9BoundaryHeight P ((h + 1) / P.period) < P.start) := by
    have hnb := bip9StateByPeriod_lockIn_atStart P ((h + 1) / P.period - 1) e1'
    have hmono := bip9BoundaryHeight_succ P ((h + 1) / P.period - 1)
    rw [show ((h + 1) / P.period - 1) + 1 = (h + 1) / P.period from by omega] at hmono
    omega
  rw [bip9State_next_period P hP h hk, if_neg hbstart, hlocked]
  simp only [bip9Transition]
  rw [if_neg (by omega : ¬ (bip9BoundaryHeight P ((h + 1) / P.period) + 1 ≥ P.minActivation))]

/-- BLK-078 / INV-125 (both directions): from LOCKED_IN at a period
boundary, the next period is ACTIVE iff the closing boundary `+ 1`
(the first block of the next period) reaches `min_activation_height`.
This is the `LOCKED_IN` arm of `bip9Transition` verbatim
(versionbits.cpp:100-105 @cce32b168):
`if (pindexPrev->nHeight + 1 >= min_activation_height)
stateNext = ThresholdState::ACTIVE;`. -/
@[rule "BLK-078", rule "INV-125"]
theorem bip9_lockedIn_active_iff (P : Bip9Params) (k : Nat)
    (hnb : ¬ (bip9BoundaryHeight P (k + 1) < P.start))
    (hprev : bip9StateByPeriod P k = .lockedIn) :
    bip9StateByPeriod P (k + 1) = .active ↔
      P.minActivation ≤ bip9BoundaryHeight P (k + 1) + 1 := by
  simp only [bip9StateByPeriod]
  rw [if_neg hnb, hprev]
  simp only [bip9Transition]
  by_cases h : P.minActivation ≤ bip9BoundaryHeight P (k + 1) + 1
  · rw [if_pos (by omega :
      bip9BoundaryHeight P (k + 1) + 1 ≥ P.minActivation)]
    simp [h]
  · rw [if_neg (by omega : ¬
      bip9BoundaryHeight P (k + 1) + 1 ≥ P.minActivation)]
    simp [h]

/-- BLK-075 / BLK-076 (single transition law from STARTED).  The row
precondition the two summaries omit is `state = STARTED`; from it the
next boundary is LOCKED_IN on `count ≥ threshold`, FAILED only on
`count < threshold ∧ deadline ≤ boundary`, and otherwise still
STARTED — Core's test order (versionbits.cpp:83-98 @cce32b168) with the
count test at :93 before the timeout test at :95. -/
@[rule "BLK-075", rule "BLK-076"]
theorem bip9_started_next (P : Bip9Params) (k : Nat)
    (hnb : ¬ (bip9BoundaryHeight P (k + 1) < P.start))
    (hprev : bip9StateByPeriod P k = .started) :
    bip9StateByPeriod P (k + 1) =
      (if P.threshold ≤ P.count (bip9BoundaryHeight P (k + 1)) then .lockedIn
       else if bip9Deadline P ≤ bip9BoundaryHeight P (k + 1) then .failed
       else .started) := by
  simp only [bip9StateByPeriod]
  rw [if_neg hnb, hprev]
  rfl

/-- BLK-080: the state at a null parent is DEFINED for every deployment
and every parameters instance — Core's cache walk assigns
`cache[nullptr] = ThresholdState::DEFINED` before consulting any
start/timeout field (versionbits.cpp:52-56 @cce32b168):

```
while (!cache.contains(pindexPrev)) {
    if (pindexPrev == nullptr) {
        // The genesis block is by definition defined.
        cache[pindexPrev] = ThresholdState::DEFINED;
        break;
    }
```
-/
def bip9ParentState (P : Bip9Params) : Option Nat → ThresholdState
  | none => .defined
  | some h => bip9State P h

/-- BLK-080: the null-parent base case of the BIP9 cache walk. -/
@[rule "BLK-080"] theorem bip9_null_parent_defined (P : Bip9Params) :
    bip9ParentState P none = .defined := rfl

/-- BLK-080 (universal form): every deployment's null-parent state is
DEFINED, independent of `start`, `timeout`, `threshold`, `period`,
`minActivation` and the count oracle. -/
theorem bip9_null_parent_defined_all :
    ∀ P : Bip9Params, bip9ParentState P none = .defined :=
  fun _ => rfl

/-- BLK-080: before the start boundary every state is DEFINED — Core
assigns DEFINED without a transition when the period ends before
`nStartTime` (versionbits.cpp:57-63; the null-ancestor base at genesis is
the `k = 0` instance). -/
@[rule "BLK-080"] theorem bip9_genesis_defined (P : Bip9Params) (k : Nat)
    (hb : bip9BoundaryHeight P k < P.start) :
    bip9StateByPeriod P k = .defined := by
  cases k with
  | zero => rw [bip9StateByPeriod, if_pos hb]
  | succ k' => rw [bip9StateByPeriod, if_pos hb]

/-! ## Mainnet deployment table (BLK-081) -/

/-- A BIP9 deployment row (Consensus::BIP9Deployment + the params-table
fields). Sentinel start/timeout encodings as in `Interface`
(`BIP9_ALWAYS_ACTIVE` = 2³²−1, `BIP9_NEVER_ACTIVE` = 2³²−2). -/
structure Bip9Deployment where
  bit : Nat
  start : UInt32
  timeout : UInt32
  minActivation : UInt32 := 0
  threshold : Nat
  period : Nat

/-- BLK-081: mainnet's only BIP9 deployment entry
(kernel/chainparams.cpp:128-134, also confirmed @cce32b168): testdummy,
bit 28, NEVER_ACTIVE start (−2), NO_TIMEOUT (int64-max → the unreachable
height 2³²−1 in our abstraction), min_activation_height 0, threshold
1815 (90%), period 2016. -/
@[rule "BLK-081"] def mainnetTestdummy : Bip9Deployment :=
  { bit := 28, start := BIP9_NEVER_ACTIVE, timeout := BIP9_ALWAYS_ACTIVE,
    minActivation := 0, threshold := 1815, period := 2016 }

/-- The mainnet deployment table: exactly one (dormant) entry. -/
def mainnetDeployments : List Bip9Deployment := [mainnetTestdummy]

/-! ### SWT-036: the historical segwit BIP9 deployment (BIP9 "segwit")

SegWit itself deployed through BIP9 (name `"segwit"`, **bit 1**, start
2016-11-15 = 1483228800, timeout 2017-11-14 = 1510708800, threshold 1916
= 95%, period 2016) and LOCKED_IN at height 475,680 — ACTIVE well before
the work date, so the LIVE rule path is the buried-height lane
(`mainnetParams.segwitHeight = 481824`, SWT-035) and the params table
@`cce32b168` carries only testdummy (`mainnetDeployments`). This pinned
record is the historical row (bip-0141.mediawiki:304-308, BIP9
deployment params); it is deliberately NOT in `mainnetDeployments` so
the dormancy theorems above stay faithful to the current table. -/

/-- Historical mainnet segwit BIP9 deployment (bit 1, 2016-11-15 start). -/
@[rule "SWT-036"] def segwitBip9Deployment : Bip9Deployment :=
  { bit := 1, start := 1483228800, timeout := 1510708800,
    minActivation := 0, threshold := 1916, period := 2016 }

/-- SWT-036 value pin: bit 1, the BIP9 parameters of the segwit rollout. -/
theorem segwitBip9Deployment_values :
    segwitBip9Deployment.bit = 1 ∧
    segwitBip9Deployment.start = 1483228800 ∧
    segwitBip9Deployment.timeout = 1510708800 ∧
    segwitBip9Deployment.threshold = 1916 ∧
    segwitBip9Deployment.period = 2016 :=
  ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- SWT-036 (corrected historical deployment): BIP141/BIP147 give the
segwit BIP9 window as start `1479168000` = 2016-11-15 00:00 UTC and
timeout `1510704000` = 2017-11-15 00:00 UTC.  `segwitBip9Deployment`
above retains the old `1483228800`/`1510708800` values (definitions are
never rewritten in this remediation); this is the faithful record the
row text describes. -/
@[rule "SWT-036"] def segwitBip9DeploymentHistorical : Bip9Deployment :=
  { bit := 1, start := 1479168000, timeout := 1510704000,
    minActivation := 0, threshold := 1916, period := 2016 }

/-- The BIP9 deployment name string.  `Bip9Deployment` deliberately has
no name field (the live table is keyed by the `DeploymentPos` enum); the
historical BIP141 name is recorded separately so the row's name claim is
not silently dropped. -/
def segwitBip9Name : String := "segwit"

/-- SWT-036 value pin (corrected): name `segwit`, bit 1, start
1479168000 (2016-11-15), timeout 1510704000 (2017-11-15), threshold
1916 (95%), period 2016. -/
@[rule "SWT-036"]
theorem segwitBip9DeploymentHistorical_values :
    segwitBip9Name = "segwit" ∧
    segwitBip9DeploymentHistorical.bit = 1 ∧
    segwitBip9DeploymentHistorical.start = 1479168000 ∧
    segwitBip9DeploymentHistorical.timeout = 1510704000 ∧
    segwitBip9DeploymentHistorical.threshold = 1916 ∧
    segwitBip9DeploymentHistorical.period = 2016 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- SWT-036 divergence witness: the old pinned values are not the BIP141
window (`1483228800` = 2017-01-01 UTC, `1510708800` = 2017-11-15
01:20 UTC), so the corrected record cannot be identified with the old
definition without changing its meaning. -/
theorem segwitBip9Deployment_start_divergence :
    segwitBip9Deployment.start = 1483228800 ∧
      segwitBip9DeploymentHistorical.start = 1479168000 ∧
      (1483228800 : Nat) ≠ 1479168000 :=
  ⟨rfl, rfl, by decide⟩

theorem mainnet_deployments_length : mainnetDeployments.length = 1 := rfl

/-- Dormancy: EVERY mainnet deployment is FAILED at EVERY height, for
every count function — the single entry is NEVER_ACTIVE
(versionbits.cpp:40-42 short-circuits before any state machine). -/
theorem mainnet_deployments_dormant (count : UInt32 → UInt32) (h : UInt32)
    (d : Bip9Deployment) (hd : d ∈ mainnetDeployments) :
    thresholdState d.start d.timeout d.threshold d.period count h = .failed := by
  simp [mainnetDeployments] at hd
  subst hd
  exact bip9_never_active _ _ _ _ h

/-- BLK-081 (dormancy corollary): as of the work date (2026) mainnet has
exactly one BIP9 deployment and it can never activate — no future soft
fork is in the signalling pipeline until Core's table grows. -/
theorem mainnet_2026_exactly_one_dormant (count : UInt32 → UInt32) (h : UInt32) :
    mainnetDeployments.length = 1 ∧
    ∀ d ∈ mainnetDeployments,
      thresholdState d.start d.timeout d.threshold d.period count h = .failed :=
  ⟨rfl, fun d hd => mainnet_deployments_dormant count h d hd⟩

end Bitcoin.Activation
