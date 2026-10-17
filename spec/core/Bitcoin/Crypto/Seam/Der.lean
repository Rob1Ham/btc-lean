import Bitcoin.Crypto.Seam.Interface

/-!
# Bitcoin.Crypto.Seam.Der — BIP66 signature-encoding gate (W13)

Verbatim transliteration of the consensus-visible DER predicates from
Bitcoin Core `src/script/interpreter.cpp` @ cce32b168:

* `IsValidSignatureEncoding`  (interpreter.cpp:117-179) — consensus since
  BIP66; the encoding is
  `0x30 [total-len] 0x02 [lenR] [R] 0x02 [lenS] [S] [hashtype]`.
* `CheckSignatureEncoding`    (interpreter.cpp:211-227) — the flag
  dispatch. Consensus-visible part: empty sig → OK (a compact way to
  provide an invalid signature for CHECKMULTISIG); under DERSIG the
  encoding must be valid. LOW_S (BIP62 rule 5, INV-053) and STRICTENC
  hashtype-definedness (interpreter.cpp:198-208) are POLICY-only for v0
  scripts, so the consensus port takes just the dersig bit.
* `CPubKey::GetLen`/`IsValid` (pubkey.h) — header-byte key length; used
  by `CheckECDSASignature`'s `pubkey.IsValid()` gate
  (interpreter.cpp:1703-1704).
* `IsCompressedOrUncompressedPubKey` (interpreter.cpp:72-89) — STRICTENC
  policy gate (CheckPubKeyEncoding), included for completeness and
  clearly marked policy.

Theorems banked here are the seam contract for W09: empty-ok, the
DERSIG dispatch iff, lax acceptance, and BIP66's "valid DER is accepted
at every flag setting".
-/

/-!
## License notice (OPEN-004, landed 2026-10-17 by S13)

This file is a Lean transliteration (port) of MIT-licensed Bitcoin
Core code — see the module header above for the exact upstream anchors
(`src/script/interpreter.cpp`, `src/pubkey.h` @ cce32b168). Per MIT §2,
the notice text for the portion derived from Bitcoin Core (`COPYING`):

  The MIT License (MIT)
  Copyright (c) 2009-2026 The Bitcoin Core developers

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Project license: MIT (repo-root `LICENSE`, 2026 btc-lean contributors);
per-file provenance table: `docs/PROVENANCE.md` §1a.
-/

namespace Bitcoin.Crypto.Seam.Der

/-! ## IsValidSignatureEncoding (interpreter.cpp:117-179) -/

/-- BIP66 canonical signature encoding, consensus-critical since BIP66.
Line-by-line transliteration of `IsValidSignatureEncoding`
(interpreter.cpp:117-179 @cce32b168); out-of-range reads via `!` yield 0,
which can only make the predicate STRICTER, never weaker — and every
indexed position is in range whenever the earlier length checks passed
(unfolded bounds in `isValidSignatureEncoding_indexed_inbounds`). -/
def isValidSignatureEncoding (sig : ByteArray) : Bool :=
  -- Minimum and maximum size constraints. (:128-131)
  if sig.size < 9 then false
  else if sig.size > 73 then false
  -- A signature is of type 0x30 (compound). (:134)
  else if sig[0]! != 0x30 then false
  -- Make sure the length covers the entire signature. (:137)
  else if sig[1]!.toNat != sig.size - 3 then false
  else
    -- Extract the length of the R element. (:140)
    let lenR := sig[3]!.toNat
    -- Make sure the length of the S element is still inside the signature. (:143)
    if 5 + lenR >= sig.size then false
    else
      -- Extract the length of the S element. (:146)
      let lenS := sig[5 + lenR]!.toNat
      -- Verify that the length of the signature matches the sum of the
      -- length of the elements. (:149)
      if lenR + lenS + 7 != sig.size then false
      -- Check whether the R element is an integer. (:152)
      else if sig[2]! != 0x02 then false
      -- Zero-length integers are not allowed for R. (:155)
      else if lenR == 0 then false
      -- Negative numbers are not allowed for R. (:158)
      else if (sig[4]! &&& 0x80) != 0 then false
      -- Null bytes at the start of R are not allowed, unless R would
      -- otherwise be interpreted as a negative number. (:161-162)
      else if lenR > 1 && sig[4]! == 0x00 && (sig[5]! &&& 0x80) == 0 then false
      -- Check whether the S element is an integer. (:165)
      else if sig[lenR + 4]! != 0x02 then false
      -- Zero-length integers are not allowed for S. (:168)
      else if lenS == 0 then false
      -- Negative numbers are not allowed for S. (:171)
      else if (sig[lenR + 6]! &&& 0x80) != 0 then false
      -- Null bytes at the start of S are not allowed, unless S would
      -- otherwise be interpreted as a negative number. (:174-175)
      else if lenS > 1 && sig[lenR + 6]! == 0x00 && (sig[lenR + 7]! &&& 0x80) == 0 then false
      else true

/-! ## CheckSignatureEncoding dispatch (interpreter.cpp:211-227) -/

/-- The consensus-visible part of `CheckSignatureEncoding`
(interpreter.cpp:211-227 @cce32b168): empty signatures are ALWAYS
accepted (compact invalid-signature idiom for CHECKMULTISIG);
otherwise DERSIG (BIP66) demands a canonical encoding. LOW_S / STRICTENC
branches are policy (BIP146 catalogue, SCR-178/180) and live behind the
`dersig := false` lax mode here. -/
def checkSignatureEncoding (sig : ByteArray) (dersig : Bool) : Bool :=
  if sig.size = 0 then true
  else if dersig then isValidSignatureEncoding sig
  else true

/-- Empty signatures pass at every flag setting (interpreter.cpp:214-217:
"allowed to provide a compact way to provide an invalid signature for
use with CHECK(MULTI)SIG"). -/
theorem checkSignatureEncoding_empty (sig : ByteArray) (dersig : Bool)
    (h : sig.size = 0) : checkSignatureEncoding sig dersig = true := by
  unfold checkSignatureEncoding
  rw [if_pos h]

/-- Under DERSIG the check IS the BIP66 predicate (interpreter.cpp:218-219). -/
@[rule "INV-052"]
theorem checkSignatureEncoding_dersig_iff (sig : ByteArray) (h : 0 < sig.size) :
    checkSignatureEncoding sig true = isValidSignatureEncoding sig := by
  unfold checkSignatureEncoding
  rw [if_neg (by omega), if_pos rfl]

/-- Without DERSIG (and without the policy-only LOW_S/STRICTENC
consensus effect) any nonempty encoding passes (interpreter.cpp:226). -/
theorem checkSignatureEncoding_lax (sig : ByteArray) :
    checkSignatureEncoding sig false = true := by
  unfold checkSignatureEncoding
  split <;> rfl

/-- A BIP66-valid encoding is accepted at EVERY flag setting — the
consensus direction of the gate (validity can only be demanded, never
penalized). -/
theorem bip66_valid_accepted_everywhere (sig : ByteArray) (dersig : Bool)
    (h : isValidSignatureEncoding sig) : checkSignatureEncoding sig dersig = true := by
  unfold checkSignatureEncoding
  split
  · rfl
  · cases dersig
    · rfl
    · exact h

/-! ## Public-key validity (pubkey.h GetLen/IsValid; interpreter.cpp:1703) -/

/-- `CPubKey::GetLen` (pubkey.h): the header byte fixes the serialized
key length — 33 for compressed (0x02/0x03), 65 for uncompressed
(0x04) and hybrid (0x06/0x07), 0 for anything else. -/
def pubKeyLen (pk : ByteArray) : Nat :=
  if pk.size = 0 then 0
  else if pk[0]! = 0x02 || pk[0]! = 0x03 then 33
  else if pk[0]! = 0x04 || pk[0]! = 0x06 || pk[0]! = 0x07 then 65
  else 0

/-- `CPubKey::IsValid` = `size() > 0` (pubkey.h): exactly "the header
byte names a real key format". This is the gate
`CheckECDSASignature` applies BEFORE popping the hashtype
(interpreter.cpp:1703-1704). -/
def isValidPubKey (pk : ByteArray) : Bool := pubKeyLen pk ≠ 0

/-- A valid pubkey header yields the promised length (`GetLen` spec). -/
theorem pubKeyLen_values (pk : ByteArray) :
    pubKeyLen pk = 0 ∨ pubKeyLen pk = 33 ∨ pubKeyLen pk = 65 := by
  unfold pubKeyLen
  split
  · exact Or.inl rfl
  · split
    · exact Or.inr (Or.inl rfl)
    · split
      · exact Or.inr (Or.inr rfl)
      · exact Or.inl rfl

/-- Empty pubkey is invalid (`pubkey.IsValid()` fails on the 0-byte
vector) — the SWT-054-adjacent pubkey gate of CheckECDSASignature. -/
theorem isValidPubKey_empty : isValidPubKey ByteArray.empty = false := by decide

/-! ## Policy-only predicates (NOT consensus; BIP146 catalogue) -/

/-- `IsCompressedOrUncompressedPubKey` (interpreter.cpp:72-89): the
STRICTENC pubkey-type gate `CheckPubKeyEncoding` applies
(interpreter.cpp:228-236). Policy for v0 (SCR-178/180); consensus only
via tapscript's own rules (W09/Review-3). -/
def isCompressedOrUncompressedPubKey (pk : ByteArray) : Bool :=
  if pk.size < 33 then false
  else if pk[0]! == 0x04 then pk.size == 65
  else if pk[0]! == 0x02 || pk[0]! == 0x03 then pk.size == 33
  else false

end Bitcoin.Crypto.Seam.Der
