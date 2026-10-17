import BitcoinProofs.AF.PDW75.PDW75

/-! # PDW75Guards — axiom pins for TOP-396..400 (charter trio check).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_script' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_script

/-- info: 'BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_empty

/-- info: 'BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_mismatch' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wsh_mismatch

/-- info: 'BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_wrong_len' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_wrong_len

/-- info: 'BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_script' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW75.verifyWitnessProgram_v0_p2wpkh_script
