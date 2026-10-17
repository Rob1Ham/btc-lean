import BitcoinProofs.AF.PDW26.PDW26
import BitcoinProofs.AF.PDW26.PDW26Wire

/-! # PDW26Guards — axiom pins (charter trio check), 17/17.

Every pin ⊆ [propext, Classical.choice, Quot.sound] = the charter
trio (DECISIONS / RC-suite convention); zero `sorryAx` (no sorry in
any of the three modules; guards = the PDW12-g3/PDW13Guards/
PDW16Guards convention).

The full-trio pins on the `versionBitsSignals` family = the core
def's own UInt32 `&&&`/`==`/`>>>` decide machinery (the core
`versionBitsSignals` :33 and its in-core `_vectors` :40 decide-pins
carry exactly the same trio — my AF theorems over the def inherit
it; the [p] `not_in_mainnet` = `List.Mem` propext; the [p,Q] pair =
`omega` on the ite-arms). The BIP9-machine reject-lane
`bip9_below_threshold_not_lockedIn` (by_cases + nomatch) and the
activates half (ite_eq_left) = ZERO-axiom; the SWT-036 pins are
rfl×5 / decide = ZERO-axiom (the 5-field value equality) — the
strongest possible axiom tier (PDW16's "10 zero-axiom" class).

## Core carriers (B-verified, probe1 texts verbatim) -/

/-- info: 'Bitcoin.Activation.versionBitsSignals' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.versionBitsSignals

/-- info: 'Bitcoin.Activation.versionBitsSignals_vectors' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.versionBitsSignals_vectors

/-- info: 'Bitcoin.Activation.bip9_threshold_locks_in' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_threshold_locks_in

/-- info: 'Bitcoin.Activation.bip9_timeout_fails' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_timeout_fails

/-- info: 'Bitcoin.Activation.bip9_min_activation' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Activation.bip9_min_activation

/-- info: 'Bitcoin.Activation.segwitBip9Deployment' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.segwitBip9Deployment

/-- info: 'Bitcoin.Activation.segwitBip9Deployment_values' does not depend on any axioms -/
#guard_msgs in #print axioms Bitcoin.Activation.segwitBip9Deployment_values

/-! ## PDW26.lean (the BIP9-machine companions) -/

/-- info: 'BitcoinProofs.AF.PDW26.bip9_below_threshold_not_lockedIn' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.bip9_below_threshold_not_lockedIn

/-- info: 'BitcoinProofs.AF.PDW26.bip9_not_yet_timeout_stays_started' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.bip9_not_yet_timeout_stays_started

/-- info: 'BitcoinProofs.AF.PDW26.bip9_min_activation_activates' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.bip9_min_activation_activates

/-! ## PDW26Wire.lean (the BLK-073 / SWT-036 companions) -/

/-- info: 'BitcoinProofs.AF.PDW26.versionBitsSignals_eq_true' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.versionBitsSignals_eq_true

/-- info: 'BitcoinProofs.AF.PDW26.versionBitsSignals_topBits_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.versionBitsSignals_topBits_reject

/-- info: 'BitcoinProofs.AF.PDW26.versionBitsSignals_bitUnset_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.versionBitsSignals_bitUnset_reject

/-- info: 'BitcoinProofs.AF.PDW26.segwitBip9Deployment_values_pdw26' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.segwitBip9Deployment_values_pdw26

/-- info: 'BitcoinProofs.AF.PDW26.segwitBip9Deployment_not_in_mainnet' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.segwitBip9Deployment_not_in_mainnet

/-- info: 'BitcoinProofs.AF.PDW26.segwitBip9Deployment_window' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.segwitBip9Deployment_window

/-- info: 'BitcoinProofs.AF.PDW26.segwitBip9Deployment_not_sentinel' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW26.segwitBip9Deployment_not_sentinel
