import BitcoinProofs.AF.PDW53.PDW53

/-! # PDW53Guards — axiom pins (charter trio, 8/8 silent).
All eight row-face theorems pin ⊆ `[propext, Classical.choice, Quot.sound]`;
zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW53.merkleFailureKind_plain_of_free' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.merkleFailureKind_plain_of_free

/-- info: 'BitcoinProofs.AF.PDW53.merkleFailureKind_mutated' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.merkleFailureKind_mutated

/-- info: 'BitcoinProofs.AF.PDW53.contextualChecksOrdered_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.contextualChecksOrdered_row

/-- info: 'BitcoinProofs.AF.PDW53.connectGenesis_utxo_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.connectGenesis_utxo_row

/-- info: 'BitcoinProofs.AF.PDW53.connectGenesis_hash_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.connectGenesis_hash_row

/-- info: 'BitcoinProofs.AF.PDW53.blockSequenceLocksOk_gate_off' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.blockSequenceLocksOk_gate_off

/-- info: 'BitcoinProofs.AF.PDW53.validateBlock_commitment_preempts_weight_row' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.validateBlock_commitment_preempts_weight_row

/-- info: 'BitcoinProofs.AF.PDW53.validateBlock_commitment_failure_ne_badBlkWeight' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW53.validateBlock_commitment_failure_ne_badBlkWeight
