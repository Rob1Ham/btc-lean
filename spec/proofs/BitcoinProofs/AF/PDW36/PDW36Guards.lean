import BitcoinProofs.AF.PDW36.PDW36

/-! # PDW36Guards — axiom pins (charter trio check, TOP-176..180).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on the row-face theorems. -/

/-- info: 'BitcoinProofs.AF.PDW36.flagsComboOk_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.flagsComboOk_iff

/-- info: 'BitcoinProofs.AF.PDW36.flagsComboOk_witness_requires_p2sh' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.flagsComboOk_witness_requires_p2sh

/-- info: 'BitcoinProofs.AF.PDW36.sigOpCount_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.sigOpCount_eq

/-- info: 'BitcoinProofs.AF.PDW36.sigOpCount_single' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.sigOpCount_single

/-- info: 'BitcoinProofs.AF.PDW36.p2shSigOpCount_malformed' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.p2shSigOpCount_malformed

/-- info: 'BitcoinProofs.AF.PDW36.p2shSigOpCount_push' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.p2shSigOpCount_push

/-- info: 'BitcoinProofs.AF.PDW36.sigOpCost_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.sigOpCost_eq

/-- info: 'BitcoinProofs.AF.PDW36.sigOpCost_budget_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.sigOpCost_budget_iff

/-- info: 'BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_eq

/-- info: 'BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_lt_thousand' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_lt_thousand
