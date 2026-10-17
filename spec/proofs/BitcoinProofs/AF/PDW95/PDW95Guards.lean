import BitcoinProofs.AF.PDW95.PDW95
import BitcoinProofs.AF.PDW95.PDW95b
import BitcoinProofs.AF.PDW95.PDW95c

/-! # PDW95 axiom pins (subset [propext, Classical.choice, Quot.sound]) -/

/-- info: 'BitcoinProofs.AF.PDW95.stepBody_minimalIf_witnessV0' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.stepBody_minimalIf_witnessV0
/-- info: 'BitcoinProofs.AF.PDW95.checkPubKeyEncoding_witnessPubkeyType_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.checkPubKeyEncoding_witnessPubkeyType_off
/-- info: 'BitcoinProofs.AF.PDW95.checkPubKeyEncoding_witnessPubkeyType_on' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.checkPubKeyEncoding_witnessPubkeyType_on
/-- info: 'BitcoinProofs.AF.PDW95.witnessPubkeyType_absent_from_consensus' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.witnessPubkeyType_absent_from_consensus
/-- info: 'BitcoinProofs.AF.PDW95.executeWitnessScript_discourageOpSuccess' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.executeWitnessScript_discourageOpSuccess
/-- info: 'BitcoinProofs.AF.PDW95.executeWitnessScript_opSuccess_policy_off' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.executeWitnessScript_opSuccess_policy_off
/-- info: 'BitcoinProofs.AF.PDW95.decodeNum_length_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.decodeNum_length_le
/-- info: 'BitcoinProofs.AF.PDW95.decodeNum_minimal' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.decodeNum_minimal
/-- info: 'BitcoinProofs.AF.PDW95.decodeNum_minimal_off_accepts_nonminimal' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.decodeNum_minimal_off_accepts_nonminimal
/-- info: 'BitcoinProofs.AF.PDW95.checksigAddStep_num_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.checksigAddStep_num_size
/-- info: 'BitcoinProofs.AF.PDW95.checksigAddStep_num_minimal' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.checksigAddStep_num_minimal
/-- info: 'BitcoinProofs.AF.PDW95.verifyScriptFull_scriptSig_error_first' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.verifyScriptFull_scriptSig_error_first
/-- info: 'BitcoinProofs.AF.PDW95.verifyScriptFull_sequential_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.verifyScriptFull_sequential_ok
/-- info: 'BitcoinProofs.AF.PDW95.sequence_boundary_witness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW95.sequence_boundary_witness
