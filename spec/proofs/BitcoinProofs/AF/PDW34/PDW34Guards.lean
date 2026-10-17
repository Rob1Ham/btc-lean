import BitcoinProofs.AF.PDW34.PDW34

/-! # PDW34Guards — axiom pins (charter trio check, TOP-166..170).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on the nine row-face/companion theorems. -/

/-- info: 'BitcoinProofs.AF.PDW34.encTxL_witness_marker_flag' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.encTxL_witness_marker_flag

/-- info: 'BitcoinProofs.AF.PDW34.decTxCore_flag_one_superfluous' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.decTxCore_flag_one_superfluous

/-- info: 'BitcoinProofs.AF.PDW34.decTxCore_flag_even_unknown' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.decTxCore_flag_even_unknown

/-- info: 'BitcoinProofs.AF.PDW34.decTxCore_flag_odd_superfluous' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.decTxCore_flag_odd_superfluous

/-- info: 'BitcoinProofs.AF.PDW34.decTxCore_flag_not_one_error' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.decTxCore_flag_not_one_error

/-- info: 'BitcoinProofs.AF.PDW34.checkTransaction_none_weight' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.checkTransaction_none_weight

/-- info: 'BitcoinProofs.AF.PDW34.checkTransaction_oversize' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.checkTransaction_oversize

/-- info: 'BitcoinProofs.AF.PDW34.dshaL_is_sha256d' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.dshaL_is_sha256d

/-- info: 'BitcoinProofs.AF.PDW34.dshaL_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.dshaL_size

/-- info: 'BitcoinProofs.AF.PDW34.signatureHashBip143_dshaL' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.signatureHashBip143_dshaL

/-- info: 'BitcoinProofs.AF.PDW34.hashPrevoutsL_dshaL' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW34.hashPrevoutsL_dshaL
