import BitcoinProofs.AF.PDW58.PDW58D

/-! # PDW58GuardsD — axiom pins for the SCR-140 BIP143 preimage faces

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Expected footprints are guarded so drift fails the build. -/

open BitcoinProofs.AF.PDW58

/-- info: 'BitcoinProofs.AF.PDW58.bip143MsgL_field_order' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143MsgL_field_order

/-- info: 'BitcoinProofs.AF.PDW58.bip143MsgL_amount_slot' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143MsgL_amount_slot

/-- info: 'BitcoinProofs.AF.PDW58.serAmountL_length' depends on axioms: [propext] -/
#guard_msgs in #print axioms serAmountL_length

/-- info: 'BitcoinProofs.AF.PDW58.bip143MsgL_amount_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143MsgL_amount_eq
