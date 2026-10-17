import BitcoinProofs.AF.PDW39.PDW39

/-! # PDW39Guards — axiom pins (charter trio check, TOP-191..195).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW39.mutated64ByteTx_cons_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.mutated64ByteTx_cons_iff
/-- info: 'BitcoinProofs.AF.PDW39.mutated64ByteTx_mutated_witness' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.mutated64ByteTx_mutated_witness
/-- info: 'BitcoinProofs.AF.PDW39.merklePathRoot_sound_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.merklePathRoot_sound_row
/-- info: 'BitcoinProofs.AF.PDW39.merklePathRoot_append' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.merklePathRoot_append
/-- info: 'BitcoinProofs.AF.PDW39.merklePathRoot_singleton_left' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.merklePathRoot_singleton_left
/-- info: 'BitcoinProofs.AF.PDW39.merklePathRoot_singleton_right' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.merklePathRoot_singleton_right
/-- info: 'BitcoinProofs.AF.PDW39.cachedVerdict_genesis_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.cachedVerdict_genesis_row
/-- info: 'BitcoinProofs.AF.PDW39.cachedVerdict_unknown' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.cachedVerdict_unknown
/-- info: 'BitcoinProofs.AF.PDW39.cachedVerdict_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.cachedVerdict_iff
/-- info: 'BitcoinProofs.AF.PDW39.reservedValueFill_fill' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.reservedValueFill_fill
/-- info: 'BitcoinProofs.AF.PDW39.reservedValueFill_inactive' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.reservedValueFill_inactive
/-- info: 'BitcoinProofs.AF.PDW39.reservedValueFill_zero_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.reservedValueFill_zero_size
/-- info: 'BitcoinProofs.AF.PDW39.memoVerdict_hit' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.memoVerdict_hit
/-- info: 'BitcoinProofs.AF.PDW39.memoVerdict_miss_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39.memoVerdict_miss_row
