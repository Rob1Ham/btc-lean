import BitcoinProofs.AF.PDW13.PDW13

/-! # PDW13Guards — axiom pins (charter trio check).

Expected lines = the g2.out collection run verbatim (the
`#guard_msgs` doc-comment pattern). Every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio
(DECISIONS / RC-suite convention); zero `sorryAx`.

The [p,c,q] pins on the BLK-017/BLK-019 theorems = the core
`witnessCommitmentOk` / `commitmentGate` /
`witnessCommitmentOutput` def layer's own footprints (Cor
CapstoneCommitmentCor's axiom table: "the core defs themselves
already depend on [propext, Classical.choice, Quot.sound]; no
choice is introduced by these proofs"); the BLK-018 family +
the two Pow-lane iffs = [propext] only. -/

/-- info: 'BitcoinProofs.AF.PDW13.witnessCommitmentOk_eq_true' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.witnessCommitmentOk_eq_true

/-- info: 'BitcoinProofs.AF.PDW13.witnessCommitmentOk_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.witnessCommitmentOk_none

/-- info: 'BitcoinProofs.AF.PDW13.commitmentNonceOk_eq_true' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.commitmentNonceOk_eq_true

/-- info: 'BitcoinProofs.AF.PDW13.commitmentNonceOk_witness_nil' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.commitmentNonceOk_witness_nil

/-- info: 'BitcoinProofs.AF.PDW13.commitmentNonceOk_head_nil' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.commitmentNonceOk_head_nil

/-- info: 'BitcoinProofs.AF.PDW13.commitmentNonceOk_head_multi' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.commitmentNonceOk_head_multi

/-- info: 'BitcoinProofs.AF.PDW13.commitmentGate_unexpected_witness' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.commitmentGate_unexpected_witness

/-- info: 'BitcoinProofs.AF.PDW13.commitmentGate_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.commitmentGate_eq

/-- info: 'BitcoinProofs.AF.PDW13.commitmentGate_witness_free_pass' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.commitmentGate_witness_free_pass

/-- info: 'BitcoinProofs.AF.PDW13.timewarpOk_true_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.timewarpOk_true_iff

/-- info: 'BitcoinProofs.AF.PDW13.timeNotTooOld_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW13.timeNotTooOld_eq
