import BitcoinProofs.AF.PDW33.PDW33
import BitcoinProofs.AF.PDW33.PDW33b

/-! # PDW33Guards — axiom pins (charter trio, TOP-161..165).
Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

open BitcoinProofs.AF.PDW33

/-- info: 'BitcoinProofs.AF.PDW33.flagsComboOk_consensus_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms flagsComboOk_consensus_row
/-- info: 'BitcoinProofs.AF.PDW33.flagsComboOk_witness_requires_p2sh' depends on axioms: [propext] -/
#guard_msgs in #print axioms flagsComboOk_witness_requires_p2sh
/-- info: 'BitcoinProofs.AF.PDW33.flagsComboOk_witness_p2sh_ok' depends on axioms: [propext] -/
#guard_msgs in #print axioms flagsComboOk_witness_p2sh_ok
/-- info: 'BitcoinProofs.AF.PDW33.flagsComboOk_cleanstack_arm' depends on axioms: [propext] -/
#guard_msgs in #print axioms flagsComboOk_cleanstack_arm
/-- info: 'BitcoinProofs.AF.PDW33.locktimeEnvOf_version' depends on axioms: [propext] -/
#guard_msgs in #print axioms locktimeEnvOf_version
/-- info: 'BitcoinProofs.AF.PDW33.locktimeEnvOf_locktime' depends on axioms: [propext] -/
#guard_msgs in #print axioms locktimeEnvOf_locktime
/-- info: 'BitcoinProofs.AF.PDW33.locktimeEnvOf_congr_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms locktimeEnvOf_congr_row
/-- info: 'BitcoinProofs.AF.PDW33.checkLockTime_perInput_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkLockTime_perInput_row
/-- info: 'BitcoinProofs.AF.PDW33.checkSequence_perInput_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequence_perInput_row
/-- info: 'BitcoinProofs.AF.PDW33.witnessSigOps_v0_20_one_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOps_v0_20_one_row
/-- info: 'BitcoinProofs.AF.PDW33.witnessSigOps_v1_zero_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOps_v1_zero_row
/-- info: 'BitcoinProofs.AF.PDW33.witnessSigOps_v0_32' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOps_v0_32
/-- info: 'BitcoinProofs.AF.PDW33.witnessSigOps_v0_other_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOps_v0_other_zero
/-- info: 'BitcoinProofs.AF.PDW33.countWitnessSigOps_bare_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_bare_row
/-- info: 'BitcoinProofs.AF.PDW33.countWitnessSigOps_p2sh_wrapped' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_p2sh_wrapped
/-- info: 'BitcoinProofs.AF.PDW33.countWitnessSigOps_nonp2sh_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_nonp2sh_zero
/-- info: 'BitcoinProofs.AF.PDW33.MAX_BLOCK_SIGOPS_COST_row' does not depend on any axioms -/
#guard_msgs in #print axioms MAX_BLOCK_SIGOPS_COST_row
/-- info: 'BitcoinProofs.AF.PDW33.blockSigOpsCostOk_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms blockSigOpsCostOk_iff
/-- info: 'BitcoinProofs.AF.PDW33.blockSigOpsCostOk_reject' depends on axioms: [propext] -/
#guard_msgs in #print axioms blockSigOpsCostOk_reject
