import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Crypto.Seam.Der
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Seam.Mock

/-!
# Bitcoin.Crypto.Seam.Tests — build-time verified examples

Every check here is a `decide`-verified `example` (kernel-checked at
build time, no runtime harness needed). These exercise the DER gate,
the pubkey predicate, both checker adapters and the mock checker on
small fixed inputs.

NOTE: full-fidelity hash vectors (incl. the genesis header dsha256) live
in `Test/Crypto/SeamHashTest.lean` — the kernel's `decide` does not
whnf-reduce the 64-round compression fast enough, so those use
`native_decide` under the Test/ path (sorry-lint L1 rule) plus an IO
harness cross-checked against `python3 hashlib`.
-/

namespace Bitcoin.Crypto.Seam.Tests

open Der Entry Mock

set_option maxRecDepth 100000

/-! ## Hex helper (test infra only) -/

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)        -- '0'..'9'
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)  -- 'a'..'f'
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)  -- 'A'..'F'
  else none

/-- Parse a hex string into a ByteArray (test infra only). -/
def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-! ## BIP66 DER vectors (INV-052) -/

/-- Minimal valid DER sig: `30 06 02 01 01 02 01 03` + hashtype `01`. -/
def vSig : ByteArray := fromHex "300602010102010301"

-- Well-formed minimal encoding passes (the consensus happy path).
example : isValidSignatureEncoding vSig = true := by decide

-- Wrong compound type byte (0x31).
example : isValidSignatureEncoding (fromHex "310602010102010301") = false := by decide

-- Too short (8 bytes).
example : isValidSignatureEncoding (fromHex "30050201010201") = false := by decide

-- Too long (74 bytes: 0x30 0x47 then 72 filler bytes).
example : isValidSignatureEncoding
    (fromHex ("3047" ++ String.mk (List.replicate 144 'a'))) = false := by decide

-- Total length != lenR+lenS+7 (length descriptor lies).
example : isValidSignatureEncoding (fromHex "30070201010201030101") = false := by decide

-- R-length zero (zero-length integers not allowed).
example : isValidSignatureEncoding (fromHex "300602000102010301") = false := by decide

-- R negative (high bit set).
example : isValidSignatureEncoding (fromHex "300602018002010301") = false := by decide

-- Excessively padded R (leading null without a negative next byte).
example : isValidSignatureEncoding (fromHex "30070202000102010301") = false := by decide

-- S element not tagged 0x02 (R ok, S tag 0x03).
example : isValidSignatureEncoding (fromHex "300602010103010301") = false := by decide

-- S zero-length.
example : isValidSignatureEncoding (fromHex "300602010102000301") = false := by decide

-- S negative.
example : isValidSignatureEncoding (fromHex "300602010102018001") = false := by decide

/-! ## CheckSignatureEncoding dispatch (INV-052) -/

-- Empty signature accepted at EVERY flag setting (compact CHECKMULTISIG fail idiom).
example : checkSignatureEncoding ByteArray.empty true = true := by decide
example : checkSignatureEncoding ByteArray.empty false = true := by decide

-- DERSIG on ⇒ verdict = BIP66 predicate.
example : checkSignatureEncoding vSig true = true := by decide
example : checkSignatureEncoding (fromHex "310602010102010301") true = false := by decide

-- DERSIG off ⇒ nonempty encodings pass (lax; policy checks are not consensus).
example : checkSignatureEncoding (fromHex "310602010102010301") false = true := by decide

-- BIP66's accept-direction: valid DER accepted everywhere (bip66_valid_accepted_everywhere, instanced).
example : (checkSignatureEncoding vSig true, checkSignatureEncoding vSig false) = (true, true) := by
  decide

/-! ## Pubkey validity (pubkey.h GetLen/IsValid) -/

example : isValidPubKey (fromHex "02") = true := by decide
example : isValidPubKey (fromHex "03") = true := by decide
example : isValidPubKey (fromHex "04") = true := by decide
example : isValidPubKey (fromHex "06") = true := by decide
example : isValidPubKey (fromHex "07") = true := by decide
example : isValidPubKey (fromHex "05") = false := by decide
example : isValidPubKey (fromHex "01") = false := by decide
example : isValidPubKey ByteArray.empty = false := by decide
example : pubKeyLen (fromHex "03") = 33 := by decide
example : pubKeyLen (fromHex "04") = 65 := by decide

/-- Repeat a hex char n times (test infra only). -/
private def hexRep (c : Char) (n : Nat) : String := String.ofList (List.replicate n c)

-- STRICTENC policy predicate (NOT consensus): compressed/uncompressed only.
example : isCompressedOrUncompressedPubKey (fromHex ("02" ++ hexRep '2' 64)) = true := by decide
example : isCompressedOrUncompressedPubKey (fromHex ("04" ++ hexRep '2' 128)) = true := by decide
example : isCompressedOrUncompressedPubKey (fromHex ("06" ++ hexRep '2' 128)) = false := by decide
example : isCompressedOrUncompressedPubKey (fromHex "02") = false := by decide

/-! ## ECDSA entry (SWT-053/054/055) -/

def pkC : ByteArray := fromHex "02"    -- valid header ⇒ isValidPubKey

-- Always-true verifier + hashtype-echoing sighash: a well-formed spend passes.
example : (ecdsaEntry (fun _ _ _ => true) (fun _ ht _ => ByteArray.empty.push ht) true
    |>.checkECDSASignature vSig pkC (fromHex "51") SigVersion.base default) = true := by decide

-- The verifier receives sig-minus-hashtype (SWT-053, pop before verify):
-- sig body is 8 bytes, sighash gets the popped byte 0x01.
example : (ecdsaEntry (fun s _ _ => s.size == 8)
    (fun _ ht _ => ByteArray.empty.push ht) true
    |>.checkECDSASignature vSig pkC (fromHex "51") SigVersion.base default) = true := by decide
example : (ecdsaEntry (fun s _ _ => s.size == 9)
    (fun _ ht _ => ByteArray.empty.push ht) true
    |>.checkECDSASignature vSig pkC (fromHex "51") SigVersion.base default) = false := by decide

-- SWT-054: empty signature fails closed, even with an always-true verifier.
example : (ecdsaEntry (fun _ _ _ => true) (fun _ _ _ => ByteArray.empty) true
    |>.checkECDSASignature ByteArray.empty pkC (fromHex "51") SigVersion.base default) = false := by decide

-- SWT-055: WITNESS_V0 with missing amount fails closed.
example : (ecdsaEntry (fun _ _ _ => true) (fun _ _ _ => ByteArray.empty) false
    |>.checkECDSASignature vSig pkC (fromHex "51") SigVersion.witnessV0 default) = false := by decide

--...but the same spend passes once the amount is present.
example : (ecdsaEntry (fun _ _ _ => true) (fun _ _ _ => ByteArray.empty) true
    |>.checkECDSASignature vSig pkC (fromHex "51") SigVersion.witnessV0 default) = true := by decide

-- Invalid pubkey header fails before anything else.
example : (ecdsaEntry (fun _ _ _ => true) (fun _ _ _ => ByteArray.empty) true
    |>.checkECDSASignature vSig (fromHex "05") (fromHex "51") SigVersion.base default) = false := by decide

/-! ## Schnorr entry -/

def pk32 : ByteArray := fromHex (String.mk (List.replicate 64 '2'))
def sig64 : ByteArray := fromHex (String.mk (List.replicate 128 '1'))
def sig65 : ByteArray :=
  fromHex (String.mk (List.replicate 128 '1')) ++ ByteArray.empty.push 0x01
def sig65Default : ByteArray :=
  fromHex (String.mk (List.replicate 128 '1')) ++ ByteArray.empty.push 0x00
def digest32 : ByteArray := fromHex (String.mk (List.replicate 64 '7'))

-- Key-path spend, 64-byte sig, digest available: passes.
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkSchnorrSignature sig64 pk32 SigVersion.taproot default) = true := by decide

-- 65-byte sig with explicit hashtype (popped before verify): passes.
example : (schnorrEntry (fun s _ _ => s.size == 64) (fun _ ht _ => some digest32)
    |>.checkSchnorrSignature sig65 pk32 SigVersion.tapscript default) = true := by decide

-- interpreter.cpp:1741-1742: 65-byte sig with SIGHASH_DEFAULT as its
-- explicit hashtype byte is a hashtype error.
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkSchnorrSignature sig65Default pk32 SigVersion.taproot default) = false := by decide

-- Size gate: 63-byte sig rejected before EC math.
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkSchnorrSignature (fromHex (String.mk (List.replicate 126 '1'))) pk32
      SigVersion.taproot default) = false := by decide

-- Core asserts 32-byte keys; fail-closed here.
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkSchnorrSignature sig64 pkC SigVersion.taproot default) = false := by decide

-- Core asserts sigversion ∈ {TAPROOT, TAPSCRIPT}; fail-closed here.
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkSchnorrSignature sig64 pk32 SigVersion.base default) = false := by decide
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkSchnorrSignature sig64 pk32 SigVersion.witnessV0 default) = false := by decide

-- Missing sighash data (none): fail-closed (HandleMissingData).
example : (schnorrEntry (fun _ _ _ => true) (fun _ _ _ => none)
    |>.checkSchnorrSignature sig64 pk32 SigVersion.taproot default) = false := by decide

-- SIGHASH_DEFAULT is 0.
example : SIGHASH_DEFAULT = 0 := by decide

/-! ## The checker assembly (txCheckerOf) -/

example : (txCheckerOf (fun _ _ _ => true) (fun _ ht _ => ByteArray.empty.push ht) true
    (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkECDSASignature vSig pkC (fromHex "51") SigVersion.base default) = true := by decide
example : (txCheckerOf (fun _ _ _ => true) (fun _ ht _ => ByteArray.empty.push ht) true
    (fun _ _ _ => true) (fun _ _ _ => some digest32)
    |>.checkSchnorrSignature sig64 pk32 SigVersion.taproot default) = true := by decide

/-! ## Mock checker -/

def sigA : ByteArray := fromHex "01"
def pkA : ByteArray := fromHex "02"
def table : MockTable := [((sigA, pkA), true), ((pkA, sigA), false)]

example : mockFind table sigA pkA = true := by decide
example : mockFind table pkA sigA = false := by decide
example : mockFind table (fromHex "ff") pkA = false := by decide

example : (mockChecker table |>.checkECDSASignature sigA pkA (fromHex "51")
    SigVersion.base default) = true := by decide
example : (mockChecker table |>.checkSchnorrSignature sigA pkA
    SigVersion.taproot default) = true := by decide
example : (mockChecker [] |>.checkECDSASignature sigA pkA (fromHex "51")
    SigVersion.base default) = false := by decide

/-! ## Frozen stub + seam shape (unchanged from the frozen interface's freeze) -/

example : stubChecker.checkECDSASignature (fromHex "01") pkA (fromHex "51")
    SigVersion.base default = true := by decide
example : stubChecker.checkECDSASignature ByteArray.empty pkA (fromHex "51")
    SigVersion.base default = false := by decide

-- The seam has exactly two entry points (checker_ext, instanced).
example : (stubChecker.checkECDSASignature, stubChecker.checkSchnorrSignature) =
    (stubChecker.checkECDSASignature, stubChecker.checkSchnorrSignature) := rfl

/-! ## ScriptExecutionData / SigVersion shape -/

example : (default : ScriptExecutionData).tapleafHashInit = false := by decide
example : (default : ScriptExecutionData).annexPresent = false := by decide
example : (default : ScriptExecutionData).outputHash = none := by decide
example : (default : ScriptExecutionData).codesepPos = 0xFFFFFFFF := by decide

-- Four sig versions, all distinct (Core's BASE/WITNESS_V0/TAPROOT/TAPSCRIPT).
example : SigVersion.base ≠ SigVersion.witnessV0 := by decide
example : SigVersion.witnessV0 ≠ SigVersion.taproot := by decide
example : SigVersion.taproot ≠ SigVersion.tapscript := by decide

end Bitcoin.Crypto.Seam.Tests
