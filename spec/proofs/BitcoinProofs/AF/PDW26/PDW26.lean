import Bitcoin.Activation.Bip9

/-! # PDW26.lean — RC22, items TOP-126..130
(PDW26, RC22, 2026-10-17).

The D-BIP9 tag-stacked pocket of `Bitcoin.Activation.Bip9.lean`
("implemented + proved 2026-10-16"; claim v1 = commit ba6c71b):

* **INV-123** `bip9_threshold_locks_in` (Bip9.lean:51, versionbits.cpp:
  83-98) — the core tag-twin of PROVEN row BLK-075 (F-PDW26-001:
  the PD02-22-census-blind class). Core = the lock-in →-direction;
  here the reject-lane `bip9_below_threshold_not_lockedIn`
  (count < threshold ⇒ never LOCKED_IN, fail-closed on the :93-94
  count test).
* **INV-124** `bip9_timeout_fails` (Bip9.lean:63, versionbits.cpp:
  95-97) — tag-twin of PROVEN BLK-076. Core = the fail →-direction;
  here `bip9_not_yet_timeout_stays_started` (below threshold AND
  before the deadline ⇒ the deployment STAYS STARTED — the :95-97
  timeout test needs `bip9Deadline ≤ h`, no early fail).
* **INV-125** `bip9_min_activation` (Bip9.lean:89, versionbits.cpp:
  100-105) — tag-twin of PROVEN BLK-078. Core = the
  persists-below-half (LOCKED_IN stays LOCKED_IN while the closing
  boundary is below min_activation_height); here the positive half
  `bip9_min_activation_activates` (closing boundary ≥ minActivation
  ⇒ ACTIVE) = the two-halves row face.
* **BLK-073** `versionBitsSignals` (Bip9.lean:33) + **SWT-036**
  `segwitBip9Deployment` (Bip9.lean:156) — def-tagged-on-target rows;
  the def-mirror / wire-law / value-pin companions live in
  `PDW26Wire.lean` (same dir).

Route B (PDW11 21f0745 / PDW15 0fa324e THM-on-target pattern): zero
core writes, all five `@[rule]` tags already sit on the core
lean_target carriers (INV-123/124/125 tags stacked on the sorry-free
core theorems Bip9.lean:51/:63/:89 alongside their PROVEN BLK-twin
rows BLK-075/076/078) — NO AF tags, no tag moves (PDW15-22-class;
rule_crosscheck stays green as-is), pins ⊆ the charter trio
[propext, Classical.choice, Quot.sound] (PDW26Guards.lean), zero
sorry/sorryAx. The module is deliberately NOT imported by the
BitcoinProofs root (PDW12-AF isolation), own-target direct-lean
built, outside `core/**`. Non-goals: the pocket twins {INV-122
(BLK-073's own stacked-twin row), BLK-081 (mainnetTestdummy
dormancy)} + the post-100 next-deep register,
frozen BIP30R-5/CORPUS2/E14/EDGE/L2/PDW17-20 paths. -/

namespace BitcoinProofs.AF.PDW26

/-! ## INV-123 — `bip9_threshold_locks_in` (V:versionbits.cpp:83-98):
STARTED → LOCKED_IN iff `count ≥ threshold` at the closing period
boundary (the :93-94 count test).

The reject-lane (fail-closed): if the next period is NOT started
(`k+1` = LOCKED_IN), the count test must have passed — contrapositive
shape = count < threshold ⇒ the machine never reaches LOCKED_IN
(either still STARTED, or FAILED once past the deadline). -/

theorem bip9_below_threshold_not_lockedIn
    (P : Bitcoin.Activation.Bip9Params) (k : Nat)
    (hprev : Bitcoin.Activation.bip9StateByPeriod P k = .started)
    (hc : Bitcoin.Activation.bip9StateByPeriod P (k + 1) = .lockedIn) :
    P.threshold ≤ P.count (Bitcoin.Activation.bip9BoundaryHeight P (k + 1)) := by
  by_cases hle : P.threshold ≤ P.count (Bitcoin.Activation.bip9BoundaryHeight P (k + 1))
  · exact hle
  · exfalso
    simp only [Bitcoin.Activation.bip9StateByPeriod] at hc
    by_cases hnb : Bitcoin.Activation.bip9BoundaryHeight P (k + 1) < P.start
    · rw [ite_eq_left hnb] at hc; exact nomatch hc
    · rw [ite_eq_right hnb, hprev] at hc
      simp only [Bitcoin.Activation.bip9Transition] at hc
      rw [ite_eq_right hle] at hc
      by_cases hto : Bitcoin.Activation.bip9Deadline P
          ≤ Bitcoin.Activation.bip9BoundaryHeight P (k + 1)
      · rw [ite_eq_left hto] at hc; exact nomatch hc
      · rw [ite_eq_right hto] at hc; exact nomatch hc

/-! ## INV-124 — `bip9_timeout_fails` (V:versionbits.cpp:95-97):
STARTED → FAILED needs BOTH `count < threshold` (the :93 test fails)
AND `bip9Deadline ≤ boundary` (the :95 timeout test passes).

The no-early-fail lane: below threshold AND strictly before the
deadline ⇒ the next state is still STARTED (no early FAILED, no
early LOCKED_IN). -/

theorem bip9_not_yet_timeout_stays_started
    (P : Bitcoin.Activation.Bip9Params) (k : Nat)
    (hprev : Bitcoin.Activation.bip9StateByPeriod P k = .started)
    (hnb : ¬ (Bitcoin.Activation.bip9BoundaryHeight P (k + 1) < P.start))
    (hc : P.count (Bitcoin.Activation.bip9BoundaryHeight P (k + 1)) < P.threshold)
    (hto : ¬ (Bitcoin.Activation.bip9Deadline P
          ≤ Bitcoin.Activation.bip9BoundaryHeight P (k + 1))) :
    Bitcoin.Activation.bip9StateByPeriod P (k + 1) = .started := by
  simp only [Bitcoin.Activation.bip9StateByPeriod]
  rw [ite_eq_right hnb, hprev]
  simp only [Bitcoin.Activation.bip9Transition]
  rw [ite_eq_right (by omega : ¬ (P.threshold ≤
      P.count (Bitcoin.Activation.bip9BoundaryHeight P (k + 1)))), ite_eq_right hto]

/-! ## INV-125 — `bip9_min_activation` (V:versionbits.cpp:100-105):
LOCKED_IN → ACTIVE exactly when the closing boundary `+ 1` (the first
block of the next period) reaches `minActivation`.

Core `bip9_min_activation` (Bip9.lean:89) = the persists-below half
(`boundary + 1 < minActivation` ⇒ still LOCKED_IN); here the positive
half — `boundary + 1 ≥ minActivation` ⇒ ACTIVE = the two-halves row
face (the `lockedIn` transition arm of `bip9Transition` is exactly
`if h + 1 ≥ minActivation then active else lockedIn`). -/

theorem bip9_min_activation_activates
    (P : Bitcoin.Activation.Bip9Params) (k : Nat)
    (hprev : Bitcoin.Activation.bip9StateByPeriod P k = .lockedIn)
    (hnb : ¬ (Bitcoin.Activation.bip9BoundaryHeight P (k + 1) < P.start))
    (hmin : P.minActivation
          ≤ Bitcoin.Activation.bip9BoundaryHeight P (k + 1) + 1) :
    Bitcoin.Activation.bip9StateByPeriod P (k + 1) = .active := by
  simp only [Bitcoin.Activation.bip9StateByPeriod]
  rw [ite_eq_right hnb, hprev]
  simp only [Bitcoin.Activation.bip9Transition]
  rw [ite_eq_left (by omega : Bitcoin.Activation.bip9BoundaryHeight P (k + 1) + 1
      ≥ P.minActivation)]

end BitcoinProofs.AF.PDW26
