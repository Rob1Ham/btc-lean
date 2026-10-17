import Bitcoin.Crypto.Taproot.Program

/-! # PDW18 — TPR-009 (route B: tags ride MY theorems, zero core writes)

Control-block size lattice on the **core** gate
`Bitcoin.Crypto.Taproot.Program.controlBlockSizeOk`: `len = 33 + 32m`,
`0 ≤ m ≤ 128`, else TAPROOT_WRONG_CONTROL_SIZE
(interpreter.cpp:1980-1982; interpreter.h:244-247 @cce32b168).
Mirrors the pre-existing untagged core twins (Program.lean:398-436) and
the LeafVersionSweep lattice; the core def/tag site (Program.lean:389)
and those twins stay untouched. -/

namespace BitcoinProofs.AF.PDW18

open Bitcoin.Crypto.Taproot.Program

@[rule "TPR-009"]
theorem controlBlockSizeOk_iff_sizes (control : ByteArray) :
    controlBlockSizeOk control = true ↔
      (33 ≤ control.size ∧ control.size ≤ 33 + 128 * 32 ∧
        (control.size - 33) % 32 = 0) := by
  unfold controlBlockSizeOk
  exact decide_eq_true_iff

theorem controlBlockSizeOk_minimal_pdw (control : ByteArray)
    (h : control.size = 33) : controlBlockSizeOk control = true :=
  (controlBlockSizeOk_iff_sizes control).mpr (by omega)

theorem controlBlockSizeOk_maximal_pdw (control : ByteArray)
    (h : control.size = 33 + 128 * 32) :
    controlBlockSizeOk control = true :=
  (controlBlockSizeOk_iff_sizes control).mpr (by omega)

theorem controlBlockSizeOk_rejects (control : ByteArray)
    (h : control.size = 32 ∨ control.size = 34 ∨ control.size = 66 ∨
      control.size = 4161) : controlBlockSizeOk control = false := by
  rcases h with h | h | h | h <;>
    · have h' : ¬ (33 ≤ control.size ∧ control.size ≤ 33 + 128 * 32 ∧
          (control.size - 33) % 32 = 0) := by rw [h]; decide
      exact decide_eq_false_iff_not.mpr h'

theorem controlBlockSizeOk_m_pdw (control : ByteArray)
    (h : controlBlockSizeOk control = true) :
    ∃ m : Nat, m ≤ 128 ∧ control.size = 33 + 32 * m := by
  obtain ⟨h₁, h₂, h₃⟩ := (controlBlockSizeOk_iff_sizes control).mp h
  refine ⟨(control.size - 33) / 32, ?_, ?_⟩
  · have hlt : control.size - 33 < 32 * 129 := by omega
    have := Nat.div_lt_of_lt_mul hlt
    omega
  · have := Nat.div_add_mod (control.size - 33) 32
    omega

end BitcoinProofs.AF.PDW18
