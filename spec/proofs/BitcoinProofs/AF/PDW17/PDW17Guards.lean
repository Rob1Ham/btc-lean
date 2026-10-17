import BitcoinProofs.AF.PDW17.PDW17

/-! # PDW17Guards — axiom pins (charter trio check).

Expected lines = the g1.out pass-1b output verbatim (the
`#guard_msgs` doc-comment pattern, PDW16Guards g3 convention;
capture run `g1bare.lean` -> g1.out, direct-lean
RC=0 after the own-target flock lake build 15/15 RC=0).
Every pin ⊆ the charter trio `[propext, Classical.choice,
Quot.sound]`; ZERO `sorryAx`. The row-face theorem
(`isOpSuccessWire_set`, the `@[rule "TPR-060"]` carrier) depends
on `[propext]` only; the eight boundary faces are `by decide`
= zero axioms. -/

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_set' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_set

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_80' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_80

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_98' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_98

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_126' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_126

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_254' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_254

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_130' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_130

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_154' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_154

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_186' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_186

/-- info: 'BitcoinProofs.AF.PDW17.isOpSuccessWire_255' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW17.isOpSuccessWire_255
