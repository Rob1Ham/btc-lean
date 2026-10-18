import Bitcoin.Interpreter.Defs

/-! # PDW95b — SCR-051 / SCR-157 numeric-operand faces.

`decodeNum` is the Lean `CScriptNum(vch, fRequireMinimal, nMaxNumSize)`
wrapper. SCR-051 ("numeric operands always minimal") is honest only as
the flag-conditional statement: the constructor rejects a non-minimal
vector whenever `pol.minimalData = true` (P3pol). SCR-157's CHECKSIGADD
`num` operand adds the unconditional 4-byte width bound. The absolute
"always" reading (i.e. minimal even with the flag off) is FALSE in the
model and in Core; see the counterexample below.

Disposition: SCR-051 is a **policy-conditional** row, not a consensus
rule. The rule DB entry currently carries `consensus: true` and the
"always minimal" summary; that entry overstates the proved statement and
must be reclassified (`consensus: false`, summary narrowed to
"MINIMALDATA-gated"). The `@[rule "SCR-051"]` tags here are traceability
tags on the flag-conditional theorems, not a consensus claim. -/

namespace BitcoinProofs.AF.PDW95
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Crypto.Seam

/-- Lean 4.34 core ships no `DecidableEq (Except α β)`. -/
instance instDecEqExcept95b {α β : Type} [DecidableEq α] [DecidableEq β] :
    DecidableEq (Except α β)
  | .error e, .error e' =>
      match decEq e e' with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.error.inj h2))
  | .ok a, .ok b =>
      match decEq a b with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.ok.inj h2))
  | .error _, .ok _ => isFalse (by intro h; simp at h)
  | .ok _, .error _ => isFalse (by intro h; simp at h)

theorem decodeBE_length_le {minimal : Bool} {maxSize : Nat} {l : List Nat}
    {n : Int} (h : decodeBE minimal maxSize l = some n) : l.length ≤ maxSize := by
  unfold decodeBE at h
  split at h
  · simp at h
  · omega

theorem decodeBE_minimal_required {minimal : Bool} {maxSize : Nat} {l : List Nat}
    {n : Int} (h : decodeBE minimal maxSize l = some n) (hm : minimal = true) :
    minimalOkBE l = true := by
  unfold decodeBE at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · rename_i h2
      by_cases hc : minimalOkBE l = true
      · exact hc
      · exact absurd ⟨hm, hc⟩ h2

/-- The `decodeNum` width check: a decoded operand fits `maxSize`. -/
theorem decodeNum_length_le {pol : PolicyFlags} {b : ByteArray} {maxSize : Nat}
    {n : ScriptNum} (h : decodeNum pol b maxSize = .ok n) : b.size ≤ maxSize := by
  unfold decodeNum at h
  cases hd : decodeScriptNum b pol.minimalData maxSize with
  | none => rw [hd] at h; simp at h
  | some m =>
    unfold decodeScriptNum at hd
    have hl := decodeBE_length_le hd
    simpa [bytesOf_length] using hl

/-- SCR-051: under MINIMALDATA the constructor accepts only minimal
encodings (`minimalOkBE` on the big-endian view). -/
@[rule "SCR-051"]
theorem decodeNum_minimal {pol : PolicyFlags} {b : ByteArray} {maxSize : Nat}
    {n : ScriptNum} (h : decodeNum pol b maxSize = .ok n)
    (hm : pol.minimalData = true) :
    minimalOkBE (bytesOf b).reverse = true := by
  unfold decodeNum at h
  cases hd : decodeScriptNum b pol.minimalData maxSize with
  | none => rw [hd] at h; simp at h
  | some m =>
    unfold decodeScriptNum at hd
    exact decodeBE_minimal_required hd hm

/-- SCR-051 note (honesty): with the policy flag off a non-minimal
encoding is accepted — so "always minimal" needs the flag. -/
@[rule "SCR-051"]
theorem decodeNum_minimal_off_accepts_nonminimal :
    decodeNum { minimalData := false } (ByteArray.mk #[0x01, 0x00]) 4 = .ok 1 := by
  decide

/-- SCR-157: CHECKSIGADD's `num` operand decodes with `maxSize = 4`, so
a successful step forces `num.size ≤ 4` unconditionally. -/
@[rule "SCR-157"]
theorem checksigAddStep_num_size {pol : PolicyFlags} {chk : ScriptChecker}
    {ed : ScriptExecutionData} {sig num pk : ByteArray} {vw : Option Int}
    {n : ScriptNum} {vw' : Option Int}
    (h : checksigAddStep pol chk ed sig num pk vw = .ok (n, vw')) :
    num.size ≤ 4 := by
  unfold checksigAddStep at h
  split at h
  · simp at h
  · rename_i n0 hdec
    split at h
    · simp at h
    · exact decodeNum_length_le hdec

/-- SCR-157: the same operand is minimal whenever MINIMALDATA is set. -/
@[rule "SCR-157"]
theorem checksigAddStep_num_minimal {pol : PolicyFlags} {chk : ScriptChecker}
    {ed : ScriptExecutionData} {sig num pk : ByteArray} {vw : Option Int}
    {n : ScriptNum} {vw' : Option Int}
    (h : checksigAddStep pol chk ed sig num pk vw = .ok (n, vw'))
    (hm : pol.minimalData = true) :
    minimalOkBE (bytesOf num).reverse = true := by
  unfold checksigAddStep at h
  split at h
  · simp at h
  · rename_i n0 hdec
    split at h
    · simp at h
    · exact decodeNum_minimal hdec hm

end BitcoinProofs.AF.PDW95
