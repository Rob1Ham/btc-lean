import Bitcoin.Crypto.Taproot.Sighash

/-! # PDW41/TPR043.lean — TPR-043 row face (BIP342 ext_flag / key_version)

Claim v3 (yield TPR-012 -> PDW56). Route B, zero core writes.

TPR-043: the BIP342 extension slice — `ext_flag = 0` for TAPROOT, `1`
for TAPSCRIPT, and the tapscript extension's key_version byte is 0
(interpreter.cpp:1568-1576). Row faces: the empty TAPROOT lane, the
TAPSCRIPT slice layout, the fail-closed init gate, and its size. -/

namespace BitcoinProofs.AF.PDW41

open Bitcoin.Crypto.Taproot
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Data (serU8 serU32)

/-- TPR-043 (TAPROOT lane): `ext_flag = 0` contributes no extension
bytes to the SigMsg. -/
@[rule "TPR-043"]
theorem extSlice_taproot_row (d : ScriptExecutionData) :
    extSlice SigVersion.taproot d = some ByteArray.empty :=
  Bitcoin.Crypto.Taproot.extSlice_taproot d

/-- TPR-043 (TAPSCRIPT lane): with both init flags set, the extension is
`tapleaf_hash ‖ key_version(0x00) ‖ codesep_pos(4 LE)`. -/
theorem extSlice_tapscript_row (d : ScriptExecutionData)
    (h₁ : d.tapleafHashInit = true) (h₂ : d.codesepPosInit = true) :
    extSlice SigVersion.tapscript d =
      some (d.tapleafHash ++ serU8 0 ++ serU32 d.codesepPos) := by
  unfold extSlice
  rw [ite_eq_left rfl, ite_eq_left (by simp [h₁, h₂])]

/-- TPR-043 (fail-closed): an uninitialized tapscript extension yields
`none` (Core asserts; the seam renders it as a failed sighash). -/
theorem extSlice_tapscript_none (d : ScriptExecutionData)
    (h : d.tapleafHashInit = false) :
    extSlice SigVersion.tapscript d = none := by
  unfold extSlice
  rw [ite_eq_left rfl, ite_eq_right (by simp [h])]

/-- TPR-043 (size): the TAPSCRIPT extension is `32 + 1 + 4` bytes for a
32-byte tapleaf hash — key_version is exactly one zero byte. -/
theorem extSlice_tapscript_size (d : ScriptExecutionData)
    (h₁ : d.tapleafHashInit = true) (h₂ : d.codesepPosInit = true)
    (hs : d.tapleafHash.size = 32) :
    (extSlice SigVersion.tapscript d).map (fun b => b.size) = some 37 := by
  rw [extSlice_tapscript_row d h₁ h₂]
  simp [Bitcoin.Crypto.Taproot.serU8_size, Bitcoin.Crypto.Taproot.serU32_size, hs]

/-- TPR-043 row face (both halves): the interpreter's `ext_flag` mapping is
TAPROOT ⇒ 0 and TAPSCRIPT ⇒ 1, and the tapscript extension's
`key_version` byte is 0 (interpreter.cpp:1496-1508, 1570-1576). This
supersedes the tapscript-only `extSlice_tapscript_row` for the row claim. -/
@[rule "TPR-043"]
theorem extFlag_keyVersion_bip342 (d : ScriptExecutionData)
    (h₁ : d.tapleafHashInit = true) (h₂ : d.codesepPosInit = true) :
    extFlagOf SigVersion.taproot = some 0 ∧
    extFlagOf SigVersion.tapscript = some 1 ∧
    extSlice SigVersion.tapscript d =
      some (d.tapleafHash ++ serU8 0 ++ serU32 d.codesepPos) :=
  ⟨rfl, rfl, extSlice_tapscript_row d h₁ h₂⟩

end BitcoinProofs.AF.PDW41
