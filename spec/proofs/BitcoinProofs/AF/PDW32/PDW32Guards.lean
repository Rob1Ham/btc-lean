import BitcoinProofs.AF.PDW32.PDW32

/-! # PDW32Guards — axiom pins (charter trio check, TOP-156..160).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on the 8 row-face theorems. -/

/-- info: 'BitcoinProofs.AF.PDW32.versionOk_bip34_face' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.versionOk_bip34_face

/-- info: 'BitcoinProofs.AF.PDW32.versionOk_bip66_face' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.versionOk_bip66_face

/-- info: 'BitcoinProofs.AF.PDW32.versionOk_bip65_face' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.versionOk_bip65_face

/-- info: 'BitcoinProofs.AF.PDW32.versionOk_row_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.versionOk_row_iff

/-- info: 'BitcoinProofs.AF.PDW32.versionOk_v1_reject' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.versionOk_v1_reject

/-- info: 'BitcoinProofs.AF.PDW32.cbLengthOk_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.cbLengthOk_iff

/-- info: 'BitcoinProofs.AF.PDW32.cbLengthOk_short' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.cbLengthOk_short

/-- info: 'BitcoinProofs.AF.PDW32.cbLengthOk_long' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW32.cbLengthOk_long
