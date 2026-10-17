import BitcoinProofs.AF.PDW20.PDW20

/-! # PDW20Guards — axiom pins (charter trio check, TOP-96..100).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on the 12 row-face theorems.
-/

/-- info: 'BitcoinProofs.AF.PDW20.chainLinkOk_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.chainLinkOk_iff

/-- info: 'BitcoinProofs.AF.PDW20.coinMeta_roundtrip' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.coinMeta_roundtrip

/-- info: 'BitcoinProofs.AF.PDW20.coinMeta_encode_decode' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.coinMeta_encode_decode

/-- info: 'BitcoinProofs.AF.PDW20.coinMeta_lt_two_pow_32' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.coinMeta_lt_two_pow_32

/-- info: 'BitcoinProofs.AF.PDW20.mainnet_testdummy_table' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.mainnet_testdummy_table

/-- info: 'BitcoinProofs.AF.PDW20.mainnet_testdummy_dormant' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.mainnet_testdummy_dormant

/-- info: 'BitcoinProofs.AF.PDW20.mainnet_deployments_singleton' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.mainnet_deployments_singleton

/-- info: 'BitcoinProofs.AF.PDW20.seqIsDisabled_bit31_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.seqIsDisabled_bit31_iff

/-- info: 'BitcoinProofs.AF.PDW20.seqDisabled_of_ge' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.seqDisabled_of_ge

/-- info: 'BitcoinProofs.AF.PDW20.seqNotDisabled_of_lt' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.seqNotDisabled_of_lt

/-- info: 'BitcoinProofs.AF.PDW20.witness_scale_factor_eq_four' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.witness_scale_factor_eq_four

/-- info: 'BitcoinProofs.AF.PDW20.legacy_units_of_weight' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW20.legacy_units_of_weight
