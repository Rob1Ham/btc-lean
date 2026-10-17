import BitcoinProofs.AF.PDW35.PDW35

/-! # PDW35Guards — axiom pins (charter trio).

Every PDW35 theorem pins to a subset of `[propext, Classical.choice,
Quot.sound]`; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW35.parityOk_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.parityOk_row

/-- info: 'BitcoinProofs.AF.PDW35.parityOk_empty_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.parityOk_empty_row

/-- info: 'BitcoinProofs.AF.PDW35.parityOk_flip_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.parityOk_flip_row

/-- info: 'BitcoinProofs.AF.PDW35.internalKeyOk_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.internalKeyOk_row

/-- info: 'BitcoinProofs.AF.PDW35.internalKeyOk_geP_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.internalKeyOk_geP_row

/-- info: 'BitcoinProofs.AF.PDW35.tapBranch_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.tapBranch_row

/-- info: 'BitcoinProofs.AF.PDW35.taprootMerkleRoot_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.taprootMerkleRoot_row

/-- info: 'BitcoinProofs.AF.PDW35.hashtypeValid_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.hashtypeValid_row

/-- info: 'BitcoinProofs.AF.PDW35.hashtypeValid_rejects' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW35.hashtypeValid_rejects
