import BitcoinProofs.AF.PDW28.PDW28

/-! # PDW28Guards — axiom pins (TOP-136..140).
Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW28.vtxCountWeightOk_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.vtxCountWeightOk_eq
/-- info: 'BitcoinProofs.AF.PDW28.vtxCountWeightOk_bound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.vtxCountWeightOk_bound
/-- info: 'BitcoinProofs.AF.PDW28.vtxCountWeightOk_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.vtxCountWeightOk_reject
/-- info: 'BitcoinProofs.AF.PDW28.powLimitMainnet_pin' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.powLimitMainnet_pin
/-- info: 'BitcoinProofs.AF.PDW28.powLimitSignet_pin' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.powLimitSignet_pin
/-- info: 'BitcoinProofs.AF.PDW28.powLimitRegtest_pin' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.powLimitRegtest_pin
/-- info: 'BitcoinProofs.AF.PDW28.permitted_nonboundary_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.permitted_nonboundary_eq
/-- info: 'BitcoinProofs.AF.PDW28.permitted_mismatch_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.permitted_mismatch_reject
/-- info: 'BitcoinProofs.AF.PDW28.permitted_mindiff_true' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.permitted_mindiff_true
/-- info: 'BitcoinProofs.AF.PDW28.nextWorkRequired_minDiff_slow' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.nextWorkRequired_minDiff_slow
/-- info: 'BitcoinProofs.AF.PDW28.nextWorkRequired_minDiff_fast' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW28.nextWorkRequired_minDiff_fast
