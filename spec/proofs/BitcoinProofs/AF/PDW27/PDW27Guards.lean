import BitcoinProofs.AF.PDW27.SCR015INV133
import BitcoinProofs.AF.PDW27.SCR103
import BitcoinProofs.AF.PDW27.BLK004INV122

/-! # PDW27Guards — axiom pins (charter trio check, TOP-131..135).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on the 18 row-face theorems + the
SCR-103 core carrier `Bitcoin.Activation.dersig_flag_flow`. -/

/-- info: 'BitcoinProofs.AF.PDW27.getBlockScriptFlagsP_eq' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.getBlockScriptFlagsP_eq

/-- info: 'BitcoinProofs.AF.PDW27.getBlockScriptFlagsP_exc' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.getBlockScriptFlagsP_exc

/-- info: 'BitcoinProofs.AF.PDW27.mainnetExceptionMap_bip16' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.mainnetExceptionMap_bip16

/-- info: 'BitcoinProofs.AF.PDW27.mainnetExceptionMap_taproot' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.mainnetExceptionMap_taproot

/-- info: 'BitcoinProofs.AF.PDW27.mainnetExceptionMap_fail_closed' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.mainnetExceptionMap_fail_closed

/-- info: 'BitcoinProofs.AF.PDW27.mainnetExceptionMap_ne' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.mainnetExceptionMap_ne

/-- info: 'BitcoinProofs.AF.PDW27.mainnet_bip66_height' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.mainnet_bip66_height

/-- info: 'BitcoinProofs.AF.PDW27.dersig_applied_from_bip66' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.dersig_applied_from_bip66

/-- info: 'BitcoinProofs.AF.PDW27.dersig_off_below_bip66' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.dersig_off_below_bip66

/-- info: 'BitcoinProofs.AF.PDW27.headerIsNull_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.headerIsNull_iff

/-- info: 'BitcoinProofs.AF.PDW27.headerIsNull_compactTarget_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.headerIsNull_compactTarget_zero

/-- info: 'BitcoinProofs.AF.PDW27.headerIsNull_nonzero' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.headerIsNull_nonzero

/-- info: 'BitcoinProofs.AF.PDW27.versionBitsSignals_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.versionBitsSignals_eq

/-- info: 'BitcoinProofs.AF.PDW27.versionBitsSignals_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.versionBitsSignals_iff

/-- info: 'BitcoinProofs.AF.PDW27.versionBitsSignals_top_bits' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.versionBitsSignals_top_bits

/-- info: 'BitcoinProofs.AF.PDW27.versionBitsSignals_bit_set' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.versionBitsSignals_bit_set

/-- info: 'BitcoinProofs.AF.PDW27.versionBitsSignals_rejects' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.versionBitsSignals_rejects

/-- info: 'BitcoinProofs.AF.PDW27.versionBitsSignals_bit_unset' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW27.versionBitsSignals_bit_unset

/-- info: 'Bitcoin.Activation.dersig_flag_flow' depends on axioms: [propext] -/
#guard_msgs in #print axioms Bitcoin.Activation.dersig_flag_flow
