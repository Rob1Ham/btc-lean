import BitcoinProofs.AF.PDW16.PDW16

/-! # PDW16Guards — axiom pins (charter trio check, pass 3).

Expected lines = the pD.out pass-1 output verbatim (the
`#guard_msgs` doc-comment pattern). Every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio
(DECISIONS / RC-suite convention); zero `sorryAx`.
Ten theorems depend on no axioms at all; five on
[propext, Quot.sound]; one (genesisCoinbaseTx_coinbase) on the
full trio (its `isCoinBase` `by decide` arm). -/

/-- info: 'BitcoinProofs.AF.PDW16.timestamp_window_eq_max_future' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.timestamp_window_eq_max_future

/-- info: 'BitcoinProofs.AF.PDW16.max_future_block_time_eq_7200' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.max_future_block_time_eq_7200

/-- info: 'BitcoinProofs.AF.PDW16.timestamp_window_eq_7200' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.timestamp_window_eq_7200

/-- info: 'BitcoinProofs.AF.PDW16.testnet4_testdummy_table' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.testnet4_testdummy_table

/-- info: 'BitcoinProofs.AF.PDW16.regtest_testdummy_table' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.regtest_testdummy_table

/-- info: 'BitcoinProofs.AF.PDW16.testdummy_ratio' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.testdummy_ratio

/-- info: 'BitcoinProofs.AF.PDW16.compactTarget_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.compactTarget_eq

/-- info: 'BitcoinProofs.AF.PDW16.compactTarget_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.compactTarget_zero

/-- info: 'BitcoinProofs.AF.PDW16.powLimit_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.powLimit_eq

/-- info: 'BitcoinProofs.AF.PDW16.targetOk_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.targetOk_eq

/-- info: 'BitcoinProofs.AF.PDW16.targetOk_difficulty_one' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.targetOk_difficulty_one

/-- info: 'BitcoinProofs.AF.PDW16.targetOk_high_bits_reject' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.targetOk_high_bits_reject

/-- info: 'BitcoinProofs.AF.PDW16.targetOk_zero_reject' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.targetOk_zero_reject

/-- info: 'BitcoinProofs.AF.PDW16.genesisCoinbaseTx_coinbase' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.genesisCoinbaseTx_coinbase

/-- info: 'BitcoinProofs.AF.PDW16.genesisCoinbaseTx_value' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.genesisCoinbaseTx_value

/-- info: 'BitcoinProofs.AF.PDW16.genesisScriptPubKey_p2pk' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW16.genesisScriptPubKey_p2pk
