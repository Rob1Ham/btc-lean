import BitcoinProofs.AF.PDW46.PDW46

/-! # PDW46Guards — axiom pins (charter trio check, TOP-226..230).

Every pin ⊆ [propext, Classical.choice, Quot.sound]; zero `sorryAx`.
Collected from `#print axioms` on all 13 row-face theorems.
`whitespace := lax` keeps the wrapped `#print axioms` output stable. -/

open BitcoinProofs.AF.PDW46

/-- info: 'BitcoinProofs.AF.PDW46.permittedDifficultyTransition_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms permittedDifficultyTransition_bounds

/-- info: 'BitcoinProofs.AF.PDW46.permittedDifficultyTransition_nonboundary' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms permittedDifficultyTransition_nonboundary

/-- info: 'BitcoinProofs.AF.PDW46.permittedDifficultyTransition_minDiff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms permittedDifficultyTransition_minDiff

/-- info: 'BitcoinProofs.AF.PDW46.bestInvalidWork_ge_mem' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms bestInvalidWork_ge_mem

/-- info: 'BitcoinProofs.AF.PDW46.bestInvalidWork_nil' does not depend on any axioms -/
#guard_msgs (whitespace := lax) in #print axioms bestInvalidWork_nil

/-- info: 'BitcoinProofs.AF.PDW46.bestInvalidWork_singleton' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms bestInvalidWork_singleton

/-- info: 'BitcoinProofs.AF.PDW46.merklePathRoot_sound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms merklePathRoot_sound

/-- info: 'BitcoinProofs.AF.PDW46.merklePathRoot_nil' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms merklePathRoot_nil

/-- info: 'BitcoinProofs.AF.PDW46.merklePathRoot_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms merklePathRoot_cons

/-- info: 'BitcoinProofs.AF.PDW46.minDiffWalkBack_step' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms minDiffWalkBack_step

/-- info: 'BitcoinProofs.AF.PDW46.minDiffWalkBack_stop' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms minDiffWalkBack_stop

/-- info: 'BitcoinProofs.AF.PDW46.minDiffWalkBack_skip_run' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms minDiffWalkBack_skip_run

/-- info: 'BitcoinProofs.AF.PDW46.minDiffWalkBack_nearest' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms minDiffWalkBack_nearest

/-- info: 'BitcoinProofs.AF.PDW46.assumevalidSkipped_none' does not depend on any axioms -/
#guard_msgs (whitespace := lax) in #print axioms assumevalidSkipped_none

/-- info: 'BitcoinProofs.AF.PDW46.assumevalidSkipped_at_or_above' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms assumevalidSkipped_at_or_above

/-- info: 'BitcoinProofs.AF.PDW46.assumevalidSkipped_below_no_guard' does not depend on any axioms -/
#guard_msgs (whitespace := lax) in #print axioms assumevalidSkipped_below_no_guard

/-- info: 'BitcoinProofs.AF.PDW46.assumevalidSkipped_below_guard' does not depend on any axioms -/
#guard_msgs (whitespace := lax) in #print axioms assumevalidSkipped_below_guard
