import BitcoinProofs.AF.PDW30.PDW30
import BitcoinProofs.AF.PDW30.PDW30b

/-! # PDW30Guards — axiom pins (charter trio, 5/5 silent).
All ten row-face theorems pin ⊆ `[propext, Classical.choice, Quot.sound]`;
zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW30.connectHeight_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.connectHeight_row

/-- info: 'BitcoinProofs.AF.PDW30.betterThan_tie_earlier' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.betterThan_tie_earlier

/-- info: 'BitcoinProofs.AF.PDW30.betterThan_tie_later' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.betterThan_tie_later

/-- info: 'BitcoinProofs.AF.PDW30.switchTip_strict' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.switchTip_strict

/-- info: 'BitcoinProofs.AF.PDW30.switchTip_tie' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.switchTip_tie

/-- info: 'BitcoinProofs.AF.PDW30.reorgPlan_disconnect' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.reorgPlan_disconnect

/-- info: 'BitcoinProofs.AF.PDW30.reorgPlan_connect' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.reorgPlan_connect

/-- info: 'BitcoinProofs.AF.PDW30.reorgPlan_at_fork' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.reorgPlan_at_fork

/-- info: 'BitcoinProofs.AF.PDW30.prunedCandidates_subset' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.prunedCandidates_subset

/-- info: 'BitcoinProofs.AF.PDW30.descendant_not_pruned' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW30.descendant_not_pruned
