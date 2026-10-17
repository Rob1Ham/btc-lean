import BitcoinProofs.AF.PDW50.PDW50

/-! # PDW50Guards — axiom pins for TOP-246..250.

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Run from `spec/proofs` after `lake build BitcoinProofs.AF.PDW50.PDW50`.
-/

/-- info: 'BitcoinProofs.AF.PDW50.txidOf_eq_sha256d_serTx' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.txidOf_eq_sha256d_serTx

/-- info: 'BitcoinProofs.AF.PDW50.txidOf_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.txidOf_congr

/-- info: 'BitcoinProofs.AF.PDW50.wtxidOf_eq_txidOf_of_noWitness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.wtxidOf_eq_txidOf_of_noWitness

/-- info: 'BitcoinProofs.AF.PDW50.wtxidOf_eq_sha256d_encodeTx_of_hasWitness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.wtxidOf_eq_sha256d_encodeTx_of_hasWitness

/-- info: 'BitcoinProofs.AF.PDW50.merkleRootOfBlock_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleRootOfBlock_eq

/-- info: 'BitcoinProofs.AF.PDW50.merkleRootOfBlock_single' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleRootOfBlock_single

/-- info: 'BitcoinProofs.AF.PDW50.merkleRootOfBlock_pair' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleRootOfBlock_pair

/-- info: 'BitcoinProofs.AF.PDW50.pairHash_eq_sha256d_append' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.pairHash_eq_sha256d_append

/-- info: 'BitcoinProofs.AF.PDW50.merkleLevel_pair' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleLevel_pair

/-- info: 'BitcoinProofs.AF.PDW50.merkleRootOf_pair' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleRootOf_pair

/-- info: 'BitcoinProofs.AF.PDW50.merkleLevel_singleton' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleLevel_singleton

/-- info: 'BitcoinProofs.AF.PDW50.merkleLevel_length' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleLevel_length

/-- info: 'BitcoinProofs.AF.PDW50.merkleLevel_length_lt' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW50.merkleLevel_length_lt
