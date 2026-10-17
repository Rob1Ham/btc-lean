import BitcoinProofs.AF.PDW56.PDW56

/-! # PDW56Guards — axiom pins for TOP-276..280 (charter trio check).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW56.tapLeaf_wire_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW56.tapLeaf_wire_eq

/-- info: 'BitcoinProofs.AF.PDW56.tapLeaf_digest_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW56.tapLeaf_digest_size

/-- info: 'BitcoinProofs.AF.PDW56.taptweak_some_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW56.taptweak_some_face

/-- info: 'BitcoinProofs.AF.PDW56.taptweak_none_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW56.taptweak_none_face

/-- info: 'BitcoinProofs.AF.PDW56.tweakPoint_commitment_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW56.tweakPoint_commitment_face

/-- info: 'BitcoinProofs.AF.PDW56.tweakPoint_overflow_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW56.tweakPoint_overflow_face
