import BitcoinProofs.AF.PDW24.PDW24

/-! # PDW24Guards — axiom pins (charter trio, pass 3).

All seven PDW24 theorems pin to `[propext, Quot.sound]`
⊆ `[propext, Classical.choice, Quot.sound]`; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW24.workOf_zero_invalid' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW24.workOf_zero_invalid

/-- info: 'BitcoinProofs.AF.PDW24.workOf_difficulty_one' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW24.workOf_difficulty_one

/-- info: 'BitcoinProofs.AF.PDW24.workOf_pos_of_inRange' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW24.workOf_pos_of_inRange

/-- info: 'BitcoinProofs.AF.PDW24.chainWork_cons_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW24.chainWork_cons_eq

/-- info: 'BitcoinProofs.AF.PDW24.chainWork_genesis' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW24.chainWork_genesis

/-- info: 'BitcoinProofs.AF.PDW24.mostWork?_maximality' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW24.mostWork?_maximality

/-- info: 'BitcoinProofs.AF.PDW24.mostWork?_pair_maximality' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW24.mostWork?_pair_maximality
