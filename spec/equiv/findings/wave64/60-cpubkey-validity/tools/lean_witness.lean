/-
  Independent witness for the SCR-112 definitional divergence:
  Bitcoin.Crypto.Seam.Der.isValidPubKey (header-only) vs Core
  CPubKey::Set/IsValid (header AND length, src/pubkey.h:86-105 @ cce32b168).

  Run from spec/:  lake env lean <this file>

  No repo edits outside this findings directory; all predicates imported
  from the pinned Lean model.
-/
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.EcdsaDeep.PubKeyParse
import Bitcoin.Interpreter.Defs

open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Seam.Der
open Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.EcdsaDeep.PubKeyParse
open Bitcoin.Crypto.Ecdsa.Der

namespace ScrubWitness

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

private def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

private def zeros (n : Nat) : String := String.ofList (List.replicate n '0')

/-- The smallest witness: one byte, compressed-header 0x02.
    Core: GetLen(0x02)=33 ≠ 1 -> Invalidate -> IsValid=false.
    Lean: pubKeyLen = 33 ≠ 0 -> isValidPubKey=true. -/
def pkMin : ByteArray := fromHex "02"

/-- The task's illustrative witness: header 0x04 (uncompressed, promises 65
    bytes) with only 2 bytes.  Core invalid; Lean valid. -/
def pkTwo : ByteArray := fromHex "0400"

/-- A valid DER signature + hashtype byte (so DERSIG cannot confound). -/
def sigOk : ByteArray := fromHex "300602010102010301"

-- Exact Lean predicate values for the minimal witness.
example : pkMin.size = 1 := by decide
example : pubKeyLen pkMin = 33 := by decide
example : isValidPubKey pkMin = true := by decide
example : validPubKeySize pkMin = false := by decide

-- Exact Lean predicate values for the illustrative witness.
example : pkTwo.size = 2 := by decide
example : pubKeyLen pkTwo = 65 := by decide
example : isValidPubKey pkTwo = true := by decide
example : validPubKeySize pkTwo = false := by decide

-- The length-sensitive SGN-105 parser also rejects both malformed keys, so
-- the *downstream real ECDSA verifier* still returns false.  This is why the
-- gate divergence does not by itself flip a full-checker outcome.
example : Bitcoin.Crypto.Ecdsa.Verify.parsePubKey pkMin = none := by decide
example : Bitcoin.Crypto.Ecdsa.Verify.parsePubKey pkTwo = none := by decide

/-- The seam's ecdsaVerdict with an ABSTRACT `verify` oracle.  Because the
    header-only gate returns true, the malformed key reaches `verify`; an
    oracle that says true makes the Lean model return true while Core's
    CPubKey gate forces false.  This is the definitional divergence at the
    checker-entry level (no claim that this oracle is the real one). -/
example :
    ecdsaVerdict (fun _ _ _ => true) (fun _ _ _ => ByteArray.empty)
      true SigVersion.base sigOk pkTwo ByteArray.empty = true := by decide

/-- With a length-sensitive verifier (the real parsePubKey acceptance), the
    same Lean entry returns false, matching Core's verdict for this input. -/
example :
    ecdsaVerdict (fun _ pk _ => (Bitcoin.Crypto.Ecdsa.Verify.parsePubKey pk).isSome)
      (fun _ _ _ => ByteArray.empty)
      true SigVersion.base sigOk pkTwo ByteArray.empty = false := by decide

/-! ## The block-mode false-and-continue path, conditional on the gate

The push-false/continue mechanism is independent of HOW the key was
classified invalid: it consumes only a false checker verdict plus
`pol.nullFail = false` (block validation; Core's mandatory flags have no
NULLFAIL bit, policy/policy.h:104-130).  This is the part SCR-112 can
close without resolving the Set/isValidPubKey mismatch. -/
theorem block_false_continue
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk scriptCode : ByteArray)
    (hsc : (if sv = SigVersion.base then
        (let r := Bitcoin.Interpreter.findAndDelete
            (bytes.extract codeSep bytes.size)
            (Bitcoin.Script.Parser.pushBytesWire sig)
         if 0 < r.1 ∧ pol.constScriptCode then
           Except.error Bitcoin.Interpreter.ExecError.sigFindAndDelete
         else Except.ok r.2)
      else Except.ok (bytes.extract codeSep bytes.size)) = Except.ok scriptCode)
    (henc : Bitcoin.Interpreter.checkSigEncoding flags pol sig = none)
    (hpk : Bitcoin.Interpreter.checkPubKeyEncoding flags pol sv pk = none)
    (hfalse : chk.base.checkECDSASignature sig pk scriptCode sv ed = false)
    (hnf : pol.nullFail = false) :
    Bitcoin.Interpreter.evalChecksigPreTapscript
      flags pol chk ed sv codeSep bytes sig pk = .ok false := by
  unfold Bitcoin.Interpreter.evalChecksigPreTapscript
  simp [hsc, henc, hpk, hfalse, hnf]

/-- The checker adapter used to instantiate the path above. -/
def ecdsaChecker
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (hasAmount : Bool) : Bitcoin.Interpreter.ScriptChecker :=
  { base := ecdsaEntry verify sighash hasAmount
    env := default
    checkSchnorrTyped := none }

/-- Conditional closure of SCR-112's block-mode path *under the current Lean
    gate*: if `isValidPubKey pk = false`, the checker returns false before
    `verify`, and with NULLFAIL off the pre-tapscript check returns
    `.ok false` (CHECKSIG then pushes false and the script continues).
    NOTE: `pkMin`/`pkTwo` do NOT satisfy `hbad` — that is the divergence. -/
theorem block_path_lean_invalid
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk scriptCode : ByteArray)
    (hbad : isValidPubKey pk = false)
    (hsc : (if sv = SigVersion.base then
        (let r := Bitcoin.Interpreter.findAndDelete
            (bytes.extract codeSep bytes.size)
            (Bitcoin.Script.Parser.pushBytesWire sig)
         if 0 < r.1 ∧ pol.constScriptCode then
           Except.error Bitcoin.Interpreter.ExecError.sigFindAndDelete
         else Except.ok r.2)
      else Except.ok (bytes.extract codeSep bytes.size)) = Except.ok scriptCode)
    (henc : Bitcoin.Interpreter.checkSigEncoding flags pol sig = none)
    (hpk : Bitcoin.Interpreter.checkPubKeyEncoding flags pol sv pk = none)
    (hnf : pol.nullFail = false) :
    Bitcoin.Interpreter.evalChecksigPreTapscript flags pol
      (ecdsaChecker verify sighash hasAmount) ed sv codeSep bytes sig pk
      = .ok false := by
  apply block_false_continue flags pol _ ed sv codeSep bytes sig pk scriptCode
    hsc henc hpk _ hnf
  exact ecdsaEntry_badPubKey_false verify sighash hasAmount
    sig pk scriptCode sv ed hbad

-- The current Lean gate does not fire on either C-invalid witness:
example : isValidPubKey pkMin = true := by decide
example : isValidPubKey pkTwo = true := by decide

/-! ## The real parse stage closes the *outcome* gap for C-invalid keys

Every byte string Core's `CPubKey::Set` rejects is also rejected by the SGN-105
parser, because the parser demands the exact (length, header) pair.  With the
real parser wired as the verifier's parse stage, the Lean checker therefore
returns false for every C-invalid key even though the header-only gate passes.
This is why the divergence is a proof/model-fidelity gap, not a consensus
accept divergence. -/
private theorem pubKeyLen_eq_65 {t : Nat} (h : t = 4 ∨ t = 6 ∨ t = 7) :
    pubKeyLen t = 65 := by
  rcases h with h | h | h <;> subst h <;> rfl

private theorem pubKeyLen_eq_33 {t : Nat} (h : t = 2 ∨ t = 3) :
    pubKeyLen t = 33 := by
  rcases h with h | h <;> subst h <;> rfl

theorem parsePubKey_none_of_not_validPubKeySize (b : ByteArray)
    (h : validPubKeySize b = false) :
    Bitcoin.Crypto.Ecdsa.Verify.parsePubKey b = none := by
  dsimp only [Bitcoin.Crypto.Ecdsa.Verify.parsePubKey]
  unfold validPubKeySize at h
  split
  · next h1 =>
    simp only [Bool.and_eq_true, beq_iff_eq] at h1
    obtain ⟨hlen, htag⟩ := h1
    have htag' : byteAt b 0 = 2 ∨ byteAt b 0 = 3 := by
      simpa only [Bool.or_eq_true, beq_iff_eq] using htag
    have h33 : pubKeyLen (byteAt b 0) = 33 := pubKeyLen_eq_33 htag'
    simp [h33, hlen] at h
  · split
    · next h2 =>
      simp only [Bool.and_eq_true, beq_iff_eq] at h2
      obtain ⟨hlen, htag⟩ := h2
      have htag' : byteAt b 0 = 4 ∨ byteAt b 0 = 6 ∨ byteAt b 0 = 7 := by
        simpa only [Bool.or_eq_true, beq_iff_eq, or_assoc] using htag
      have h65 : pubKeyLen (byteAt b 0) = 65 := pubKeyLen_eq_65 htag'
      simp [h65, hlen] at h
    · rfl

/-- The real verifier's parse stage (the only part relevant to an invalid
    key; the ECDSA verdict is never reached). -/
def parseOnlyVerify : ByteArray → ByteArray → ByteArray → Bool :=
  fun _ pk _ => (Bitcoin.Crypto.Ecdsa.Verify.parsePubKey pk).isSome

theorem parseOnlyVerify_false_of_not_validPubKeySize
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (hasAmount : Bool) (v : SigVersion) (sig pk code : ByteArray)
    (h : validPubKeySize pk = false) :
    ecdsaVerdict parseOnlyVerify sighash hasAmount v sig pk code = false := by
  unfold ecdsaVerdict
  by_cases hgate : isValidPubKey pk = true
  · simp [hgate, parseOnlyVerify, parsePubKey_none_of_not_validPubKeySize pk h]
  · simp [hgate]

/-- End-to-end block-mode false-and-continue for a C-invalid key with the real
    parse stage: the mechanism theorem plus the parse rejection above. -/
theorem block_path_core_invalid_realparse
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk scriptCode : ByteArray)
    (hinvalid : validPubKeySize pk = false)
    (hsc : (if sv = SigVersion.base then
        (let r := Bitcoin.Interpreter.findAndDelete
            (bytes.extract codeSep bytes.size)
            (Bitcoin.Script.Parser.pushBytesWire sig)
         if 0 < r.1 ∧ pol.constScriptCode then
           Except.error Bitcoin.Interpreter.ExecError.sigFindAndDelete
         else Except.ok r.2)
      else Except.ok (bytes.extract codeSep bytes.size)) = Except.ok scriptCode)
    (henc : Bitcoin.Interpreter.checkSigEncoding flags pol sig = none)
    (hpk : Bitcoin.Interpreter.checkPubKeyEncoding flags pol sv pk = none)
    (hnf : pol.nullFail = false) :
    Bitcoin.Interpreter.evalChecksigPreTapscript flags pol
      (ecdsaChecker parseOnlyVerify sighash hasAmount) ed sv codeSep bytes sig pk
      = .ok false := by
  apply block_false_continue flags pol _ ed sv codeSep bytes sig pk scriptCode
    hsc henc hpk _ hnf
  exact parseOnlyVerify_false_of_not_validPubKeySize sighash hasAmount sv
    sig pk scriptCode hinvalid

-- Block-mode premises are satisfiable with a valid-DER signature:
-- DERSIG on (BIP66 is a block flag after activation), no policy flags
-- (NULLFAIL/STRICTENC off), so the false-and-continue arm applies.
example : Bitcoin.Interpreter.checkSigEncoding
    ({ dersig := true } : Bitcoin.Activation.ScriptFlags)
    (default : Bitcoin.Interpreter.PolicyFlags) sigOk = none := by decide
example : Bitcoin.Interpreter.checkPubKeyEncoding
    ({ dersig := true } : Bitcoin.Activation.ScriptFlags)
    (default : Bitcoin.Interpreter.PolicyFlags) SigVersion.base pkTwo = none := by decide
example : (default : Bitcoin.Interpreter.PolicyFlags).nullFail = false := by decide

#print axioms block_false_continue
#print axioms block_path_lean_invalid
#print axioms parsePubKey_none_of_not_validPubKeySize
#print axioms block_path_core_invalid_realparse


/-- Row emitter: same rows as tools/c_cpubkey_validity.cpp. -/
def row (label hex : String) : String :=
  let pk := fromHex hex
  let cShape := validPubKeySize pk   -- length-sensitive (Core Set/ValidSize)
  let lGate := isValidPubKey pk      -- current Lean seam predicate
  s!"{label},{hex},{pk.size},{pubKeyLen pk},{cShape},{lGate}"

#eval IO.println "label,hex,len,lean_pubKeyLen,lean_validPubKeySize,lean_isValidPubKey"
#eval IO.println (row "empty" "")
#eval IO.println (row "badhdr-1B-01" "01")
#eval IO.println (row "min-1B-02" "02")
#eval IO.println (row "one-1B-04" "04")
#eval IO.println (row "two-2B-0400" "0400")
#eval IO.println (row "32B-02" ("02" ++ zeros 62))
#eval IO.println (row "33B-02" ("02" ++ zeros 64))
#eval IO.println (row "34B-02" ("02" ++ zeros 66))
#eval IO.println (row "64B-04" ("04" ++ zeros 126))
#eval IO.println (row "65B-04" ("04" ++ zeros 128))
#eval IO.println (row "66B-04" ("04" ++ zeros 130))
#eval IO.println (row "33B-04" ("04" ++ zeros 64))
#eval IO.println (row "65B-02" ("02" ++ zeros 128))
#eval IO.println (row "33B-06" ("06" ++ zeros 64))
#eval IO.println (row "65B-06" ("06" ++ zeros 128))
#eval IO.println (row "33B-02-G"
  "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
#eval IO.println (row "65B-04-G"
  ("0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798" ++
   "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"))

end ScrubWitness
