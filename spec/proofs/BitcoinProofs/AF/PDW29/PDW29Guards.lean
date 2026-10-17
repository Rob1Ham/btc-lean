import BitcoinProofs.AF.PDW29.PDW29
import BitcoinProofs.AF.PDW29.PDW29Sigops

/-! # PDW29Guards — axiom pins for TOP-141..145.

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`. -/

/-- info: 'BitcoinProofs.AF.PDW29.proofEquivalentWork_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.proofEquivalentWork_cons

/-- info: 'BitcoinProofs.AF.PDW29.proofEquivalentWork_boundary_in' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.proofEquivalentWork_boundary_in

/-- info: 'BitcoinProofs.AF.PDW29.proofEquivalentWork_stop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.proofEquivalentWork_stop

/-- info: 'BitcoinProofs.AF.PDW29.proofEquivalentWork_row_vector' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.proofEquivalentWork_row_vector

/-- info: 'BitcoinProofs.AF.PDW29.prunedCandidates_descendant' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.prunedCandidates_descendant

/-- info: 'BitcoinProofs.AF.PDW29.prunedCandidates_survivor' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.prunedCandidates_survivor

/-- info: 'BitcoinProofs.AF.PDW29.prunedCandidates_row_vector' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.prunedCandidates_row_vector

/-- info: 'BitcoinProofs.AF.PDW29.submitVerdict_cached_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.submitVerdict_cached_iff

/-- info: 'BitcoinProofs.AF.PDW29.submitVerdict_uncached' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.submitVerdict_uncached

/-- info: 'BitcoinProofs.AF.PDW29.legacySigOpCountTx_eq' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.legacySigOpCountTx_eq

/-- info: 'BitcoinProofs.AF.PDW29.legacySigOpCountScript_bound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.legacySigOpCountScript_bound

/-- info: 'BitcoinProofs.AF.PDW29.legacySigOpCountTx_row_vector' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.legacySigOpCountTx_row_vector

/-- info: 'BitcoinProofs.AF.PDW29.txSigOpCost_decompose_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.txSigOpCost_decompose_row

/-- info: 'BitcoinProofs.AF.PDW29.txSigOpCost_coinbase_legacy' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.txSigOpCost_coinbase_legacy

/-- info: 'BitcoinProofs.AF.PDW29.txSigOpCost_ge_legacy' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.txSigOpCost_ge_legacy

/-- info: 'BitcoinProofs.AF.PDW29.txSigOpCost_row_vector' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW29.txSigOpCost_row_vector
