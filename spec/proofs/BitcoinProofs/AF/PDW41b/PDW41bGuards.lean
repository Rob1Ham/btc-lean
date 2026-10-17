import BitcoinProofs.AF.PDW41b.PDW41b

/-! # PDW41bGuards — axiom pins for TOP-291..295 (charter trio check).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW41b.witnessLeaves_length' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41b.witnessLeaves_length

/-- info: 'BitcoinProofs.AF.PDW41b.witnessCommitmentOutput_some_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41b.witnessCommitmentOutput_some_spec

/-- info: 'BitcoinProofs.AF.PDW41b.commitmentValueZero_eq_true_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41b.commitmentValueZero_eq_true_iff

/-- info: 'BitcoinProofs.AF.PDW41b.vtxNonempty_eq_true_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41b.vtxNonempty_eq_true_iff

/-- info: 'BitcoinProofs.AF.PDW41b.commitmentNonceOk_head_32' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41b.commitmentNonceOk_head_32
