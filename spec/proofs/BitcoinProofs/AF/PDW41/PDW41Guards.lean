import BitcoinProofs.AF.PDW41.TPR004
import BitcoinProofs.AF.PDW41.TPR006
import BitcoinProofs.AF.PDW41.TPR010
import BitcoinProofs.AF.PDW41.TPR022
import BitcoinProofs.AF.PDW41.TPR043

/-! # PDW41Guards — axiom pins for the five promoted row faces.

Every footprint ⊆ [propext, Classical.choice, Quot.sound]; zero sorryAx.
(Actual footprints are narrower: [propext] or [propext, Quot.sound].) -/

/-- info: 'BitcoinProofs.AF.PDW41.isPayToAnchor_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.isPayToAnchor_iff

/-- info: 'BitcoinProofs.AF.PDW41.isPayToAnchor_p2a_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.isPayToAnchor_p2a_row

/-- info: 'BitcoinProofs.AF.PDW41.isPayToAnchor_partition' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.isPayToAnchor_partition

/-- info: 'BitcoinProofs.AF.PDW41.annexHash_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.annexHash_row

/-- info: 'BitcoinProofs.AF.PDW41.annexHash_size32' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.annexHash_size32

/-- info: 'BitcoinProofs.AF.PDW41.annexHash_tag_included' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.annexHash_tag_included

/-- info: 'BitcoinProofs.AF.PDW41.annexHash_eq_shaAnnex' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.annexHash_eq_shaAnnex

/-- info: 'BitcoinProofs.AF.PDW41.leafVersionOf_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.leafVersionOf_row

/-- info: 'BitcoinProofs.AF.PDW41.leafVersionOf_even_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.leafVersionOf_even_row

/-- info: 'BitcoinProofs.AF.PDW41.leafVersionOf_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.leafVersionOf_le

/-- info: 'BitcoinProofs.AF.PDW41.tapscriptLeaf_even_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.tapscriptLeaf_even_row

/-- info: 'BitcoinProofs.AF.PDW41.validationWeightInit_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.validationWeightInit_row

/-- info: 'BitcoinProofs.AF.PDW41.validationWeightInit_offset' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.validationWeightInit_offset

/-- info: 'BitcoinProofs.AF.PDW41.validationWeightInit_nil' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.validationWeightInit_nil

/-- info: 'BitcoinProofs.AF.PDW41.witnessSerSize_append_single' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.witnessSerSize_append_single

/-- info: 'BitcoinProofs.AF.PDW41.validationWeightInit_strict_growth' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.validationWeightInit_strict_growth

/-- info: 'BitcoinProofs.AF.PDW41.extSlice_taproot_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.extSlice_taproot_row

/-- info: 'BitcoinProofs.AF.PDW41.extSlice_tapscript_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.extSlice_tapscript_row

/-- info: 'BitcoinProofs.AF.PDW41.extSlice_tapscript_none' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.extSlice_tapscript_none

/-- info: 'BitcoinProofs.AF.PDW41.extSlice_tapscript_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW41.extSlice_tapscript_size
