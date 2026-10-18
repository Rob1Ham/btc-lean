import BitcoinProofs.AF.PDW19.PDW19

/-! # PDW19Guards — axiom pins (charter trio, ≤ [propext,
Classical.choice, Quot.sound]).

Expected lines = the p2.out pass-1 output verbatim
(`#guard_msgs` doc-comment pattern, PDW12-g3 convention). All five
pins are the `[propext, Quot.sound]` subset; zero `sorryAx`. -/

open BitcoinProofs.AF.PDW19

/-- info: 'BitcoinProofs.AF.PDW19.verifyWitnessProgram_taproot_gate_silent_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_taproot_gate_silent_ok

/-- info: 'BitcoinProofs.AF.PDW19.verifyWitnessProgram_keypath' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_keypath

/-- info: 'BitcoinProofs.AF.PDW19.verifyWitnessProgram_keypath_fail_closed' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_keypath_fail_closed

/-- info: 'BitcoinProofs.AF.PDW19.verifyTaprootLeafDispatch_upgradable_ok_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyTaprootLeafDispatch_upgradable_ok_face

/-- info: 'BitcoinProofs.AF.PDW19.verifyTaprootLeafDispatch_upgradable_discourage_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyTaprootLeafDispatch_upgradable_discourage_face

/-- info: 'BitcoinProofs.AF.PDW19.verifyWitnessProgram_upgradable_leaf_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_upgradable_leaf_ok

/-- info: 'BitcoinProofs.AF.PDW19.witnessSigOps_p2wsh' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOps_p2wsh
