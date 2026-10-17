import Bitcoin.Interpreter.Defs
import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Crypto.Seam.Interface

/-! # PDW95e — SCR-104, SCR-164, TPR-045 row faces.

* SCR-104: the LOW_S policy gate rejects exactly the signatures whose
  DER `s` exceeds `SIG_S_HALF_ORDER` (BIP146).
* SCR-164: tapscript's sighash extension slice is
  `tapleaf_hash ‖ 0x00 ‖ codeseparator_pos` (key_version = 0 pinned).
* TPR-045: `codesepPos` defaults to 0xFFFFFFFF (uninitialized) and the
  extension slice is gated on `codesepPosInit`.

Residual for TPR-045 (precise): the executable model has no tapscript
opcode-index counter — the interpreter threads `codeSep` as a *byte
offset* and never populates `codesepPos` from it. The opcode-index
semantics ("counts parsed-but-unexecuted opcodes; multi-byte push = 1")
is therefore NOT proved here; only the seam default and gate are. -/

namespace BitcoinProofs.AF.PDW95
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Crypto.Seam Bitcoin.Activation Bitcoin.Data
open Bitcoin.Crypto.Taproot

/-! ## SCR-104 — LOW_S policy gate (BIP146) -/

/-- SCR-104: on a valid DER encoding, `checkLowS` accepts iff the
scanned `s` value is ≤ half the group order. -/
@[rule "SCR-104"]
theorem checkLowS_iff (sigNoHT : ByteArray)
    (h : isValidSigEncoding (sigNoHT.push 0x01) = true) :
    checkLowS sigNoHT = true ↔
      (List.range (byteOr sigNoHT (5 + (byteOr sigNoHT 3).toNat)).toNat).foldl
        (fun acc j => acc * 256 + (byteOr sigNoHT
          (6 + (byteOr sigNoHT 3).toNat + j)).toNat) 0 ≤ SIG_S_HALF_ORDER := by
  unfold checkLowS
  simp [h]

/-- SCR-104: the `CheckSignatureEncoding` high-S branch fires exactly
when the policy bit is set and `checkLowS` fails. -/
@[rule "SCR-104"]
theorem checkSigEncoding_highS_iff (flags : ScriptFlags) (pol : PolicyFlags)
    (sig : ByteArray) (hsz : sig.size ≠ 0)
    (hder : isValidSigEncoding sig = true) (hlow : pol.lowS = true) :
    checkSigEncoding flags pol sig = some .sigHighS ↔
      checkLowS (sig.extract 0 (sig.size - 1)) = false := by
  unfold checkSigEncoding
  simp [hsz, hder, hlow]

/-! ## SCR-164 — tapscript sighash extension fields -/

/-- SCR-164: tapscript's ext slice = tapleaf hash ‖ key_version 0 ‖
codeseparator_pos (interpreter.cpp:1570-1576). -/
@[rule "SCR-164"]
theorem extSlice_tapscript (d : ScriptExecutionData)
    (h₁ : d.tapleafHashInit = true) (h₂ : d.codesepPosInit = true) :
    extSlice .tapscript d =
      some (d.tapleafHash ++ serU8 0 ++ serU32 d.codesepPos) := by
  simp [extSlice, h₁, h₂]

/-- SCR-164: without both ext fields initialized the slice is absent. -/
@[rule "SCR-164"]
theorem extSlice_tapscript_none (d : ScriptExecutionData)
    (h : d.tapleafHashInit = false ∨ d.codesepPosInit = false) :
    extSlice .tapscript d = none := by
  rcases h with h | h <;> simp [extSlice, h]

/-- SCR-164: non-tapscript versions contribute the empty slice. -/
@[rule "SCR-164"]
theorem extSlice_nonTapscript (sv : SigVersion) (d : ScriptExecutionData)
    (h : sv ≠ .tapscript) :
    extSlice sv d = some ByteArray.empty := by
  simp [extSlice, h]

/-! ## TPR-045 — codesep_pos seam default / init gate -/

/-- TPR-045: uninitialized `codesepPos` is 0xFFFFFFFF. -/
@[rule "TPR-045"]
theorem codesepPos_default :
    (default : ScriptExecutionData).codesepPos = 0xFFFFFFFF := by decide

/-- TPR-045: the init flag defaults to false. -/
@[rule "TPR-045"]
theorem codesepPosInit_default :
    (default : ScriptExecutionData).codesepPosInit = false := rfl

/-- TPR-045: a tapscript ext slice is only produced when the code
separator position was initialized. -/
@[rule "TPR-045"]
theorem extSlice_requires_codesepPosInit (d : ScriptExecutionData)
    (h : extSlice .tapscript d ≠ none) : d.codesepPosInit = true := by
  by_cases h₂ : d.codesepPosInit = true
  · exact h₂
  · simp [extSlice, h₂] at h

end BitcoinProofs.AF.PDW95
