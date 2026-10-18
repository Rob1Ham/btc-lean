import BitcoinProofs.AF.PDW73.PDW73

/-! # PDW73Guards — axiom pins (TOP-386..390)

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on all eight row-face theorems. -/

/-- info: 'BitcoinProofs.AF.PDW73.stepBody_nop_discourage' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.stepBody_nop_discourage

/-- info: 'BitcoinProofs.AF.PDW73.stepBody_cltv_csv_noflag_nop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.stepBody_cltv_csv_noflag_nop

/-- info: 'BitcoinProofs.AF.PDW73.stepBody_tapscript_checkmultisig_ban' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.stepBody_tapscript_checkmultisig_ban

/-- info: 'BitcoinProofs.AF.PDW73.checksigAddStep_ok' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.checksigAddStep_ok

/-- info: 'BitcoinProofs.AF.PDW73.verifyScriptFull_ok_base_stack' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.verifyScriptFull_ok_base_stack

/-- info: 'BitcoinProofs.AF.PDW73.stepBody_opCount_reject' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.stepBody_opCount_reject

/-- info: 'BitcoinProofs.AF.PDW73.MAX_SCRIPT_ELEMENT_SIZE_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.MAX_SCRIPT_ELEMENT_SIZE_eq

/-- info: 'BitcoinProofs.AF.PDW73.stepBody_pushSize_reject' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW73.stepBody_pushSize_reject
