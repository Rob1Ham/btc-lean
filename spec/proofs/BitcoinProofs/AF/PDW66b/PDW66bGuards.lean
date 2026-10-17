import BitcoinProofs.AF.PDW66b.PDW66b
import BitcoinProofs.AF.PDW66b.PDW66bCms

/-! # PDW66bGuards — axiom pins for TOP-351..355 second lane. -/

/-- info: 'BitcoinProofs.AF.PDW66b.checkOutputs_ok_bounds' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW66b.checkOutputs_ok_bounds

/-- info: 'BitcoinProofs.AF.PDW66b.isCoinBase_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW66b.isCoinBase_iff

/-- info: 'BitcoinProofs.AF.PDW66b.executeWitnessScript_item_too_large' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW66b.executeWitnessScript_item_too_large

/-- info: 'BitcoinProofs.AF.PDW66b.cms_nulldummy_nonempty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW66b.cms_nulldummy_nonempty

/-- info: 'BitcoinProofs.AF.PDW66b.cms_dummy_consumed_unchecked' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW66b.cms_dummy_consumed_unchecked
