import BitcoinProofs.AF.PDW21.PDW21

/-! # PDW21Guards.lean — axiom pins for TOP-101..105
(PDW21, review RC26). Pins ⊆ `[propext, Classical.choice, Quot.sound]`. -/

namespace BitcoinProofs.AF.PDW21

/-- info: 'BitcoinProofs.AF.PDW21.sentinel_ne_real_height' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms sentinel_ne_real_height

/-- info: 'BitcoinProofs.AF.PDW21.lockpoints_mempool_face' depends on axioms: [propext] -/
#guard_msgs in
#print axioms lockpoints_mempool_face

/-- info: 'BitcoinProofs.AF.PDW21.lockpoints_real_face' does not depend on any axioms -/
#guard_msgs in
#print axioms lockpoints_real_face

/-- info: 'BitcoinProofs.AF.PDW21.muhashSet_split' depends on axioms: [propext] -/
#guard_msgs in
#print axioms muhashSet_split

/-- info: 'BitcoinProofs.AF.PDW21.muhashSet_comm' depends on axioms: [propext] -/
#guard_msgs in
#print axioms muhashSet_comm

/-- info: 'BitcoinProofs.AF.PDW21.setBestBlock_coins'' does not depend on any axioms -/
#guard_msgs in
#print axioms setBestBlock_coins'

/-- info: 'BitcoinProofs.AF.PDW21.setBestBlock_best'' does not depend on any axioms -/
#guard_msgs in
#print axioms setBestBlock_best'

/-- info: 'BitcoinProofs.AF.PDW21.connectBestBlock_coins'' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms connectBestBlock_coins'

/-- info: 'BitcoinProofs.AF.PDW21.connectBestBlock_best' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms connectBestBlock_best

/-- info: 'BitcoinProofs.AF.PDW21.defined_started' depends on axioms: [propext] -/
#guard_msgs in
#print axioms defined_started

/-- info: 'BitcoinProofs.AF.PDW21.started_locked' depends on axioms: [propext] -/
#guard_msgs in
#print axioms started_locked

/-- info: 'BitcoinProofs.AF.PDW21.started_failed' depends on axioms: [propext] -/
#guard_msgs in
#print axioms started_failed

/-- info: 'BitcoinProofs.AF.PDW21.locked_active' depends on axioms: [propext] -/
#guard_msgs in
#print axioms locked_active

/-- info: 'BitcoinProofs.AF.PDW21.active_stays' does not depend on any axioms -/
#guard_msgs in
#print axioms active_stays

/-- info: 'BitcoinProofs.AF.PDW21.bip9State_eq'' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms bip9State_eq'

/-- info: 'BitcoinProofs.AF.PDW21.bip9State_pre'' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms bip9State_pre'

end BitcoinProofs.AF.PDW21
