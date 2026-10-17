import Bitcoin.Interpreter.Rules

/-! # PDW60 RowsB — TOP-323/324: SCR-163, SCR-172 (review RC29).
Route B status-debt promotion on the BIP341/342 hashtype and
disabled→OP_SUCCESS predicates; zero core writes. -/

namespace BitcoinProofs.AF.PDW60

/-- SCR-163: the BIP341 hashtype predicate, char form. -/
@[rule "SCR-163"]
theorem bip341Hashtype_valid_iff (ht : UInt8) :
    Bitcoin.Interpreter.isValidBip341Hashtype ht = true
      ↔ ht ≤ 3 ∨ (0x81 ≤ ht ∧ ht ≤ 0x83) := by
  simp [Bitcoin.Interpreter.isValidBip341Hashtype, Bool.or_eq_true,
    Bool.and_eq_true]

/-- SCR-163: every other byte is rejected. -/
@[rule "SCR-163"]
theorem bip341Hashtype_invalid_iff (ht : UInt8) :
    Bitcoin.Interpreter.isValidBip341Hashtype ht = false
      ↔ ¬(ht ≤ 3 ∨ (0x81 ≤ ht ∧ ht ≤ 0x83)) := by
  simp only [Bool.eq_false_iff, ne_eq, bip341Hashtype_valid_iff]

/-- SCR-163: explicit SIGHASH_DEFAULT is in the ≤3 window; 0x04, 0x40,
0x80, 0x84, 0xff are out. -/
@[rule "SCR-163"]
theorem bip341Hashtype_matrix :
    Bitcoin.Interpreter.isValidBip341Hashtype 0x00 = true ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0x03 = true ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0x81 = true ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0x83 = true ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0x04 = false ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0x40 = false ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0x80 = false ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0x84 = false ∧
    Bitcoin.Interpreter.isValidBip341Hashtype 0xff = false := by
  decide

/-- SCR-172: EVERY legacy-disabled wire byte is an OP_SUCCESSx under
tapscript — the CVE-2010-5137 disabled set never fires there. -/
@[rule "SCR-172"]
theorem disabledWire_isOpSuccess (w : Nat)
    (h : Bitcoin.Interpreter.disabledWire w = true) :
    Bitcoin.Interpreter.isOpSuccessWire w = true := by
  simp only [Bitcoin.Interpreter.disabledWire, decide_eq_true_eq,
    List.mem_cons, List.not_mem_nil, or_false] at h
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl <;>
    decide

/-- SCR-172: the fifteen wire bytes explicitly, as a matrix. -/
@[rule "SCR-172"]
theorem disabledWire_successx_row :
    Bitcoin.Interpreter.isOpSuccessWire 0x7e = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x7f = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x80 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x81 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x83 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x84 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x85 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x86 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x8d = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x8e = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x95 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x96 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x97 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x98 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x99 = true := by
  decide


/-! ## Axiom pins (guard_msgs) -/

/-- info: 'BitcoinProofs.AF.PDW60.bip341Hashtype_valid_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.bip341Hashtype_valid_iff
/-- info: 'BitcoinProofs.AF.PDW60.bip341Hashtype_invalid_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.bip341Hashtype_invalid_iff
/-- info: 'BitcoinProofs.AF.PDW60.bip341Hashtype_matrix' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.bip341Hashtype_matrix
/-- info: 'BitcoinProofs.AF.PDW60.disabledWire_isOpSuccess' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.disabledWire_isOpSuccess
/-- info: 'BitcoinProofs.AF.PDW60.disabledWire_successx_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.disabledWire_successx_row

end BitcoinProofs.AF.PDW60
