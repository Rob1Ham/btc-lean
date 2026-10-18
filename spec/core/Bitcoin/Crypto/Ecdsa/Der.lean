import Bitcoin.Data.Basic
import Bitcoin.Crypto.Curve.Secp

/-!
# Bitcoin.Crypto.Ecdsa.Der — DER signature parsing (lax + strict BIP66)

Faithful port of Core `src/pubkey.cpp::ecdsa_signature_parse_der_lax`
(taken by Core itself from libsecp256k1) and
`src/script/interpreter.cpp::IsValidSignatureEncoding` (BIP66), both read
at the pinned commit `cce32b168`.

## Lax grammar (what pre-BIP66 consensus effectively accepted)

```
0x30 seqLenSkipped 0x02 rLen r 0x02 sLen s
```

* the sequence length byte may use long form; its bytes are **skipped, not
  checked** (garbage tolerated);
* integer lengths may use long form; zero-valued length bytes inside the
  long-form prefix are skipped; the remaining length must be < 4 bytes and
  the declared length must fit the input;
* integer payloads may have arbitrary leading zeros (stripped) and may be
  "negative" DER (no `0x00` pad before a high bit) — the raw big-endian
  value is used either way;
* payloads longer than 32 bytes (after zero-stripping) set libsecp256k1's
  `overflow`, which zeroes that integer — so the signature parses but has
  `r = 0` (resp. `s = 0`) and fails verification's nonzero check;
* trailing garbage after `s` is ignored (parse stops at `spos`).

The parser is structurally recursive and total: no `none` is ever returned
for a structurally valid prefix, matching Core. The result `(r, s)` carries
**unreduced** big-endian values; the `% n` reduction (libsecp256k1's
`secp256k1_scalar_set_b32` behavior inside `signature_parse_compact`) happens
in `Verify.verifyImpl`.

## Strict BIP66 (`isDERSignature`)

Byte-exact port of `IsValidSignatureEncoding` — operates on the script
signature INCLUDING the trailing sighash byte:
`0x30 totalLen 0x02 rLen R 0x02 sLen S sighash` with minimal encodings,
no negatives, `9 ≤ size ≤ 73`. Empty signatures are allowed by the
interpreter (`CheckSignatureEncoding`) before this check is reached.

`isLowDERSignature` ports `IsLowDERSignature`/`CPubKey::CheckLowS`
(policy-only since low-S is NOT consensus-enforced; BIP62 rule 5).
-/

/-!
## License notice (OPEN-004, landed 2026-10-17 by the license cleanup)

This file is a Lean transliteration (port) of MIT-licensed Bitcoin
Core code — see the module header above for the exact upstream anchors
(`src/pubkey.cpp::ecdsa_signature_parse_der_lax`,
`src/script/interpreter.cpp::IsValidSignatureEncoding` @ cce32b168). Per
MIT §2, the notice text for the portion derived from Bitcoin Core
(`COPYING`):

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

Project license: MIT (repo-root `LICENSE`, 2026 btc-lean authors);
per-file provenance table: `docs/PROVENANCE.md` §1a.
-/

namespace Bitcoin.Crypto.Ecdsa.Der

open Bitcoin.Crypto.Curve.Secp

/-! ## Byte access -/

/-- Bounds-safe byte read (`0` past the end). -/
def byteAt (b : ByteArray) (i : Nat) : Nat := (b.data.getD i 0).toNat

def blen (b : ByteArray) : Nat := b.data.size

/-- Big-endian read of `len` bytes starting at `pos`. -/
def readBE (b : ByteArray) (pos len : Nat) : Nat :=
  match len with
  | 0 => 0
  | l + 1 => readBE b pos l * 256 + byteAt b (pos + l)

/-- Drop the trailing sighash byte (used by `isLowDERSignature`). -/
def dropLastByte (b : ByteArray) : ByteArray := ⟨b.data.take (blen b - 1)⟩

/-! ## Length decoding -/

/-- libsecp256k1's zero-skipping inside long-form integer lengths:
consume length-descriptor bytes that are `0x00`. Returns the new position
and the remaining descriptor count. -/
def skipZeroBytes (b : ByteArray) (pos cnt : Nat) : Nat × Nat :=
  match cnt with
  | 0 => (pos, 0)
  | c + 1 => if byteAt b pos == 0 then skipZeroBytes b (pos + 1) c else (pos, c + 1)

/-- Strip leading zero payload bytes (lax: excessive padding tolerated). -/
def stripZeros (b : ByteArray) (pos len : Nat) : Nat × Nat :=
  match len with
  | 0 => (pos, 0)
  | l + 1 => if byteAt b pos == 0 then stripZeros b (pos + 1) l else (pos, l + 1)

/-- Integer length decoding at `pos` (after the `0x02` tag): short form, or
long form with zero-skipping and the `< 4` descriptor bound.
Returns `(length, payloadPosition)`. -/
def readLenAt (b : ByteArray) (pos : Nat) : Option (Nat × Nat) :=
  if pos ≥ blen b then none
  else
    let lb := byteAt b pos
    if lb < 0x80 then some (lb, pos + 1)
    else
      let lf := lb - 0x80
      if lf > blen b - (pos + 1) then none
      else
        let (pos', cnt) := skipZeroBytes b (pos + 1) lf
        if cnt ≥ 4 then none
        else some (readBE b pos' cnt, pos' + cnt)

/-! ## The lax parser -/

/-- `parse_der_lax` (Core `pubkey.cpp` @ cce32b168). Returns the **raw**
big-endian `(r, s)` — `0` where libsecp256k1's overflow path zeroed an
overlong integer. Structural failures yield `none`.
SGN-106 + SGN-109: lax DER parse; shared-flag overlong integers zero BOTH r and s. -/
@[rule "SGN-106", rule "SGN-109"]
def parseDerLax (b : ByteArray) : Option (Nat × Nat) :=
  -- sequence tag byte
  if blen b < 1 || byteAt b 0 != 0x30 then none
  -- sequence length byte(s): long-form bytes are skipped without validation
  else if blen b < 2 then none
  else
    let lb0 := byteAt b 1
    let pos1 := if lb0 < 0x80 then 2 else 2 + (lb0 - 0x80)
    if lb0 ≥ 0x80 && pos1 > blen b then none
    -- integer tag byte for R
    else if pos1 ≥ blen b || byteAt b pos1 != 0x02 then none
    else
      match readLenAt b (pos1 + 1) with
      | none => none
      | some (rlen, rpos) =>
        if rlen > blen b - rpos then none
        else
          -- integer tag byte for S
          let pos2 := rpos + rlen
          if pos2 ≥ blen b || byteAt b pos2 != 0x02 then none
          else
            match readLenAt b (pos2 + 1) with
            | none => none
            | some (slen, spos) =>
              if slen > blen b - spos then none
              else
                -- strip leading zeroes; ONE shared overflow flag: when either
                -- integer is overlong, Core memsets the whole 64-byte compact
                -- buffer, so BOTH come out 0 (pubkey.cpp @ cce32b168).
                let (rpos', rlen') := stripZeros b rpos rlen
                let (spos', slen') := stripZeros b spos slen
                let ov := rlen' > 32 || slen' > 32
                let r := if ov then 0 else readBE b rpos' rlen'
                let s := if ov then 0 else readBE b spos' slen'
                some (r, s)

/-! ## Strict BIP66 validators -/

/-- `IsValidSignatureEncoding` (Core `interpreter.cpp` @ cce32b168; BIP66).
Input includes the trailing sighash byte.
SGN-111: strict BIP66 DER predicate. -/
@[rule "SGN-111"]
def isDERSignature (b : ByteArray) : Bool :=
  if blen b < 9 || blen b > 73 then false
  else if byteAt b 0 != 0x30 then false
  else if byteAt b 1 != blen b - 3 then false
  else
    let lenR := byteAt b 3
    if 5 + lenR ≥ blen b then false
    else
      let lenS := byteAt b (5 + lenR)
      if lenR + lenS + 7 != blen b then false
      else if byteAt b 2 != 0x02 then false
      else if lenR == 0 then false
      else if byteAt b 4 / 128 % 2 == 1 then false
      else if lenR > 1 && byteAt b 4 == 0 && byteAt b 5 / 128 % 2 != 1 then false
      else if byteAt b (lenR + 4) != 0x02 then false
      else if lenS == 0 then false
      else if byteAt b (lenR + 6) / 128 % 2 == 1 then false
      else if lenS > 1 && byteAt b (lenR + 6) == 0 && byteAt b (lenR + 7) / 128 % 2 != 1 then false
      else true

/-- Half the group order (`secp256k1_scalar_half`): `s` must be `≤` this for
low-S. -/
def halfN : Nat := n / 2

/-- `IsLowDERSignature` (BIP62 §5; POLICY — not consensus-enforced): strict
DER, and `s % n ≤ n/2` on the DER part (sighash byte dropped, exactly as
`CPubKey::CheckLowS` receives `vchSigCopy`).
SGN-108: high-S verifies (no normalize in consensus; low-S is policy). -/
@[rule "SGN-108"]
def isLowDERSignature (b : ByteArray) : Bool :=
  isDERSignature b &&
  match parseDerLax (dropLastByte b) with
  | none => false
  | some (_, s) => s % n ≤ halfN

/-! ## Sanity theorems (structural; nothing here needs P's primality) -/

/-- Empty input does not parse. -/
theorem parseDerLax_nil : parseDerLax (ByteArray.empty) = none := by
  simp [parseDerLax, blen, byteAt]

/-- The strict-DER validator rejects empty and short inputs. -/
theorem isDERSignature_short (b : ByteArray) (h : blen b < 9) : isDERSignature b = false := by
  unfold isDERSignature
  have hc : (decide (blen b < 9) || decide (blen b > 73)) = true := by
    simp [decide_eq_true h]
  rw [hc]
  rfl

end Bitcoin.Crypto.Ecdsa.Der
