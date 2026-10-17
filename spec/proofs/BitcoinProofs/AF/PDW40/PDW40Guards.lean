import BitcoinProofs.AF.PDW40.PDW40

/-! # PDW40Guards — axiom pins (TOP-196..200).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW40.decTxCore_base_layout' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW40.decTxCore_base_layout

/-- info: 'BitcoinProofs.AF.PDW40.decTxCore_flag0_shortRecord' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW40.decTxCore_flag0_shortRecord

/-- info: 'BitcoinProofs.AF.PDW40.decTxCore_witness_layout' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW40.decTxCore_witness_layout

/-- info: 'BitcoinProofs.AF.PDW40.decTxCore_superfluous' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW40.decTxCore_superfluous

/-- info: 'BitcoinProofs.AF.PDW40.decTxCore_unknownFlag' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW40.decTxCore_unknownFlag
