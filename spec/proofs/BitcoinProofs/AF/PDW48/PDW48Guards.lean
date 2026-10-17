import BitcoinProofs.AF.PDW48.PDW48Finality
import BitcoinProofs.AF.PDW48.PDW48Locktime

/-! # PDW48Guards — axiom pins (charter trio check, TOP-161..165).
Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW48.isFinalTx_mono_cutoff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.isFinalTx_mono_cutoff

/-- info: 'BitcoinProofs.AF.PDW48.bip113Cutoff_switch' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.bip113Cutoff_switch

/-- info: 'BitcoinProofs.AF.PDW48.bip113Cutoff_mem'' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.bip113Cutoff_mem'

/-- info: 'BitcoinProofs.AF.PDW48.bip113_cutoff_finality_sandwich' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.bip113_cutoff_finality_sandwich

/-- info: 'BitcoinProofs.AF.PDW48.blockAllFinal_cons' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.blockAllFinal_cons

/-- info: 'BitcoinProofs.AF.PDW48.blockAllFinal_mono_cutoff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.blockAllFinal_mono_cutoff

/-- info: 'BitcoinProofs.AF.PDW48.blockAllFinal_nonfinal_poisons' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.blockAllFinal_nonfinal_poisons

/-- info: 'BitcoinProofs.AF.PDW48.bip68Enabled_row_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.bip68Enabled_row_iff

/-- info: 'BitcoinProofs.AF.PDW48.bip68Enabled_flag_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.bip68Enabled_flag_off

/-- info: 'BitcoinProofs.AF.PDW48.bip68Enabled_v1' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.bip68Enabled_v1

/-- info: 'BitcoinProofs.AF.PDW48.bip68Enabled_wire_high' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.bip68Enabled_wire_high

/-- info: 'BitcoinProofs.AF.PDW48.seqRelative_mod' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.seqRelative_mod

/-- info: 'BitcoinProofs.AF.PDW48.seqRelative_eq_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.seqRelative_eq_iff

/-- info: 'BitcoinProofs.AF.PDW48.seqRelative_pins' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.seqRelative_pins

/-- info: 'BitcoinProofs.AF.PDW48.seqRelative_height_lock' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.seqRelative_height_lock

/-- info: 'BitcoinProofs.AF.PDW48.evalSequenceLocks_row_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.evalSequenceLocks_row_iff

/-- info: 'BitcoinProofs.AF.PDW48.evalSequenceLocks_agrees' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.evalSequenceLocks_agrees

/-- info: 'BitcoinProofs.AF.PDW48.sequenceLocksOk_disabled_pass' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.sequenceLocksOk_disabled_pass

/-- info: 'BitcoinProofs.AF.PDW48.sequenceLocksOk_enabled_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW48.sequenceLocksOk_enabled_iff
