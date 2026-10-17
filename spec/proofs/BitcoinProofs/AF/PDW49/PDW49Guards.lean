import BitcoinProofs.AF.PDW49.PDW49

/-! # PDW49Guards — axiom pins (charter trio, TOP-241..245).
All 9 row-face theorems pin ⊆ `[propext, Classical.choice, Quot.sound]`;
zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW49.prevNotFailed_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.prevNotFailed_iff

/-- info: 'BitcoinProofs.AF.PDW49.prevNotFailed_missing' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.prevNotFailed_missing

/-- info: 'BitcoinProofs.AF.PDW49.minChainWorkOk_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.minChainWorkOk_iff

/-- info: 'BitcoinProofs.AF.PDW49.minChainWorkOk_below' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.minChainWorkOk_below

/-- info: 'BitcoinProofs.AF.PDW49.scriptVerdicts_serial' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.scriptVerdicts_serial

/-- info: 'BitcoinProofs.AF.PDW49.scriptVerdicts_partition_face' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.scriptVerdicts_partition_face

/-- info: 'BitcoinProofs.AF.PDW49.scriptVerdicts_append' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.scriptVerdicts_append

/-- info: 'BitcoinProofs.AF.PDW49.connectGenesis_utxo_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.connectGenesis_utxo_face

/-- info: 'BitcoinProofs.AF.PDW49.connectGenesis_hash_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.connectGenesis_hash_face

/-- info: 'BitcoinProofs.AF.PDW49.connectBlock_genesis_utxo_bestBlock_wired' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.connectBlock_genesis_utxo_bestBlock_wired

/-- info: 'BitcoinProofs.AF.PDW49.connectBlock_genesis_skips_tx_fold_wired' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.connectBlock_genesis_skips_tx_fold_wired

/-- info: 'BitcoinProofs.AF.PDW49.connectBlock_genesis_coinbase_not_connected_wired' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW49.connectBlock_genesis_coinbase_not_connected_wired
