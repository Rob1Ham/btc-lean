import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Activation.Flags

/-! # PDW89b — lost-flip restorations: SCR-164 (tapscript ext slice) and
TXV-055 (hash-keyed block script flags). Row faces over existing core defs;
zero core writes. -/

namespace BitcoinProofs.AF.PDW89b
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Crypto.Taproot (extSlice)
open Bitcoin.Activation

/-! ## SCR-164 — tapscript sighash extension fields -/

/-- SCR-164: with both caller-contract flags set, the TAPSCRIPT extension
is `tapleaf_hash ‖ key_version(0x00) ‖ codesep_pos(4 LE)` exactly
(interpreter.cpp:1570-1576). -/
@[rule "SCR-164"]
theorem extSlice_tapscript_ext (d : ScriptExecutionData)
    (h₁ : d.tapleafHashInit = true) (h₂ : d.codesepPosInit = true) :
    extSlice SigVersion.tapscript d =
      some (d.tapleafHash ++ Bitcoin.Data.serU8 0 ++
        Bitcoin.Data.serU32 d.codesepPos) := by
  unfold extSlice
  rw [ite_eq_left rfl, ite_eq_left (by simp [h₁, h₂])]

/-- SCR-164 (fail-closed): an uninitialized tapscript extension is `none`. -/
@[rule "SCR-164"]
theorem extSlice_tapscript_uninit (d : ScriptExecutionData)
    (h : d.tapleafHashInit = false) :
    extSlice SigVersion.tapscript d = none := by
  unfold extSlice
  rw [ite_eq_left rfl, ite_eq_right (by simp [h])]

/-- SCR-164: the TAPROOT lane contributes no extension bytes. -/
@[rule "SCR-164"]
theorem extSlice_taproot_empty (d : ScriptExecutionData) :
    extSlice SigVersion.taproot d = some ByteArray.empty :=
  Bitcoin.Crypto.Taproot.extSlice_taproot d

/-! ## TXV-055 — hash-keyed GetBlockScriptFlags -/

/-- TXV-055: a script-flag exception entry REPLACES the base P2SH/WITNESS/
TAPROOT set (validation.cpp:2262-2265). -/
@[rule "TXV-055"]
theorem blockFlags_exception_row (P : ChainParams) (hash : BlockHash)
    (height : UInt32) (exf : ScriptFlags)
    (hexc : P.scriptFlagExceptions hash = some exf) :
    (getBlockScriptFlagsP P hash height).p2sh = exf.p2sh ∧
    (getBlockScriptFlagsP P hash height).witness = exf.witness ∧
    (getBlockScriptFlagsP P hash height).taproot = exf.taproot :=
  exception_replaces_base P hash height exf hexc

/-- TXV-055: away from exception blocks the base set is P2SH|WITNESS|TAPROOT
and the buried ORs never drop it (validation.cpp:2256-2260). -/
@[rule "TXV-055"]
theorem blockFlags_base_row (P : ChainParams) (hash : BlockHash) (height : UInt32)
    (hnone : P.scriptFlagExceptions hash = none) :
    (getBlockScriptFlagsP P hash height).p2sh = true ∧
    (getBlockScriptFlagsP P hash height).witness = true ∧
    (getBlockScriptFlagsP P hash height).taproot = true :=
  base_flags_p2sh_witness_taproot P hash height hnone

end BitcoinProofs.AF.PDW89b

#print axioms BitcoinProofs.AF.PDW89b.extSlice_tapscript_ext
#print axioms BitcoinProofs.AF.PDW89b.extSlice_tapscript_uninit
#print axioms BitcoinProofs.AF.PDW89b.extSlice_taproot_empty
#print axioms BitcoinProofs.AF.PDW89b.blockFlags_exception_row
#print axioms BitcoinProofs.AF.PDW89b.blockFlags_base_row
