import Bitcoin.Wallet.Key.Origin
import Bitcoin.Wallet.Crypto.Hmac
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Seam.Hash

/-!
# Bitcoin.Wallet.Key.Bip32

An executable model of the BIP32 key tree: master key generation from a
seed, private and public child-key derivation, neutering, path
derivation, and the raw 78-byte extended-key encoding (without Base58).

## Shape of the model

An extended key is `depth`, parent fingerprint, child number, chain code
and key material. `ExtKey K` is parameterised by the key type, so the
private and public records share the four metadata fields and differ
only in `key`. A private key carries its range invariant (`0 < k < n`)
in the structure; a public key is the curve's raw affine point, with
`none` standing for the point at infinity.

## Derivation (BIP32 "Child key derivation (CKD) functions")

`ckdPriv` implements CKDpriv. For a hardened child (`i ≥ 2^31`,
`isHardened i = true`) the HMAC data is

  0x00 ‖ ser₂₅₆(k_par) ‖ ser₃₂(i),

and for a normal child it is

  ser_P(point(k_par)) ‖ ser₃₂(i),

where `ser_P` is SEC1 compressed form, starting with 0x02 or 0x03.
`ckdPub` implements CKDpub for normal children only, using
`ser_P(K_par) ‖ ser₃₂(i)`; hardened indices fail.

Bitcoin Core spells the same branches out in `CKey::Derive`
(`src/key.cpp:294-311`): hardened uses header byte `0` and the 32-byte
secret, normal uses the first byte of the compressed public key as the
header and the next 32 bytes as data. `CPubKey::Derive`
(`src/pubkey.cpp:341-363`) rejects hardened indices by assertion and
otherwise tweaks the public key by `I_L`. The HMAC itself is
`BIP32Hash` (`src/hash.cpp:71-76`): chain code as key, header ‖ 32-byte
key ‖ `ser32(i)` as data, big-endian index written by `WriteBE32`.

This module's documentation mentions "0x00/0x01 ser32 prefixes".
BIP32 has 0x00 for the hardened private-key branch and SEC1 0x02/0x03
for the public-key branch; no 0x01 appears in CKD. The code follows the
specification and Core, and the tests below would fail on a 0x01 byte.

## Validity and failure

BIP32 declares a child invalid when `parse₂₅₆(I_L) ≥ n` or the
resulting secret is zero (private) / the resulting point is infinity
(public); Core's `CExtKey::Derive` returns `false` and
`CPubKey::Derive` returns `false` in those cases. `DeriveError`
distinguishes those conditions from a hardened public derivation and
from depth overflow (Core refuses to derive below depth 255,
`src/key.cpp:362`). BIP32 also says to continue with the next index;
this model does not search, it returns the error, so callers choose the
skip policy.

## The public-key agreement law (target)

BIP32's "Private parent key → public child key" section states

  N(CKDpriv((k,c), i)) = CKDpub(N(k,c), i)     for non-hardened i,

and, for a path, `N(m/a/b) = N(m/a)/b = …`. The statement is present
below as `ckdPubAgreementTarget` and `ckdPubPathAgreementTarget`. They
are **targets**, not theorems: the missing ingredient is the group
homomorphism `point(I_L + k) = point(I_L) + point(k)`, which needs the
secp256k1 group law over the field, not merely the executable
double-and-add in `Bitcoin.Crypto.Curve.Secp`. Only the cheap
structural lemmas are proved in this module.

## Serialization

`serializePriv` / `serializePub` emit the 78-byte BIP32 payload:
4 version bytes, depth, 4 parent-fingerprint bytes, 4 child-number
bytes (big-endian), 32 chain-code bytes, then either `0x00 ‖ ser₂₅₆(k)`
or `ser_P(K)`. Mainnet versions are `0x0488ADE4` (private) and
`0x0488B21E` (public), from `src/kernel/chainparams.cpp:179-180`.
Core's `CExtKey::Serialize` writes the 74 bytes after the version
(`src/key.h:262-268`), and `EncodeExtKey` prepends the four version
bytes (`src/key_io.cpp:283-290`). Base58 and the double-SHA256 checksum
are deliberately absent; they are a later wrapper.

## Fingerprints

`fingerprint` is the first four bytes of `HASH160(ser_P(K))`. Core's
`CKey::id_key_fingerprint` is `GetPubKey().GetID().fingerprint()`
(`src/key.h:257-260`), and `CPubKey::GetID` is `Hash160` of the
serialized key (`src/pubkey.h:169-172`); `KeyFingerprint` is the four-byte
prefix (`src/pubkey.h:33-38`). This model hashes the compressed
serialization and takes bytes 0–3.

## What is not modelled

No Base58Check, no WIF, no BIP39 mnemonic or seed derivation, no BIP85,
no signing or ECDSA/Schnorr production, no wallet database, no address
encoding, no watch-only import policy, and no on-curve validation of
imported public keys (BIP32 requires it; here a raw point is accepted
and serialization is defined even for `none`). Fingerprint collisions
are not resolved, the "advance to the next index" rule is not automated,
and the model says nothing about side channels or secret erasure. The
curve arithmetic is the executable raw-`Nat` layer; its group-law
correctness is not proved here.
-/

namespace Bitcoin.Wallet.Key

open Bitcoin.Wallet.Crypto
open Bitcoin.Crypto.Curve

/-! ## Byte helpers -/

/-- Big-endian serialization of a natural number into 32 bytes,
`ser₂₅₆` (BIP32 "Conventions"). Values below 2^256 are represented
exactly; larger values are truncated by the byte mask, which callers
never rely on. -/
def ser32BE (x : Nat) : ByteArray :=
  (List.range 32).foldl
    (fun a i => a.push ((x >>> ((31 - i) * 8)).toUInt8)) ByteArray.empty

/-- `ser32BE` is always 32 bytes. -/
theorem ser32BE_size (x : Nat) : (ser32BE x).size = 32 := by
  unfold ser32BE
  exact (Crypto.Sha512.foldl_size_of_step (l := List.range 32)
    (step := fun a i => a.push ((x >>> ((31 - i) * 8)).toUInt8))
    (hstep := fun a i => by simp) ByteArray.empty).trans (by simp)

/-- Big-endian serialization of a 32-bit integer into four bytes,
`ser₃₂(i)` (BIP32 "Conventions"). -/
def ser32U (x : UInt32) : ByteArray :=
  (List.range 4).foldl
    (fun a i => a.push ((x >>> ((3 - i) * 8).toUInt32).toUInt8)) ByteArray.empty

/-- `ser32U` is always four bytes. -/
theorem ser32U_size (x : UInt32) : (ser32U x).size = 4 := by
  unfold ser32U
  exact (Crypto.Sha512.foldl_size_of_step (l := List.range 4)
    (step := fun a i => a.push ((x >>> ((3 - i) * 8).toUInt32).toUInt8))
    (hstep := fun a i => by simp) ByteArray.empty).trans (by simp)

/-! ## Keys -/

/-- A private key as an integer in `[1, n-1]` (BIP32 master-key
validity: `parse₂₅₆(I_L)` must be nonzero and below the group order). -/
structure PrivKey where
  val : Nat
  pos : 0 < val
  lt : val < Secp.n

/-- A public key is the raw affine point; `none` is infinity. -/
abbrev PubKey := Secp.RawPoint

/-- `point(k)`: scalar multiplication of the generator (BIP32
`point(p)`). -/
def pubOfPriv (k : PrivKey) : PubKey :=
  Secp.mulP k.val Secp.G

/-- SEC1 compressed serialization, `ser_P` (BIP32 "Conventions"):
`(0x02 or 0x03) ‖ ser₂₅₆(x)`. -/
def serPub : PubKey → ByteArray
  | none => ByteArray.empty
  | some (x, y) =>
    (ByteArray.empty.push (if y % 2 == 0 then (0x02 : UInt8) else 0x03)) ++ ser32BE x

/-- A valid compressed public key is 33 bytes. -/
theorem serPub_size (p : PubKey) (h : p ≠ none) : (serPub p).size = 33 := by
  cases p with
  | none => exact absurd rfl h
  | some q =>
    obtain ⟨x, y⟩ := q
    simp [serPub, ser32BE_size]

/-- The four-byte key fingerprint: the first four bytes of
`HASH160(ser_P(K))` (BIP32 "Key identifiers"). -/
def fingerprint (p : PubKey) : ByteArray :=
  (Bitcoin.Crypto.Seam.Hash.hash160 (serPub p)).extract 0 4

/-- A public key's fingerprint is four bytes (for `none` the definition
still yields four bytes of `HASH160` of the empty string; that input is
not a valid key and is never serialized by a caller). -/
theorem fingerprint_size (p : PubKey) : (fingerprint p).size = 4 := by
  unfold fingerprint
  rw [ByteArray.size_extract, Bitcoin.Crypto.Seam.Hash.hash160_size]
  simp

/-! ## Extended keys -/

/-- BIP32 extended-key metadata plus one key of type `K`. -/
structure ExtKey (K : Type) where
  depth : UInt8
  parentFingerprint : ByteArray
  childNumber : UInt32
  chainCode : ByteArray
  key : K

abbrev ExtPrivKey := ExtKey PrivKey
abbrev ExtPubKey := ExtKey PubKey

/-- `N((k,c))`: replace the private key by `point(k)` and keep the
metadata and chain code ("Neutered" in Core, `src/key.cpp:394-403`). -/
def neuter (x : ExtPrivKey) : ExtPubKey :=
  { depth := x.depth
    parentFingerprint := x.parentFingerprint
    childNumber := x.childNumber
    chainCode := x.chainCode
    key := pubOfPriv x.key }

theorem neuter_depth (x : ExtPrivKey) : (neuter x).depth = x.depth := rfl

theorem neuter_parentFingerprint (x : ExtPrivKey) :
    (neuter x).parentFingerprint = x.parentFingerprint := rfl

theorem neuter_childNumber (x : ExtPrivKey) :
    (neuter x).childNumber = x.childNumber := rfl

theorem neuter_chainCode (x : ExtPrivKey) :
    (neuter x).chainCode = x.chainCode := rfl

theorem neuter_key (x : ExtPrivKey) : (neuter x).key = pubOfPriv x.key := rfl

/-! ## Hardened indices -/

/-- BIP32's `i ≥ 2^31` test, written on the 32-bit index. -/
def isHardened (i : UInt32) : Bool :=
  decide (0x80000000 ≤ i)

theorem isHardened_flag : isHardened 0x80000000 = true := by decide

theorem isHardened_zero : isHardened 0 = false := by decide

/-! ## Errors -/

/-- Distinct causes of a failed derivation. -/
inductive DeriveError where
  | invalidSeedLength
  | invalidMasterKey
  | depthOverflow
  | hardenedFromPublic
  | invalidParentPubKey
  | invalidChild
  | invalidPublicChild
  deriving Repr, DecidableEq

/-! ## Master key generation -/

/-- The ASCII HMAC key `"Bitcoin seed"` (BIP32 "Master key generation";
Core `src/key.cpp:383-385`). -/
def seedHmacKey : ByteArray := "Bitcoin seed".toUTF8

/-- Master extended private key from a seed: `I = HMAC-SHA512("Bitcoin
seed", S)`, `k = parse₂₅₆(I_L)`, `c = I_R`, depth 0, zero fingerprint
and child number. Core's `CExtKey::SetSeed` additionally asserts
`16 ≤ |S| ≤ 64` (`src/key.cpp:381-392`); the length rule is returned as
an error here instead of an assertion. -/
def masterFromSeed (seed : ByteArray) : Except DeriveError ExtPrivKey :=
  if h : seed.size < 16 ∨ seed.size > 64 then .error .invalidSeedLength
  else
    let I := Crypto.Hmac.hmacSha512 seedHmacKey seed
    let il := Secp.bytesToNatBE (I.extract 0 32)
    if h : il = 0 ∨ Secp.n ≤ il then .error .invalidMasterKey
    else
      let hpos : 0 < il := by omega
      let hlt : il < Secp.n := by omega
      .ok { depth := 0
            parentFingerprint := ByteArray.mk #[0, 0, 0, 0]
            childNumber := 0
            chainCode := I.extract 32 64
            key := ⟨il, hpos, hlt⟩ }

/-! ## CKD -/

/-- CKDpriv (BIP32 "Private parent key → private child key"). -/
def ckdPriv (parent : ExtPrivKey) (i : UInt32) : Except DeriveError ExtPrivKey :=
  if parent.depth = 0xFF then .error .depthOverflow
  else
    let data :=
      if isHardened i then
        ByteArray.mk #[(0 : UInt8)] ++ ser32BE parent.key.val ++ ser32U i
      else
        serPub (pubOfPriv parent.key) ++ ser32U i
    let I := Crypto.Hmac.hmacSha512 parent.chainCode data
    let il := Secp.bytesToNatBE (I.extract 0 32)
    if Secp.n ≤ il then .error .invalidChild
    else
      let child := (il + parent.key.val) % Secp.n
      if h : child = 0 then .error .invalidChild
      else
        .ok { depth := parent.depth + 1
              parentFingerprint := fingerprint (pubOfPriv parent.key)
              childNumber := i
              chainCode := I.extract 32 64
              key := ⟨child, Nat.pos_of_ne_zero h, Nat.mod_lt _ Secp.n_pos⟩ }

/-- CKDpub (BIP32 "Public parent key → public child key"). Hardened
indices have no public derivation. -/
def ckdPub (parent : ExtPubKey) (i : UInt32) : Except DeriveError ExtPubKey :=
  if parent.depth = 0xFF then .error .depthOverflow
  else if isHardened i then .error .hardenedFromPublic
  else if _h : parent.key = none then .error .invalidParentPubKey
  else
    let I := Crypto.Hmac.hmacSha512 parent.chainCode
      (serPub parent.key ++ ser32U i)
    let il := Secp.bytesToNatBE (I.extract 0 32)
    if Secp.n ≤ il then .error .invalidChild
    else
      let child := Secp.addP (Secp.mulP il Secp.G) parent.key
      if _h : child = none then .error .invalidPublicChild
      else
        .ok { depth := parent.depth + 1
              parentFingerprint := fingerprint parent.key
              childNumber := i
              chainCode := I.extract 32 64
              key := child }

/-- Derive a private descendant along a list of 32-bit indices. -/
def derivePath : ExtPrivKey → List UInt32 → Except DeriveError ExtPrivKey
  | x, [] => .ok x
  | x, i :: rest =>
    match ckdPriv x i with
    | .error e => .error e
    | .ok y => derivePath y rest

/-- Derive a public descendant along a list of 32-bit indices. -/
def derivePubPath : ExtPubKey → List UInt32 → Except DeriveError ExtPubKey
  | x, [] => .ok x
  | x, i :: rest =>
    match ckdPub x i with
    | .error e => .error e
    | .ok y => derivePubPath y rest

/-- Derive along a parsed descriptor path (the hardened bit is already
inside each `ChildNumber`). -/
def derivePathCN (x : ExtPrivKey) (p : List ChildNumber) :
    Except DeriveError ExtPrivKey :=
  derivePath x (p.map ChildNumber.toUInt32)

theorem derivePath_nil (x : ExtPrivKey) : derivePath x [] = .ok x := rfl

theorem derivePubPath_nil (x : ExtPubKey) : derivePubPath x [] = .ok x := rfl

/-! ## Public-key agreement (targets)

These are the statements the proof phase must discharge. They are
`Prop`-valued definitions rather than `theorem`s because the proof needs
the secp256k1 group law; declaring them as theorems without that proof
would require the missing proof. The structural half (same HMAC input, same chain
code, metadata preserved by `neuter`) is already true by construction
and is recorded by the `neuter_*` lemmas above.
-/

/-- One non-hardened step: neutering after CKDpriv equals CKDpub of the
neutered parent. This is BIP32's `N(CKDpriv((k,c),i)) = CKDpub(N(k,c),i)`. -/
def ckdPubAgreementTarget : Prop :=
  ∀ (x : ExtPrivKey) (i : UInt32) (y : ExtPrivKey),
    isHardened i = false →
    ckdPriv x i = .ok y →
    ckdPub (neuter x) i = .ok (neuter y)

/-- The same law along a path all of whose indices are non-hardened. -/
def ckdPubPathAgreementTarget : Prop :=
  ∀ (x : ExtPrivKey) (p : List UInt32) (y : ExtPrivKey),
    (∀ i ∈ p, isHardened i = false) →
    derivePath x p = .ok y →
    derivePubPath (neuter x) p = .ok (neuter y)

/-- Path form scaled out: neutering commutes with a non-hardened
derivation sequence. -/
def neuterDeriveTarget : Prop :=
  ∀ (x : ExtPrivKey) (p : List UInt32) (y : ExtPrivKey),
    (∀ i ∈ p, isHardened i = false) →
    derivePath x p = .ok y →
    derivePubPath (neuter x) p = .ok (neuter y)

/-! ## Serialization (78 bytes, no Base58) -/

/-- Mainnet private extended-key version, `0x0488ADE4`
(`src/kernel/chainparams.cpp:180`). -/
def versionXprv : UInt32 := 0x0488ADE4

/-- Mainnet public extended-key version, `0x0488B21E`
(`src/kernel/chainparams.cpp:179`). -/
def versionXpub : UInt32 := 0x0488B21E

/-- The 78-byte private extended-key payload: version ‖ depth ‖
fingerprint ‖ child number ‖ chain code ‖ `0x00 ‖ ser₂₅₆(k)`. -/
def serializePriv (x : ExtPrivKey) : ByteArray :=
  ser32U versionXprv ++ ByteArray.empty.push x.depth ++
  x.parentFingerprint ++ ser32U x.childNumber ++ x.chainCode ++
  ByteArray.empty.push (0 : UInt8) ++ ser32BE x.key.val

/-- The 78-byte public extended-key payload: version ‖ depth ‖
fingerprint ‖ child number ‖ chain code ‖ `ser_P(K)`. -/
def serializePub (x : ExtPubKey) : ByteArray :=
  ser32U versionXpub ++ ByteArray.empty.push x.depth ++
  x.parentFingerprint ++ ser32U x.childNumber ++ x.chainCode ++
  serPub x.key

/-- With a four-byte fingerprint and a 32-byte chain code, the private
payload is exactly 78 bytes. -/
theorem serializePriv_size (x : ExtPrivKey)
    (hf : x.parentFingerprint.size = 4) (hc : x.chainCode.size = 32) :
    (serializePriv x).size = 78 := by
  unfold serializePriv
  simp [ser32U_size, ser32BE_size, ByteArray.size_append, ByteArray.size_push, hf, hc]

/-- With a four-byte fingerprint, a 32-byte chain code and a finite
public key, the public payload is exactly 78 bytes. -/
theorem serializePub_size (x : ExtPubKey)
    (hf : x.parentFingerprint.size = 4) (hc : x.chainCode.size = 32)
    (hk : x.key ≠ none) :
    (serializePub x).size = 78 := by
  unfold serializePub
  simp [ser32U_size, ByteArray.size_append, ByteArray.size_push, hf, hc,
    serPub_size x.key hk]

end Bitcoin.Wallet.Key
