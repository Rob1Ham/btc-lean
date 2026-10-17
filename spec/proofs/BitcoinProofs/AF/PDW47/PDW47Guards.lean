import BitcoinProofs.AF.PDW47.PDW47

/-! # PDW47Guards — axiom pins (charter trio check, TOP-231..235).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on the 5 row-face theorems. -/

/-- info: 'BitcoinProofs.AF.PDW47.schnorrVerdict_size_gate' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_size_gate

/-- info: 'BitcoinProofs.AF.PDW47.schnorrVerdict_65_default_rejected' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_65_default_rejected

/-- info: 'BitcoinProofs.AF.PDW47.schnorrVerdict_default_64' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_default_64

/-- info: 'BitcoinProofs.AF.PDW47.schnorrVerdict_sighash_fail_closed' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW47.schnorrVerdict_sighash_fail_closed

/-- info: 'BitcoinProofs.AF.PDW47.stepBody_codesep_records_next' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW47.stepBody_codesep_records_next
