import BitcoinProofs.AF.PDW43.PDW43

/-! # PDW43Guards — axiom pins for TOP-211..215 (claim `30897db`).

Every row-face theorem depends on a subset of
`[propext, Classical.choice, Quot.sound]`; no `sorryAx`. Expected
messages captured from a `#print axioms` run on PDW43.lean (RC=0). -/

/-- info: 'BitcoinProofs.AF.PDW43.bestInvalidWork_ge' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.bestInvalidWork_ge

/-- info: 'BitcoinProofs.AF.PDW43.bestInvalidWork_le' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.bestInvalidWork_le

/-- info: 'BitcoinProofs.AF.PDW43.bestInvalidWork_nil' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.bestInvalidWork_nil

/-- info: 'BitcoinProofs.AF.PDW43.cachedVerdict_genesis_exempt' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.cachedVerdict_genesis_exempt

/-- info: 'BitcoinProofs.AF.PDW43.cachedVerdict_known_verdict' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.cachedVerdict_known_verdict

/-- info: 'BitcoinProofs.AF.PDW43.cachedVerdict_unknown' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.cachedVerdict_unknown

/-- info: 'BitcoinProofs.AF.PDW43.calculateNextWorkRequired_scaled' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.calculateNextWorkRequired_scaled

/-- info: 'BitcoinProofs.AF.PDW43.clampedSpan_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.clampedSpan_le

/-- info: 'BitcoinProofs.AF.PDW43.calculateNextWorkRequired_bip94_base' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.calculateNextWorkRequired_bip94_base

/-- info: 'BitcoinProofs.AF.PDW43.calculateNextWorkRequired_base_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.calculateNextWorkRequired_base_eq

/-- info: 'BitcoinProofs.AF.PDW43.minDiffWalkBack_zero' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.minDiffWalkBack_zero

/-- info: 'BitcoinProofs.AF.PDW43.minDiffWalkBack_boundary_stops' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.minDiffWalkBack_boundary_stops

/-- info: 'BitcoinProofs.AF.PDW43.minDiffWalkBack_stop_of_bits' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.minDiffWalkBack_stop_of_bits

/-- info: 'BitcoinProofs.AF.PDW43.isFinalTx_iff_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.isFinalTx_iff_row

/-- info: 'BitcoinProofs.AF.PDW43.isFinalTx_false_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW43.isFinalTx_false_iff
