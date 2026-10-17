import BitcoinProofs.AF.PDW18.PDW18

/-! # PDW18Guards — axiom pins (charter trio check, pass 3).

Expected lines = the pD.out pass-1 output verbatim (the
`#guard_msgs` doc-comment pattern). Every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio
(DECISIONS / RC-suite convention); zero `sorryAx`.
Four theorems depend on no axioms at all (the Coin record law
×3 + the 66-reject decide lane); five on [propext] (the
isSpent/_sizes iff-decide lanes + the E-band boundary faces);
three on [propext, Quot.sound] (the SCR-042 twin + the
nullFail-fires/_false lanes); four on the full trio (the
controlBlockSizeOk omega-lanes, the p0-twin-pins). -/

/-- info: 'BitcoinProofs.AF.PDW18.evalChecksigTapscript_upgradable_key_decrements' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.evalChecksigTapscript_upgradable_key_decrements

/-- info: 'BitcoinProofs.AF.PDW18.isSpent_true_iff_none' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.isSpent_true_iff_none

/-- info: 'BitcoinProofs.AF.PDW18.isSpent_false_iff_some' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.isSpent_false_iff_some

/-- info: 'BitcoinProofs.AF.PDW18.Coin_mk_eta' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.Coin_mk_eta

/-- info: 'BitcoinProofs.AF.PDW18.Coin_mk_inj' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.Coin_mk_inj

/-- info: 'BitcoinProofs.AF.PDW18.Coin_coinbase_two_face' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.Coin_coinbase_two_face

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_fires' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_fires

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_nullFail_off

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_le' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_le

/-- info: 'BitcoinProofs.AF.PDW18.cmsCleanup_fuel0' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.cmsCleanup_fuel0

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_sizes' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_sizes

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_minimal' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_minimal

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_maximal' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_maximal

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_66' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_66

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_m' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_m

/-- info: 'BitcoinProofs.AF.PDW18.controlBlockSizeOk_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW18.controlBlockSizeOk_iff
