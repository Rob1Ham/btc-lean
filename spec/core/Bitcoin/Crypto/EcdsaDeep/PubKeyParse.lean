import Bitcoin.Data.Basic
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Crypto.Ecdsa.Verify

/-!
# Bitcoin.Crypto.EcdsaDeep.PubKeyParse — pubkey parse, the deep/provable twin

The pubkey-parse layer of the deep-verification suite. `spec/core/Bitcoin/Crypto/EcdsaDeep/` is
new ground: this file is the **pubkey-parse lane** — a
semantics-identical twin of `Ecdsa/Verify.parsePubKey` (SGN-105)
plus the CPubKey-side header matrix, with the structure the pubkey-parse proofs
(`spec/proofs/BitcoinProofs/EcdsaDeep/PubKeyCor.lean`) need:
Core-anchored tag constants, a port of `CPubKey::GetLen`, serializers,
and the byte/tag/length reject matrix (kernel-reducible, no
`native_decide` — the no-axiom policy).

## Core @ cce32b168 anchors (all read at the full pin
`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`, 2026-10-15)

* `CPubKey::GetLen` — src/pubkey.h:69-76:
  `chHeader == 2 || 3 → COMPRESSED_SIZE (33, pubkey.h:49)`;
  `chHeader == 4 || 6 || 7 → SIZE (65, pubkey.h:48)`; else `0`.
* `CPubKey::ValidSize` — src/pubkey.h:86-88:
  `vch.size() > 0 && GetLen(vch[0]) == vch.size()`.
* `CPubKey::Set` — src/pubkey.h:98-105 (the decode dimension check):
  `len = GetLen(pbegin[0]); if (len && len == pend - pbegin) copy else
  Invalidate()` (a mismatched header/length pair never becomes a valid
  `CPubKey`; `Invalidate` writes `vch[0] = 0xFF`, pubkey.h:79-82).
* `CPubKey::Verify` — src/pubkey.cpp:283-294:
  `IsValid() → secp256k1_ec_pubkey_parse(ctx, &pubkey, vch, size())`
  (pubkey.cpp:288) `→ ecdsa_signature_parse_der_lax` (pubkey.cpp:291).
* `secp256k1_ec_pubkey_parse` — src/secp256k1/src/secp256k1.c:265-281:
  `ge_parse` (secp256k1.c:272) + `ge_is_in_correct_subgroup`
  (secp256k1.c:275; trivially true for the secp256k1 prime-order group
  outside `EXHAUSTIVE_TEST_ORDER`, group_impl.h:969-980).
* `secp256k1_ge_impl_parse` — src/secp256k1/src/group_impl.h:1084-1102:
  - 33 bytes, tag 02/03 (`SECP256K1_TAG_PUBKEY_EVEN/ODD`):
    `fe_set_b32_limit(&x, pub+1) && ge_set_xo_var(elem, &x, tag == ODD)`
    (group_impl.h:1087) — `fe_set_b32_limit` rejects `x ≥ p`
    (hence "limit"), `ge_set_xo_var` rejects non-residues
    (`fe_sqrt` returns 0) and picks the root with the tag's parity
    (group_impl.h:370-374: `if (fe_is_odd(&y) != odd) negate`).
  - 65 bytes, tag 04/06/07 (`UNCOMPRESSED/HYBRID_EVEN/HYBRID_ODD`):
    `fe_set_b32_limit` for x AND y (group_impl.h:1090, rejects ≥ p),
    `ge_set_xy` (group_impl.h:1093), **hybrid parity check**
    (group_impl.h:1094-1096: for tags 06/07,
    `fe_is_odd(&y) != (tag == HYBRID_ODD)` → reject; tag 04 is NOT
    parity-checked), then `ge_is_valid_var` (group_impl.h:1098) —
    the on-curve check `y² = x³ + 7` (secp256k1.h:30 curve constant).
  - every other (size, tag) combination: reject (group_impl.h:1099-1101).
* `secp256k1_eckey_seckey_tweak_add`/`pubkey_tweak_add` etc. —
  src/secp256k1/src/eckey_impl.h (2026 layout: the parse lives in
  `group_impl.h::ge_parse`, the eckey file carries only the tweaks).

## Relationship to `parsePubKey` (SGN-105)

`parsePubKeyDeep` is a byte-identical transliteration of
`Ecdsa/Verify.parsePubKey` (Verify.lean:47-63) — the 33/65-byte forms,
`x ≥ P` (fe_set_b32_limit), the `isSqrt` acceptance (ge_set_xo_var /
`fe_sqrt`'s residue check), the tag-parity root pick
(`(tag == 0x03) == (root % 2 == 1)`, ge_set_xo_var's
"negate unless parity matches"), the 65-byte `x,y < P`, the hybrid
parity rejection (group_impl.h:1094-1096) and `onCurveN`
(`ge_is_valid_var`). The theorem `parsePubKeyDeep_eq` below pins the
equality by `rfl`; **`parsePubKey`'s 215/215 conformance battery
(the curve/ECDSA notes §2.2) therefore transfers verbatim to
`parsePubKeyDeep`.**

## The parse matrices (proof-friendly, have-free)

`parseMatrix33`/`parseMatrix65` are the **have-free** relational twins
of the two accept lanes (same conditions as `parsePubKeyDeep`'s
branches, but with `liftY2`/`sqrtP` inlined — no `let`s — so that
`split at h` extraction works, the `liftX`/`liftX_onCurve` pattern
(Secp.lean:367-443)); `parsePubKeyDeep_spec` pins the def ↔ matrix
bridge case-exhaustively over every tag/length `Bool` condition.

The pubkey-parse layer proofs proper (round-trips, y-parity, hybrid acceptance
matrix, `expM ↔ x^e mod P`, Euler/Fermat in `ZMod P`) live in the
proofs package (`BitcoinProofs.EcdsaDeep.PubKeyCor`) — mathlib is a
leaf dependency of that package only.

## The CPubKey-side acceptance matrix (GetLen port)

`CPubKey::GetLen` + `ValidSize` + `Set` (pubkey.h:69-105) decide which
byte strings can even *become* a `CPubKey` before the secp256k1 parse
runs — the header tags {02, 03} pair with length 33, {04, 06, 07} with
length 65, everything else (incl. tag 0xFF from `Invalidate`, empty)
is an invalid key and `CPubKey::Verify` returns false early
(pubkey.cpp:284-285). `pubKeyLen` + `validPubKeySize` below port this
matrix.
-/

namespace Bitcoin.Crypto.EcdsaDeep.PubKeyParse

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Curve.Mod
open Bitcoin.Crypto.Ecdsa.Der
open Bitcoin.Crypto.Ecdsa.Verify

/-! ## Tag constants (secp256k1.h `SECP256K1_TAG_PUBKEY_*`) -/

/-- `SECP256K1_TAG_PUBKEY_EVEN` = 0x02 (33-byte compressed, even y). -/
def tagPubKeyEven : Nat := 0x02
/-- `SECP256K1_TAG_PUBKEY_ODD` = 0x03 (33-byte compressed, odd y). -/
def tagPubKeyOdd : Nat := 0x03
/-- `SECP256K1_TAG_PUBKEY_UNCOMPRESSED` = 0x04 (65-byte, no parity check). -/
def tagPubKeyUncompressed : Nat := 0x04
/-- `SECP256K1_TAG_PUBKEY_HYBRID_EVEN` = 0x06 (65-byte hybrid, y must be even). -/
def tagPubKeyHybridEven : Nat := 0x06
/-- `SECP256K1_TAG_PUBKEY_HYBRID_ODD` = 0x07 (65-byte hybrid, y must be odd). -/
def tagPubKeyHybridOdd : Nat := 0x07

/-- `CPubKey::COMPRESSED_SIZE` = 33 (pubkey.h:49). -/
def compressedSize : Nat := 33
/-- `CPubKey::SIZE` = 65 (pubkey.h:48). -/
def uncompressedSize : Nat := 65

/-! ## The CPubKey header matrix (pubkey.h:69-105) -/

/-- **Port of `CPubKey::GetLen`** (pubkey.h:69-76): the length a header
byte promises — `2/3 → 33`, `4/6/7 → 65`, else `0` (invalid). Note the
hybrid tags 06/07 ARE valid CPubKey headers: a hybrid pubkey is a valid
`CPubKey` (hybrid acceptance at the Core script level, pinned
`pkform-*` vectors). -/
def pubKeyLen (tag : Nat) : Nat :=
  if tag == 2 || tag == 3 then compressedSize
  else if tag == 4 || tag == 6 || tag == 7 then uncompressedSize
  else 0

/-- **Port of `CPubKey::ValidSize`** (pubkey.h:86-88):
`vch.size() > 0 && GetLen(vch[0]) == vch.size()` — the decode-dimension
consistency a `CPubKey` enforces on `Set` (pubkey.h:98-105). -/
def validPubKeySize (b : ByteArray) : Bool :=
  blen b > 0 && pubKeyLen (byteAt b 0) == blen b

/-! ## The secp256k1 ge_impl_parse acceptance matrix (group_impl.h:1084-1102)

The hybrid parity check (group_impl.h:1094-1096), the fe_set_b32_limit
`x,y < P` checks (1087/1090) and the `ge_set_xo_var` residue acceptance
(1087 + 370-376) are factored out as `hybridParityOk`/`limitOk65`/
`sqrtOk` so the 65B matrix is decidable on literals without touching
`expM` (the R6 fuel-recursion poison — the curve/ECDSA notes §2.1, the modular-arithmetic note);
R6 is confined to the compressed lane's `sqrtP`. -/

/-- The hybrid parity check (group_impl.h:1094-1096): for tags 06/07,
`fe_is_odd(y) == (tag == 0x07)`; tags 04 (and the 33-byte lane) skip
the check entirely. -/
def hybridParityOk (tag y : Nat) : Bool :=
  if tag == 0x06 || tag == 0x07 then (y % 2 == 1) == (tag == 0x07) else true

/-- `fe_set_b32_limit` for both fields, 65-byte lane — group_impl.h:1090. -/
def limitOk65 (x y : Nat) : Bool := x < P && y < P

/-- The `ge_set_xo_var` residue acceptance: `isSqrt (liftY2 x) (sqrtP (liftY2 x))`
(group_impl.h:1087 + 370-376; `sqrtP` = the p ≡ 3 mod 4 exponent
`secp256k1_fe_sqrt` computes). -/
def sqrtOk (x : Nat) : Bool := isSqrt (liftY2 x) (sqrtP (liftY2 x))

/-- **The 33-byte accept lane** (tag 02/03, group_impl.h:1087), have-free:
reject `x ≥ P` (fe_set_b32_limit), reject non-residues (`!isSqrt` =
ge_set_xo_var/fe_sqrt), else the tag-parity root pick
(`(tag == 0x03) == (root % 2 == 1)`, "negate unless parity matches",
group_impl.h:370-374). `root = sqrtP (liftY2 x)` = `liftCand x`
(Secp.lean:352), delta-equal at every use site. -/
def parseMatrix33 (tag x : Nat) : Option (Nat × Nat) :=
  if x ≥ P then none
  else if !isSqrt (liftY2 x) (sqrtP (liftY2 x)) then none
  else some (x, if (tag == 0x03) == (sqrtP (liftY2 x) % 2 == 1)
                then sqrtP (liftY2 x) else negN (sqrtP (liftY2 x)))

/-- **The 65-byte accept lane** (tag 04/06/07, group_impl.h:1090-1098),
have-free: reject `x ≥ P ∨ y ≥ P` (fe_set_b32_limit), reject hybrid
parity mismatch (06/07 only, group_impl.h:1094-1096), reject off-curve
(`ge_is_valid_var` = `onCurveN`), else `some (x, y)`. -/
def parseMatrix65 (tag x y : Nat) : Option (Nat × Nat) :=
  if x ≥ P || y ≥ P then none
  else if (tag == 0x06 || tag == 0x07) && ((y % 2 == 1) != (tag == 0x07)) then none
  else if onCurveN x y then some (x, y) else none

/-! ## The parse twin + the `rfl` bridge to SGN-105 -/

/-- The pubkey-parse layer parse twin: a byte-identical transliteration of
`Ecdsa/Verify.parsePubKey` (SGN-105) — compressed (02/03) with
`x < P` + `isSqrt` acceptance + tag-parity root pick (ge_set_xo_var:
group_impl.h:370-374), uncompressed (04) / hybrid (06/07) with
`x,y < P`, hybrid parity (group_impl.h:1094-1096) and `onCurveN`
(`ge_is_valid_var`, group_impl.h:1098). Rejects everything else
(group_impl.h:1099-1101). -/
def parsePubKeyDeep (b : ByteArray) : RawPoint :=
  let tag := byteAt b 0
  if blen b == 33 && (tag == 0x02 || tag == 0x03) then
    let x := readBE b 1 32
    if x ≥ P then none
    else
      let y2 := liftY2 x
      let root := sqrtP y2
      if !isSqrt y2 root then none
      else some (x, if (tag == 0x03) == (root % 2 == 1) then root else negN root)
  else if blen b == 65 && (tag == 0x04 || tag == 0x06 || tag == 0x07) then
    let x := readBE b 1 32
    let y := readBE b 33 32
    if x ≥ P || y ≥ P then none
    else if (tag == 0x06 || tag == 0x07) && ((y % 2 == 1) != (tag == 0x07)) then none
    else if onCurveN x y then some (x, y) else none
  else none

/-- The bridge to SGN-105: **`parsePubKeyDeep` is `parsePubKey`**,
byte for byte (definitional). The 215/215 conformance battery over
`parsePubKey` (the curve/ECDSA notes §2.2: 10 `pk-*` negatives
incl. bad tag / x ≥ P / off-curve / hybrid parity / lengths, 10
`pkform-*` 04 + 06/07 accept paths) therefore transfers to
`parsePubKeyDeep` verbatim. -/
theorem parsePubKeyDeep_eq (b : ByteArray) :
    parsePubKeyDeep b = Bitcoin.Crypto.Ecdsa.Verify.parsePubKey b := by
  rfl

/-! ## Serializers (ge_impl_serialize33 / ge_impl_serialize65) -/

/-- `secp256k1_ge_impl_serialize33` (group_impl.h:1111-1118):
`pub33[0] = fe_is_odd(y) ? 0x03 : 0x02; fe_get_b32(&pub33[1], x)`.
The tag byte carries the y-parity bit. -/
def serCompressed (tag x : Nat) : ByteArray :=
  ByteArray.empty.push tag.toUInt8 ++ beBytes32 x

/-- `secp256k1_ge_impl_serialize65` (group_impl.h:1125-1133):
`pub65[0] = 0x04; fe_get_b32(&pub65[1], x); fe_get_b32(&pub65[33], y)`.
(The C serializer always writes tag 04 — hybrid tags 06/07 are
parse-only, never produced.) -/
def serUncompressed (x y : Nat) : ByteArray :=
  ByteArray.empty.push 0x04 ++ beBytes32 x ++ beBytes32 y

/-- The hybrid form 06/07: like 65B-uncompressed but the tag carries
the y-parity bit (hybrid = parse-accepted by the matrix, never
serialized by libsecp256k1). -/
def serHybrid (x y : Nat) : ByteArray :=
  ByteArray.empty.push (if y % 2 == 1 then 0x07 else 0x06) ++ beBytes32 x
    ++ beBytes32 y

end Bitcoin.Crypto.EcdsaDeep.PubKeyParse
