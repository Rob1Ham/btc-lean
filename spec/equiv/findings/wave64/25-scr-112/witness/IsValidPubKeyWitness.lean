import Bitcoin.Crypto.Seam.Der
import Bitcoin.Crypto.EcdsaDeep.PubKeyParse
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Interpreter.Defs

/-!
# Wave-64 / SCR-112 — the `isValidPubKey` definitional divergence (F-DIV)

**Pinned Core:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.

This file is the L-side witness for the F-DIV finding filed with row
SCR-112.  It does not restate the row as green and it does not replace
the Core-invalid predicate by the Lean one.  It proves, kernel-checked:

* the exact witness `pk = 0x02` (one byte): Lean's `isValidPubKey`
  accepts it, while the port of Core's `CPubKey::Set` / `ValidSize`
  (`validPubKeySize`, `spec/core/Bitcoin/Crypto/EcdsaDeep/PubKeyParse.lean`)
  rejects it;
* the inclusion direction that does hold: every key Core's `CPubKey`
  accepts is accepted by Lean's weaker header-only predicate (so the
  divergence is Lean-over-approximation, not a two-sided mismatch);
* the consequence in the checker seam: for the witness pubkey, the real
  ECDSA seam still returns `false` (the downstream `parsePubKey` rejects
  the malformed length), so the CHECKSIG verdict agrees for the real
  crypto seam even though the gate does not;
* the block-mode shape: with `pol.nullFail = false` (consensus/default
  block policy) a `false` checker verdict flows through
  `evalChecksigPreTapscript` as `.ok false`, and `stepBody`'s CHECKSIG
  arm pushes `false` and continues.

The point of the finding is the gate itself: Lean's `isValidPubKey`
(`spec/core/Bitcoin/Crypto/Seam/Der.lean:162-175`) is header-only,
while Core's `CPubKey::Set` (`src/pubkey.h:98-105`) enforces
`GetLen(header) == length`.  The correct port already exists in the
deep layer (`validPubKeySize`); the seam does not use it.
-/

namespace Wave64.Scr112

open Bitcoin.Crypto.Seam.Der
open Bitcoin.Crypto.EcdsaDeep.PubKeyParse (validPubKeySize)

/-! ## 1. The concrete witness -/

/-- The one-byte pubkey `0x02`: a compressed-key header with no payload.
Lean's header-only gate accepts it. -/
def pk02 : ByteArray := ByteArray.mk #[0x02]

/-- Lean's gate accepts `0x02`. -/
theorem lean_accepts_pk02 : isValidPubKey pk02 = true := by decide

/-- Core's `CPubKey::Set` / `ValidSize` rejects `0x02` (33 != 1). -/
theorem core_rejects_pk02 : validPubKeySize pk02 = false := by decide

/-- The divergence, as a kernel-checked conjunction. -/
theorem isValidPubKey_diverges :
    isValidPubKey pk02 = true ∧ validPubKeySize pk02 = false := by
  exact ⟨lean_accepts_pk02, core_rejects_pk02⟩

/-- A second header class: uncompressed tag `0x04` with no payload. -/
theorem lean_accepts_pk04 : isValidPubKey (ByteArray.mk #[0x04]) = true := by decide
theorem core_rejects_pk04 : validPubKeySize (ByteArray.mk #[0x04]) = false := by decide

/-- A 34-byte compressed-tag key (`0x02` followed by 33 zero bytes):
Core requires exactly 33 bytes, Lean only reads the header. -/
theorem lean_accepts_pk02_len34 :
    isValidPubKey (ByteArray.mk (Array.replicate 34 0x02)) = true := by decide
theorem core_rejects_pk02_len34 :
    validPubKeySize (ByteArray.mk (Array.replicate 34 0x02)) = false := by decide

/-- A 33-byte uncompressed-tag key: Core requires 65 bytes. -/
theorem lean_accepts_pk04_len33 :
    isValidPubKey (ByteArray.mk (Array.replicate 33 0x04)) = true := by decide
theorem core_rejects_pk04_len33 :
    validPubKeySize (ByteArray.mk (Array.replicate 33 0x04)) = false := by decide

/-! ## 2. The direction that does hold

Lean's predicate is *weaker*: `CPubKey::Set`-accept implies
`isValidPubKey = true`.  There is no key Core accepts and Lean rejects.
-/

/-- `pk[0]!` is the bounds-safe first byte `byteAt pk 0`. -/
theorem getElem!_zero_eq_getD (b : ByteArray) : b[0]! = b.data.getD 0 0 := by
  rw [getElem!_def, Array.getD]
  by_cases h : 0 < b.data.size
  · rw [dite_eq_left h]
    have hq : b[0]? = some b.data[0] := by
      change b.data[0]? = some b.data[0]
      exact Array.getElem?_eq_getElem h
    rw [hq]
    rfl
  · rw [dite_eq_right h]
    have hle : b.data.size ≤ 0 := Nat.le_of_not_lt h
    have hq : b[0]? = none := by
      change b.data[0]? = none
      exact Array.getElem?_eq_none hle
    rw [hq]
    rfl

theorem byteAt_zero_eq (b : ByteArray) :
    Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 = b[0]!.toNat := by
  unfold Bitcoin.Crypto.Ecdsa.Der.byteAt
  rw [getElem!_zero_eq_getD]

/-- **Inclusion:** every `CPubKey::Set`-accepted byte string has a valid
Lean header.  (The converse fails: see `isValidPubKey_diverges`.) -/
theorem core_valid_imp_lean_valid (b : ByteArray) (h : validPubKeySize b = true) :
    isValidPubKey b = true := by
  unfold validPubKeySize at h
  simp only [Bitcoin.Crypto.Ecdsa.Der.blen] at h
  have hsize : 0 < b.size := by
    cases Nat.eq_zero_or_pos b.size with
    | inl h0 => simp [h0] at h
    | inr hp => exact hp
  have htag : Bitcoin.Crypto.EcdsaDeep.PubKeyParse.pubKeyLen
      (Bitcoin.Crypto.Ecdsa.Der.byteAt b 0) = b.size := by
    simpa [hsize] using h
  have hne : Bitcoin.Crypto.EcdsaDeep.PubKeyParse.pubKeyLen
      (Bitcoin.Crypto.Ecdsa.Der.byteAt b 0) ≠ 0 := by
    rw [htag]
    exact Nat.pos_iff_ne_zero.mp hsize
  unfold isValidPubKey pubKeyLen
  have hsize' : ¬ b.size = 0 := Nat.pos_iff_ne_zero.mp hsize
  rw [ite_eq_right hsize']
  unfold Bitcoin.Crypto.EcdsaDeep.PubKeyParse.pubKeyLen at hne
  split at hne
  · rename_i htag'
    have : Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 = 2 ∨
        Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 = 3 := by
      simpa using htag'
    have hb : b[0]!.toNat = 2 ∨ b[0]!.toNat = 3 := by
      simpa [byteAt_zero_eq] using this
    rcases hb with h2 | h3
    · have : b[0]! = 0x02 := by
        apply UInt8.toNat_inj.mp
        simpa using h2
      simp [this]
    · have : b[0]! = 0x03 := by
        apply UInt8.toNat_inj.mp
        simpa using h3
      simp [this]
  · split at hne
    · rename_i htag'
      have : (Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 = 4 ∨
          Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 = 6) ∨
          Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 = 7 := by
        simpa using htag'
      have hb : (b[0]!.toNat = 4 ∨ b[0]!.toNat = 6) ∨ b[0]!.toNat = 7 := by
        simpa [byteAt_zero_eq] using this
      rcases hb with (h4 | h6) | h7
      · have : b[0]! = 0x04 := by
          apply UInt8.toNat_inj.mp
          simpa using h4
        simp [this]
      · have : b[0]! = 0x06 := by
          apply UInt8.toNat_inj.mp
          simpa using h6
        simp [this]
      · have : b[0]! = 0x07 := by
          apply UInt8.toNat_inj.mp
          simpa using h7
        simp [this]
    · exact absurd hne (by simp)

/-! ## 3. The checker seam

The witness pubkey passes Lean's header gate, so `ecdsaEntry` does NOT
take the `!isValidPubKey` early-false branch; it calls the EC verifier.
With the real `verifyImpl`, that call is still `false` because
`parsePubKey` rejects the malformed length.  This is the honest scope:
the *gate* diverges, the real-crypto verdict does not.
-/

/-- `verifyImpl` on the witness pubkey is false for every signature and
message (the downstream parse is length-exact). -/
theorem verifyImpl_witness (sig msg : ByteArray) :
    Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sig pk02 msg = false := by
  unfold Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
  cases h : Bitcoin.Crypto.Ecdsa.Der.parseDerLax sig with
  | none => rfl
  | some v =>
      have hp : Bitcoin.Crypto.Ecdsa.Verify.parsePubKey pk02 = none := by decide
      simp [hp]

/-- The ECDSA seam gives `false` for the witness pubkey on every
sigversion (base or witness v0), even though the gate let it through. -/
theorem ecdsaEntry_witness_false
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray)
    (hasAmount : Bool) (sig code : ByteArray)
    (v : Bitcoin.Crypto.Seam.SigVersion)
    (d : Bitcoin.Crypto.Seam.ScriptExecutionData) (hne : 0 < sig.size) :
    (Bitcoin.Crypto.Seam.Entry.ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
        sighash hasAmount).checkECDSASignature
      sig pk02 code v d = false := by
  unfold Bitcoin.Crypto.Seam.Entry.ecdsaEntry Bitcoin.Crypto.Seam.Entry.ecdsaVerdict
  simp [isValidPubKey, pubKeyLen, Nat.pos_iff_ne_zero.mp hne, verifyImpl_witness]

/-! ## 4. The block-mode false-and-continue guard

`evalChecksigPreTapscript` under a `false` checker verdict and
`pol.nullFail = false` yields `.ok false`; `stepBody`'s CHECKSIG arm then
pushes `false` and leaves the stack for the next opcode.  The theorem is
stated for `sv = witnessV0` so that the scriptCode is exactly
`bytes.extract codeSep bytes.size` (the base arm has the same shape but
its scriptCode passes through `FindAndDelete` first).
-/

theorem evalChecksigPreTapscript_witness_false
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sv : Bitcoin.Crypto.Seam.SigVersion) (codeSep : Nat) (bytes sig : ByteArray)
    (hsv : sv ≠ Bitcoin.Crypto.Seam.SigVersion.base)
    (hsig : Bitcoin.Interpreter.checkSigEncoding flags pol sig = none)
    (hpk : Bitcoin.Interpreter.checkPubKeyEncoding flags pol sv pk02 = none)
    (hnull : pol.nullFail = false)
    (hck : chk.base.checkECDSASignature sig pk02
      (bytes.extract codeSep bytes.size) sv ed = false) :
    Bitcoin.Interpreter.evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk02
      = .ok false := by
  unfold Bitcoin.Interpreter.evalChecksigPreTapscript
  simp [hsv, hsig, hpk, hnull, hck]

theorem evalChecksigPreTapscript_ecdsaEntry_witness_false
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sv : Bitcoin.Crypto.Seam.SigVersion) (codeSep : Nat) (bytes sig : ByteArray)
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray)
    (hasAmount : Bool)
    (hsv : sv ≠ Bitcoin.Crypto.Seam.SigVersion.base)
    (hsig : Bitcoin.Interpreter.checkSigEncoding flags pol sig = none)
    (hpk : Bitcoin.Interpreter.checkPubKeyEncoding flags pol sv pk02 = none)
    (hnull : pol.nullFail = false)
    (hne : 0 < sig.size) :
    Bitcoin.Interpreter.evalChecksigPreTapscript flags pol
      { base := Bitcoin.Crypto.Seam.Entry.ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
          sighash hasAmount }
      ed sv codeSep bytes sig pk02 = .ok false := by
  apply evalChecksigPreTapscript_witness_false flags pol _ ed sv codeSep bytes sig
      hsv hsig hpk hnull
  exact ecdsaEntry_witness_false sighash hasAmount sig
    (bytes.extract codeSep bytes.size) sv ed hne

/-- `stepBody` CHECKSIG with a `false` verdict and block-policy
`nullFail = false`: push `false`, drop the two operands, continue. -/
theorem stepBody_checksig_false_continue
    (ctx : Bitcoin.Interpreter.Ctx) (op : Bitcoin.Interpreter.WireOp)
    (st : Bitcoin.Interpreter.State)
    (hast : op.ast = .op ⟨0xac, by decide⟩)
    (hw : op.wire = 0xac)
    (h2 : 2 ≤ st.stack.length)
    (hvf : st.vf.all id = true)
    (hcount : ¬ Bitcoin.Interpreter.MAX_OPS_PER_SCRIPT < st.opCount + 1)
    (hsv : ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
    (henc : Bitcoin.Interpreter.checkSigEncoding ctx.flags ctx.pol
      (Bitcoin.Interpreter.topAt st.stack 2) = none)
    (hpk : Bitcoin.Interpreter.checkPubKeyEncoding ctx.flags ctx.pol ctx.sv
      (Bitcoin.Interpreter.topAt st.stack 1) = none)
    (hnull : ctx.pol.nullFail = false)
    (hck : ctx.chk.base.checkECDSASignature
      (Bitcoin.Interpreter.topAt st.stack 2) (Bitcoin.Interpreter.topAt st.stack 1)
      (ctx.bytes.extract st.codeSep ctx.bytes.size) ctx.sv
      (Bitcoin.Interpreter.signatureExecutionData ctx st) = false) :
    Bitcoin.Interpreter.stepBody ctx op st =
      .ok { st with
        stack := Bitcoin.Interpreter.pushBoolV false :: st.stack.drop 2,
        opCount := st.opCount + 1 } := by
  rcases op with ⟨ast, w, next⟩
  simp only at hast hw
  subst hast
  subst hw
  have h2' : ¬ st.stack.length < 2 := Nat.not_lt_of_ge h2
  rw [hsv] at hpk hck
  simp [Bitcoin.Interpreter.signatureExecutionData, hsv] at hck
  simp [Bitcoin.Interpreter.stepBody, Bitcoin.Interpreter.stepBody.dispatchOp,
    Bitcoin.Interpreter.disabledWire, h2', hvf, hcount, hsv, henc, hpk, hnull, hck,
    Bitcoin.Interpreter.signatureExecutionData, Bitcoin.Interpreter.evalChecksigDispatch,
    Bitcoin.Interpreter.evalChecksigPreTapscript]

/-- Under block/default policy (`strictEnc = false`, `witnessPubkeyType =
false`), `CheckPubKeyEncoding` returns `none` for the witness pubkey, so
the divergent `isValidPubKey` gate is actually reached.  (With STRICTENC
on, `isCompressedOrUncompressedPubKey` rejects the 1-byte key first, which
masks this divergence in policy mode.) -/
theorem checkPubKeyEncoding_pk02_block
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion)
    (hstrict : pol.strictEnc = false)
    (hwpk : pol.witnessPubkeyType = false) :
    Bitcoin.Interpreter.checkPubKeyEncoding flags pol sv pk02 = none := by
  unfold Bitcoin.Interpreter.checkPubKeyEncoding
  simp [hstrict, hwpk]

/-- Composed witness guard: for the witness pubkey `0x02`, with the real
ECDSA seam and block-policy `nullFail = false`, `stepBody`'s CHECKSIG arm
pushes `false` and continues.  This is the block-mode false-and-continue
result *despite* the gate divergence (Lean let the key through; the real
`verifyImpl` returned false downstream). -/
theorem stepBody_witness_false_continue
    (ctx : Bitcoin.Interpreter.Ctx) (op : Bitcoin.Interpreter.WireOp)
    (st : Bitcoin.Interpreter.State)
    (hast : op.ast = .op ⟨0xac, by decide⟩)
    (hw : op.wire = 0xac)
    (h2 : 2 ≤ st.stack.length)
    (hvf : st.vf.all id = true)
    (hcount : ¬ Bitcoin.Interpreter.MAX_OPS_PER_SCRIPT < st.opCount + 1)
    (hsv : ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
    (henc : Bitcoin.Interpreter.checkSigEncoding ctx.flags ctx.pol
      (Bitcoin.Interpreter.topAt st.stack 2) = none)
    (hpk : Bitcoin.Interpreter.checkPubKeyEncoding ctx.flags ctx.pol ctx.sv
      (Bitcoin.Interpreter.topAt st.stack 1) = none)
    (hnull : ctx.pol.nullFail = false)
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray)
    (hasAmount : Bool)
    (hbase : ctx.chk.base = Bitcoin.Crypto.Seam.Entry.ecdsaEntry
      Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount)
    (hpk02 : Bitcoin.Interpreter.topAt st.stack 1 = pk02)
    (hne : 0 < (Bitcoin.Interpreter.topAt st.stack 2).size) :
    Bitcoin.Interpreter.stepBody ctx op st =
      .ok { st with
        stack := Bitcoin.Interpreter.pushBoolV false :: st.stack.drop 2,
        opCount := st.opCount + 1 } := by
  apply stepBody_checksig_false_continue ctx op st hast hw h2 hvf hcount hsv
      henc hpk hnull
  rw [hbase, hpk02]
  exact ecdsaEntry_witness_false sighash hasAmount
    (Bitcoin.Interpreter.topAt st.stack 2)
    (ctx.bytes.extract st.codeSep ctx.bytes.size) ctx.sv
    (Bitcoin.Interpreter.signatureExecutionData ctx st) hne

/-- Block-policy reachability: the composed guard needs no pubkey-encoding
premise — `strictEnc = false` / `witnessPubkeyType = false` discharge it
via `checkPubKeyEncoding_pk02_block`. -/
theorem stepBody_pk02_block_false_continue
    (ctx : Bitcoin.Interpreter.Ctx) (op : Bitcoin.Interpreter.WireOp)
    (st : Bitcoin.Interpreter.State)
    (hast : op.ast = .op ⟨0xac, by decide⟩)
    (hw : op.wire = 0xac)
    (h2 : 2 ≤ st.stack.length)
    (hvf : st.vf.all id = true)
    (hcount : ¬ Bitcoin.Interpreter.MAX_OPS_PER_SCRIPT < st.opCount + 1)
    (hsv : ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
    (henc : Bitcoin.Interpreter.checkSigEncoding ctx.flags ctx.pol
      (Bitcoin.Interpreter.topAt st.stack 2) = none)
    (hstrict : ctx.pol.strictEnc = false)
    (hwpk : ctx.pol.witnessPubkeyType = false)
    (hnull : ctx.pol.nullFail = false)
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray)
    (hasAmount : Bool)
    (hbase : ctx.chk.base = Bitcoin.Crypto.Seam.Entry.ecdsaEntry
      Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount)
    (hpk02 : Bitcoin.Interpreter.topAt st.stack 1 = pk02)
    (hne : 0 < (Bitcoin.Interpreter.topAt st.stack 2).size) :
    Bitcoin.Interpreter.stepBody ctx op st =
      .ok { st with
        stack := Bitcoin.Interpreter.pushBoolV false :: st.stack.drop 2,
        opCount := st.opCount + 1 } := by
  apply stepBody_witness_false_continue ctx op st hast hw h2 hvf hcount hsv
      henc _ hnull sighash hasAmount hbase hpk02 hne
  rw [hpk02]
  exact checkPubKeyEncoding_pk02_block ctx.flags ctx.pol ctx.sv hstrict hwpk

/-! ## 5. Evaluated values (raw output is recorded in `l_isvalidpubkey.out`;
the `decide` theorems above are the kernel check, these lines are the
human-readable table) -/

#eval isValidPubKey pk02
#eval validPubKeySize pk02
#eval isValidPubKey (ByteArray.mk #[0x04])
#eval validPubKeySize (ByteArray.mk #[0x04])
#eval isValidPubKey (ByteArray.mk (Array.replicate 34 0x02))
#eval validPubKeySize (ByteArray.mk (Array.replicate 34 0x02))
#eval isValidPubKey (ByteArray.mk (Array.replicate 33 0x04))
#eval validPubKeySize (ByteArray.mk (Array.replicate 33 0x04))

/-! ## 6. Axiom pins (raw output is recorded in `l_isvalidpubkey.out`) -/

#print axioms isValidPubKey_diverges
#print axioms lean_accepts_pk02
#print axioms core_rejects_pk02
#print axioms core_valid_imp_lean_valid
#print axioms verifyImpl_witness
#print axioms checkPubKeyEncoding_pk02_block
#print axioms ecdsaEntry_witness_false
#print axioms evalChecksigPreTapscript_witness_false
#print axioms evalChecksigPreTapscript_ecdsaEntry_witness_false
#print axioms stepBody_checksig_false_continue
#print axioms stepBody_witness_false_continue
#print axioms stepBody_pk02_block_false_continue

end Wave64.Scr112
