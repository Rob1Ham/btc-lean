import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Crypto.Seam.Der

/-!
# Bitcoin.Crypto.Seam.Entry — checker adapters

Faithful ports of the two `GenericTransactionSignatureChecker` entry
points (interpreter.cpp:1701-1752 @cce32b168) as *adapters*: the EC math
and the BIP340/BIP342 sighash are abstract function parameters, so this
module has NO dependency on the sighash layer and NO dependency on
the curve work — it boots with mock/lax verifiers and drops the
real ones in without touching this file or the interpreter.

## What is ported where

* `ecdsaVerdict` / `ecdsaEntry` — CheckECDSASignature
  (interpreter.cpp:1701-1724): `pubkey.IsValid()` gate → hashtype pop
  (SWT-053) → empty-sig reject (SWT-054) → WITNESS_V0 amount-missing
  reject (SWT-055, `HandleMissingData` fail-closed) → sighash → LAX
  ECDSA verify (DECISIONS.md OPEN-002: DER strictness is the
  interpreter's BIP66 gate, `Seam/Der.lean`; the EC lib accepts
  non-strict encodings).
* `schnorrVerdict` / `schnorrEntry` — CheckSchnorrSignature
  (interpreter.cpp:1726-1752): sigversion restricted to TAPROOT/
  TAPSCRIPT (Core `assert`s; fail-closed here), 32-byte keys
  (caller-enforced in Core; fail-closed here), 64/65-byte sigs, 65th
  byte ≠ SIGHASH_DEFAULT, hashtype popped before verify, missing-data
  fail-closed.
* `txCheckerOf` — the smart constructor the interpreter binds the
  seam to: lax-ECDSA entry (the crypto layer supplies the EC verifier; the sighash
  is threaded through) + Schnorr entry (slot).

All consensus outcomes are `Bool` — Core's `ScriptError` channel only
affects reject *reasons*, which the seam does not virtualize (B5).
-/

namespace Bitcoin.Crypto.Seam.Entry

open Der

/-! ## ECDSA entry (interpreter.cpp:1701-1724) -/

/-- The consensus verdict of `CheckECDSASignature` for a checker whose
EC verification is `verify` and whose sighash function is `sighash`.
`hasAmount = false` models the checker's `amount < 0` missing-data state
(`HandleMissingData(m_mdb)` fails closed with the default missing-data
behavior). -/
def ecdsaVerdict (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (hasAmount : Bool) (v : SigVersion) (sig pk code : ByteArray) : Bool :=
  -- CPubKey::IsValid gate (interpreter.cpp:1703-1704).
  if !isValidPubKey pk then false
  -- Hash type is one byte tacked on to the end of the signature:
  -- popped BEFORE hashing/verifying (interpreter.cpp:1707-1712; SWT-053)
  -- — see `ecdsaEntry_pops_hashtype` for exactly what reaches verify.
  -- Empty signature reject (interpreter.cpp:1708-1709; SWT-054).
  else if sig.size = 0 then false
  -- Witness sighashes need the amount (interpreter.cpp:1715-1716; SWT-055).
  else if v = SigVersion.witnessV0 && !hasAmount then false
  else verify (sig.extract 0 (sig.size - 1)) pk (sighash code sig[sig.size - 1]! v)

/-- ECDSA adapter packaged as a checker. The Schnorr entry is the
The Schnorr slot: fail-closed (`false`) here, replaced by `schnorrEntry` via
`txCheckerOf`. -/
def ecdsaEntry (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (hasAmount : Bool) : BaseSignatureChecker :=
  { checkECDSASignature := fun sig pk code v _ =>
      ecdsaVerdict verify sighash hasAmount v sig pk code
    checkSchnorrSignature := fun _ _ _ _ => false }

/-- SEAM CONTRACT: the 5th (execdata) parameter of the frozen ECDSA entry
is consensus-inert — Core's `CheckECDSASignature` takes NO
ScriptExecutionData (interpreter.cpp:1701-1706 @cce32b168), so a faithful
adapter's verdict cannot depend on it. Holds definitionally for the
adapter; the interpreter may pass any execdata it has at hand. -/
theorem ecdsaEntry_execData_independent (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData) :
    (ecdsaEntry verify sighash hasAmount).checkECDSASignature sig pk code v d₁
      = (ecdsaEntry verify sighash hasAmount).checkECDSASignature sig pk code v d₂ := by
  simp only [ecdsaEntry, ecdsaVerdict]

/-- SWT-054: empty signatures fail closed before any EC math
(interpreter.cpp:1708-1709: `if (vchSig.empty()) return false;`). -/
@[rule "SWT-054"]
theorem ecdsaEntry_empty_sig_false (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (ecdsaEntry verify sighash hasAmount).checkECDSASignature
      ByteArray.empty pk code v d = false := by
  simp only [ecdsaEntry, ecdsaVerdict]
  split
  · rfl
  · simp

/-- SWT-054-adjacent pubkey gate: an invalid pubkey header fails before
the signature is even looked at (interpreter.cpp:1703-1704). -/
theorem ecdsaEntry_badPubKey_false (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : isValidPubKey pk = false) :
    (ecdsaEntry verify sighash hasAmount).checkECDSASignature sig pk code v d = false := by
  simp only [ecdsaEntry, ecdsaVerdict]
  rw [if_pos (by simp [h])]

/-- SWT-053: the hashtype byte is popped before verify — the adapter
hands the verifier EXACTLY `sig` minus its last byte, and hashes with
exactly the popped byte (interpreter.cpp:1707-1712). -/
@[rule "SWT-053"]
theorem ecdsaEntry_pops_hashtype (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hpk : isValidPubKey pk = true) (hne : 0 < sig.size)
    (ham : v = SigVersion.witnessV0 → hasAmount = true) :
    (ecdsaEntry verify sighash hasAmount).checkECDSASignature sig pk code v d
      = verify (sig.extract 0 (sig.size - 1)) pk (sighash code sig[sig.size - 1]! v) := by
  simp only [ecdsaEntry, ecdsaVerdict]
  rw [if_neg (by simp [hpk]),
      if_neg (by omega),
      if_neg (by
        by_cases hv : v = SigVersion.witnessV0
        · rw [hv]
          by_cases ha : hasAmount
          · simp [ha]
          · exact absurd (ham hv) (by simp [ha])
        · simp [hv])]

/-- SWT-055: a WITNESS_V0 sighash with missing amount data fails closed
(interpreter.cpp:1715-1716: `sigversion == SigVersion::WITNESS_V0 &&
amount < 0` → `HandleMissingData`, which with the default handler is a
verify failure). -/
@[rule "SWT-055"]
theorem ecdsaEntry_witnessV0_missing_amount_false
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (sig pk code : ByteArray) (d : ScriptExecutionData)
    (hpk : isValidPubKey pk = true) (hne : 0 < sig.size) :
    (ecdsaEntry verify sighash false).checkECDSASignature
      sig pk code SigVersion.witnessV0 d = false := by
  simp only [ecdsaEntry, ecdsaVerdict]
  rw [if_neg (by simp [hpk]), if_neg (by omega), if_pos (by simp)]

/-! ## Schnorr entry (interpreter.cpp:1726-1752) -/

/-- `SIGHASH_DEFAULT` (BIP341): the implicit default hashtype for
key-path/tapscript Schnorr spends. -/
def SIGHASH_DEFAULT : UInt8 := 0

/-- The hashtype/body split for a BIP340 signature (interpreter.cpp:1739-1743):
64-byte sigs verify under SIGHASH_DEFAULT; 65-byte sigs carry an explicit
hashtype in the last byte, which must NOT be SIGHASH_DEFAULT and is popped
before verification. Any other size (incl. empty — tapscript's
empty-sig special case is resolved by `EvalChecksigTapscript` BEFORE this
entry is invoked, interpreter.cpp:377-380) is `none` = reject. -/
def schnorrHashtype (sig : ByteArray) : Option (ByteArray × UInt8) :=
  if sig.size = 64 then some (sig, SIGHASH_DEFAULT)
  else if sig.size = 65 then
    if sig[64]! = SIGHASH_DEFAULT then none
    else some (sig.extract 0 64, sig[64]!)
  else none

theorem schnorrHashtype_none (sig : ByteArray) (h : sig.size ≠ 64 ∧ sig.size ≠ 65) :
    schnorrHashtype sig = none := by
  unfold schnorrHashtype
  rw [if_neg (by omega), if_neg (by omega)]

theorem schnorrHashtype_64 (sig : ByteArray) (h : sig.size = 64) :
    schnorrHashtype sig = some (sig, SIGHASH_DEFAULT) := by
  unfold schnorrHashtype
  rw [if_pos h]

/-- interpreter.cpp:1741-1742: a 65-byte signature whose trailing
hashtype byte IS `SIGHASH_DEFAULT` is a hashtype error (reject). -/
theorem schnorrHashtype_65_default_rejected (sig : ByteArray) (h : sig.size = 65)
    (h0 : sig[64]! = SIGHASH_DEFAULT) : schnorrHashtype sig = none := by
  unfold schnorrHashtype
  rw [if_neg (by omega), if_pos h, if_pos h0]

theorem schnorrHashtype_65 (sig : ByteArray) (h : sig.size = 65)
    (h0 : sig[64]! ≠ SIGHASH_DEFAULT) :
    schnorrHashtype sig = some (sig.extract 0 64, sig[64]!) := by
  unfold schnorrHashtype
  rw [if_neg (by omega), if_pos h, if_neg h0]

/-- The consensus verdict of `CheckSchnorrSignature` for a checker whose
BIP340 verification is `verify` and whose BIP342 sighash is
`sighashSchnorr` (which may fail — missing txdata → fail-closed,
interpreter.cpp:1745-1747). Core `assert`s `sigversion ∈ {TAPROOT,
TAPSCRIPT}` and `pubkey.size == 32` (caller-enforced); a consensus
function cannot assert, so both become fail-closed rejects here. -/
def schnorrVerdict (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData) : Bool :=
  if v = SigVersion.taproot || v = SigVersion.tapscript then
    if pk.size = 32 then
      match schnorrHashtype sig with
      | none => false
      | some (body, ht) =>
          match sighashSchnorr d ht v with
          | none => false
          | some h => verify body pk h
    else false
  else false

/-- Schnorr adapter packaged as a checker. The ECDSA entry is the
The ECDSA slot (fail-closed here); assemble both with `txCheckerOf`. -/
def schnorrEntry (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray) :
    BaseSignatureChecker :=
  { checkECDSASignature := fun _ _ _ _ _ => false
    checkSchnorrSignature := schnorrVerdict verify sighashSchnorr }

/-- Size gate: only 64- and 65-byte signatures reach the EC math
(interpreter.cpp:1736-1737: `SCRIPT_ERR_SCHNORR_SIG_SIZE`). -/
theorem schnorrEntry_size_gate (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : sig.size ≠ 64 ∧ sig.size ≠ 65) :
    (schnorrEntry verify sighashSchnorr).checkSchnorrSignature sig pk v d = false := by
  simp only [schnorrEntry, schnorrVerdict, schnorrHashtype_none sig h]
  split
  · split <;> rfl
  · rfl

/-- TPR-072 (seam plumbing contract): the execdata record threaded
through the frozen Schnorr entry REACHES the sighash — two execution
datas agreeing on the sighash for every hashtype give identical
verdicts, and the digest passed to verify is `sighashSchnorr d ht v`
(interpreter.cpp:1745-1750). -/
@[rule "TPR-072"]
theorem schnorrEntry_execData_plumbed
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData)
    (hag : ∀ ht : UInt8, sighashSchnorr d₁ ht v = sighashSchnorr d₂ ht v) :
    (schnorrEntry verify sighashSchnorr).checkSchnorrSignature sig pk v d₁
      = (schnorrEntry verify sighashSchnorr).checkSchnorrSignature sig pk v d₂ := by
  simp only [schnorrEntry, schnorrVerdict]
  cases hs : schnorrHashtype sig with
  | none => rfl
  | some p =>
      cases p with
      | mk body ht =>
          simp only [hag]

/-- TPR-072 (threading face, evaluator step): once `schnorrHashtype` fixes the
signature body and hashtype, the entry hands the CALLER's execdata record `d`
unchanged to `sighashSchnorr`, and passes that function's result `digest`
verbatim to `verify`. There is no other execdata in scope, so every field the
sighash reads (annex/tapleaf/codesep/weight/output hash as implemented by
`sighashSchnorr`) is exactly the field of `d` supplied at the call site. -/
@[rule "TPR-072"]
theorem schnorrEntry_execData_threaded
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (body : ByteArray) (ht : UInt8)
    (hh : schnorrHashtype sig = some (body, ht))
    (digest : ByteArray)
    (hd : sighashSchnorr d ht v = some digest)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) :
    (schnorrEntry verify sighashSchnorr).checkSchnorrSignature sig pk v d
      = verify body pk digest := by
  simp only [schnorrEntry, schnorrVerdict]
  rw [if_pos (by rcases hv with rfl | rfl <;> simp), if_pos hp, hh]
  simp only [hd]

/-- TPR-072 (64-byte corollary): a 64-byte signature is hashed under the
implicit `SIGHASH_DEFAULT` (`0x00`) using the caller's exact execdata, and
the resulting digest is what `verify` receives. -/
@[rule "TPR-072"]
theorem schnorrEntry_64_digest
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (digest : ByteArray) (h64 : sig.size = 64)
    (hd : sighashSchnorr d SIGHASH_DEFAULT v = some digest)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) :
    (schnorrEntry verify sighashSchnorr).checkSchnorrSignature sig pk v d
      = verify sig pk digest :=
  schnorrEntry_execData_threaded verify sighashSchnorr sig pk v d sig
    SIGHASH_DEFAULT (schnorrHashtype_64 sig h64) digest hd hv hp

/-! ## TPR-072 residual (interpreter side, documented not claimed)

The theorems above quantify over the execdata supplied at the checker call
site. They do NOT claim that `Bitcoin.Interpreter.verifyWitnessProgram` /
`executeWitnessScript` populate every BIP341/342 field: the script-path arm
constructs a `default` record (plus `validationWeightLeft*`) and does not
forward `annexInit/annexPresent/annexHash` from the outer call, while
`tapleafHash`/`codesepPos`/`outputHash` have no writer in the interpreter
tree at all (the interpreter-audit offset note; see `Script/Tapscript/LeafVersion.lean`
"Honest gaps"). Closing that direction is an interpreter-seam change, not
a property of this checker adapter. -/

/-- The 65-byte explicit-hashtype path pops the byte before verify:
the digest is computed for the POPPED hashtype and the body handed to
verify is the first 64 bytes (interpreter.cpp:1739-1743, `SpanPopBack`). -/
theorem schnorrEntry_pops_hashtype
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript) (hp : pk.size = 32)
    (h : sig.size = 65) (h0 : sig[64]! ≠ SIGHASH_DEFAULT)
    (digest : ByteArray)
    (hd : sighashSchnorr d sig[64]! v = some digest)
    (hok : verify (sig.extract 0 64) pk digest = true) :
    (schnorrEntry verify sighashSchnorr).checkSchnorrSignature sig pk v d = true := by
  simp only [schnorrEntry, schnorrVerdict]
  rw [if_pos (by rcases hv with hv | hv <;> subst hv <;> simp),
      if_pos hp, schnorrHashtype_65 sig h h0]
  simp only [hd]
  exact hok

/-! ## The checker assembly -/

/-- The checker the interpreter binds the seam to for the checker assembly: real
lax-ECDSA entry parameterized by the EC verifier and the sighash
function, plus the Schnorr slot. -/
def txCheckerOf (verifyEcdsa : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray) :
    BaseSignatureChecker :=
  { checkECDSASignature := fun sig pk code v _ =>
      ecdsaVerdict verifyEcdsa sighash hasAmount v sig pk code
    checkSchnorrSignature := schnorrVerdict verifySchnorr sighashSchnorr }

/-- `txCheckerOf` agrees with `ecdsaEntry` on the ECDSA entry point. -/
theorem txCheckerOf_ecdsa
    (verifyEcdsa : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (txCheckerOf verifyEcdsa sighash hasAmount verifySchnorr sighashSchnorr).checkECDSASignature
        sig pk code v d
      = (ecdsaEntry verifyEcdsa sighash hasAmount).checkECDSASignature
          sig pk code v d := rfl

/-- `txCheckerOf` agrees with `schnorrEntry` on the Schnorr entry point. -/
theorem txCheckerOf_schnorr
    (verifyEcdsa : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (txCheckerOf verifyEcdsa sighash hasAmount verifySchnorr sighashSchnorr).checkSchnorrSignature
        sig pk v d
      = (schnorrEntry verifySchnorr sighashSchnorr).checkSchnorrSignature
          sig pk v d := rfl

end Bitcoin.Crypto.Seam.Entry
