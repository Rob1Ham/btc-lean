import Bitcoin.Data.Basic
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Ecdsa.Der

/-!
# Bitcoin.Crypto.Ecdsa.Verify — the lax ECDSA verifier

Consensus semantics = Core's `CPubKey::Verify` (src/key.cpp @ cce32b168):

1. `parsePubKey` — `secp256k1_ec_pubkey_parse` (`group_impl.h::ge_parse`):
   33-byte compressed (02 even-y / 03 odd-y; y recovered by the p ≡ 3 mod 4
   square root, report §2.3), 65-byte uncompressed (04) and hybrid (06/07,
   parity-checked), with `x, y < P` and the on-curve check `y² = x³+7`.
2. `parseDerLax` — see `Ecdsa.Der`.
3. **mod-n reduction**: libsecp256k1's `secp256k1_scalar_set_b32` reduces the
   32-byte big-endian `r`, `s` (and message hash) modulo the group order
   `n` inside `signature_parse_compact`; only AFTERwards does
   `secp256k1_ecdsa_verify` reject `r = 0 ∨ s = 0`. This reduction is
   consensus-relevant: strict DER (BIP66) admits 33-byte integers, so
   values `≥ n` can reach the verifier and are taken modulo `n`.
   (Subtle edge — pinned by a dedicated vector in the test layer.)
4. `w = s⁻¹ (mod n)`; `u1 = z·w`, `u2 = r·w` (mod `n`);
   `R = u1·G + u2·Q`; reject if `R = 𝒪`; accept iff `R.x % n = r`.

Low-S normalization (`signature_normalize`) is applied by Core before
`ecdsa_verify`, but verification is invariant under `s ↦ n − s`
(`u1, u2 ↦ −u1, −u2` gives `R ↦ −R`, same x), so the verifier here needs no
normalize step — low-S stays POLICY (`Der.isLowDERSignature`), never
consensus. This is exactly Core's own comment at key.cpp.

Argument order of the frozen `verifyLax` stub was unnamed; the implementation pins
it as `verifyLax sig pubKey msg32` mirroring `CPubKey::Verify(hash, sig)`
with the pubkey as receiver. The seam must pass arguments in this order.
-/

namespace Bitcoin.Crypto.Ecdsa.Verify

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Curve.Mod
open Bitcoin.Crypto.Ecdsa.Der

/-! ## Public-key parsing -/

/-- `secp256k1_ec_pubkey_parse` → affine coordinates, `none` = reject.
SGN-105: pubkey parse (33/65-byte forms, hybrid parity check). -/
@[rule "SGN-105"]
def parsePubKey (b : ByteArray) : RawPoint :=
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

/-! ## Big-endian serialization (test/bridge helpers) -/

/-- Byte `i` (0 = most significant) of the big-endian 32-byte encoding of `x`. -/
def beByte32 (x : Nat) (i : Nat) : UInt8 :=
  (x / 256^(31 - i)) % 256 |>.toUInt8

/-- The big-endian 32-byte encoding of `x` (as `secp256k1_eckey_pubkey_serialize`
writes compressed keys' payload). -/
def beBytes32 (x : Nat) : ByteArray :=
  ByteArray.mk ((Array.range 32).map (fun i => beByte32 x i))

/-! ## The verifier -/

/-- Core `CPubKey::Verify`'s EC part, lax DER semantics. `msg` is the
32-byte sighash (already composed by the caller — the seam).
SGN-107 + SGN-110: compact sig parse mod-n reduction of r,s,msg before zero check. -/
@[rule "SGN-107", rule "SGN-110"]
def verifyImpl (sig pk msg : ByteArray) : Bool :=
  match parseDerLax sig with
  | none => false
  | some (r0, s0) =>
    match parsePubKey pk with
    | none => false
    | some (qx, qy) =>
      -- scalar_set_b32 reduction (mod n) + nonzero check
      let z := bytesToNatBE msg % n
      let r := r0 % n
      let s := s0 % n
      if r == 0 || s == 0 then false
      else
        let w := invM n s
        let u1 := mulM n z w
        let u2 := mulM n r w
        match addP (mulP u1 (some G)) (mulP u2 (some (qx, qy))) with
        | none => false
        | some (rx, _) => rx % n == r

/-! ## Sanity theorems (structural; the parser is kernel-reducible) -/

/-- An unparseable (empty) signature fails verification. -/
theorem verifyImpl_sig_nil (pk msg : ByteArray) :
    verifyImpl ByteArray.empty pk msg = false := by
  unfold verifyImpl parseDerLax
  simp [blen, byteAt]

/-- A garbage pubkey (empty) fails verification. -/
theorem verifyImpl_pk_nil (sig msg : ByteArray) :
    verifyImpl sig ByteArray.empty msg = false := by
  unfold verifyImpl
  cases h : parseDerLax sig with
  | none => rfl
  | some v =>
    have hpk : parsePubKey ByteArray.empty = none := by
      simp only [parsePubKey, blen, byteAt]
      simp
    rw [hpk]

end Bitcoin.Crypto.Ecdsa.Verify
