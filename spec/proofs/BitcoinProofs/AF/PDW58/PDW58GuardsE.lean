import BitcoinProofs.AF.PDW58.PDW58E

/-! # PDW58GuardsE — axiom pins for the INV-073 tapleaf commitment faces

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Expected footprints are guarded so drift fails the build. -/

open BitcoinProofs.AF.PDW58

/-- info: 'BitcoinProofs.AF.PDW58.control_shape_pins' does not depend on any axioms -/
#guard_msgs in #print axioms control_shape_pins

/-- info: 'BitcoinProofs.AF.PDW58.tapleafCommitment_short' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapleafCommitment_short

/-- info: 'BitcoinProofs.AF.PDW58.tapleafCommitment_badResidue' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tapleafCommitment_badResidue

/-- info: 'BitcoinProofs.AF.PDW58.tapleafCommitment_single' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapleafCommitment_single

/-- info: 'BitcoinProofs.AF.PDW58.tapleafCommitment_oneNode' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms tapleafCommitment_oneNode
