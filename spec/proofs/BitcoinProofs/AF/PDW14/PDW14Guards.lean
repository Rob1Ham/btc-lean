import BitcoinProofs.AF.PDW14.B020
import BitcoinProofs.AF.PDW14.B089B104
import BitcoinProofs.AF.PDW14.B103
import BitcoinProofs.AF.PDW14.B069

/-! # PDW14Guards — axiom pins (charter trio check, pass 3).

Expected lines = the g2.out pass-2 output verbatim (the
`#guard_msgs` doc-comment pattern). Every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio
(DECISIONS / RC-suite convention); zero `sorryAx`. The 5th row
(BLK-103) additionally rides the CORE pin
`Bitcoin.TxValidation.checkTxInputs_ok_conservation` =
[propext, Classical.choice, Quot.sound] (Interface.lean:1122,
`#guard_msgs`-pinned W10), its promotion target. -/

/-- info: 'BitcoinProofs.AF.PDW14.commitmentGate_forces_binding' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW14.commitmentGate_forces_binding

/-- info: 'BitcoinProofs.AF.PDW14.cbAmountOk_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW14.cbAmountOk_iff

/-- info: 'BitcoinProofs.AF.PDW14.blockSequenceLocksOk_all' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW14.blockSequenceLocksOk_all

/-- info: 'BitcoinProofs.AF.PDW14.blockSequenceLocksOk_fail' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW14.blockSequenceLocksOk_fail

/-- info: 'BitcoinProofs.AF.PDW14.checkTxInputs_in_belowout_reject' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW14.checkTxInputs_in_belowout_reject

/-- info: 'BitcoinProofs.AF.PDW14.bip34Ok_vacuous_below' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW14.bip34Ok_vacuous_below

/-- info: 'BitcoinProofs.AF.PDW14.bip34Ok_push_prefix' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW14.bip34Ok_push_prefix
