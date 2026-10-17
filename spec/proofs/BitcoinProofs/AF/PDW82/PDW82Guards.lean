import BitcoinProofs.AF.PDW82.PDW82
import BitcoinProofs.AF.PDW82.PDW82b
import BitcoinProofs.AF.PDW82.PDW82c

/-! Axiom-pin audit for the PDW82 row faces. -/

#print axioms BitcoinProofs.AF.PDW82.isValidSigEncoding_size
#print axioms BitcoinProofs.AF.PDW82.isValidSigEncoding_der_prefix
#print axioms BitcoinProofs.AF.PDW82.evalChecksigTapscript_weight_before_pubkey
#print axioms BitcoinProofs.AF.PDW82.evalChecksigTapscript_empty_sig_no_weight
#print axioms BitcoinProofs.AF.PDW82b.executeWitnessScript_opSuccess_ok
#print axioms BitcoinProofs.AF.PDW82b.executeWitnessScript_opSuccess_discouraged
#print axioms BitcoinProofs.AF.PDW82c.verifyWitnessProgram_annex_detected
#print axioms BitcoinProofs.AF.PDW82c.verifyWitnessProgram_no_annex_singleton
