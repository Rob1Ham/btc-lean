import Bitcoin.Numeric.ScriptNum

/-!
# BitcoinProofs.Theorems.Exhaust.ScriptNumBoundary4

F02: the `CScriptNum` decode domain at the 4-byte boundary, made
exhaustive. Every one-byte sign-magnitude encoding (all 256 digits —
`one_byte_256`) and every 2/3/4-byte encoding is classified —
minimal-valid vs non-minimal-but-valid vs rejected — per corrected
minimal-encoding rule (report w2-04 K1: reject iff `back & 0x7f = 0` AND
(`size ≤ 1` OR `vch[size−2] & 0x80 = 0`); the two-byte wire `0x80 0x00`
= 128 IS valid).

Ground truth: `Bitcoin.Numeric.decodeBE` / `minimalOkBE` / `setVchBE`
(`Numeric/ScriptNum.lean`, mirroring Core script.h:246-271,
376-391 @ `cce32b168`). Byte lists here are big-endian digit lists
(most-significant first), the Lean-internal convention.

Structure:

* §1 closed forms: `minimalOkBE` depends only on the top two bytes;
  `setVchBE` value formulas for lengths 1-4.
* §2 the decode matrices at the consensus width 4 (SCR-080):
  `decode1_matrix` … `decode4_matrix`, the width-4 master
  classification `boundary_matrix_4byte`, and `decode_none_iff`.
* §3 the decided boundary rows: the 0x7f/0x80/0xff patterns at every
  decisive position — the corrected case, the negative zeros, the
  2^31−1 extremes, the 5-byte −2^31 CLTV/CSV special case (SCR-081) and
  the width-4 overflow gate.

All rows cross-checked against an independent python3 re-implementation
of the corrected rule (scratch `F02/gen_matrix.py`; 622-line matrix
diffed against the Lean runner output).
-/

namespace BitcoinProofs.Theorems.Exhaust.ScriptNumBoundary4

open Bitcoin.Numeric

/-! ## §1 Closed forms of the ingredients -/

/-- The empty vector is trivially minimal (decodes to `0`). -/
theorem minimalOkBE_nil : minimalOkBE [] = true := rfl

/-- One-byte minimality: exactly the digits with `d % 128 ≠ 0`. In
particular `0x00` (zero) and `0x80` (negative zero, SCR-083) are
non-minimal as one-byte encodings. -/
theorem minimalOkBE_singleton (d : Nat) :
    minimalOkBE [d] = decide (d % 128 ≠ 0) := by
  by_cases hd : d % 128 = 0
  · simp [minimalOkBE, hd]
  · simp [minimalOkBE, hd]

/-- For length ≥ 2, minimality depends only on the two most significant
bytes: reject iff the top byte minus its sign bit is zero AND the
second byte's high bit is clear (script.h:252-268). -/
theorem minimalOkBE_cons2 (d e : Nat) (t : List Nat) :
    minimalOkBE (d :: e :: t) = decide (d % 128 ≠ 0 ∨ e ≥ 128) := by
  by_cases hd : d % 128 = 0
  · simp [minimalOkBE, hd]
  · simp [minimalOkBE, hd]

/-- `set_vch` on a single byte (script.h:376-391). -/
theorem setVchBE_singleton (d : Nat) :
    setVchBE [d] = if d < 128 then ((d : Int)) else -(((d - 128 : Nat) : Int)) := by
  simp [setVchBE, magOfBE]

/-- `set_vch` on two big-endian bytes. -/
theorem setVchBE_pair (d e : Nat) :
    setVchBE [d, e] =
      if d < 128 then (((d * 256 + e : Nat) : Int))
      else -((((d - 128) * 256 + e : Nat) : Int)) := by
  simp [setVchBE, magOfBE]

/-- `set_vch` on three big-endian bytes. -/
theorem setVchBE_triple (d e f : Nat) :
    setVchBE [d, e, f] =
      if d < 128 then (((d * 256 ^ 2 + (e * 256 + f) : Nat) : Int))
      else -((((d - 128) * 256 ^ 2 + (e * 256 + f) : Nat) : Int)) := by
  simp [setVchBE, magOfBE]

/-- `set_vch` on four big-endian bytes: the full 4-byte magnitude. -/
theorem setVchBE_quad (d e f g : Nat) :
    setVchBE [d, e, f, g] =
      if d < 128 then (((d * 256 ^ 3 + (e * 256 ^ 2 + (f * 256 + g)) : Nat) : Int))
      else -((((d - 128) * 256 ^ 3 + (e * 256 ^ 2 + (f * 256 + g)) : Nat) : Int)) := by
  simp [setVchBE, magOfBE]

/-! ## §2 The decode matrices at consensus width 4 (SCR-080) -/

/-- Below the width gate, decode fails exactly under the minimal-encoding
rejection (corrected rule). -/
theorem decodeBE_le (m : Bool) (maxSize : Nat) (l : List Nat)
    (hlen : l.length ≤ maxSize) :
    decodeBE m maxSize l =
      if m ∧ minimalOkBE l = false then none else some (setVchBE l) := by
  unfold decodeBE
  rw [ite_eq_right (show ¬ l.length > maxSize from by omega)]
  cases hm : minimalOkBE l with
  | false => cases m <;> simp [hm]
  | true => cases m <;> simp [hm]

/-- **One-byte matrix (exhaustive over all 256 digits).** `0x00` and
`0x80` are the two rejected one-byte encodings under `fRequireMinimal`. -/
theorem decode1_matrix (m : Bool) (d : Nat) :
    decodeBE m 4 [d] =
      if m ∧ d % 128 = 0 then none else some (setVchBE [d]) := by
  rw [decodeBE_le m 4 [d] (by simp)]
  by_cases hm : m
  · by_cases hd : d % 128 = 0
    · have hmin : minimalOkBE [d] = false := by simp [minimalOkBE, hd]
      simp [hm, hd, hmin]
    · have hmin : minimalOkBE [d] = true := by simp [minimalOkBE, hd]
      simp [hm, hd, hmin, setVchBE_singleton]
  · simp [hm, setVchBE_singleton]

/-- The exhaustive 1-byte matrix: all 256 one-byte sign-magnitude
encodings (indeed every `d : ℕ`) classified at the consensus width. -/
theorem one_byte_256 (m : Bool) (d : Nat) (_hd : d < 256) :
    decodeBE m 4 [d] =
      if m ∧ d % 128 = 0 then none
      else some (if d < 128 then ((d : Int)) else -(((d - 128 : Nat) : Int))) := by
  rw [decode1_matrix m d, setVchBE_singleton]

/-- **Two-byte matrix.** Rejection needs the top byte's magnitude zero
AND the second byte's high bit clear — so `[0x00, 0x80] = 128` IS
minimal-valid (correction), while `[0x80, 0x00]` (two-byte
negative zero) is not. -/
theorem decode2_matrix (m : Bool) (d e : Nat) :
    decodeBE m 4 [d, e] =
      if m ∧ d % 128 = 0 ∧ e < 128 then none else some (setVchBE [d, e]) := by
  rw [decodeBE_le m 4 [d, e] (by simp)]
  by_cases hm : m
  · by_cases hd : d % 128 = 0
    · have h2 : minimalOkBE [d, e] = decide (e ≥ 128) := by simp [minimalOkBE, hd]
      by_cases he : e ≥ 128
      · have hmin : minimalOkBE [d, e] = true := h2.trans (by simp [he])
        simp [hm, hd, he, hmin, setVchBE_pair]
      · have he2 : e < 128 := by omega
        have hmin : minimalOkBE [d, e] = false := h2.trans (by simp [he])
        simp [hm, hd, he2, hmin]
    · simp [hm, hd, minimalOkBE, setVchBE_pair]
  · simp [hm, setVchBE_pair]

/-- **Three-byte matrix.** Same boundary condition on the top two bytes;
the third byte only feeds the magnitude. -/
theorem decode3_matrix (m : Bool) (d e f : Nat) :
    decodeBE m 4 [d, e, f] =
      if m ∧ d % 128 = 0 ∧ e < 128 then none else some (setVchBE [d, e, f]) := by
  rw [decodeBE_le m 4 [d, e, f] (by simp)]
  by_cases hm : m
  · by_cases hd : d % 128 = 0
    · have h2 : minimalOkBE [d, e, f] = decide (e ≥ 128) := by simp [minimalOkBE, hd]
      by_cases he : e ≥ 128
      · have hmin : minimalOkBE [d, e, f] = true := h2.trans (by simp [he])
        simp [hm, hd, he, hmin, setVchBE_triple]
      · have he2 : e < 128 := by omega
        have hmin : minimalOkBE [d, e, f] = false := h2.trans (by simp [he])
        simp [hm, hd, he2, hmin]
    · simp [hm, hd, minimalOkBE, setVchBE_triple]
  · simp [hm, setVchBE_triple]

/-- **Four-byte matrix.** The full 4-byte boundary: at width 4 an
encoding is rejected (under `fRequireMinimal`) exactly when its top byte
is `0x00`/`0x80` and its second byte is below `0x80`. -/
theorem decode4_matrix (m : Bool) (d e f g : Nat) :
    decodeBE m 4 [d, e, f, g] =
      if m ∧ d % 128 = 0 ∧ e < 128 then none else some (setVchBE [d, e, f, g]) := by
  rw [decodeBE_le m 4 [d, e, f, g] (by simp)]
  by_cases hm : m
  · by_cases hd : d % 128 = 0
    · have h2 : minimalOkBE [d, e, f, g] = decide (e ≥ 128) := by simp [minimalOkBE, hd]
      by_cases he : e ≥ 128
      · have hmin : minimalOkBE [d, e, f, g] = true := h2.trans (by simp [he])
        simp [hm, hd, he, hmin, setVchBE_quad]
      · have he2 : e < 128 := by omega
        have hmin : minimalOkBE [d, e, f, g] = false := h2.trans (by simp [he])
        simp [hm, hd, he2, hmin]
    · simp [hm, hd, minimalOkBE, setVchBE_quad]
  · simp [hm, setVchBE_quad]

/-- **Width-4 master classification:** decode fails iff the vector
overflows the 4-byte width (SCR-079/080) or trips the minimal-encoding
gate (SCR-083/084). -/
theorem decode_none_iff (m : Bool) (l : List Nat) :
    decodeBE m 4 l = none ↔ 4 < l.length ∨ (m ∧ minimalOkBE l = false) := by
  by_cases h4 : 4 < l.length
  · simp [decodeBE, h4]
  · have hlen : l.length ≤ 4 := by omega
    rw [decodeBE_le m 4 l hlen]
    have hnone : ¬ (some (setVchBE l) = none) := by simp
    by_cases h : m ∧ minimalOkBE l = false
    · simp [h]
    · simp [h, hnone, h4]

/-- **The decisive boundary matrix.** For every big-endian digit list the
decode outcome at width 4 is decided by the top two bytes alone (length
≥ 2), by the single top byte (length 1), by nothing at all (empty
vector), or by the width gate (length ≥ 5). -/
theorem boundary_matrix_4byte (m : Bool) (l : List Nat) :
    decodeBE m 4 l =
      match l with
      | [] => some 0
      | [d] => if m ∧ d % 128 = 0 then none else some (setVchBE [d])
      | [d, e] => if m ∧ d % 128 = 0 ∧ e < 128 then none else some (setVchBE [d, e])
      | [d, e, f] => if m ∧ d % 128 = 0 ∧ e < 128 then none else some (setVchBE [d, e, f])
      | [d, e, f, g] =>
          if m ∧ d % 128 = 0 ∧ e < 128 then none else some (setVchBE [d, e, f, g])
      | _ => none := by
  cases l with
  | nil => simp [decodeBE, minimalOkBE, setVchBE]
  | cons d t =>
    cases t with
    | nil => exact decode1_matrix m d
    | cons e t' =>
      cases t' with
      | nil => exact decode2_matrix m d e
      | cons f t'' =>
        cases t'' with
        | nil => exact decode3_matrix m d e f
        | cons g t''' =>
          cases t''' with
          | nil => exact decode4_matrix m d e f g
          | cons x t'''' =>
            have h4 : (d :: e :: f :: g :: x :: t'''').length > 4 := by
              simp only [List.length_cons]
              omega
            simp [decodeBE, h4]

/-! ## §3 The decided boundary rows -/

/-! ### One-byte rows (representatives of the 256-case matrix) -/

theorem row1_00_min : decodeBE true 4 [0x00] = none := by decide
theorem row1_00_nonmin : decodeBE false 4 [0x00] = some 0 := by decide
theorem row1_01 : decodeBE true 4 [0x01] = some 1 := by decide
theorem row1_7f : decodeBE true 4 [0x7f] = some 127 := by decide
theorem row1_80_min : decodeBE true 4 [0x80] = none := by decide
theorem row1_80_nonmin : decodeBE false 4 [0x80] = some 0 := by decide
theorem row1_ff : decodeBE true 4 [0xff] = some (-127) := by decide

/-! ### Two-byte rows: the 0x7f/0x80 boundary on both top positions -/

theorem row2_00_01_min : decodeBE true 4 [0x00, 0x01] = none := by decide
theorem row2_00_01_nonmin : decodeBE false 4 [0x00, 0x01] = some 1 := by decide
theorem row2_00_7f_min : decodeBE true 4 [0x00, 0x7f] = none := by decide
theorem row2_00_7f_nonmin : decodeBE false 4 [0x00, 0x7f] = some 127 := by decide
/-- corrected case: the two-byte wire `0x80 0x00` = 128 IS
minimal-valid (the `0x80` rides on the *second* byte). -/
theorem row2_00_80 : decodeBE true 4 [0x00, 0x80] = some 128 := by decide
/-- Two-byte negative zero: valid only without the minimal gate. -/
theorem row2_80_00_min : decodeBE true 4 [0x80, 0x00] = none := by decide
theorem row2_80_00_nonmin : decodeBE false 4 [0x80, 0x00] = some 0 := by decide
theorem row2_80_80 : decodeBE true 4 [0x80, 0x80] = some (-128) := by decide
theorem row2_80_ff : decodeBE true 4 [0x80, 0xff] = some (-255) := by decide
theorem row2_7f_ff : decodeBE true 4 [0x7f, 0xff] = some 32767 := by decide
theorem row2_ff_7f : decodeBE true 4 [0xff, 0x7f] = some (-32639) := by decide

/-! ### Three-byte rows: the boundary persists unchanged -/

theorem row3_00_00_01_min : decodeBE true 4 [0x00, 0x00, 0x01] = none := by decide
theorem row3_00_00_01_nonmin : decodeBE false 4 [0x00, 0x00, 0x01] = some 1 := by decide
theorem row3_00_80_00 : decodeBE true 4 [0x00, 0x80, 0x00] = some 32768 := by decide
theorem row3_00_80_80 : decodeBE true 4 [0x00, 0x80, 0x80] = some 32896 := by decide
/-- Three-byte negative zero. -/
theorem row3_80_00_00_min : decodeBE true 4 [0x80, 0x00, 0x00] = none := by decide
theorem row3_80_00_00_nonmin : decodeBE false 4 [0x80, 0x00, 0x00] = some 0 := by decide
theorem row3_7f_ff_ff : decodeBE true 4 [0x7f, 0xff, 0xff] = some 8388607 := by decide
theorem row3_ff_80_00 : decodeBE true 4 [0xff, 0x80, 0x00] = some (-8355840) := by decide

/-! ### Four-byte rows: the full-width boundary -/

theorem row4_00_00_00_01_min : decodeBE true 4 [0x00, 0x00, 0x00, 0x01] = none := by decide
theorem row4_00_00_00_01_nonmin :
    decodeBE false 4 [0x00, 0x00, 0x00, 0x01] = some 1 := by decide
/-- corrected case one width up: wire `00 00 00 80` = 128,
rejected as non-minimal. -/
theorem row4_00_00_00_80_min : decodeBE true 4 [0x00, 0x00, 0x00, 0x80] = none := by decide
theorem row4_00_00_00_80_nonmin :
    decodeBE false 4 [0x00, 0x00, 0x00, 0x80] = some 128 := by decide
theorem row4_00_80_00_00 : decodeBE true 4 [0x00, 0x80, 0x00, 0x00] = some 8388608 := by decide
/-- Four-byte negative zero. -/
theorem row4_80_00_00_00_min : decodeBE true 4 [0x80, 0x00, 0x00, 0x00] = none := by decide
theorem row4_80_00_00_00_nonmin : decodeBE false 4 [0x80, 0x00, 0x00, 0x00] = some 0 := by
  decide
/-- `-1` in four bytes: decodes, but is non-minimal (1 byte suffices). -/
theorem row4_80_00_00_01_min : decodeBE true 4 [0x80, 0x00, 0x00, 0x01] = none := by decide
theorem row4_80_00_00_01_nonmin :
    decodeBE false 4 [0x80, 0x00, 0x00, 0x01] = some (-1) := by decide
/-- The maximal 4-byte value: `2^31 − 1` (THM-008's carry bound is sharp). -/
theorem row4_7f_ff_ff_ff : decodeBE true 4 [0x7f, 0xff, 0xff, 0xff] = some 2147483647 := by
  decide
theorem row4_ff_ff_ff_ff : decodeBE true 4 [0xff, 0xff, 0xff, 0xff] = some (-2147483647) := by
  decide
theorem row4_00_ff_ff_ff : decodeBE true 4 [0x00, 0xff, 0xff, 0xff] = some 16777215 := by
  decide

/-! ### Width-gate rows (SCR-079/080/081) -/

/-- The empty vector decodes to `0` (both modes). -/
theorem row0_empty : decodeBE true 4 [] = some 0 := by decide
/-- Five bytes never decode at the default width 4. -/
theorem row5_overflow_min : decodeBE true 4 [0x00, 0x00, 0x00, 0x80, 0x01] = none := by decide
theorem row5_overflow_nonmin : decodeBE false 4 [0x00, 0x00, 0x00, 0x80, 0x01] = none := by
  decide
/-- `−2^31` has a 5-byte minimal encoding (wire `00 00 00 80 80`) — the
only int64 excluded from width 4; CLTV/CSV widen to 5 precisely for it
(SCR-081, K2). -/
theorem row5_minus2pow31_w5 :
    decodeBE true 5 [0x80, 0x80, 0x00, 0x00, 0x00] = some (-2147483648) := by decide
theorem row5_minus2pow31_w4 :
    decodeBE true 4 [0x80, 0x80, 0x00, 0x00, 0x00] = none := by decide

end BitcoinProofs.Theorems.Exhaust.ScriptNumBoundary4
