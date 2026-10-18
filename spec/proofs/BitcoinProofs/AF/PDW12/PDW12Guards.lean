import BitcoinProofs.AF.PDW12.PDW12

/-! # PDW12Guards — axiom pins (charter trio check, pass 3).

Expected lines = the g2.out pass-2 output verbatim (the
`#guard_msgs` doc-comment pattern). Every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio
(DECISIONS / RC-suite convention); zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW12.bytes_eq_of_beq_eq_true' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.bytes_eq_of_beq_eq_true

/-- info: 'BitcoinProofs.AF.PDW12.merkleOk_of_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.merkleOk_of_eq

/-- info: 'BitcoinProofs.AF.PDW12.levelHasAdjacentDup_cons2_of_beq' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.levelHasAdjacentDup_cons2_of_beq

/-- info: 'BitcoinProofs.AF.PDW12.levelHasAdjacentDup_nil' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.levelHasAdjacentDup_nil

/-- info: 'BitcoinProofs.AF.PDW12.levelHasAdjacentDup_singleton' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.levelHasAdjacentDup_singleton

/-- info: 'BitcoinProofs.AF.PDW12.nextWorkRequired_nonboundary_const' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.nextWorkRequired_nonboundary_const

/-- info: 'BitcoinProofs.AF.PDW12.nextWorkRequired_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.nextWorkRequired_none

/-- info: 'BitcoinProofs.AF.PDW12.timeNotTooNew_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.timeNotTooNew_eq

/-- info: 'BitcoinProofs.AF.PDW12.feeAccumInRange_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.feeAccumInRange_eq

/-- info: 'BitcoinProofs.AF.PDW12.levelHasAdjacentDupCap_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.levelHasAdjacentDupCap_eq

/-- info: 'BitcoinProofs.AF.PDW12.merkleMutationFreeCap_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.merkleMutationFreeCap_eq

/-- info: 'BitcoinProofs.AF.PDW12.merkleMutationOk_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.merkleMutationOk_eq

/-- info: 'BitcoinProofs.AF.PDW12.merkleMutationOk_eq_false_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.merkleMutationOk_eq_false_iff

/-- info: 'BitcoinProofs.AF.PDW12.merkleMutationOk_of_mutationFree' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.merkleMutationOk_of_mutationFree

/-- info: 'BitcoinProofs.AF.PDW12.validateBlock_badMutated_of_mutationFree_false' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.validateBlock_badMutated_of_mutationFree_false

/-- info: 'BitcoinProofs.AF.PDW12.validateBlock_badMutated_of_levelDup' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.validateBlock_badMutated_of_levelDup

/-- info: 'BitcoinProofs.AF.PDW12.validateBlock_badMutated_of_adjacent_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW12.validateBlock_badMutated_of_adjacent_eq
