import BitcoinProofs.AF.PDW68x.PDW68x
import BitcoinProofs.AF.PDW68x.PDW68xB

/-! # PDW68xGuards.lean — axiom pins for TOP-361..365 (PDW68, RC29).
Expected footprints: INV-022/023/SCR-131 subset {propext, Classical.choice,
Quot.sound}; SCR-106/107 subset {propext}. -/

open BitcoinProofs.AF.PDW68x

#print axioms cltv_accept_iff
#print axioms csv_accept_iff
#print axioms csv_accept_masked_le
#print axioms csv_accept_mask_congr
#print axioms pubkey_none_iff
#print axioms pubkey_strictenc_reject
#print axioms pubkey_strictenc_pass
#print axioms witness_pubkeytype_reject
#print axioms witness_pubkeytype_pass
