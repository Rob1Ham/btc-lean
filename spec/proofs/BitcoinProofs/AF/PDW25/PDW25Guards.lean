import BitcoinProofs.AF.PDW25.PDW25

/-! # PDW25Guards — axiom pins (charter trio check; the PDW12-g3 /
PDW16Guards / PDW16 pD.out convention).

Expected lines = the pD25.out pass-1 output verbatim (the
`#guard_msgs` doc-comment pattern). Every pin ⊆ the charter trio
`[propext, Classical.choice, Quot.sound]` (DECISIONS / RC-suite
convention); ZERO `sorryAx` (guards fail on any axiom-list
mismatch = sorry-freeness pinned). Three theorems depend on no
axioms at all (the `rfl` def-mirrors + the `_pure` congruence
lane); one (isPayToTaproot_p2trScript_iff, the P2 round-trip)
on the full trio (its core twin's own pin, Program.lean:553);
six on [propext]; one (classifySpend_annex_pop_keyPath) on
[propext, Quot.sound] (core pin :568). -/

/-- info: 'BitcoinProofs.AF.PDW25.p2trProgram_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.p2trProgram_eq

/-- info: 'BitcoinProofs.AF.PDW25.isPayToTaproot_p2trScript_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.isPayToTaproot_p2trScript_iff

/-- info: 'BitcoinProofs.AF.PDW25.taprootLane_gate_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.taprootLane_gate_off

/-- info: 'BitcoinProofs.AF.PDW25.taprootLane_consensus_pure' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.taprootLane_consensus_pure

/-- info: 'BitcoinProofs.AF.PDW25.isAnnex_def' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.isAnnex_def

/-- info: 'BitcoinProofs.AF.PDW25.isAnnex_empty_stack' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.isAnnex_empty_stack

/-- info: 'BitcoinProofs.AF.PDW25.isAnnex_one_item' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.isAnnex_one_item

/-- info: 'BitcoinProofs.AF.PDW25.classifySpend_one_keyPath' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.classifySpend_one_keyPath

/-- info: 'BitcoinProofs.AF.PDW25.classifySpend_annex_pop_keyPath' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.classifySpend_annex_pop_keyPath

/-- info: 'BitcoinProofs.AF.PDW25.classifySpend_many_scriptPath' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.classifySpend_many_scriptPath

/-- info: 'BitcoinProofs.AF.PDW25.classifySpend_annex_pop_scriptPath' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW25.classifySpend_annex_pop_scriptPath
