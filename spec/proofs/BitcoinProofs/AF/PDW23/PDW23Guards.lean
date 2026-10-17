import BitcoinProofs.AF.PDW23.PDW23

/-! # PDW23Guards — axiom pins (charter trio check, TOP-111..115).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW23.disconnectRelevant_row_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.disconnectRelevant_row_iff

/-- info: 'BitcoinProofs.AF.PDW23.disconnectRelevant_opreturn' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.disconnectRelevant_opreturn

/-- info: 'BitcoinProofs.AF.PDW23.undoCountOk_row_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.undoCountOk_row_iff

/-- info: 'BitcoinProofs.AF.PDW23.undoCountOk_coinbase_only' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.undoCountOk_coinbase_only

/-- info: 'BitcoinProofs.AF.PDW23.undoCountOk_short' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.undoCountOk_short

/-- info: 'BitcoinProofs.AF.PDW23.undoCountOk_long' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.undoCountOk_long

/-- info: 'BitcoinProofs.AF.PDW23.genesisHeader_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.genesisHeader_row

/-- info: 'BitcoinProofs.AF.PDW23.genesisHeader_difficulty_one' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.genesisHeader_difficulty_one

/-- info: 'BitcoinProofs.AF.PDW23.bip143MsgL_amount_field' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.bip143MsgL_amount_field

/-- info: 'BitcoinProofs.AF.PDW23.bip143MsgL_hashtype_tail' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW23.bip143MsgL_hashtype_tail
