import Bitcoin.Interpreter.Rules

/-! # PDW46b.lean — items TOP-301..303: OP_CHECKLOCKTIMEVERIFY operand checks
(PDW46b, review RC28). Claim `89e1eb6`.

Row faces for the BIP65 checker `Bitcoin.Interpreter.checkLockTimeDef`
(Defs.lean:255, interpreter.cpp:1755-1788 @ cce32b168). Route B: zero core
writes; the DB rows SCR-123/124/125 were `implemented` with no theorem on
the def, only the 3253-cell differential matrix of IX04.
-/

namespace BitcoinProofs.AF.PDW46b

open Bitcoin.Interpreter
open Bitcoin.Numeric (ScriptNum)

/-- The CLTV type-agreement proposition (interpreter.cpp:1764-1768):
both operands below `LOCKTIME_THRESHOLD` (block heights) or both at/above
it (wall-clock times). -/
def cltvSameType (env : LocktimeEnv) (n : ScriptNum) : Prop :=
  ((env.txLockTime.toNat : Int) < (LOCKTIME_THRESHOLD : Int) ∧ n < (LOCKTIME_THRESHOLD : Int)) ∨
  ((LOCKTIME_THRESHOLD : Int) ≤ (env.txLockTime.toNat : Int) ∧ (LOCKTIME_THRESHOLD : Int) ≤ n)

/-- `!decide p = true` from `¬p` (Core's early-exit condition). -/
theorem notdecide_true {p : Prop} [Decidable p] (h : ¬p) : (!(decide p)) = true := by
  simp [h]

/-- `!decide p = false` from `p`. -/
theorem notdecide_false {p : Prop} [Decidable p] (h : p) : (!(decide p)) = false := by
  simp [h]

/-- SCR-123: a mixed-type pair (height vs. wall-clock) is rejected before
any numeric comparison (interpreter.cpp:1764-1768). -/
@[rule "SCR-123"]
theorem cltv_mixed_type_false (env : LocktimeEnv) (n : ScriptNum)
    (h : ¬ cltvSameType env n) : checkLockTimeDef env n = false := by
  have h' : ¬ (((env.txLockTime.toNat : Int) < (LOCKTIME_THRESHOLD : Int) ∧
      n < (LOCKTIME_THRESHOLD : Int)) ∨
      ((LOCKTIME_THRESHOLD : Int) ≤ (env.txLockTime.toNat : Int) ∧
       (LOCKTIME_THRESHOLD : Int) ≤ n)) := by simpa [cltvSameType] using h
  unfold checkLockTimeDef
  dsimp only
  rw [ite_eq_left (notdecide_true h')]

/-- SCR-123 (pass direction): an accepted CLTV therefore saw operands of
the same type. -/
@[rule "SCR-123"]
theorem cltv_pass_type_agreed (env : LocktimeEnv) (n : ScriptNum)
    (h : checkLockTimeDef env n = true) : cltvSameType env n := by
  by_cases hc : cltvSameType env n
  · exact hc
  · rw [cltv_mixed_type_false env n hc] at h
    simp at h

/-- SCR-124: an operand strictly above `txTo->nLockTime` fails
(interpreter.cpp:1772-1773). -/
@[rule "SCR-124"]
theorem cltv_above_locktime_false (env : LocktimeEnv) (n : ScriptNum)
    (h : (env.txLockTime.toNat : Int) < n) : checkLockTimeDef env n = false := by
  unfold checkLockTimeDef
  dsimp only
  by_cases ht : (((env.txLockTime.toNat : Int) < (LOCKTIME_THRESHOLD : Int) ∧
      n < (LOCKTIME_THRESHOLD : Int)) ∨
      ((LOCKTIME_THRESHOLD : Int) ≤ (env.txLockTime.toNat : Int) ∧
       (LOCKTIME_THRESHOLD : Int) ≤ n))
  · rw [ite_eq_right (by rw [notdecide_false ht]; decide), ite_eq_left h]
  · rw [ite_eq_left (notdecide_true ht)]

/-- SCR-124 (pass direction): acceptance implies `n ≤ txTo->nLockTime`. -/
@[rule "SCR-124"]
theorem cltv_pass_le (env : LocktimeEnv) (n : ScriptNum)
    (h : checkLockTimeDef env n = true) : n ≤ (env.txLockTime.toNat : Int) := by
  by_cases hc : n ≤ (env.txLockTime.toNat : Int)
  · exact hc
  · rw [cltv_above_locktime_false env n (Int.not_le.mp hc)] at h
    simp at h

/-- SCR-125: a final input (`nSequence = 0xffffffff`) can never satisfy
CLTV (interpreter.cpp:1785-1786). -/
@[rule "SCR-125"]
theorem cltv_final_input_false (env : LocktimeEnv) (n : ScriptNum)
    (h : env.txSequence.toNat = 0xFFFFFFFF) : checkLockTimeDef env n = false := by
  unfold checkLockTimeDef
  dsimp only
  by_cases ht : (((env.txLockTime.toNat : Int) < (LOCKTIME_THRESHOLD : Int) ∧
      n < (LOCKTIME_THRESHOLD : Int)) ∨
      ((LOCKTIME_THRESHOLD : Int) ≤ (env.txLockTime.toNat : Int) ∧
       (LOCKTIME_THRESHOLD : Int) ≤ n))
  · rw [ite_eq_right (by rw [notdecide_false ht]; decide)]
    by_cases hn : (env.txLockTime.toNat : Int) < n
    · rw [ite_eq_left hn]
    · rw [ite_eq_right (by simp [hn]), ite_eq_left h]
  · rw [ite_eq_left (notdecide_true ht)]

/-- SCR-125 (pass direction): acceptance implies the input is non-final. -/
@[rule "SCR-125"]
theorem cltv_pass_nonfinal (env : LocktimeEnv) (n : ScriptNum)
    (h : checkLockTimeDef env n = true) : env.txSequence.toNat ≠ 0xFFFFFFFF := by
  intro hc
  rw [cltv_final_input_false env n hc] at h
  simp at h

/-- SCR-124/125 (accept direction): type agreement, `n ≤ txLockTime` and a
non-final input are jointly sufficient. -/
@[rule "SCR-124", rule "SCR-125"]
theorem cltv_accept (env : LocktimeEnv) (n : ScriptNum)
    (ht : (((env.txLockTime.toNat : Int) < (LOCKTIME_THRESHOLD : Int) ∧
      n < (LOCKTIME_THRESHOLD : Int)) ∨
      ((LOCKTIME_THRESHOLD : Int) ≤ (env.txLockTime.toNat : Int) ∧
       (LOCKTIME_THRESHOLD : Int) ≤ n)))
    (hn : n ≤ (env.txLockTime.toNat : Int))
    (hseq : ¬ (env.txSequence.toNat = 0xFFFFFFFF)) : checkLockTimeDef env n = true := by
  unfold checkLockTimeDef
  dsimp only
  rw [ite_eq_right (by rw [notdecide_false ht]; decide)]
  rw [ite_eq_right (Int.not_lt.mpr hn)]
  rw [ite_eq_right hseq]

end BitcoinProofs.AF.PDW46b
