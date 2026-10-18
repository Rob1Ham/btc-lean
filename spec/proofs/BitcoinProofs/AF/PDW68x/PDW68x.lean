import BitcoinProofs.AF.PDW46b.PDW46bB
import Bitcoin.DataLaws.Laws

/-! # PDW68x.lean — TOP-361..363: full CLTV/CSV checker verdicts
(PDW68, RC29). Claim `94fac5e`. Route B, zero core writes.
Reject/pass halves of SCR-123..125/129..130 (PDW46b) are reused.
Path `AF/PDW68x/` avoids the concurrent `AF/PDW68/`. -/

namespace BitcoinProofs.AF.PDW68x

open Bitcoin.Interpreter
open Bitcoin.Numeric (ScriptNum)
open BitcoinProofs.AF.PDW46b (cltvSameType cltv_pass_type_agreed cltv_pass_le
  cltv_pass_nonfinal cltv_accept csv_pass_gates csv_masked_above_false
  csv_masked_under_true notdecide_true notdecide_false)

/-- CSV type agreement (both masked operands in the same domain). -/
def csvSameType (env : LocktimeEnv) (n : ScriptNum) : Prop :=
  let mask := SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK
  let txMasked := env.txSequence.toNat &&& mask
  let nMasked := n.toNat &&& mask
  (txMasked < SEQUENCE_LOCKTIME_TYPE_FLAG ∧ nMasked < SEQUENCE_LOCKTIME_TYPE_FLAG) ∨
  (SEQUENCE_LOCKTIME_TYPE_FLAG ≤ txMasked ∧ SEQUENCE_LOCKTIME_TYPE_FLAG ≤ nMasked)

/-- Mixed-type CSV operands are rejected before the masked compare. -/
theorem csv_mixed_type_false (env : LocktimeEnv) (n : ScriptNum)
    (h : ¬ csvSameType env n) : checkSequenceDef env n = false := by
  unfold checkSequenceDef
  dsimp only
  by_cases hv : env.txVersion < 2
  · rw [ite_eq_left hv]
  · rw [ite_eq_right (by simp [hv])]
    by_cases hd : (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0
    · rw [ite_eq_left hd]
    · rw [ite_eq_right (by simp [hd])]
      rw [ite_eq_left (notdecide_true (by simpa [csvSameType] using h))]

/-- INV-022: complete CLTV acceptance condition. -/
@[rule "INV-022"]
theorem cltv_accept_iff (env : LocktimeEnv) (n : ScriptNum) :
    checkLockTimeDef env n = true ↔
      cltvSameType env n ∧ n ≤ (env.txLockTime.toNat : Int) ∧
        env.txSequence.toNat ≠ 0xFFFFFFFF := by
  exact ⟨fun h => ⟨cltv_pass_type_agreed env n h, cltv_pass_le env n h,
      cltv_pass_nonfinal env n h⟩, fun ⟨ht, hn, hs⟩ => cltv_accept env n ht hn hs⟩

/-- INV-023: complete CSV acceptance condition. -/
@[rule "INV-023"]
theorem csv_accept_iff (env : LocktimeEnv) (n : ScriptNum) :
    checkSequenceDef env n = true ↔
      ¬ env.txVersion < 2 ∧
      (env.txSequence.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) = 0 ∧
      csvSameType env n ∧
      (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≤
        (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) := by
  constructor
  · intro h
    obtain ⟨hv, hd⟩ := csv_pass_gates env n h
    have ht : csvSameType env n := by
      by_cases hc : csvSameType env n
      · exact hc
      · exact absurd (csv_mixed_type_false env n hc) (by rw [h]; decide)
    have hle : (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≤
        (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) := by
      by_cases hc : (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≤
          (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))
      · exact hc
      · exact absurd (csv_masked_above_false env n (Nat.not_le.mp hc)) (by rw [h]; decide)
    exact ⟨hv, hd, ht, hle⟩
  · rintro ⟨hv, hd, ht, hle⟩
    exact csv_masked_under_true env n hv hd (by simpa [csvSameType] using ht) hle

/-- SCR-131: acceptance compares the raw masked values; granularity is
SequenceLocks' job. -/
@[rule "SCR-131"]
theorem csv_accept_masked_le (env : LocktimeEnv) (n : ScriptNum)
    (h : checkSequenceDef env n = true) :
    (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≤
      (env.txSequence.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) :=
  (csv_accept_iff env n).mp h |>.2.2.2

/-- SCR-131: acceptance depends on the operand only through its raw
BIP68-masked value (granularity is SequenceLocks' job). -/
@[rule "SCR-131"]
theorem csv_accept_mask_congr (env : LocktimeEnv) (n n' : ScriptNum)
    (hm : (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) =
          (n'.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))) :
    checkSequenceDef env n = true ↔ checkSequenceDef env n' = true := by
  rw [csv_accept_iff, csv_accept_iff]
  simp only [csvSameType, hm]

/-- SCR-131: the two-layer BIP68 split stated in one theorem.
(a) The script-level `OP_CHECKSEQUENCEVERIFY` verdict compares only the
raw BIP68-masked operands (`transaction.h:105,115`; `tx_verify.cpp:94-95`).
(b) The 512-second granularity is applied by SequenceLocks: a time-based
sequence's masked payload is scaled by `2^9` seconds
(`tx_verify.cpp:79-94`, `SEQUENCE_LOCKTIME_GRANULARITY = 9`). -/
@[rule "SCR-131"]
theorem csv_accept_masked_and_sequencelocks_granularity
    (env : LocktimeEnv) (n : ScriptNum) (h : checkSequenceDef env n = true)
    (mtpParent : Nat) (s : UInt32) (mtpBlock : Nat) :
    (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ≤
        (env.txSequence.toNat &&&
          (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) ∧
    (Bitcoin.DataLaws.seqTimeOk mtpParent s mtpBlock = true ↔
      mtpParent + Bitcoin.DataLaws.seqRelative s * 512 ≤ mtpBlock) ∧
    ((512 : Nat) = 2 ^ Bitcoin.DataLaws.SEQUENCE_LOCKTIME_GRANULARITY) :=
  ⟨csv_accept_masked_le env n h,
    Bitcoin.DataLaws.seqTimeOk_iff mtpParent s mtpBlock,
    Bitcoin.DataLaws.seqTimeGranularity_pow⟩

end BitcoinProofs.AF.PDW68x
