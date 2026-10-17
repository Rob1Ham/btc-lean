import BitcoinProofs.AF.PDW46b.PDW46b

/-! # PDW46bB.lean — items TOP-304..305: OP_CHECKSEQUENCEVERIFY gates/mask
(PDW46b, review RC28). Row faces for `Bitcoin.Interpreter.checkSequenceDef`
(Defs.lean:267, interpreter.cpp:1791-1848 @ cce32b168). -/

namespace BitcoinProofs.AF.PDW46b

open Bitcoin.Interpreter
open Bitcoin.Numeric (ScriptNum)

/-- SCR-129: the tx-level disable flag (bit 31 of `nSequence`) fails CSV
(the tx-version gate is the other reject branch). -/
@[rule "SCR-129"]
theorem csv_tx_disable_flag_false (env : LocktimeEnv) (n : ScriptNum)
    (h : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0) :
    checkSequenceDef env n = false := by
  unfold checkSequenceDef
  dsimp only
  by_cases hv : env.txVersion < 2
  · rw [ite_eq_left hv]
  · rw [ite_eq_right (by simp [hv]), ite_eq_left h]

/-- SCR-129 (pass direction): acceptance implies the version and disable
gates were both clear. -/
@[rule "SCR-129"]
theorem csv_pass_gates (env : LocktimeEnv) (n : ScriptNum)
    (h : checkSequenceDef env n = true) :
    ¬ env.txVersion < 2 ∧ (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0 := by
  constructor
  · intro hv
    unfold checkSequenceDef at h
    dsimp only at h
    rw [ite_eq_left hv] at h
    exact absurd h (by decide)
  · by_cases hd : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0
    · unfold checkSequenceDef at h
      dsimp only at h
      by_cases hv : env.txVersion < 2
      · rw [ite_eq_left hv] at h
        exact absurd h (by decide)
      · rw [ite_eq_right (by simp [hv]), ite_eq_left hd] at h
        exact absurd h (by decide)
    · simpa using hd

/-- SCR-130: the BIP68 mask is exactly TYPE_FLAG ‖ MASK = 0x0040ffff. -/
@[rule "SCR-130"]
theorem csv_mask_pin : SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK = 0x0040ffff := by
  decide

/-- SCR-130: masked operand above masked tx sequence ⇒ reject (no side
conditions: every earlier gate fails closed, the mask is the comparator). -/
@[rule "SCR-130"]
theorem csv_masked_above_false (env : LocktimeEnv) (n : ScriptNum)
    (h : (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) <
         (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))) :
    checkSequenceDef env n = false := by
  unfold checkSequenceDef
  dsimp only
  by_cases hv : env.txVersion < 2
  · rw [ite_eq_left hv]
  · rw [ite_eq_right (by simp [hv])]
    by_cases hd : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0
    · rw [ite_eq_left hd]
    · rw [ite_eq_right (by simp [hd])]
      by_cases ht : (((env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG ∧
            (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG) ∨
            (SEQUENCE_LOCKTIME_TYPE_FLAG ≤ (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ∧
             SEQUENCE_LOCKTIME_TYPE_FLAG ≤ (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))))
      · rw [ite_eq_right (by rw [notdecide_false ht]; decide), notdecide_false h]
      · rw [ite_eq_left (notdecide_true ht)]

/-- SCR-130 (literal mask): the row's exact `0x0040ffff` mask on both
sides — a masked operand above the masked tx sequence rejects. This is the
literal-constant face of `csv_masked_above_false` (whose hypothesis is the
symbolic `TYPE_FLAG ||| MASK`). -/
@[rule "SCR-130"]
theorem csv_masked_above_false_literal (env : LocktimeEnv) (n : ScriptNum)
    (h : (env.txSequence.toNat &&& 0x0040ffff) <
         (n.toNat &&& 0x0040ffff)) :
    checkSequenceDef env n = false := by
  apply csv_masked_above_false
  simpa [← csv_mask_pin] using h

/-- SCR-130: with version, disable and type gates passed, masked
under-run (`nMasked ≤ txMasked`) accepts — the mask-&-compare face. -/
@[rule "SCR-130"]
theorem csv_masked_under_true (env : LocktimeEnv) (n : ScriptNum)
    (hv : ¬ env.txVersion < 2)
    (hd : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0)
    (ht : (((env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG ∧
            (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG) ∨
            (SEQUENCE_LOCKTIME_TYPE_FLAG ≤ (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ∧
             SEQUENCE_LOCKTIME_TYPE_FLAG ≤ (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)))))
    (hle : (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≤
           (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))) :
    checkSequenceDef env n = true := by
  unfold checkSequenceDef
  dsimp only
  rw [ite_eq_right (by simp [hv])]
  have hd' : ¬ ((env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0) := by simpa using hd
  rw [ite_eq_right (by simp [hd']), ite_eq_right (by rw [notdecide_false ht]; decide)]
  exact notdecide_true (by omega)

end BitcoinProofs.AF.PDW46b

#print axioms BitcoinProofs.AF.PDW46b.csv_masked_above_false_literal
