import Bitcoin.Wallet.Key.Bip32
import BitcoinProofs.Wallet.Encoding.Laws
import Mathlib.Tactic
open Bitcoin.Wallet.Key
open Bitcoin.Crypto.Curve
open Bitcoin.Crypto.Curve.Secp
set_option maxHeartbeats 2000000

/-!
# BitcoinProofs.Wallet.Key.Serialize

Byte-level laws for the 78-byte BIP32 extended-key payloads defined in
`Bitcoin.Wallet.Key.Bip32` (`serializePriv`, `serializePub`) and for the
Base58Check wrapper around them.

Two different notions of "round-trip" appear here, and their scopes
differ:

* `parsePriv_serializePriv` is unconditional (given the metadata field
  sizes): the private payload contains the whole scalar, so the parser
  can reconstruct the key exactly.
* `parsePubWith_serializePub` is **conditional** on a caller-supplied
  decoder `decodeKey : ByteArray → Option PubKey`.  The model's
  `serPub` is lossy (it keeps only the x-coordinate and the parity of
  `y`) and the model has no on-curve validation or square-root
  computation, so recovering the actual point from 33 bytes is outside
  this development.  The theorem says: any decoder that inverts
  `serPub` on the key at hand yields a full payload round-trip.

The Base58Check theorems delegate entirely to the already-proved
`BitcoinProofs.Wallet.Encoding.base58CheckDecode_encode`; they only feed
it the 78-byte size lemma.  No cryptographic assumption is introduced:
`sha256d` is the executable model hash, and the statements are about
encoding agreement, not about checksum unforgeability.

Nothing here models HMAC-SHA-512, the secp256k1 group law, secret
erasure, or any security property.
-/

namespace BitcoinProofs.Wallet.Key

/-! ## Big-endian bytes -/

/-- Little list of the `n` big-endian base-256 digits of `x` (most
significant first).  Auxiliary definition used to connect `ser32BE` to
`Nat` arithmetic. -/
def beBytes : Nat → Nat → List UInt8
  | 0, _ => []
  | n + 1, x => beBytes n (x / 256) ++ [(x % 256).toUInt8]

theorem foldl_push_toList (l : List Nat) (f : Nat → UInt8) (b : ByteArray) :
    (l.foldl (fun a i => a.push (f i)) b).data.toList = b.data.toList ++ l.map f := by
  induction l generalizing b with
  | nil => simp
  | cons i rest ih =>
    simp only [List.foldl_cons, List.map_cons]
    rw [ih (b.push (f i)), ByteArray.data_push, Array.toList_push]
    simp

theorem ser32BE_data_toList (x : Nat) :
    (ser32BE x).data.toList =
      (List.range 32).map (fun i => (x >>> ((31 - i) * 8)).toUInt8) := by
  unfold ser32BE
  rw [foldl_push_toList]
  simp

theorem map_range_beBytes (n x : Nat) :
    (List.range n).map (fun i => (x >>> ((n - 1 - i) * 8)).toUInt8) =
      beBytes n x := by
  induction n generalizing x with
  | zero => rfl
  | succ n ih =>
    rw [List.range_succ, List.map_append, beBytes]
    have hmap : (List.range n).map
        (fun i => (x >>> ((n + 1 - 1 - i) * 8)).toUInt8) =
        (List.range n).map
          (fun i => ((x / 256) >>> ((n - 1 - i) * 8)).toUInt8) := by
      apply List.map_congr_left
      intro i hi
      have hi' : i < n := List.mem_range.mp hi
      have hexp : (n + 1 - 1 - i) * 8 = 8 + (n - 1 - i) * 8 := by omega
      rw [hexp, Nat.shiftRight_add]
      simp only [Nat.shiftRight_eq_div_pow, Nat.reducePow]
    rw [hmap, ih (x / 256)]
    simp only [List.map_cons, List.map_nil]
    rw [show n + 1 - 1 - n = 0 by omega, Nat.shiftRight_zero]
    have hbyte : x.toUInt8 = (x % 256).toUInt8 := by
      apply UInt8.toNat_inj.mp
      simp [Nat.toUInt8]
    rw [hbyte]

theorem mod256_step (x n : Nat) :
    (x / 256 % 256 ^ n) * 256 + x % 256 = x % 256 ^ (n + 1) := by
  let p := 256 ^ n
  have hp : 0 < p := by
    dsimp [p]
    exact pow_pos (by norm_num) n
  have hpow : 256 ^ (n + 1) = p * 256 := by rw [pow_succ]
  rw [hpow]
  change (x / 256 % p) * 256 + x % 256 = x % (p * 256)
  have hx : x = 256 * (x / 256) + x % 256 := (Nat.div_add_mod x 256).symm
  have hq : x / 256 = p * ((x / 256) / p) + (x / 256) % p :=
    (Nat.div_add_mod (x / 256) p).symm
  have hlt : (x / 256) % p * 256 + x % 256 < p * 256 := by
    have h1 : (x / 256) % p < p := Nat.mod_lt _ hp
    have h2 : x % 256 < 256 := Nat.mod_lt _ (by decide)
    nlinarith
  have key : x = p * 256 * ((x / 256) / p) +
      ((x / 256) % p * 256 + x % 256) := by
    calc x = 256 * (x / 256) + x % 256 := hx
      _ = 256 * (p * ((x / 256) / p) + (x / 256) % p) + x % 256 := by
            conv_lhs => rw [hq]
      _ = p * 256 * ((x / 256) / p) +
            ((x / 256) % p * 256 + x % 256) := by ring
  conv_rhs => rw [key]
  rw [Nat.mul_add_mod, Nat.mod_eq_of_lt hlt]

theorem fold_beBytes : ∀ (n x : Nat),
    List.foldl (fun acc b => acc * 256 + b.toNat) 0 (beBytes n x) = x % 256 ^ n
  | 0, x => by simp [beBytes, Nat.mod_one]
  | n + 1, x => by
    rw [beBytes, List.foldl_append, fold_beBytes n (x / 256)]
    simp only [List.foldl_cons, List.foldl_nil]
    simp only [Nat.toUInt8, UInt8.toNat_ofNat', Nat.mod_mod]
    exact mod256_step x n

/-- `ser32BE` reads back the low 256 bits of its argument. -/
theorem bytesToNatBE_ser32BE (x : Nat) :
    bytesToNatBE (ser32BE x) = x % 256 ^ 32 := by
  rw [bytesToNatBE, ← Array.foldl_toList, ser32BE_data_toList]
  change List.foldl (fun acc b => acc * 256 + b.toNat) 0
      ((List.range 32).map (fun i => (x >>> ((32 - 1 - i) * 8)).toUInt8)) =
    x % 256 ^ 32
  rw [map_range_beBytes]
  exact fold_beBytes 32 x

/-- `ser32U` is the exact big-endian reading of a 32-bit word. -/
theorem bytesToNatBE_ser32U (x : UInt32) :
    bytesToNatBE (ser32U x) = x.toNat := by
  have hx : x.toNat < 2 ^ 32 := x.toNat_lt
  rw [bytesToNatBE, ← Array.foldl_toList,
    show (ser32U x).data.toList = [(x >>> 24).toUInt8, (x >>> 16).toUInt8,
      (x >>> 8).toUInt8, x.toUInt8] by
      unfold ser32U
      simp [show List.range 4 = [0,1,2,3] by decide]]
  simp only [List.foldl_cons, List.foldl_nil, Nat.zero_mul, Nat.zero_add]
  rw [UInt32.toNat_toUInt8, UInt32.toNat_toUInt8, UInt32.toNat_toUInt8,
    UInt32.toNat_toUInt8]
  simp only [UInt32.toNat_shiftRight, Nat.shiftRight_eq_div_pow]
  norm_num
  omega

theorem toList_toByteArray_data (l : List UInt8) :
    l.toByteArray.data.toList = l := by
  rw [List.data_toByteArray]

/-- Rebuild a byte array from its `toList`. -/
theorem toByteArray_eq_of_data_toList {l : List UInt8} {b : ByteArray}
    (h : b.data.toList = l) : l.toByteArray = b := by
  apply ByteArray.ext
  apply Array.toList_inj.mp
  rw [toList_toByteArray_data, h]

/-- A byte array is recovered from its list of bytes. -/
theorem data_toList_toByteArray (b : ByteArray) : b.data.toList.toByteArray = b :=
  toByteArray_eq_of_data_toList rfl

theorem bytesToNatBE_eq_list_foldl (b : ByteArray) :
    bytesToNatBE b = b.data.toList.foldl (fun acc b => acc * 256 + b.toNat) 0 := by
  rw [bytesToNatBE, ← Array.foldl_toList]

theorem bytesToNatBE_toByteArray_toList (b : ByteArray) :
    bytesToNatBE b.data.toList.toByteArray = bytesToNatBE b := by
  rw [bytesToNatBE_eq_list_foldl, bytesToNatBE_eq_list_foldl,
    toList_toByteArray_data]

/-! ## Payload layout -/

/-- Field-by-field spelling of the 78-byte payload.  The parentheses are
explicit right-nesting: `++` is left-associative, so this shape makes
`List.take_left`/`List.drop_left` applicable at each field boundary. -/
def payloadFields (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) : List UInt8 :=
  (ser32U version).data.toList ++
    ([depth] ++ (fp.data.toList ++
      ((ser32U cn).data.toList ++ (cc.data.toList ++ tail))))

theorem nlen (b : ByteArray) : b.data.toList.length = b.size := by
  rw [Array.length_toList, ByteArray.size_data]

theorem drop_append_of_length {α : Type} (a b : List α) (n : Nat) (h : a.length = n) :
    (a ++ b).drop n = b := by
  rw [← h, List.drop_left]

theorem take_append_of_length {α : Type} (a b : List α) (n : Nat) (h : a.length = n) :
    (a ++ b).take n = a := by
  rw [← h, List.take_left]

theorem payloadFields_drop4 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) :
    (payloadFields version depth fp cn cc tail).drop 4 =
      [depth] ++ (fp.data.toList ++
        ((ser32U cn).data.toList ++ (cc.data.toList ++ tail))) := by
  have hv : (ser32U version).data.toList.length = 4 := by simp [ser32U_size]
  unfold payloadFields
  exact drop_append_of_length _ _ 4 hv

theorem payloadFields_drop5 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) (_hf : fp.size = 4) :
    (payloadFields version depth fp cn cc tail).drop 5 =
      fp.data.toList ++ ((ser32U cn).data.toList ++ (cc.data.toList ++ tail)) := by
  rw [← List.drop_drop (i := 1) (j := 4), payloadFields_drop4]
  exact drop_append_of_length [depth] _ 1 (by simp)

theorem payloadFields_drop9 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) (hf : fp.size = 4) :
    (payloadFields version depth fp cn cc tail).drop 9 =
      (ser32U cn).data.toList ++ (cc.data.toList ++ tail) := by
  have hfl : fp.data.toList.length = 4 := by simp [hf]
  rw [← List.drop_drop (i := 4) (j := 5), payloadFields_drop5 _ _ _ _ _ _ hf]
  exact drop_append_of_length _ _ 4 hfl

theorem payloadFields_drop13 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) (hf : fp.size = 4) :
    (payloadFields version depth fp cn cc tail).drop 13 = cc.data.toList ++ tail := by
  have hcn : (ser32U cn).data.toList.length = 4 := by simp [ser32U_size]
  rw [← List.drop_drop (i := 4) (j := 9), payloadFields_drop9 _ _ _ _ _ _ hf]
  exact drop_append_of_length _ _ 4 hcn

theorem payloadFields_drop45 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8)
    (hf : fp.size = 4) (hc : cc.size = 32) :
    (payloadFields version depth fp cn cc tail).drop 45 = tail := by
  have hcc : cc.data.toList.length = 32 := by simp [hc]
  rw [← List.drop_drop (i := 32) (j := 13), payloadFields_drop13 _ _ _ _ _ _ hf]
  exact drop_append_of_length _ _ 32 hcc

theorem payloadFields_take4 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) :
    (payloadFields version depth fp cn cc tail).take 4 =
      (ser32U version).data.toList := by
  have hv : (ser32U version).data.toList.length = 4 := by simp [ser32U_size]
  exact take_append_of_length _ _ 4 hv

theorem payloadFields_take5 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) (hf : fp.size = 4) :
    ((payloadFields version depth fp cn cc tail).drop 5).take 4 = fp.data.toList := by
  have hfl : fp.data.toList.length = 4 := by simp [hf]
  rw [payloadFields_drop5 _ _ _ _ _ _ hf]
  exact take_append_of_length _ _ 4 hfl

theorem payloadFields_take9 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8) (hf : fp.size = 4) :
    ((payloadFields version depth fp cn cc tail).drop 9).take 4 =
      (ser32U cn).data.toList := by
  have hcn : (ser32U cn).data.toList.length = 4 := by simp [ser32U_size]
  rw [payloadFields_drop9 _ _ _ _ _ _ hf]
  exact take_append_of_length _ _ 4 hcn

theorem payloadFields_take13 (version : UInt32) (depth : UInt8) (fp : ByteArray)
    (cn : UInt32) (cc : ByteArray) (tail : List UInt8)
    (hf : fp.size = 4) (hc : cc.size = 32) :
    ((payloadFields version depth fp cn cc tail).drop 13).take 32 = cc.data.toList := by
  have hcc : cc.data.toList.length = 32 := by simp [hc]
  rw [payloadFields_drop13 _ _ _ _ _ _ hf]
  exact take_append_of_length _ _ 32 hcc

/-! ## The scalar always fits in 32 bytes -/

theorem n_lt_two_pow_256 : Secp.n < 2 ^ 256 := by decide

/-- `ser32BE` is exact on every in-range private key scalar. -/
theorem bytesToNatBE_ser32BE_priv (k : PrivKey) :
    bytesToNatBE (ser32BE k.val) = k.val := by
  rw [bytesToNatBE_ser32BE]
  exact Nat.mod_eq_of_lt (Nat.lt_trans k.lt n_lt_two_pow_256)

/-! ## Private payload -/

/-- The private payload as a list of bytes. -/
def privPayloadList (x : ExtPrivKey) : List UInt8 :=
  payloadFields versionXprv x.depth x.parentFingerprint x.childNumber x.chainCode
    ([0] ++ (ser32BE x.key.val).data.toList)

theorem serializePriv_payload (x : ExtPrivKey) :
    (serializePriv x).data.toList = privPayloadList x := by
  simp [serializePriv, privPayloadList, payloadFields, ByteArray.data_append,
    ByteArray.data_push, Array.toList_append, Array.toList_push, List.append_assoc]

theorem privPayloadList_length (x : ExtPrivKey)
    (hf : x.parentFingerprint.size = 4) (hc : x.chainCode.size = 32) :
    (privPayloadList x).length = 78 := by
  simp [privPayloadList, payloadFields, ser32U_size, ser32BE_size, hf, hc]

/-- Different proof fields do not distinguish two private keys with the
same scalar. -/
theorem privKey_ext {v : Nat} (p1 p2 : 0 < v) (l1 l2 : v < Secp.n) :
    (⟨v, p1, l1⟩ : PrivKey) = ⟨v, p2, l2⟩ := by
  rw [PrivKey.mk.injEq]

/-- Errors raised by the payload parsers. -/
inductive KeyDecodeError where
  | wrongLength
  | badVersion
  | badKeyMarker
  | invalidKey
  deriving Repr, DecidableEq

/-- Parse the 78-byte private payload.  Rejects a wrong length, a wrong
version, a nonzero key marker, and scalars outside `0 < k < n`. -/
def parsePriv (b : ByteArray) : Except KeyDecodeError ExtPrivKey :=
  if _h : b.data.toList.length = 78 then
    let l := b.data.toList
    let version := bytesToNatBE (l.take 4).toByteArray
    let depth := (l.drop 4).headD 0
    let fp := (l.drop 5).take 4 |>.toByteArray
    let cn := (bytesToNatBE ((l.drop 9).take 4).toByteArray).toUInt32
    let cc := (l.drop 13).take 32 |>.toByteArray
    let marker := (l.drop 45).headD 0
    let kval := bytesToNatBE (l.drop 46).toByteArray
    if version ≠ versionXprv.toNat then .error .badVersion
    else if marker ≠ 0 then .error .badKeyMarker
    else if hk : 0 < kval ∧ kval < Secp.n then
      .ok { depth := depth
            parentFingerprint := fp
            childNumber := cn
            chainCode := cc
            key := ⟨kval, hk.1, hk.2⟩ }
    else .error .invalidKey
  else .error .wrongLength

/-- Every private payload round-trips through `parsePriv`, provided the
metadata fields have their BIP32 widths.  This is unconditional: the
private serialization carries the complete scalar. -/
theorem parsePriv_serializePriv (x : ExtPrivKey)
    (hf : x.parentFingerprint.size = 4) (hc : x.chainCode.size = 32) :
    parsePriv (serializePriv x) = .ok x := by
  have hlen : (serializePriv x).data.toList.length = 78 := by
    rw [serializePriv_payload]
    exact privPayloadList_length x hf hc
  have hver : bytesToNatBE (((privPayloadList x).take 4).toByteArray) =
      versionXprv.toNat := by
    rw [privPayloadList, payloadFields_take4, data_toList_toByteArray,
      bytesToNatBE_ser32U]
  have hdepth : ((privPayloadList x).drop 4).headD 0 = x.depth := by
    rw [privPayloadList, payloadFields_drop4]
    simp
  have hfp : (((privPayloadList x).drop 5).take 4).toByteArray =
      x.parentFingerprint := by
    rw [privPayloadList, payloadFields_take5 _ _ _ _ _ _ hf]
    exact toByteArray_eq_of_data_toList rfl
  have hcn : (bytesToNatBE ((((privPayloadList x).drop 9).take 4).toByteArray)).toUInt32 =
      x.childNumber := by
    rw [privPayloadList, payloadFields_take9 _ _ _ _ _ _ hf,
      data_toList_toByteArray, bytesToNatBE_ser32U]
    apply UInt32.toNat_inj.mp
    simp [Nat.toUInt32]
  have hcc : (((privPayloadList x).drop 13).take 32).toByteArray = x.chainCode := by
    rw [privPayloadList, payloadFields_take13 _ _ _ _ _ _ hf hc]
    exact toByteArray_eq_of_data_toList rfl
  have hmarker : ((privPayloadList x).drop 45).headD 0 = 0 := by
    rw [privPayloadList, payloadFields_drop45 _ _ _ _ _ _ hf hc]
    simp
  have hdrop46 : (privPayloadList x).drop 46 = (ser32BE x.key.val).data.toList := by
    rw [privPayloadList, ← List.drop_drop (i := 1) (j := 45),
      payloadFields_drop45 _ _ _ _ _ _ hf hc]
    simp
  have hval : bytesToNatBE (((privPayloadList x).drop 46).toByteArray) = x.key.val := by
    rw [hdrop46, data_toList_toByteArray, bytesToNatBE_ser32BE_priv]
  have hpos : 0 < bytesToNatBE (((privPayloadList x).drop 46).toByteArray) := by
    rw [hval]
    exact x.key.pos
  have hlt : bytesToNatBE (((privPayloadList x).drop 46).toByteArray) < Secp.n := by
    rw [hval]
    exact x.key.lt
  unfold parsePriv
  rw [dite_eq_left hlen]
  simp only [serializePriv_payload]
  rw [ite_eq_right (by simp [hver])]
  rw [ite_eq_right (by rw [hmarker]; simp)]
  rw [dite_eq_left ⟨hpos, hlt⟩]
  rw [hdepth, hfp, hcn, hcc]
  rw [Except.ok.injEq, ExtKey.mk.injEq]
  refine ⟨rfl, rfl, rfl, rfl, ?_⟩
  rw [PrivKey.mk.injEq, hval]

/-! ## Public payload -/

/-- The public payload as a list of bytes. -/
def pubPayloadList (x : ExtPubKey) : List UInt8 :=
  payloadFields versionXpub x.depth x.parentFingerprint x.childNumber x.chainCode
    (serPub x.key).data.toList

theorem serializePub_payload (x : ExtPubKey) :
    (serializePub x).data.toList = pubPayloadList x := by
  simp [serializePub, pubPayloadList, payloadFields, ByteArray.data_append,
    ByteArray.data_push, Array.toList_append, Array.toList_push, List.append_assoc]

theorem pubPayloadList_length (x : ExtPubKey)
    (hf : x.parentFingerprint.size = 4) (hc : x.chainCode.size = 32)
    (hk : x.key ≠ none) :
    (pubPayloadList x).length = 78 := by
  simp [pubPayloadList, payloadFields, ser32U_size, serPub_size x.key hk, hf, hc]

/-- Parse a 78-byte public payload, using an externally supplied
`decodeKey` to turn 33 SEC1 bytes into a raw point.  This development
does not implement on-curve validation or `y` recovery, so the decoder
is a parameter rather than a definition. -/
def parsePubWith (decodeKey : ByteArray → Option PubKey) (b : ByteArray) :
    Except KeyDecodeError ExtPubKey :=
  if _h : b.data.toList.length = 78 then
    let l := b.data.toList
    let version := bytesToNatBE (l.take 4).toByteArray
    let depth := (l.drop 4).headD 0
    let fp := (l.drop 5).take 4 |>.toByteArray
    let cn := (bytesToNatBE ((l.drop 9).take 4).toByteArray).toUInt32
    let cc := (l.drop 13).take 32 |>.toByteArray
    if version ≠ versionXpub.toNat then .error .badVersion
    else
      match decodeKey ((l.drop 45).toByteArray) with
      | some k =>
        .ok { depth := depth
              parentFingerprint := fp
              childNumber := cn
              chainCode := cc
              key := k }
      | none => .error .invalidKey
  else .error .wrongLength

/-- Public payload round-trip, **conditioned on** a decoder that inverts
`serPub` on this key.  `serPub` forgets the y-coordinate, and the model
performs no on-curve check, so no total decoder exists inside the
development; `decodeKey (serPub x.key) = some x.key` is the exact
additional hypothesis needed. -/
theorem parsePubWith_serializePub (decodeKey : ByteArray → Option PubKey)
    (x : ExtPubKey) (hf : x.parentFingerprint.size = 4)
    (hc : x.chainCode.size = 32) (hk : x.key ≠ none)
    (hdec : decodeKey (serPub x.key) = some x.key) :
    parsePubWith decodeKey (serializePub x) = .ok x := by
  have hlen : (serializePub x).data.toList.length = 78 := by
    rw [serializePub_payload]
    exact pubPayloadList_length x hf hc hk
  have hver : bytesToNatBE (((pubPayloadList x).take 4).toByteArray) =
      versionXpub.toNat := by
    rw [pubPayloadList, payloadFields_take4, data_toList_toByteArray,
      bytesToNatBE_ser32U]
  have hdepth : ((pubPayloadList x).drop 4).headD 0 = x.depth := by
    rw [pubPayloadList, payloadFields_drop4]
    simp
  have hfp : (((pubPayloadList x).drop 5).take 4).toByteArray =
      x.parentFingerprint := by
    rw [pubPayloadList, payloadFields_take5 _ _ _ _ _ _ hf]
    exact toByteArray_eq_of_data_toList rfl
  have hcn : (bytesToNatBE ((((pubPayloadList x).drop 9).take 4).toByteArray)).toUInt32 =
      x.childNumber := by
    rw [pubPayloadList, payloadFields_take9 _ _ _ _ _ _ hf,
      data_toList_toByteArray, bytesToNatBE_ser32U]
    apply UInt32.toNat_inj.mp
    simp [Nat.toUInt32]
  have hcc : (((pubPayloadList x).drop 13).take 32).toByteArray = x.chainCode := by
    rw [pubPayloadList, payloadFields_take13 _ _ _ _ _ _ hf hc]
    exact toByteArray_eq_of_data_toList rfl
  have hdec' : decodeKey (((pubPayloadList x).drop 45).toByteArray) = some x.key := by
    rw [pubPayloadList, payloadFields_drop45 _ _ _ _ _ _ hf hc,
      data_toList_toByteArray]
    exact hdec
  unfold parsePubWith
  rw [dite_eq_left hlen]
  simp only [serializePub_payload]
  rw [ite_eq_right (by simp [hver])]
  rw [hdec']
  rw [hdepth, hfp, hcn, hcc]

/-! ## Base58Check agreement -/

/-- Base58Check decoding inverts encoding of the private payload.  This is
an encoding-agreement statement; the checksum collision/forgery question
is not modelled. -/
theorem base58Check_serializePriv (x : ExtPrivKey)
    (hf : x.parentFingerprint.size = 4) (hc : x.chainCode.size = 32)
    (maxLen : Nat) (hmax : 78 ≤ maxLen) :
    Bitcoin.Wallet.Encoding.base58CheckDecode
        (Bitcoin.Wallet.Encoding.base58CheckEncode (serializePriv x)) maxLen =
      .ok (serializePriv x) :=
  BitcoinProofs.Wallet.Encoding.base58CheckDecode_encode _
    maxLen (by rw [serializePriv_size x hf hc]; exact hmax)

/-- Base58Check decoding inverts encoding of the public payload, under
the same field-width and finite-key hypotheses used above. -/
theorem base58Check_serializePub (x : ExtPubKey)
    (hf : x.parentFingerprint.size = 4) (hc : x.chainCode.size = 32)
    (hk : x.key ≠ none) (maxLen : Nat) (hmax : 78 ≤ maxLen) :
    Bitcoin.Wallet.Encoding.base58CheckDecode
        (Bitcoin.Wallet.Encoding.base58CheckEncode (serializePub x)) maxLen =
      .ok (serializePub x) :=
  BitcoinProofs.Wallet.Encoding.base58CheckDecode_encode _
    maxLen (by rw [serializePub_size x hf hc hk]; exact hmax)

end BitcoinProofs.Wallet.Key
