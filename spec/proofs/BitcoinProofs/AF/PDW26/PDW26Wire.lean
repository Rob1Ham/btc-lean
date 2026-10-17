import Bitcoin.Activation.Bip9

/-! # PDW26Wire.lean — BLK-073 + SWT-036 companions (PDW26, RC22).

The wire/pins half of the D-BIP9 pocket (claim ba6c71b; the
BIP9-machine half = `PDW26.lean`):

* **BLK-073** `versionBitsSignals` (Bip9.lean:33) — def-tagged row
  (stacked with INV-122) + in-core decide-pins
  `versionBitsSignals_vectors` (:40). Here: the P2 def-mirror
  (`_eq_true`, the gate IS the Core conjunction versionbits_impl.h:
  79-82) + the two reject-lanes (top-bits mask fail / deployment-bit
  unset — `_vectors` cases 3/4/5 by general proof).
* **SWT-036** `segwitBip9Deployment` (Bip9.lean:156) — def-tagged row
  + in-core 5-field value-pins `segwitBip9Deployment_values` (:164,
  rfl×5). Here: the pins restated on the exact full name
  `Bitcoin.Activation.segwitBip9Deployment` (F-PDW26-002: the row's
  `lean_target` `Bitcoin.Activation.Bip9.segwitBip9Deployment` is a
  TPR-032/SCR-101-class module-path-vs-namespace drift — the decl
  lives in `namespace Bitcoin.Activation`, Bip9.lean:24; fixed in the
  flip) + the row-note face `segwitBip9Deployment_not_in_mainnet`
  ("deliberately NOT in mainnetDeployments", the @cce32b168
  buried-height faithfulness) + the window/anti-sentinel pins
  (bit 1 start 1483228800 < timeout 1510708800 = the 2016-11-15 →
  2017-11-14 signalling window; start ≠ the ALWAYS/NEVER sentinels =
  the historical NOT-dormant record).

Route B, zero core writes, NO AF tags (both rows' `@[rule]` tags
already sit on the core lean_target defs; the in-core `_vectors` /
`_values` pins ride the core), pins ⊆ the charter trio
(PDW26Guards.lean), zero sorry/sorryAx. -/

namespace BitcoinProofs.AF.PDW26

/-! ## BLK-073 — `versionBitsSignals` (versionbits_impl.h:79-82):
`(v &&& 0xE0000000) == 0x20000000 && ((v >>> bit) &&& 1) == 1`. -/

/-- P2 def-mirror: the gate = the Core top-bits test AND the
deployment-bit test (the `&&` = `Bool.and`). -/
theorem versionBitsSignals_eq_true (v : UInt32) (bit : Nat) :
    Bitcoin.Activation.versionBitsSignals v bit = true ↔
      ((v &&& 0xE0000000) == 0x20000000) ∧
      ((v >>> Nat.toUInt32 bit) &&& 1) == 1 := by
  simp [Bitcoin.Activation.versionBitsSignals]

/-- Reject-lane 1: masked version ≠ `001·····` ⇒ never signals
(the `_vectors` cases 3/4/5 `000`/`011`/`101` by general proof). -/
theorem versionBitsSignals_topBits_reject (v : UInt32) (bit : Nat)
    (h : (v &&& 0xE0000000) ≠ 0x20000000) :
    Bitcoin.Activation.versionBitsSignals v bit = false := by
  simp [Bitcoin.Activation.versionBitsSignals, h]

/-- Reject-lane 2: deployment bit not set ⇒ never signals (the
`_vectors` cases 2/6). -/
theorem versionBitsSignals_bitUnset_reject (v : UInt32) (bit : Nat)
    (h : ((v >>> Nat.toUInt32 bit) &&& 1) ≠ 1) :
    Bitcoin.Activation.versionBitsSignals v bit = false := by
  simp [Bitcoin.Activation.versionBitsSignals, h]

/-! ## SWT-036 — `segwitBip9Deployment` (bip-0141:304-308):
bit 1, start 1483228800 (2016-11-15), timeout 1510708800
(2017-11-14), threshold 1916 (95%), period 2016. -/

/-- The 5-field value-pins (≡ in-core `segwitBip9Deployment_values`
:164, rfl×5), restated on the exact full name (F-PDW26-002). -/
theorem segwitBip9Deployment_values_pdw26 :
    Bitcoin.Activation.segwitBip9Deployment.bit = 1 ∧
    Bitcoin.Activation.segwitBip9Deployment.start = 1483228800 ∧
    Bitcoin.Activation.segwitBip9Deployment.timeout = 1510708800 ∧
    Bitcoin.Activation.segwitBip9Deployment.threshold = 1916 ∧
    Bitcoin.Activation.segwitBip9Deployment.period = 2016 :=
  ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- The row-note face: the historical record is deliberately NOT in
`mainnetDeployments` (the @cce32b168 params table carries only
testdummy; the live path = the buried lane SWT-035). -/
theorem segwitBip9Deployment_not_in_mainnet :
    ¬ (Bitcoin.Activation.segwitBip9Deployment ∈
        Bitcoin.Activation.mainnetDeployments) := by
  intro h
  exact nomatch h

/-- The signalling window: start 2016-11-15 < timeout 2017-11-14. -/
theorem segwitBip9Deployment_window :
    Bitcoin.Activation.segwitBip9Deployment.start
      < Bitcoin.Activation.segwitBip9Deployment.timeout := by
  decide

/-- Anti-sentinel: the historical start is a real height, not the
ALWAYS_ACTIVE / NEVER_ACTIVE encodings (the NOT-dormant record). -/
theorem segwitBip9Deployment_not_sentinel :
    Bitcoin.Activation.segwitBip9Deployment.start
        ≠ Bitcoin.Activation.BIP9_ALWAYS_ACTIVE ∧
    Bitcoin.Activation.segwitBip9Deployment.start
        ≠ Bitcoin.Activation.BIP9_NEVER_ACTIVE := by
  decide

end BitcoinProofs.AF.PDW26
