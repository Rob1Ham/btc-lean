import BitcoinProofs.AF.PDW45.PDW45

/-! # PDW45Guards — axiom pins for TOP-181..185 (charter trio check).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on the five row-face theorems. -/

/-- info: 'BitcoinProofs.AF.PDW45.isWitnessProgram_template' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW45.isWitnessProgram_template

/-- info: 'BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wpkh_arity' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wpkh_arity

/-- info: 'BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_empty_witness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_empty_witness

/-- info: 'BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_mismatch' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_p2wsh_mismatch

/-- info: 'BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_wrongLength' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW45.verifyWitnessProgram_v0_wrongLength
