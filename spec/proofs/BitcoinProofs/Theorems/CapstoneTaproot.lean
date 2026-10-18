import BitcoinProofs.Theorems.CapstoneSigops
import BitcoinProofs.Theorems.WitnessSerialization

/-! Public script adjudication status and complete live-view prevout data.
Complete here refers only to script adjudication, not a whole-Core theorem. -/
namespace BitcoinProofs.Theorems.CapstoneTaproot
open Bitcoin.Data Bitcoin.Capstone.Block Bitcoin.Capstone.Context

 theorem validateBlock_script_status {raw : ByteArray} {st : CapState}
    {context : Option ChainContext} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    report.scriptAdjudication = (if report.scriptUnjudged = 0 then .complete else .incomplete) := by
  obtain ⟨_, _, _, _, _, _, _, status⟩ := CapstoneSigops.validateBlock_sigop_stage h
  exact status.2

 theorem validateBlock_scripts_complete_iff {raw : ByteArray} {st : CapState}
    {context : Option ChainContext} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    report.scriptAdjudication = .complete ↔ report.scriptUnjudged = 0 := by
  rw [validateBlock_script_status h]
  split <;> simp_all

 theorem validateBlock_scripts_incomplete_iff {raw : ByteArray} {st : CapState}
    {context : Option ChainContext} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    report.scriptAdjudication = .incomplete ↔ report.scriptUnjudged ≠ 0 := by
  rw [validateBlock_script_status h]
  split <;> simp_all
end BitcoinProofs.Theorems.CapstoneTaproot

/-! Exact new trust footprints, measured from the kernel declarations. -/

/-- info: 'Bitcoin.Capstone.Block.collectSpentOutputs_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.collectSpentOutputs_spec

/-- info: 'Bitcoin.Capstone.Block.collectSpentOutputs_complete' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.collectSpentOutputs_complete

/-- info: 'Bitcoin.Capstone.Block.checkTxInputs_spentOutputs' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkTxInputs_spentOutputs

/-- info: 'Bitcoin.Crypto.Taproot.Program.compactSizeEnc_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Crypto.Taproot.Program.compactSizeEnc_size

/-- info: 'Bitcoin.Crypto.Taproot.Program.compactSizeEnc_size_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Crypto.Taproot.Program.compactSizeEnc_size_mono

/-- info: 'Bitcoin.Crypto.Taproot.Program.witnessSerSize_append_single' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Crypto.Taproot.Program.witnessSerSize_append_single

/-- info: 'Bitcoin.Crypto.Taproot.Program.witnessSerSize_append_strict' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Crypto.Taproot.Program.witnessSerSize_append_strict

/-- info: 'BitcoinProofs.Theorems.WitnessSerialization.witnessSerSize_eq_encoder' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.WitnessSerialization.witnessSerSize_eq_encoder

/-- info: 'BitcoinProofs.Theorems.WitnessSerialization.interpreter_size_eq_encoder' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.WitnessSerialization.interpreter_size_eq_encoder

/-- info: 'BitcoinProofs.Theorems.CapstoneTaproot.validateBlock_script_status' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneTaproot.validateBlock_script_status

/-- info: 'BitcoinProofs.Theorems.CapstoneTaproot.validateBlock_scripts_complete_iff' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneTaproot.validateBlock_scripts_complete_iff

/-- info: 'BitcoinProofs.Theorems.CapstoneTaproot.validateBlock_scripts_incomplete_iff' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneTaproot.validateBlock_scripts_incomplete_iff

/-- info: 'BitcoinProofs.Theorems.WitnessSerialization.validationWeightInit_eq_encoder' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.WitnessSerialization.validationWeightInit_eq_encoder

/-- info: 'BitcoinProofs.Theorems.WitnessSerialization.executeWitnessScript_encoder_budget' depends on axioms: [propext,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.WitnessSerialization.executeWitnessScript_encoder_budget


/-- info: 'BitcoinProofs.Theorems.WitnessSerialization.executeWitnessScript_exact_seed' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.WitnessSerialization.executeWitnessScript_exact_seed
