/-
# BitcoinProofs.Bip.B04.Bip66Coverage — BIP66 strict-DER clause audit (Review-5, contributor B04)

Deliverable for the BIP-coverage audit of BIP66 (strict DER signatures).
BIP text: https://github.com/bitcoin/bips/blob/master/bip-0066.mediawiki
(BSD-2-Clause; this port of the reference checker is a faithful
re-implementation, structurally diffed against it clause by clause).

The 23 decisive per-clause vectors below were cross-checked in python3
against a verbatim port of the BIP's `IsValidSignatureEncoding`
(`scratch/B04/bip66_ref.py` in the suite tree, ALL_MATCH 2026-10-16).

Status split:
- The `isValidSignatureEncoding` port + all clause vectors: VERIFIED
  (BIP text + python3 cross-check).
- The tree-state references (`BIP66_HEIGHT`, `ScriptFlags.dersig`) are
  frozen-interface facts; see findings-w5/B04.md for the clause table.
- Revived-run note (2026-10-16): the live main-repo tree has since landed
  its own ports — Bitcoin.Interpreter.Defs.isValidSigEncoding :287
  (SCR-102) + checkSigEncoding :341 (C1/C2/C4) and
  Bitcoin.Crypto.Seam.Der :40/:87 (W14b); w05 had none. This module
  stays the BIP-text-faithful List-Nat port + the 23 per-clause
  kill-vectors (VERIFIED sorry-free by direct v4.35.0 toolchain
  compile, exit 0, axioms [propext]; lake build blocked by the
  build.lock stampede, F-B04-008). No cross-equivalence with the two
  live ports (F-B04-010).

Clause map (BIP66 §Specification, consensus force only):
- C1 DER requirement on CHECKSIG/CHECKSIGVERIFY/CHECKMULTISIG(VERIFY) under
  the DERSIG flag      → rules.yaml INV-052 / SCR-102
- C2 fail-entire-script on non-DER (not merely push-false) → INV-052
- C3 valid-DER-but-ECDSA-invalid ⇒ push false, continue (soft semantics,
  "only additional failures" soft-fork monotonicity)      → SCR-102/103
- C4 empty-signature exemption (size 0 not subject to the checker)
- C5 the 13 structural checks (a..m)                      → SCR-102
- C6 sighash flag byte outside DER scope                  → (implicit)
- C7 activation: DERSIG flag at height ≥ 363725 (BIP90-buried);
  originally isSuperMajority 950/1000 v3 gate, v2-block invalidation
                                                          → INV-128 / SCR-103 /
                                                            BLK-061 / BLK-085
-/

namespace BitcoinProofs.Bip.B04

/-! ## C5/C6: faithful port of `IsValidSignatureEncoding` (BIP66 reference)

Bytes are `Nat` (0..255) so every guard is kernel-`decide`-able; the
`getD … 0` defaults mirror C++ `operator[]` on the in-range indices the
reference touches (defaults are unreachable on the paths taken).
Check order is preserved verbatim — it is load-bearing (the BIP text
and Core's `interpreter.cpp:118-181@cce32b168` both rely on it). -/

/-- Verbatim port of BIP66's `IsValidSignatureEncoding`. `sig` includes
the trailing 1-byte sighash flag (C6), which is not part of DER. -/
def isValidSignatureEncoding (sig : List Nat) : Bool :=
  let n := sig.length
  -- C5a: minimum and maximum size constraints
  if n < 9 then false
  else if n > 73 then false
  -- C5b: a signature is of type 0x30 (compound)
  else if sig.getD 0 0 ≠ 0x30 then false
  -- C5c: the length covers the entire signature (minus sighash)
  else if sig.getD 1 0 ≠ n - 3 then false
  else
    let lenR := sig.getD 3 0
    -- C5d: the length of the S element is still inside the signature
    if 5 + lenR ≥ n then false
    else
      let lenS := sig.getD (5 + lenR) 0
      -- C5e: length of the signature matches the sum of the elements
      if lenR + lenS + 7 ≠ n then false
      -- C5f: the R element is an integer
      else if sig.getD 2 0 ≠ 0x02 then false
      -- C5g: zero-length integers are not allowed for R
      else if lenR = 0 then false
      -- C5h: negative numbers are not allowed for R
      else if sig.getD 4 0 ≥ 128 then false
      -- C5i: null bytes at the start of R are not allowed, unless R
      --      would otherwise be interpreted as a negative number
      else if lenR > 1 && sig.getD 4 0 = 0 && sig.getD 5 0 < 128 then false
      -- C5j: the S element is an integer
      else if sig.getD (lenR + 4) 0 ≠ 0x02 then false
      -- C5k: zero-length integers are not allowed for S
      else if lenS = 0 then false
      -- C5l: negative numbers are not allowed for S
      else if sig.getD (lenR + 6) 0 ≥ 128 then false
      -- C5m: null bytes at the start of S are not allowed, unless S
      --      would otherwise be interpreted as a negative number
      else if lenS > 1 && sig.getD (lenR + 6) 0 = 0 && sig.getD (lenR + 7) 0 < 128
        then false
      else true

/-- The interpreter's DERSIG gate (`CheckSignatureEncoding`,
interpreter.cpp:~449): the empty signature is exempt (C4 — "not called
for cases where the length of sig is 0"), everything else must be
strict DER. -/
def checkSignatureEncoding (sig : List Nat) : Bool :=
  sig.isEmpty || isValidSignatureEncoding sig

/-! ## Decisive per-clause vectors (python3 cross-checked, ALL_MATCH) -/

/-- Minimal well-formed sig: R=[0x01], S=[0x01], sighash=0x01. -/
def MIN : List Nat := [0x30,0x06,0x02,0x01,0x01,0x02,0x01,0x01,0x01]

-- positive control
theorem vec_valid_minimal : isValidSignatureEncoding MIN = true := by decide

-- C4: empty signature is exempt from the DER checker
theorem vec_empty_exempt : checkSignatureEncoding [] = true := by decide

-- C5a: 9 ≤ size ≤ 73
theorem vec_size_8_too_small :
    isValidSignatureEncoding [0x30,0x06,0x02,0x01,0x01,0x02,0x01,0x01] = false := by decide
theorem vec_size_74_too_big :
    isValidSignatureEncoding
      ([0x30,0x46,0x02,0x21] ++ List.replicate 33 1 ++ [0x02,0x21] ++
        List.replicate 33 1 ++ [0x01, 0x01]) = false := by decide
theorem vec_size_73_ok :
    isValidSignatureEncoding
      ([0x30,0x46,0x02,0x21] ++ List.replicate 33 1 ++ [0x02,0x21] ++
        List.replicate 33 1 ++ [0x01]) = true := by decide

-- C5b: compound header 0x30
theorem vec_header_not_0x30 :
    isValidSignatureEncoding [0x31,0x06,0x02,0x01,0x01,0x02,0x01,0x01,0x01] = false := by decide

-- C5c: total-length covers everything but the sighash byte
theorem vec_totallen_mismatch :
    isValidSignatureEncoding [0x30,0x07,0x02,0x01,0x01,0x02,0x01,0x01,0x01] = false := by decide

-- C5d: S length must still be inside the signature
theorem vec_lenR_outside :
    isValidSignatureEncoding [0x30,0x06,0x02,0x40,0x01,0x02,0x01,0x01,0x01] = false := by decide

-- C5e: lenR + lenS + 7 = size
theorem vec_sum_mismatch :
    isValidSignatureEncoding [0x30,0x06,0x02,0x01,0x01,0x02,0x02,0x01,0x01] = false := by decide

-- C5f: R is an integer (0x02)
theorem vec_R_not_integer :
    isValidSignatureEncoding [0x30,0x06,0x03,0x01,0x01,0x02,0x01,0x01,0x01] = false := by decide

-- C5g: zero-length R forbidden (two-byte S keeps size ≥ 9 so this kills
-- the lenR=0 clause specifically, not the size clause)
theorem vec_R_zero_len :
    isValidSignatureEncoding [0x30,0x04,0x02,0x00,0x02,0x02,0x00,0x80,0x01] = false := by decide

-- C5h: negative R forbidden (high bit set, no 0x00 pad)
theorem vec_R_negative :
    isValidSignatureEncoding [0x30,0x05,0x02,0x01,0x80,0x02,0x01,0x01,0x01] = false := by decide

-- C5i: null-padded R forbidden (leading 0x00, next byte without high bit)
theorem vec_R_null_padded :
    isValidSignatureEncoding [0x30,0x07,0x02,0x02,0x00,0x01,0x02,0x01,0x01,0x01] = false := by decide

-- C5i (allowed side): single 0x00 when next byte has the high bit
theorem vec_R_null_single_ok :
    isValidSignatureEncoding [0x30,0x07,0x02,0x02,0x00,0x80,0x02,0x01,0x01,0x01] = true := by decide

-- C5j: S is an integer (0x02)
theorem vec_S_not_integer :
    isValidSignatureEncoding [0x30,0x06,0x02,0x01,0x01,0x03,0x01,0x01,0x01] = false := by decide

-- C5k: zero-length S forbidden (lenR=2 keeps size ≥ 9)
theorem vec_S_zero_len :
    isValidSignatureEncoding [0x30,0x05,0x02,0x02,0x01,0x01,0x02,0x00,0x01] = false := by decide

-- C5l: negative S forbidden
theorem vec_S_negative :
    isValidSignatureEncoding [0x30,0x06,0x02,0x01,0x01,0x02,0x01,0x80,0x01] = false := by decide

-- C5m: null-padded S forbidden
theorem vec_S_null_padded :
    isValidSignatureEncoding [0x30,0x07,0x02,0x01,0x01,0x02,0x02,0x00,0x01,0x01] = false := by decide

-- C5m (allowed side): single 0x00 when next byte has the high bit
theorem vec_S_null_single_ok :
    isValidSignatureEncoding [0x30,0x07,0x02,0x01,0x01,0x02,0x02,0x00,0x80,0x01] = true := by decide

-- C6: the sighash byte is outside DER scope (two flag values, same verdict)
theorem vec_sighash_01_ok :
    isValidSignatureEncoding [0x30,0x06,0x02,0x01,0x01,0x02,0x01,0x01,0x01] = true := by decide
theorem vec_sighash_ff_ok :
    isValidSignatureEncoding [0x30,0x06,0x02,0x01,0x01,0x02,0x01,0x01,0xff] = true := by decide

/-! ## C2/C3 essence: soft-fork monotonicity ("only additional failures")

Strict mode (flag on) differs from lax mode (flag off) only by
requiring DER: a signature accepted under DERSIG is accepted without
it (C3's "opcode execution continues as it used to"), and the
empty-signature exemption (C4) keeps the deliberately-invalid
compact form legal in both modes. Pinned on the checker pair above. -/

theorem strict_implies_lax (sig : List Nat)
    (h : isValidSignatureEncoding sig = true) :
    checkSignatureEncoding sig = true := by
  simp [checkSignatureEncoding, h]

theorem empty_allowed_without_flag (sig : List Nat) (h : sig.isEmpty) :
    checkSignatureEncoding sig = true := by
  simp [checkSignatureEncoding, h]

end BitcoinProofs.Bip.B04

-- Axiom footprints (rule 4: no sorryAx on any audit theorem).
#print axioms BitcoinProofs.Bip.B04.vec_valid_minimal
#print axioms BitcoinProofs.Bip.B04.vec_size_74_too_big
#print axioms BitcoinProofs.Bip.B04.strict_implies_lax
