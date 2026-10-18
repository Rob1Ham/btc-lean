import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.SigHash.Digest

/-!
# Bitcoin.SigHash — FROZEN INTERFACE

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/script/interpreter.cpp
                        (SignatureHash legacy:1417-1464? / WITNESS_V0:
                        1633-1670, BIP143 midstate), BIP143 spec,
                        BIP341 (SigMsg/tagged hashes — proofs are future work,
                        signature shape frozen here)
Status: frozen 2026-10-16. Some statements are
                        sorry-stubbed placeholders; bodies are filled.

## Scope

Both digest constructions (legacy + BIP143), the tri-modal
SIGHASH_SINGLE index-overflow behavior (B2-verified: legacy →
uint256::ONE, BIP143 → zero hashOutputs, BIP341 → fail-closed hashtype
error), scriptCode re-serialization (OP_CODESEPARATOR trimming).
-/

namespace Bitcoin.SigHash

open Bitcoin.Data Bitcoin.Crypto.Seam
open Bitcoin.Serialization (Bytes bytesOfList bL bL_bytesOfList bytesOfList_bL)

/-- SIGHASH type flags (interpreter.h / BIP143). -/
inductive SigHashType where
  | all                   -- 0x01
  | none                  -- 0x02
  | single                -- 0x03
  | allAnybodyCanPay      -- 0x81
  | noneAnybodyCanPay     -- 0x82
  | singleAnybodyCanPay   -- 0x83
  | raw (bits : UInt32)   -- pass-through (invalid bits ⇒ fail-closed paths)
deriving Repr, DecidableEq, BEq

/-- Legacy `SignatureHash` (interpreter.cpp, pre-segwit path):
`scriptCode` is the scriptPubKey with OP_CODESEPARATOR-trimmed suffix.
Body: the modified-transaction serialization of
`CTransactionSignatureSerializer` (:1337-1356) + 4-byte LE hashtype,
double-SHA256'd — see `Bitcoin.SigHash.signatureHashLegacyImpl`. Def
(not `opaque`) so the interface theorems below are provable by `unfold`. -/
def signatureHashLegacy (tx : Tx) (nIn : Nat) (scriptCode : Script) (ht : UInt32) :
    ByteArray :=
  signatureHashLegacyImpl tx nIn (bL scriptCode.bytes) ht

/-- BIP143 `SignatureHash` (midstate construction over the
precomputed-hash matrix; `amount` is the spent output's value).
Body: the 10-field preimage
`version ‖ hashPrevouts ‖ hashSequence ‖ outpoint ‖ scriptCode ‖ amount ‖
nSequence ‖ hashOutputs ‖ nLockTime ‖ hashtype` (interpreter.cpp:1660-1670),
double-SHA256'd — see `Bitcoin.SigHash.signatureHashBip143Impl`. Def
(not `opaque`) so the theorem set unfold it. P2WPKH/P2WSH scriptCode
construction rules: `p2wpkhScriptCodeL` / `witnessScriptSizeOk`. -/
def signatureHashBip143 (tx : Tx) (nIn : Nat) (scriptCode : Script) (ht : UInt32)
    (amount : Amount) : ByteArray :=
  signatureHashBip143Impl tx nIn (bL scriptCode.bytes) ht amount

/-- Tri-modal SIGHASH_SINGLE behavior (B2-verified):
legacy — index ≥ vout.length ⇒ hash = uint256::ONE (`01` followed by
31 zero bytes); BIP143 — ⇒ hashOutputs = 0 (zeroes, not ONE);
BIP341 — fail-closed hashtype error. -/
def SINGLE_OVERFLOW_ONE : ByteArray :=
  bytesOfList (0x01 :: List.replicate 31 0x00)

/-- Legacy single-overflow digest is `uint256::ONE`. -/
theorem legacy_single_overflow (tx : Tx) (nIn : Nat) (scriptCode : Script)
    (h : tx.vout.length ≤ nIn) :
    signatureHashLegacy tx nIn scriptCode 0x03 = SINGLE_OVERFLOW_ONE := by
  unfold signatureHashLegacy signatureHashLegacyImpl
  -- htBase 0x03 = singleHt (0x03 &&& 0x1f == 0x03), so the early return fires
  -- BEFORE any vin access (interpreter.cpp:1614-1622).
  rw [if_pos (show htBase 0x03 = HtBase.singleHt ∧ tx.vout.length ≤ nIn from ⟨rfl, h⟩)]
  rfl

/-- scriptCode re-serialization law: the scriptCode hashed is the
subscript with `FindAndDelete(OP_CODESEPARATOR)` applied — byte-exact
`CScript` semantics (B2 dark corner: the legacy digest splices the parsed
1-byte OP_CODESEPARATOR ops out of the raw bytes; pushes are NOT
canonically re-encoded — see `Bitcoin.SigHash.serializeScriptCodeL`).
Body: byte-level `FindAndDelete` of the `[0xab]` pattern
(`findAndDeleteB`, the general `CScript::FindAndDelete` machinery). -/
def scriptCodeOf (s : Script) : Script :=
  ⟨findAndDeleteB s.bytes (bytesOfList codeSepL)⟩

/-- scriptCodeOf is idempotent (FindAndDelete is a closure). -/
@[rule "SCR-101"]
theorem scriptCodeOf_idempotent (s : Script) :
    scriptCodeOf (scriptCodeOf s) = scriptCodeOf s := by
  have hb : (scriptCodeOf (scriptCodeOf s)).bytes = (scriptCodeOf s).bytes := by
    simp only [scriptCodeOf, findAndDeleteB, bL_bytesOfList]
    exact congrArg bytesOfList (findAndDeleteL_codeSep_idempotent (bL s.bytes))
  exact congrArg Script.mk hb

/-! ## SCR-101 — scriptCode is the OP_CODESEPARATOR-free splice

The row ("1-byte opcodes removed from serialization") is about *which*
bytes are hashed, not only about the closure of the operation. The
theorems below pin the byte-level content: `scriptCodeOf` is exactly the
GetOp walk with every parsed `OP_CODESEPARATOR` (0xab) spliced out, the
walk visits no further 0xab, the result never grows, and it is the
identity on scripts already free of parsed code separators. -/

/-- **SCR-101**: the scriptCode bytes are the `dropCsFrom` walk of the
script (each parsed 1-byte `OP_CODESEPARATOR` removed; push payloads are
copied verbatim). -/
@[rule "SCR-101"]
theorem scriptCodeOf_bytes (s : Script) :
    (scriptCodeOf s).bytes = bytesOfList (dropCsFrom (bL s.bytes) 0) := by
  simp only [scriptCodeOf, findAndDeleteB, bL_bytesOfList, findAndDeleteL_codeSep_eq]

/-- **SCR-101**: the walk of the resulting scriptCode visits no
`OP_CODESEPARATOR` opcode (`CleanFrom`). -/
@[rule "SCR-101"]
theorem scriptCodeOf_clean (s : Script) :
    CleanFrom (bL (scriptCodeOf s).bytes) 0 := by
  rw [scriptCodeOf_bytes, bL_bytesOfList]
  exact dropCsFrom_clean (bL s.bytes) 0

/-- The drop-code-separator walk never increases length. -/
theorem dropCsAux_length_le (b : Bytes) (fuel i : Nat) :
    (dropCsAux b fuel i).length ≤ b.length - i := by
  induction fuel generalizing i with
  | zero => simp [dropCsAux_zero]
  | succ fuel ih =>
    rw [dropCsAux_step]
    split
    · simp
    · split
      · rename_i hnone
        rw [List.length_drop]
        omega
      · rename_i op len hsome
        split
        · rename_i hab
          have := ih (i + len)
          omega
        · rename_i hnab
          rw [List.length_append, List.length_drop, List.length_take]
          have hih := ih (i + len)
          by_cases hle : i + len ≤ b.length
          · rw [Nat.min_eq_left hle]; omega
          · rw [Nat.min_eq_right (by omega)]; omega

/-- Auxiliary: the `dropCsFrom` walk never increases length. -/
theorem dropCsFrom_length_le (b : Bytes) (i : Nat) :
    (dropCsFrom b i).length ≤ b.length - i :=
  dropCsAux_length_le b (b.length + 1) i

/-- **SCR-101**: the scriptCode is never longer than the script (each
removed `OP_CODESEPARATOR` shortens the serialization by one byte). -/
@[rule "SCR-101"]
theorem scriptCodeOf_size_le (s : Script) :
    (scriptCodeOf s).bytes.size ≤ s.bytes.size := by
  rw [scriptCodeOf_bytes]
  simp only [bytesOfList, List.size_toByteArray]
  have h := dropCsFrom_length_le (bL s.bytes) 0
  have hlen : (bL s.bytes).length = s.bytes.size := by simp [bL]
  omega

/-- **SCR-101**: a script with no parsed `OP_CODESEPARATOR` is its own
scriptCode (no bytes are spliced out). -/
@[rule "SCR-101"]
theorem scriptCodeOf_eq_self_of_clean (s : Script)
    (h : CleanFrom (bL s.bytes) 0) : scriptCodeOf s = s := by
  have hb : (scriptCodeOf s).bytes = s.bytes := by
    rw [scriptCodeOf_bytes, dropCsFrom_of_clean h, List.drop_zero, bytesOfList_bL]
  exact congrArg Script.mk hb

/-- **SCR-101**: exact characterization of the no-op case — the
serialization is unchanged iff the walk meets no parsed
`OP_CODESEPARATOR`. -/
@[rule "SCR-101"]
theorem scriptCodeOf_eq_self_iff (s : Script) :
    scriptCodeOf s = s ↔ CleanFrom (bL s.bytes) 0 := by
  constructor
  · intro h
    have hc := scriptCodeOf_clean s
    rw [h] at hc
    exact hc
  · exact scriptCodeOf_eq_self_of_clean s

end Bitcoin.SigHash
