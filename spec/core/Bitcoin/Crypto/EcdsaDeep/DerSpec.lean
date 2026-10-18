import Bitcoin.Data.Basic
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Ecdsa.Der

/-!
# Bitcoin.Crypto.EcdsaDeep.DerSpec — abstract relational spec of the lax-DER parser

The DER layer of the deep-verification suite: an ABSTRACT, Core-anchored relational specification of
Bitcoin Core's `ecdsa_signature_parse_der_lax` (src/pubkey.cpp:45-185 @
cce32b168 = cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, the parent of the
cce32b168 pin; fetched 2026-10-16), and its PROVED correspondence with the
Lean executable parser `Bitcoin.Crypto.Ecdsa.Der.parseDerLax`
(spec/core/Bitcoin/Crypto/Ecdsa/Der.lean:108-142, read-only for the DER module).

Der-layer rung of the DER and verification-equation layers' proved-ECDSA tower: the relation is pure
first-order structure (positions, lengths, payload arithmetic) — no
WF-recursive crypto (R6/the no-axiom policy clean), fully kernel-checkable.

## What the C actually does (pubkey.cpp:45-185 @ cce32b168)

`pos` = byte offset, `inputlen` = `blen b`. 13 `return 0` sites:

| C lines | condition (C) | Lean (Der.lean) | `DerRej` ctor |
|---|---|---|---|
| 56 | `pos == inputlen ∥ input[0] ≠ 0x30` | 110 | `vac` |
| 62 | `pos == inputlen` (seq len byte) | 112 | `short` |
| 68 | long-form seq len doesn't fit | 116 | `seqlen` |
| 75 | R tag ≠ 0x02 | 118 | `rtag` (`IntRej.itag`) |
| 81 | R len byte past end | 120 → 89 | `rlend` (`itend`) |
| 87 | R long-form len doesn't fit | 120 → 95 | `rlenf` (`itfit`) |
| 95 | ≥ 4 R len-descriptor bytes | 120 → 98 | `rlenc` (`itcnt`) |
| 107 | `rlen > inputlen - pos` | 123 | `rfit` |
| 114 | S tag ≠ 0x02 | 127 | `stag` (`itag`) |
| 120/127/135 | S-len analogues of 81/87/95 | 129 | `slend`/`slenf`/`slenc` |
| 146 | `slen > inputlen - pos` | 131 | `sfit` |

(`Der.lean:89/95/98` are the three `none`-guards inside `readLenAt`,
Der.lean:88-99.)

Integer payload + value layer (C 151-184 ↔ Der.lean 135-142):

* C 151-155 / 163-167: leading zero payload bytes stripped
  (`stripZeros`, Der.lean 80-83) — `CoreLax` fields.
* C 157-158 / 169-170: post-strip length > 32 sets the ONE shared `int
  overflow` flag → C 178-183 `memset(tmpsig, 0, 64)` → **both** r and s
  come out 0 (`DerCoreSig.czero`; SGN-106/109).
* C 160 / 172: `memcpy(tmpsig + 32 - rlen, input + rpos, rlen)` = the
  post-strip big-endian payload read raw (`readBE`, Der.lean 61-64;
  `DerCoreSig.crs`). The mod-`n` `scalar_set_b32` reduction is NOT in this
  layer — it is in `secp256k1_ecdsa_signature_parse_compact`
  (src/secp256k1/src/secp256k1.c:407-427) — see `CoreZero` below; it is
  recorded as the DER-window note.

## The relation layer (this file)

`DerRej b` (13 ctors) = "Core returns 0 at that site";
`CoreLax b r s` = "Core returns 1 with signature value (r, s)" (the raw
layer = exactly `parseDerLax`'s value layer);
`IntRej` = the four `readLenAt`-level guards (C 81/87/95 + the tag C 75/114)
with `pos` = tag position (length byte at `pos+1`).

## Theorems (sorry-free; axiom pins in BitcoinProofs.EcdsaDeep.DerCor)

* `parseDerLax_rel` (R): `parseDerLax b = some (r, s) ↔ CoreLax b r s`.
* `parseDerLax_rej` (E): `parseDerLax b = none ↔ DerRej b` — reject cases
  exhaustive over the 13 C `return 0` sites.
* `coreLax_deterministic` (D): relation-functional r, s.
* `coreLax_exhaustive` (X): `CoreLax b r s ∨ DerRej b`.
* `coreLax_none`, `derRej_not_coreLax`: the split is a partition.

## Core ground truth, 32-byte `r ≥ n` window (the DER-window note)

`CoreZero b r s` = Core's `parse_compact`-overflow value layer
(secp256k1.c:407-427 + pubkey.cpp:175-183): post-strip rlen/slen ≤ 32 but
`readBE ≥ n` (scalar_set_b32 overflow) → parse_compact returns 0 →
`overflow = 1` (pubkey.cpp:175) → the whole 64-byte compact buffer is
zeroed (pubkey.cpp:178-183) → (r, s) = (0, 0) → `ecdsa_verify`
(ecdsa_impl.h:204-206) rejects zero r/s. The Lean `parseDerLax`/
`verifyImpl` instead keeps the raw r and reduces `r % n` (Verify.lean:91)
BEFORE the nonzero check — the two differ exactly on
`readBE rpos' rlen' ≥ n`, post-strip `rlen' ≤ 32`, `slen' ≤ 32`.
0/215 battery vectors cover it (the DER-layer python-C oracle, 2026-10-16).
-/

namespace Bitcoin.Crypto.EcdsaDeep.DerSpec

open Bitcoin.Crypto.Ecdsa.Der
open Bitcoin.Crypto.Curve.Secp

/-! ## `readLenAt`-structure props -/

/-- Integer head = tag byte 0x02 (C 75/114; Der.lean 118/127). -/
def TagAt (b : ByteArray) (pos : Nat) : Prop := pos < blen b ∧ byteAt b pos = 0x02

/-- `readLenAt b (pos+1) = none`, guard 1: `pos+1 ≥ blen b` (C 81/120;
`readLenAt` Der.lean 89). -/
def LenEnd (b : ByteArray) (pos : Nat) : Prop := pos + 1 ≥ blen b

/-- `readLenAt b (pos+1) = none`, guard 2: remaining long-form length
descriptor does not fit (C 87/127; Der.lean 95). -/
def LenFit (b : ByteArray) (pos : Nat) : Prop :=
  pos + 1 < blen b ∧ byteAt b (pos + 1) ≥ 0x80 ∧
  byteAt b (pos + 1) - 0x80 > blen b - (pos + 2)

/-- `readLenAt b (pos+1) = none`, guard 3: ≥ 4 length-descriptor bytes
remain after zero-skipping (C 95/135; Der.lean 98). `skipZeroBytes b
(pos+2) lf = (p', c')` with `c' ≥ 4`. -/
def LenCnt (b : ByteArray) (pos : Nat) : Prop :=
  pos + 1 < blen b ∧ byteAt b (pos + 1) ≥ 0x80 ∧
  byteAt b (pos + 1) - 0x80 ≤ blen b - (pos + 2) ∧
  ∃ p' c', skipZeroBytes b (pos + 2) (byteAt b (pos + 1) - 0x80) = (p', c') ∧ c' ≥ 4

/-- `readLenAt b (pos+1) = some (len, p)` = tag + well-formed length
descriptor (C 81-106/119-145; Der.lean 118-120/127-129). -/
def LenSome (b : ByteArray) (pos len p : Nat) : Prop :=
  readLenAt b (pos + 1) = some (len, p)

/-- The sequence-header prefix of every non-vacuous parse (C 56-72;
Der.lean 110-116): nonempty, tag 0x30, seq-len byte present, and the
R-tag position `p2` = 2 (short form) or 2 + (lb0 - 0x80) (long form,
bytes skipped unchecked), in bounds. -/
def SeqOk (b : ByteArray) (p2 : Nat) : Prop :=
  1 ≤ blen b ∧ 2 ≤ blen b ∧ byteAt b 0 = 0x30 ∧
  (byteAt b 1 < 0x80 → p2 = 2) ∧
  (byteAt b 1 ≥ 0x80 → p2 = 2 + (byteAt b 1 - 0x80)) ∧ p2 ≤ blen b

/-- The full R/S structural prefix (up to and including the S length
descriptor): everything the value layer needs (C 74-149; Der.lean
118-131). -/
def StrOk (b : ByteArray) (p2 rlen rpos slen spos : Nat) : Prop :=
  SeqOk b p2 ∧ TagAt b p2 ∧ LenSome b p2 rlen rpos ∧ rlen ≤ blen b - rpos ∧
  TagAt b (rpos + rlen) ∧ LenSome b (rpos + rlen) slen spos ∧ slen ≤ blen b - spos

/-! ## The reject relation: `DerRej b` = "Core returns 0" (13 sites) -/

/-- The `readLenAt`-level guards (C 81/87/95) plus the tag byte (C 75/114).
`pos` = tag position. `itag` carries the negated disjunction of
`TagAt` = "past end OR byte ≠ 0x02". -/
inductive IntRej (b : ByteArray) : Nat → Type
  /-- C 75 / 114; Der.lean 118 / 127. -/
  | itag (pos : Nat) (h : ¬ (pos < blen b ∧ byteAt b pos = 0x02)) :
      IntRej b pos
  /-- C 81 / 120. -/
  | itend (pos : Nat) (h : LenEnd b pos) : IntRej b pos
  /-- C 87 / 127. -/
  | itfit (pos : Nat) (h : LenFit b pos) : IntRej b pos
  /-- C 95 / 135. -/
  | itcnt (pos : Nat) (h : LenCnt b pos) : IntRej b pos

/-- The full reject relation (13 constructors = the 13 `return 0` sites).
`vac` covers both halves of the C 56 disjunction; `rtag`…`rlenc` carry the
`SeqOk b p2` + R-tag + R-`readLenAt`-failure structure; `rfit`…`sfit`
carry the structure up to the failing site. -/
inductive DerRej (b : ByteArray) : Type
  /-- C 56 (both `||` halves) + Der.lean 110. -/
  | vac (h : blen b < 1 ∨ byteAt b 0 ≠ 0x30)
  /-- C 62; Der.lean 112. -/
  | short (h : 1 ≤ blen b ∧ blen b < 2)
  /-- C 68; Der.lean 116. -/
  | seqlen (h : 2 ≤ blen b ∧ byteAt b 0 = 0x30 ∧ byteAt b 1 ≥ 0x80 ∧
      2 + (byteAt b 1 - 0x80) > blen b)
  /-- C 75; Der.lean 118. -/
  | rtag (p2 : Nat) (hseq : SeqOk b p2) (hr : ¬ (p2 < blen b ∧ byteAt b p2 = 0x02))
  /-- C 81; Der.lean 120 → 89. -/
  | rlend (p2 : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2) (hr : LenEnd b p2)
  /-- C 87; Der.lean 120 → 95. -/
  | rlenf (p2 : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2) (hr : LenFit b p2)
  /-- C 95; Der.lean 120 → 98. -/
  | rlenc (p2 : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2) (hr : LenCnt b p2)
  /-- C 107; Der.lean 123. -/
  | rfit (p2 rlen rpos : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2)
      (hrl : LenSome b p2 rlen rpos) (h : rlen > blen b - rpos)
  /-- C 114; Der.lean 127. -/
  | stag (p2 rlen rpos : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2)
      (hrl : LenSome b p2 rlen rpos) (hrf : rlen ≤ blen b - rpos)
      (hs : ¬ (rpos + rlen < blen b ∧ byteAt b (rpos + rlen) = 0x02))
  /-- C 120; Der.lean 129 → 89. -/
  | slend (p2 rlen rpos : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2)
      (hrl : LenSome b p2 rlen rpos) (hrf : rlen ≤ blen b - rpos)
      (hst : TagAt b (rpos + rlen)) (hs : LenEnd b (rpos + rlen))
  /-- C 127; Der.lean 129 → 95. -/
  | slenf (p2 rlen rpos : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2)
      (hrl : LenSome b p2 rlen rpos) (hrf : rlen ≤ blen b - rpos)
      (hst : TagAt b (rpos + rlen)) (hs : LenFit b (rpos + rlen))
  /-- C 135; Der.lean 129 → 98. -/
  | slenc (p2 rlen rpos : Nat) (hseq : SeqOk b p2) (hrt : TagAt b p2)
      (hrl : LenSome b p2 rlen rpos) (hrf : rlen ≤ blen b - rpos)
      (hst : TagAt b (rpos + rlen)) (hs : LenCnt b (rpos + rlen))
  /-- C 146; Der.lean 131. -/
  | sfit (p2 rlen rpos slen spos : Nat) (hst : StrOk b p2 rlen rpos slen spos)
      (h : slen > blen b - spos)

/-! ## The accept path: value layer (C 151-184; Der.lean 135-142). -/

/-- The integer value layer. `rpos' rlen'` resp. `spos' slen'` are the
post-`stripZeros` payload positions/lengths (C 151-155/163-167);
`czero` = the SHARED overflow flag zeroes both (C 157-158/169-170/175-183;
Der.lean 139-142, SGN-106/109); `crs` = the raw big-endian payload read
(C 160/172; Der.lean 140-141). -/
inductive DerCoreSig (b : ByteArray) (rpos' rlen' spos' slen' : Nat) :
    Nat → Nat → Prop
  /-- C 157-158 / 169-170 / 175-183: `rlen' > 32 ∨ slen' > 32` (or the
  parse_compact overflow, see `CoreZero`) → r = s = 0. -/
  | czero (hov : rlen' > 32 ∨ slen' > 32) : DerCoreSig b rpos' rlen' spos' slen' 0 0
  /-- C 160 / 172; Der.lean 140-141: raw `readBE` of the post-strip
  payloads. -/
  | crs (hr : rlen' ≤ 32) (hs : slen' ≤ 32)
      (r s : Nat) (hrv : r = readBE b rpos' rlen') (hsv : s = readBE b spos' slen') :
      DerCoreSig b rpos' rlen' spos' slen' r s

/-- The accept relation: `CoreLax b r s` = "Core returns 1 with (r, s)"
(the raw layer = `parseDerLax`'s value layer, BEFORE the mod-n
`scalar_set_b32` step — see `CoreZero`/the DER-window note). -/
def CoreLax (b : ByteArray) (r s : Nat) : Prop :=
  ∃ p2 rlen rpos slen spos rpos' rlen' spos' slen',
    StrOk b p2 rlen rpos slen spos ∧
    stripZeros b rpos rlen = (rpos', rlen') ∧
    stripZeros b spos slen = (spos', slen') ∧
    DerCoreSig b rpos' rlen' spos' slen' r s

/-! ## Core's post-`parse_compact` value layer (DER-window) -/

/-- `secp256k1_ecdsa_signature_parse_compact` (secp256k1.c:407-427) on the
raw `(r32, s32)` = `readBE` values: `scalar_set_b32` reduces mod `n` AND
returns 0 (b32-overflow) iff `r32 ≥ n ∨ s32 ≥ n`; pubkey.cpp:175-183 then
zeroes the whole 64-byte compact buffer → the Core signature value is
`(0, 0)` (rejected by ecdsa_verify, ecdsa_impl.h:204-206). This is where
Core and the Lean raw layer part ways (Lean keeps r32/s32; the mod-n
happens in verifyImpl, Verify.lean:91, before the nonzero check). -/
def CoreZero (b : ByteArray) : Prop :=
  ∃ p2 rlen rpos slen spos rpos' rlen' spos' slen',
    StrOk b p2 rlen rpos slen spos ∧
    stripZeros b rpos rlen = (rpos', rlen') ∧
    stripZeros b spos slen = (spos', slen') ∧
    rlen' ≤ 32 ∧ slen' ≤ 32 ∧
    (readBE b rpos' rlen' ≥ n ∨ readBE b spos' slen' ≥ n)

end Bitcoin.Crypto.EcdsaDeep.DerSpec
