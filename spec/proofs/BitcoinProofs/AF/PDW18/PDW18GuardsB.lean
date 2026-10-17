import BitcoinProofs.AF.PDW18.SCR042
import BitcoinProofs.AF.PDW18.TPR009
import BitcoinProofs.AF.PDW18.INV051
import BitcoinProofs.AF.PDW18.BLK101
import BitcoinProofs.AF.PDW18.INV114

/-! # PDW18Guards — axiom pins (charter trio check).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`
(no `sorry` in the five modules). Expected lines are the direct-lean
`#print axioms` output verbatim, pinned with `#guard_msgs`. -/

/-- info: 'BitcoinProofs.AF.PDW18.evalChecksigTapscript_upgradable_key_decrements' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.evalChecksigTapscript_upgradable_key_decrements

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_iff_sizes' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_iff_sizes

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_minimal_pdw' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_minimal_pdw

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_maximal_pdw' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_maximal_pdw

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_rejects' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_rejects

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_m_pdw' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_m_pdw

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_fires' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_fires

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_off

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_boundary_i' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_boundary_i

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_boundary_fuel' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_boundary_fuel

/-- info: 'BitcoinProofs.AF.PDW18.Coin_eta' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.Coin_eta

/-- info: 'BitcoinProofs.AF.PDW18.Coin_mk_inj' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.Coin_mk_inj

/-- info: 'BitcoinProofs.AF.PDW18.Coin_coinbase_bit' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.Coin_coinbase_bit

/-- info: 'BitcoinProofs.AF.PDW18.isSpent_true_iff_none' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.isSpent_true_iff_none

/-- info: 'BitcoinProofs.AF.PDW18.isSpent_false_iff_some' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.isSpent_false_iff_some

/-- info: 'BitcoinProofs.AF.PDW18.isSpent_none' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.isSpent_none

/-- info: 'BitcoinProofs.AF.PDW18.isSpent_some' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.isSpent_some
