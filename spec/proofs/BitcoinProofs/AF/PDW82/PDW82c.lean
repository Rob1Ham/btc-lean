import Bitcoin.Interpreter.Defs
import Mathlib.Tactic

/-! # PDW82c — TOP-431..435: SCR-143 BIP341 annex detection

Row face: annex requires ≥2 witness items, a non-empty last item whose
first byte is `0x50`; when detected the last item is stripped from the
script-path stack and recorded in `ScriptExecutionData`.
-/

namespace BitcoinProofs.AF.PDW82c

open Bitcoin.Interpreter Bitcoin.Data

/-- SCR-143 (positive): `[sig, ann]` with `ann` non-empty and starting
`0x50` is detected as an annex, leaving `[sig]` (key path) with
`annexPresent = true` and `annexHash = SHA256(CompactSize(len(ann)) ‖ ann)`. -/
@[rule "SCR-143"]
theorem verifyWitnessProgram_annex_detected
    (fuel : Nat) (sig ann program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (h32 : program.size = 32)
    (htap : flags.taproot = true) (hann : ann.size ≠ 0)
    (htag : (byteOr ann 0).toNat = ANNEX_TAG) :
    verifyWitnessProgram fuel [sig, ann] 1 program flags pol chk false =
      (let ed : Bitcoin.Crypto.Seam.ScriptExecutionData :=
        { (default : Bitcoin.Crypto.Seam.ScriptExecutionData) with
          annexInit := true
          annexPresent := true
          annexHash := annexHash ann }
       if chk.base.checkSchnorrSignature sig program .taproot ed then .ok
       else .fail .schnorrSig) := by
  unfold verifyWitnessProgram
  rw [if_neg (by decide), if_pos (by simp [h32]), if_neg (by simp [htap])]
  simp [hann, htag]

/-- SCR-143 (≥2 gate): a singleton witness is never an annex, even when
its only item begins with `0x50`; it is treated as the key-path signature. -/
@[rule "SCR-143"]
theorem verifyWitnessProgram_no_annex_singleton
    (fuel : Nat) (sig program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (h32 : program.size = 32)
    (htap : flags.taproot = true) (htag : (byteOr sig 0).toNat = ANNEX_TAG) :
    verifyWitnessProgram fuel [sig] 1 program flags pol chk false =
      (let ed : Bitcoin.Crypto.Seam.ScriptExecutionData :=
        { (default : Bitcoin.Crypto.Seam.ScriptExecutionData) with
          annexInit := true
          annexPresent := false }
       if chk.base.checkSchnorrSignature sig program .taproot ed then .ok
       else .fail .schnorrSig) := by
  unfold verifyWitnessProgram
  rw [if_neg (by decide), if_pos (by simp [h32]), if_neg (by simp [htap])]
  simp [htag]

/-- `getLast!` of a list snoc is the appended element. -/
private theorem getLast!_concat {α : Type} [Inhabited α] (l : List α) (a : α) :
    (l ++ [a]).getLast! = a := by
  rw [List.getLast!_eq_getElem!, List.getElem!_eq_getElem?_getD,
    List.getElem?_append_right (by simp)]
  simp

/-- SCR-143 (general annex detection, interpreter.cpp:1961-1969):
for ANY witness stack of at least two items whose last item is nonempty
and begins with `0x50`, the annex is detected. The last item is stripped
from the stack (`annexPresent = true`, `annexHash = SHA256(CompactSize(len(ann)) ‖ ann)`) and the
remainder follows the key-path or script-path branch according to its
length. The original `[sig, ann]` theorem is the one-item instance. -/
@[rule "SCR-143"]
theorem verifyWitnessProgram_annex_general
    (fuel : Nat) (pre : WitnessStack) (ann program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (h32 : program.size = 32)
    (htap : flags.taproot = true) (hne : pre ≠ [])
    (hann : ann.size ≠ 0) (htag : (byteOr ann 0).toNat = ANNEX_TAG) :
    verifyWitnessProgram fuel (pre ++ [ann]) 1 program flags pol chk false =
      (let ed : Bitcoin.Crypto.Seam.ScriptExecutionData :=
        { (default : Bitcoin.Crypto.Seam.ScriptExecutionData) with
          annexInit := true
          annexPresent := true
          annexHash := annexHash ann }
       if pre.length = 1 then
         if chk.base.checkSchnorrSignature pre[0]! program .taproot ed then .ok
         else .fail .schnorrSig
       else
         let control := pre.getLast!
         if control.size < TAPROOT_CONTROL_BASE_SIZE ∨
             TAPROOT_CONTROL_MAX_SIZE < control.size ∨
             (control.size - TAPROOT_CONTROL_BASE_SIZE) % TAPROOT_CONTROL_NODE_SIZE ≠ 0 then
           .fail .taprootWrongControlSize
         else .unjudged) := by
  cases pre with
  | nil => exact absurd rfl hne
  | cons p ps =>
    have hlen : 2 ≤ (p :: (ps ++ [ann])).length := by
      simp only [List.length_cons, List.length_append, List.length_nil]
      omega
    have hlast : (p :: (ps ++ [ann])).getLast! = ann := by
      have := getLast!_concat (p :: ps) ann
      simpa using this
    have hdrop : (p :: (ps ++ [ann])).dropLast = p :: ps := by
      have := List.dropLast_concat (l₁ := p :: ps) (b := ann)
      simpa using this
    unfold verifyWitnessProgram
    rw [List.cons_append]
    have hne1 : ¬ ((p :: (ps ++ [ann])).length = 1) := by
      simp only [List.length_cons, List.length_append, List.length_nil]
      omega
    have hlast' : (p :: (ps ++ [ann])).getLast?.getD default = ann := by
      simpa using hlast
    have hempty : ¬ (ann = ByteArray.empty) := by
      intro h
      rw [h] at hann
      simp at hann
    simp [h32, htap, hann, hempty, hne1, hlast', htag, hdrop]

end BitcoinProofs.AF.PDW82c
