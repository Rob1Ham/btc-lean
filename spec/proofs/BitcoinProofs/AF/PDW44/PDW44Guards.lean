import BitcoinProofs.AF.PDW44.PDW44

/-! # PDW44Guards — axiom pins (charter trio check, TOP-216..220).

D-SIGOPS row faces. Every pin ⊆ [propext, Classical.choice,
Quot.sound]; zero `sorryAx`. 11/11 `#print axioms` captured. -/

/-- info: 'BitcoinProofs.AF.PDW44.sigOpCost_legacy_scale' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.sigOpCost_legacy_scale

/-- info: 'BitcoinProofs.AF.PDW44.sigOpCost_legacy_step' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.sigOpCost_legacy_step

/-- info: 'BitcoinProofs.AF.PDW44.sigOpCost_p2sh_step' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.sigOpCost_p2sh_step

/-- info: 'BitcoinProofs.AF.PDW44.sigOpCost_p2sh_eq_legacy_scale' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.sigOpCost_p2sh_eq_legacy_scale

/-- info: 'BitcoinProofs.AF.PDW44.p2shWitnessSigOps_p2wpkh' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.p2shWitnessSigOps_p2wpkh

/-- info: 'BitcoinProofs.AF.PDW44.p2shWitnessSigOps_unparsable' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.p2shWitnessSigOps_unparsable

/-- info: 'BitcoinProofs.AF.PDW44.witnessSigOps_v0_20' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.witnessSigOps_v0_20

/-- info: 'BitcoinProofs.AF.PDW44.witnessSigOps_v0_32' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.witnessSigOps_v0_32

/-- info: 'BitcoinProofs.AF.PDW44.witnessSigOps_v0_other' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.witnessSigOps_v0_other

/-- info: 'BitcoinProofs.AF.PDW44.witnessSigOps_v1_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.witnessSigOps_v1_zero

/-- info: 'BitcoinProofs.AF.PDW44.sigOpCost_taproot_input_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW44.sigOpCost_taproot_input_zero
