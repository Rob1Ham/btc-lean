import BitcoinProofs.AF.PDW59.PDW59
import BitcoinProofs.AF.PDW59.PDW59b
import BitcoinProofs.AF.PDW59.PDW59c
import BitcoinProofs.AF.PDW59.PDW59c
import BitcoinProofs.AF.PDW59.PDW59d

open BitcoinProofs.AF.PDW59

#print axioms findAndDelete_empty
#print axioms findAndDelete_none_unchanged
#print axioms disabledWire_iff
#print axioms disabledWire_0x7e
#print axioms disabledWire_enabled_example
#print axioms verifyScriptFull_scriptSig_error
#print axioms checkTransaction_vinEmpty_reject
#print axioms checkTransaction_ok_vin_ne_nil
#print axioms checkTransaction_voutEmpty_reject
#print axioms checkTransaction_ok_vout_ne_nil
#print axioms checkOutputs_none_nonneg
#print axioms checkOutputs_neg_reject
#print axioms checkOutputs_none_le_MAX
#print axioms checkOutputs_tooLarge_reject
#print axioms checkOutputs_none_total_moneyRange
#print axioms checkOutputs_prefix_overflow
#print axioms verifyWitnessProgram_future_ok
#print axioms verifyWitnessProgram_v1_wrong_size_ok
#print axioms verifyWitnessProgram_v1_p2sh_ok
#print axioms verifyWitnessProgram_v1_anchor_ok
