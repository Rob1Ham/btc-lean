import BitcoinProofs.AF.PDW39b.PDW39b

/-! # PDW39bGuards — axiom pins for TOP-286..290.
Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW39b.stepChecked_stack_alt_bound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39b.stepChecked_stack_alt_bound

/-- info: 'BitcoinProofs.AF.PDW39b.evalFrom_nil_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39b.evalFrom_nil_ok

/-- info: 'BitcoinProofs.AF.PDW39b.evalFrom_nil_unbalanced' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39b.evalFrom_nil_unbalanced

/-- info: 'BitcoinProofs.AF.PDW39b.evalFrom_ok_vf_nil' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39b.evalFrom_ok_vf_nil

/-- info: 'BitcoinProofs.AF.PDW39b.evalScriptBytes_tapscript_no_size_guard' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW39b.evalScriptBytes_tapscript_no_size_guard
