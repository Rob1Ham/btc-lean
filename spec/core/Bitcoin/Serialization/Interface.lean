import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Chain.Basic

/-!
# Bitcoin.Serialization — canonical wire serialization

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/serialize.h (CompactSize: WriteCompactSize/
                        ReadCompactSize), src/primitives/transaction.h
                        (UnserializeTransaction:212-239), src/primitives/
                        block.h, src/consensus/consensus.h
Status: frozen 2026-10-16 (signatures); bodies +
                        proofs filled 2026-10-16. The three frozen
                        theorem statements carry one added hypothesis each
                        (`wireDomain`) — the predicted interface-change
                        (report §5.4): the wire format cannot represent
                        a `Tx` whose `witness.length ≠ vin.length`, and the
                        frozen no-witness encoder `serTx` is lossy for
                        negative `Amount`s, so `decode ∘ encode = id` is
                        false for such txs under ANY Core-faithful codec.

## Scope

CompactSize canonical encoding (TXV-012), base/witness tx framing (BIP144
marker/flag, TXV-013/014), superfluous-witness ban (TXV-015), unknown-flag
ban (TXV-016), basic tx layout (TXV-011), header + block framing
(BLK-001/002). `decode ∘ encode = id` theorems are the conformance criterion.

## Design

* The wire is modeled as `Bytes := List UInt8`; `ByteArray` is list-backed
  in Lean 4.34.1 (`ByteArray.data : Array UInt8`, `Array.data : List UInt8`),
  so the bridge `bL`/`toByteArray` is definitional and every decode/encode
  law is proved by pure list induction (no well-founded recursion anywhere
  in this module — kernel `decide` stays fast).
* `decTxCore` is a transliteration of `UnserializeTransaction`
  (primitives/transaction.h:201-239 @ c50817f), INCLUDING the quirky
  empty-vin branch: when the first CompactSize reads 0, the next byte is the
  flag; flag 0 means vin stays empty and **vout is not read at all** (Core's
  own behavior); flag ≠ 0 re-reads vin and vout.
* Every decoder returns the unconsumed remainder; the public decoders
  require the remainder to be empty (Core's hex-tx decoder rejects trailing
  data the same way, core_read.cpp `DecodeHexTx`).
* `encodeTx` = extended format iff the tx has a witness (Core's
  `SerializeTransaction`), else the frozen base encoder `serTx` — which is
  why `encodeTxNoWitness`/txid bytes and `encodeTx` agree on witness-free txs.
* Non-canonical CompactSize (TXV-012) and `> MAX_SIZE` (serialize.h:35,
  `MAX_SIZE = 0x02000000`, range_check=true on every vector read) are
  decode failures, exactly as in `ReadCompactSize`.
-/

namespace Bitcoin.Serialization

open Bitcoin.Data

/-! ## `SerError` (frozen) -/

/-- Decoding failures, one constructor per BIP144/serialize.h failure class.
This inductive may be EXTENDED only via interface-change PR (rows TXV-011..016). -/
inductive SerError where
  | truncated              -- input ended mid-field
  | compactSizeNonMinimal  -- TXV-012: non-canonical CompactSize
  | compactSizeTooLong     -- 64-bit overflow / serialize.h "size too large"
  | badMarkerOrFlag        -- TXV-013: SegWit marker/flag framing violated
  | superfluousWitness     -- TXV-015: flag set but all witness stacks empty
  | unknownFlag            -- TXV-016: flag ∉ {1}
deriving Repr, DecidableEq, BEq

/-! ## Byte-list layer

`Bytes` is the proof vehicle; `ByteArray` is list-backed so `bL` is a
projection (`b.data.toList`, with `Array.toList = Array.data`). -/

/-- Wire bytes as a list (proof-friendly view of `ByteArray`). -/
abbrev Bytes := List UInt8

/-- List view of a `ByteArray`. -/
def bL (b : ByteArray) : Bytes := b.data.toList

@[simp] theorem bL_empty : bL ByteArray.empty = [] := rfl

@[simp] theorem bL_push (b : ByteArray) (x : UInt8) : bL (b.push x) = bL b ++ [x] := by
  simp [bL, ByteArray.data_push]

@[simp] theorem bL_append (a b : ByteArray) : bL (a ++ b) = bL a ++ bL b := rfl

/-- List → ByteArray (the inverse bridge). -/
def bytesOfList (l : Bytes) : ByteArray := l.toByteArray

@[simp] theorem bL_bytesOfList (l : Bytes) : bL (bytesOfList l) = l := by
  simp [bL, bytesOfList, List.data_toByteArray]

/-- The round direction used by the decode-side equalities. -/
theorem bytesOfList_bL (b : ByteArray) : bytesOfList (bL b) = b := by
  show b.data.toList.toByteArray = b
  ext1
  simp [List.data_toByteArray]

/-- `bL` reflects equality (injectivity). -/
theorem bL_inj {a b : ByteArray} (h : bL a = bL b) : a = b := by
  ext1
  exact Array.toList_inj.mp h

/-- `bL` of a foldl-built concatenation is a flatMap of the parts. -/
theorem bL_foldl_append {α : Type} (g : α → ByteArray) :
    ∀ (xs : List α) (acc : ByteArray),
      bL (xs.foldl (fun a i => a ++ g i) acc) = bL acc ++ xs.flatMap (fun i => bL (g i)) := by
  intro xs
  induction xs with
  | nil => intro acc; simp
  | cons x xs ih =>
    intro acc
    simp only [List.foldl_cons]
    rw [ih]
    simp

/-- Drop the first-list part of an append. -/
theorem drop_append_left (bs rest : Bytes) : (bs ++ rest).drop bs.length = rest := by
  induction bs with
  | nil => simp
  | cons b bs ih => simp [ih]

/-- `List.getD` of an in-range index is an element. -/
theorem getD_mem {α : Type} (d : α) :
    ∀ (l : List α) (i : Nat), i < l.length → l.getD i d ∈ l := by
  intro l
  induction l with
  | nil => intro i hi; simp at hi
  | cons a l ih =>
    intro i hi
    cases i with
    | zero => simp
    | succ i =>
      simp only [List.getD_cons_succ]
      have hlt : i < l.length := by
        have h2 := hi
        simp at h2
        omega
      exact List.mem_cons_of_mem _ (ih i hlt)

/-- `range (n+1)` unfolds to `0 :: map succ (range n)`. -/
theorem range_cons_succ (n : Nat) :
    List.range (n + 1) = 0 :: (List.range n).map Nat.succ := by
  induction n with
  | zero => simp [List.range_succ]
  | succ k ih =>
    have e3 : 0 :: List.map Nat.succ (List.range (k+1))
        = 0 :: (List.map Nat.succ (List.range k) ++ [k+1]) := by
      rw [List.range_succ, List.map_append]
      simp
    rw [List.range_succ, e3, ih]
    rfl

/-- A list equals the `getD`-image of its own index range. -/
theorem list_eq_map_getD {α : Type} (d : α) (l : List α) :
    (List.range l.length).map (fun i => l.getD i d) = l := by
  induction l with
  | nil => simp
  | cons a l ih =>
    have hstep : List.map (fun i => (a :: l).getD i d) ((List.range l.length).map Nat.succ)
        = (List.range l.length).map (fun i => l.getD i d) := by
      rw [List.map_map]
      rfl
    have hlen : (a :: l).length = l.length + 1 := rfl
    rw [hlen, range_cons_succ, List.map_cons, hstep]
    exact congrArg (a :: ·) ih

/-- If every in-range `getD` returns the default, the list is all defaults. -/
theorem list_eq_replicate_of_getD {α : Type} (d : α) :
    ∀ (l : List α) (n : Nat), l.length = n → (∀ i, i < n → l.getD i d = d) →
      l = List.replicate n d := by
  intro l
  induction l with
  | nil => intro n hl _; simp at hl; subst hl; rfl
  | cons a l ih =>
    intro n hl h
    simp only [List.length_cons] at hl
    have hn : n = l.length + 1 := by omega
    subst hn
    have h0 : a = d := by
      have h5 := h 0 (by omega)
      simpa using h5
    have hrest : ∀ i, i < l.length → l.getD i d = d := by
      intro i hi
      have h6 := h (i + 1) (by omega)
      simpa using h6
    subst h0
    rw [List.replicate_succ]
    exact congrArg (a :: ·) (ih l.length rfl hrest)

/-! ## Fixed-width little-endian helpers -/

/-- LE bytes of a `UInt8`. -/
def encU8L (x : UInt8) : Bytes := [x]

/-- LE bytes of a `UInt16`. -/
def encU16L (x : UInt16) : Bytes := [x.toUInt8, (x >>> 8).toUInt8]

/-- LE bytes of a `UInt32`. -/
def encU32L (x : UInt32) : Bytes :=
  [x.toUInt8, (x >>> 8).toUInt8, (x >>> 16).toUInt8, (x >>> 24).toUInt8]

/-- LE bytes of a `UInt64`. -/
def encU64L (x : UInt64) : Bytes :=
  [x.toUInt8, (x >>> 8).toUInt8, (x >>> 16).toUInt8, (x >>> 24).toUInt8,
   (x >>> 32).toUInt8, (x >>> 40).toUInt8, (x >>> 48).toUInt8, (x >>> 56).toUInt8]

/-- Value of LE bytes (little end first). -/
def leNat (bs : Bytes) : Nat :=
  bs.foldr (fun b acc => b.toNat + 256 * acc) 0

@[simp] theorem leNat_nil : leNat [] = 0 := rfl

theorem leNat_cons (b : UInt8) (bs : Bytes) :
    leNat (b :: bs) = b.toNat + 256 * leNat bs := rfl

/-- Byte extraction: cast/shift byte k = the k-th base-256 digit. -/
theorem u16_b0 (x : UInt16) : x.toUInt8.toNat = x.toNat % 256 := by simp

theorem u16_b1 (x : UInt16) : ((x >>> 8 : UInt16).toUInt8).toNat = x.toNat / 256 % 256 := by
  simp only [UInt16.toNat_toUInt8, UInt16.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt16.toNat 8 % 16) = 8 from rfl, show ((2 : Nat) ^ 8) = 256 from rfl]

theorem u32_b0 (x : UInt32) : x.toUInt8.toNat = x.toNat % 256 := by simp

theorem u32_b1 (x : UInt32) : ((x >>> 8 : UInt32).toUInt8).toNat = x.toNat / 256 % 256 := by
  simp only [UInt32.toNat_toUInt8, UInt32.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt32.toNat 8 % 32) = 8 from rfl, show ((2 : Nat) ^ 8) = 256 from rfl]

theorem u32_b2 (x : UInt32) : ((x >>> 16 : UInt32).toUInt8).toNat = x.toNat / 65536 % 256 := by
  simp only [UInt32.toNat_toUInt8, UInt32.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt32.toNat 16 % 32) = 16 from rfl, show ((2 : Nat) ^ 16) = 65536 from rfl]

theorem u32_b3 (x : UInt32) :
    ((x >>> 24 : UInt32).toUInt8).toNat = x.toNat / 16777216 % 256 := by
  simp only [UInt32.toNat_toUInt8, UInt32.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt32.toNat 24 % 32) = 24 from rfl, show ((2 : Nat) ^ 24) = 16777216 from rfl]

theorem u64_b0 (x : UInt64) : x.toUInt8.toNat = x.toNat % 256 := by simp

theorem u64_b1 (x : UInt64) : ((x >>> 8 : UInt64).toUInt8).toNat = x.toNat / 256 % 256 := by
  simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt64.toNat 8 % 64) = 8 from rfl, show ((2 : Nat) ^ 8) = 256 from rfl]

theorem u64_b2 (x : UInt64) : ((x >>> 16 : UInt64).toUInt8).toNat = x.toNat / 65536 % 256 := by
  simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt64.toNat 16 % 64) = 16 from rfl, show ((2 : Nat) ^ 16) = 65536 from rfl]

theorem u64_b3 (x : UInt64) :
    ((x >>> 24 : UInt64).toUInt8).toNat = x.toNat / 16777216 % 256 := by
  simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt64.toNat 24 % 64) = 24 from rfl, show ((2 : Nat) ^ 24) = 16777216 from rfl]

theorem u64_b4 (x : UInt64) :
    ((x >>> 32 : UInt64).toUInt8).toNat = x.toNat / 4294967296 % 256 := by
  simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt64.toNat 32 % 64) = 32 from rfl, show ((2 : Nat) ^ 32) = 4294967296 from rfl]

theorem u64_b5 (x : UInt64) :
    ((x >>> 40 : UInt64).toUInt8).toNat = x.toNat / 1099511627776 % 256 := by
  simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt64.toNat 40 % 64) = 40 from rfl, show ((2 : Nat) ^ 40) = 1099511627776 from rfl]

theorem u64_b6 (x : UInt64) :
    ((x >>> 48 : UInt64).toUInt8).toNat = x.toNat / 281474976710656 % 256 := by
  simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt64.toNat 48 % 64) = 48 from rfl, show ((2 : Nat) ^ 48) = 281474976710656 from rfl]

theorem u64_b7 (x : UInt64) :
    ((x >>> 56 : UInt64).toUInt8).toNat = x.toNat / 72057594037927936 % 256 := by
  simp only [UInt64.toNat_toUInt8, UInt64.toNat_shiftRight, Nat.shiftRight_eq_div_pow,
    show (UInt64.toNat 56 % 64) = 56 from rfl, show ((2 : Nat) ^ 56) = 72057594037927936 from rfl]

theorem u16_ofNat_toNat (n : Nat) : (UInt16.ofNat n).toNat = n % 65536 := rfl
theorem u32_ofNat_toNat (n : Nat) : (UInt32.ofNat n).toNat = n % 4294967296 := rfl
theorem u64_ofNat_toNat (n : Nat) : (UInt64.ofNat n).toNat = n % 18446744073709551616 := rfl
theorem u8_ofNat_toNat (n : Nat) : (UInt8.ofNat n).toNat = n % 256 := rfl

/-- Read one byte. -/
def decU8L (l : Bytes) : Except SerError (UInt8 × Bytes) :=
  match l with
  | [] => .error .truncated
  | b :: rest => .ok (b, rest)

/-- Read 2 LE bytes as a `UInt16`. -/
def decU16L (l : Bytes) : Except SerError (UInt16 × Bytes) :=
  match l with
  | b0 :: b1 :: rest => .ok (UInt16.ofNat (b0.toNat + 256 * b1.toNat), rest)
  | _ => .error .truncated

/-- Read 4 LE bytes as a `UInt32`. -/
def decU32L (l : Bytes) : Except SerError (UInt32 × Bytes) :=
  match l with
  | b0 :: b1 :: b2 :: b3 :: rest =>
      .ok (UInt32.ofNat (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))), rest)
  | _ => .error .truncated

/-- Read 8 LE bytes as a raw `Nat` (< 2^64). -/
def decU64L (l : Bytes) : Except SerError (Nat × Bytes) :=
  match l with
  | b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: rest =>
      .ok (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
        256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat)))))), rest)
  | _ => .error .truncated

/-- `leNat` of a fixed LE encoding is the value (4-byte form). -/
theorem leNat_encU32L (x : UInt32) : leNat (encU32L x) = x.toNat := by
  simp only [encU32L, leNat_cons, leNat_nil]
  rw [u32_b0, u32_b1, u32_b2, u32_b3]
  have h : x.toNat < 4294967296 := x.toNat_lt_size
  omega

/-- `leNat` of a fixed LE encoding is the value (8-byte form). -/
theorem leNat_encU64L (x : UInt64) : leNat (encU64L x) = x.toNat := by
  simp only [encU64L, leNat_cons, leNat_nil]
  rw [u64_b0, u64_b1, u64_b2, u64_b3, u64_b4, u64_b5, u64_b6, u64_b7]
  have h : x.toNat < 18446744073709551616 := x.toNat_lt_size
  omega

theorem decU32L_encU32L (x : UInt32) (rest : Bytes) :
    decU32L (encU32L x ++ rest) = .ok (x, rest) := by
  simp only [encU32L, List.cons_append, decU32L]
  have hV : x.toUInt8.toNat + 256 * ((x >>> 8).toUInt8.toNat
      + 256 * ((x >>> 16).toUInt8.toNat + 256 * ((x >>> 24).toUInt8.toNat))) = x.toNat := by
    rw [u32_b0, u32_b1, u32_b2, u32_b3]
    have h : x.toNat < 4294967296 := x.toNat_lt_size
    omega
  rw [hV]
  have h2 : (UInt32.ofNat x.toNat) = x :=
    UInt32.toNat_inj.mp (by
      show UInt32.toNat (UInt32.ofNat x.toNat) = x.toNat
      rw [u32_ofNat_toNat, Nat.mod_eq_of_lt x.toNat_lt_size])
  simp [h2]

theorem decU8L_encU8L (x : UInt8) (rest : Bytes) :
    decU8L (encU8L x ++ rest) = .ok (x, rest) := by
  simp [encU8L, decU8L]

/-- The LE32 bytes of `UInt32.ofNat V` are the base-256 digits of `V`. -/
theorem encU32L_of_leNat (b0 b1 b2 b3 : UInt8) :
    encU32L (UInt32.ofNat (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))))
      = [b0, b1, b2, b3] := by
  have h0 : b0.toNat < 256 := by simpa using b0.toNat_lt_size
  have h1 : b1.toNat < 256 := by simpa using b1.toNat_lt_size
  have h2 : b2.toNat < 256 := by simpa using b2.toNat_lt_size
  have h3 : b3.toNat < 256 := by simpa using b3.toNat_lt_size
  generalize hV : (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))) = V
  have hVf : V = b0.toNat + 256 * b1.toNat + 65536 * b2.toNat + 16777216 * b3.toNat := by
    omega
  have e0 : (UInt32.ofNat V).toUInt8 = b0 := by
    apply UInt8.toNat_inj.mp
    simp only [u32_b0, u32_ofNat_toNat, hVf]
    omega
  have e1 : ((UInt32.ofNat V) >>> 8 : UInt32).toUInt8 = b1 := by
    apply UInt8.toNat_inj.mp
    simp only [u32_b1, u32_ofNat_toNat, hVf]
    omega
  have e2 : ((UInt32.ofNat V) >>> 16 : UInt32).toUInt8 = b2 := by
    apply UInt8.toNat_inj.mp
    simp only [u32_b2, u32_ofNat_toNat, hVf]
    omega
  have e3 : ((UInt32.ofNat V) >>> 24 : UInt32).toUInt8 = b3 := by
    apply UInt8.toNat_inj.mp
    simp only [u32_b3, u32_ofNat_toNat, hVf]
    omega
  simp only [encU32L, e0, e1, e2, e3]

/-- The LE16 bytes of `UInt16.ofNat V` are the base-256 digits of `V`. -/
theorem encU16L_of_leNat (b0 b1 : UInt8) :
    encU16L (UInt16.ofNat (b0.toNat + 256 * b1.toNat)) = [b0, b1] := by
  have h0 : b0.toNat < 256 := by simpa using b0.toNat_lt_size
  have h1 : b1.toNat < 256 := by simpa using b1.toNat_lt_size
  generalize hV : (b0.toNat + 256 * b1.toNat) = V
  have hVf : V = b0.toNat + 256 * b1.toNat := by omega
  have e0 : (UInt16.ofNat V).toUInt8 = b0 := by
    apply UInt8.toNat_inj.mp
    simp only [u16_b0, u16_ofNat_toNat, hVf]
    omega
  have e1 : ((UInt16.ofNat V) >>> 8 : UInt16).toUInt8 = b1 := by
    apply UInt8.toNat_inj.mp
    simp only [u16_b1, u16_ofNat_toNat, hVf]
    omega
  simp only [encU16L, e0, e1]

/-- The LE64 bytes of `UInt64.ofNat V` are the base-256 digits of `V`. -/
theorem encU64L_of_leNat (b0 b1 b2 b3 b4 b5 b6 b7 : UInt8) :
    encU64L (UInt64.ofNat (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))))
      = [b0, b1, b2, b3, b4, b5, b6, b7] := by
  have h0 : b0.toNat < 256 := by simpa using b0.toNat_lt_size
  have h1 : b1.toNat < 256 := by simpa using b1.toNat_lt_size
  have h2 : b2.toNat < 256 := by simpa using b2.toNat_lt_size
  have h3 : b3.toNat < 256 := by simpa using b3.toNat_lt_size
  have h4 : b4.toNat < 256 := by simpa using b4.toNat_lt_size
  have h5 : b5.toNat < 256 := by simpa using b5.toNat_lt_size
  have h6 : b6.toNat < 256 := by simpa using b6.toNat_lt_size
  have h7 : b7.toNat < 256 := by simpa using b7.toNat_lt_size
  generalize hV : (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
    256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))) = V
  have hVf : V = b0.toNat + 256 * b1.toNat + 65536 * b2.toNat + 16777216 * b3.toNat
      + 4294967296 * b4.toNat + 1099511627776 * b5.toNat
      + 281474976710656 * b6.toNat + 72057594037927936 * b7.toNat := by
    omega
  have e0 : (UInt64.ofNat V).toUInt8 = b0 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b0, u64_ofNat_toNat, hVf]
    omega
  have e1 : ((UInt64.ofNat V) >>> 8 : UInt64).toUInt8 = b1 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b1, u64_ofNat_toNat, hVf]
    omega
  have e2 : ((UInt64.ofNat V) >>> 16 : UInt64).toUInt8 = b2 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b2, u64_ofNat_toNat, hVf]
    omega
  have e3 : ((UInt64.ofNat V) >>> 24 : UInt64).toUInt8 = b3 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b3, u64_ofNat_toNat, hVf]
    omega
  have e4 : ((UInt64.ofNat V) >>> 32 : UInt64).toUInt8 = b4 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b4, u64_ofNat_toNat, hVf]
    omega
  have e5 : ((UInt64.ofNat V) >>> 40 : UInt64).toUInt8 = b5 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b5, u64_ofNat_toNat, hVf]
    omega
  have e6 : ((UInt64.ofNat V) >>> 48 : UInt64).toUInt8 = b6 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b6, u64_ofNat_toNat, hVf]
    omega
  have e7 : ((UInt64.ofNat V) >>> 56 : UInt64).toUInt8 = b7 := by
    apply UInt8.toNat_inj.mp
    simp only [u64_b7, u64_ofNat_toNat, hVf]
    omega
  simp only [encU64L, e0, e1, e2, e3, e4, e5, e6, e7]

theorem amtToU64_u64ToAmt (u : Nat) (h : u < 18446744073709551616) :
    amtToU64 (u64ToAmt u) = u := by
  unfold u64ToAmt amtToU64
  split
  · rename_i h1
    rw [if_neg (show ¬ ((u : Int) < 0) from by omega)]
    have key : (((u : Int).toNat : Int)) = u := Int.toNat_of_nonneg (by omega)
    omega
  · rename_i h1
    have h4 : ((u : Int) - 18446744073709551616 : Int) < 0 := by omega
    rw [if_pos h4]
    have key : (((u : Int) - 18446744073709551616 + 18446744073709551616 : Int).toNat : Int)
        = (u : Int) - 18446744073709551616 + 18446744073709551616 :=
      Int.toNat_of_nonneg (by omega)
    have hA : ((u : Int) - 18446744073709551616 + 18446744073709551616 : Int) = (u : Int) := by
      omega
    rw [hA] at key
    omega

theorem u64ToAmt_amtToU64 (v : Amount) (h : 0 ≤ v) (h2 : v < 9223372036854775808) :
    u64ToAmt (amtToU64 v) = v := by
  unfold amtToU64 u64ToAmt
  rw [if_neg (Int.not_lt.mpr h)]
  have key : ((v.toNat : Int)) = v := Int.toNat_of_nonneg h
  have hvi : ((v.toNat : Int)) < 9223372036854775808 := by rw [key]; exact h2
  rw [if_pos (show v.toNat < 9223372036854775808 from by omega)]
  exact key

theorem decU64L_encU64L (x : UInt64) (rest : Bytes) :
    decU64L (encU64L x ++ rest) = .ok (x.toNat, rest) := by
  simp only [encU64L, List.cons_append, decU64L]
  have hV : x.toUInt8.toNat
      + 256 * ((x >>> 8).toUInt8.toNat + 256 * ((x >>> 16).toUInt8.toNat
      + 256 * ((x >>> 24).toUInt8.toNat + 256 * ((x >>> 32).toUInt8.toNat
      + 256 * ((x >>> 40).toUInt8.toNat + 256 * ((x >>> 48).toUInt8.toNat
      + 256 * ((x >>> 56).toUInt8.toNat))))))) = x.toNat := by
    rw [u64_b0, u64_b1, u64_b2, u64_b3, u64_b4, u64_b5, u64_b6, u64_b7]
    have h : x.toNat < 18446744073709551616 := x.toNat_lt_size
    omega
  simp only [List.nil_append]
  rw [hV]

/-! ## CompactSize — canonical encode, canonical decode (TXV-012) -/

/-- `ReadCompactSize` range limit: `serialize.h:35`,
`inline constexpr uint64_t MAX_SIZE = 0x02000000`. Every consensus
deserialization reads CompactSize counts with `range_check = true`
(serialize.h:614 `CompactSizeReader`), so counts above this are decode
failures ("ReadCompactSize(): size too large"). -/
def MAX_SIZE : Nat := 0x02000000

/-- Canonical CompactSize encoding as a byte list
(mirrors `compactSizeEnc`/`WriteCompactSize`). -/
def encCSL (n : Nat) : Bytes :=
  if n < 0xfd then [n.toUInt8]
  else if n ≤ 0xffff then 0xfd :: encU16L n.toUInt16
  else if n ≤ 0xffffffff then 0xfe :: encU32L n.toUInt32
  else 0xff :: encU64L n.toUInt64

/-- The bridge from the frozen `ByteArray` encoder to the list layer. -/
theorem bL_compactSizeEnc (n : Nat) : bL (compactSizeEnc n) = encCSL n := by
  unfold compactSizeEnc encCSL
  by_cases h1 : n < 0xfd <;> by_cases h2 : n ≤ 0xffff <;> by_cases h3 : n ≤ 0xffffffff <;>
    simp [h1, h2, h3, serU8, serU16, serU32, serU64, bL_push, bL_append, bL_empty,
      encU16L, encU32L, encU64L]

/-- Canonical CompactSize decode — `ReadCompactSize` (serialize.h:333-361
@ c50817f): non-minimal encodings are rejected ("non-canonical
ReadCompactSize()") and values above `MAX_SIZE` are rejected
("size too large", range_check = true). Returns the value and the
unconsumed remainder. -/
@[rule "TXV-012"]
def decCS (l : Bytes) : Except SerError (Nat × Bytes) :=
  match l with
  | [] => .error .truncated
  | first :: rest =>
    if first.toNat < 0xfd then .ok (first.toNat, rest)
    else if first = 0xfd then
      match rest with
      | b0 :: b1 :: rest' =>
        let v := b0.toNat + 256 * b1.toNat
        if v < 0xfd then .error .compactSizeNonMinimal else .ok (v, rest')
      | _ => .error .truncated
    else if first = 0xfe then
      match rest with
      | b0 :: b1 :: b2 :: b3 :: rest' =>
        let v := b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))
        if v < 0x10000 then .error .compactSizeNonMinimal
        else if MAX_SIZE < v then .error .compactSizeTooLong
        else .ok (v, rest')
      | _ => .error .truncated
    else
      match rest with
      | b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: rest' =>
        let v := b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
          256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))
        if v < 0x100000000 then .error .compactSizeNonMinimal
        else if MAX_SIZE < v then .error .compactSizeTooLong
        else .ok (v, rest')
      | _ => .error .truncated

/-- **TXV-012 (encode side of the canonicality law)**: the canonical
encoding of `n ≤ MAX_SIZE` decodes back to exactly `n`, consuming itself. -/
theorem decCS_encCSL (n : Nat) (h : n ≤ MAX_SIZE) (rest : Bytes) :
    decCS (encCSL n ++ rest) = .ok (n, rest) := by
  unfold encCSL
  split
  · -- n < 0xfd : single byte
    rename_i h1
    simp only [List.singleton_append, decCS]
    have h8 : n.toUInt8.toNat = n := by
      have h8' : n.toUInt8.toNat = n % 256 := rfl
      rw [h8', Nat.mod_eq_of_lt (by omega : n < 256)]
    have hb : n.toUInt8.toNat < 0xfd := by omega
    rw [if_pos hb]
    simp [h8]
  · split
    · -- 0xfd ≤ n ≤ 0xffff : marker + uint16
      rename_i h1 h2
      simp only [List.cons_append, List.append_assoc, decCS]
      have hlt : ¬ ((0xfd : UInt8).toNat < 0xfd) := by decide
      have heq : (0xfd : UInt8) = (0xfd : UInt8) := rfl
      simp only [hlt, if_false, heq, if_true, List.cons_append, encU16L]
      have hv : n.toUInt16.toUInt8.toNat
          + 256 * ((n.toUInt16 >>> 8 : UInt16).toUInt8).toNat = n := by
        have h16 : n.toUInt16.toNat = n % 65536 := u16_ofNat_toNat n
        have hb0 := u16_b0 n.toUInt16
        have hb1 := u16_b1 n.toUInt16
        omega
      have hmin : ¬ (n.toUInt16.toUInt8.toNat
          + 256 * ((n.toUInt16 >>> 8 : UInt16).toUInt8).toNat < 0xfd) := by
        have : 0xfd ≤ n := by omega
        omega
      rw [if_neg hmin, hv, List.nil_append]
    · split
      · -- 0x10000 ≤ n ≤ 0xffffffff : marker + uint32
        rename_i h1 h2 h3
        simp only [List.cons_append, List.append_assoc, decCS]
        have hlt : ¬ ((0xfe : UInt8).toNat < 0xfd) := by decide
        have heq0 : ¬ ((0xfe : UInt8) = (0xfd : UInt8)) := by decide
        have heq : (0xfe : UInt8) = (0xfe : UInt8) := rfl
        simp only [hlt, if_false, heq0, if_false, heq, if_true, List.cons_append, encU32L]
        have hval : n.toUInt32.toUInt8.toNat
            + 256 * ((n.toUInt32 >>> 8 : UInt32).toUInt8.toNat
              + 256 * ((n.toUInt32 >>> 16 : UInt32).toUInt8.toNat
                + 256 * (n.toUInt32 >>> 24 : UInt32).toUInt8.toNat)) = n := by
          have hV : n.toUInt32.toUInt8.toNat
              + 256 * ((n.toUInt32 >>> 8).toUInt8.toNat
                + 256 * ((n.toUInt32 >>> 16).toUInt8.toNat
                  + 256 * ((n.toUInt32 >>> 24).toUInt8.toNat))) = n.toUInt32.toNat := by
            rw [u32_b0, u32_b1, u32_b2, u32_b3]
            have hx : n.toUInt32.toNat < 4294967296 := n.toUInt32.toNat_lt_size
            omega
          rw [hV, u32_ofNat_toNat]
          have hlt : n < 4294967296 := by omega
          rw [Nat.mod_eq_of_lt hlt]
        have hbig : ¬ (n.toUInt32.toUInt8.toNat
            + 256 * ((n.toUInt32 >>> 8 : UInt32).toUInt8.toNat
              + 256 * ((n.toUInt32 >>> 16 : UInt32).toUInt8.toNat
                + 256 * (n.toUInt32 >>> 24 : UInt32).toUInt8.toNat)) < 0x10000) := by
          rw [hval]
          omega
        rw [if_neg hbig, hval]
        have hmax : ¬ MAX_SIZE < n := by omega
        rw [if_neg hmax, List.nil_append]
      · -- n > 0xffffffff but n ≤ MAX_SIZE < 2^32: vacuous
        rename_i h1 h2 h3
        exfalso
        have hM : MAX_SIZE = 33554432 := rfl
        have hn : 0xffffffff < n := by omega
        omega

/-- **TXV-012 (reject side)**: a non-minimal encoding is rejected with
`compactSizeNonMinimal`; an over-range value with `compactSizeTooLong`. -/
theorem decCS_nonMin_0xfd (b0 b1 : UInt8) (rest : Bytes)
    (h : b0.toNat + 256 * b1.toNat < 0xfd) :
    decCS (0xfd :: b0 :: b1 :: rest) = .error .compactSizeNonMinimal := by
  simp [decCS, h]

theorem decCS_nonMin_0xfe (b0 b1 b2 b3 : UInt8) (rest : Bytes)
    (h : b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat)) < 0x10000) :
    decCS (0xfe :: b0 :: b1 :: b2 :: b3 :: rest) = .error .compactSizeNonMinimal := by
  simp [decCS, h]

theorem decCS_nonMin_0xff (b0 b1 b2 b3 b4 b5 b6 b7 : UInt8) (rest : Bytes)
    (h : b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))
      < 0x100000000) :
    decCS (0xff :: b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: rest)
      = .error .compactSizeNonMinimal := by
  simp [decCS, h]
theorem decCS_tooLarge (b0 b1 b2 b3 b4 b5 b6 b7 : UInt8) (rest : Bytes)
    (h1 : ¬ (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat)))))))
      < 0x100000000)
    (h2 : MAX_SIZE < b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))) :
    decCS (0xff :: b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: rest)
      = .error .compactSizeTooLong := by
  simp [decCS, h1, h2]

/-- **TXV-012 (reject side, 0xfe frame)**: the 32-bit CompactSize frame
applies the same `MAX_SIZE` range check as Core's `ReadCompactSize`
(serialize.h:333-361). A canonical 0xfe value above `MAX_SIZE` is
rejected with `compactSizeTooLong`, not accepted as an unbounded size. -/
theorem decCS_tooLarge_0xfe (b0 b1 b2 b3 : UInt8) (rest : Bytes)
    (h1 : ¬ (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))
      < 0x10000))
    (h2 : MAX_SIZE < b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))) :
    decCS (0xfe :: b0 :: b1 :: b2 :: b3 :: rest) = .error .compactSizeTooLong := by
  simp [decCS, h1, h2]

/-! ## Byte strings, scripts, tx pieces -/

/-- Read exactly `n` raw bytes. -/
def decBytesL (n : Nat) (l : Bytes) : Except SerError (Bytes × Bytes) :=
  if l.length < n then .error .truncated
  else .ok (l.take n, l.drop n)

/-- Reading `bs.length` bytes off `bs ++ rest` returns exactly `bs`. -/
theorem decBytesL_len (bs : Bytes) (rest : Bytes) :
    decBytesL bs.length (bs ++ rest) = .ok (bs, rest) := by
  unfold decBytesL
  have hl : (bs ++ rest).length = bs.length + rest.length := by simp
  have hlt : ¬ ((bs ++ rest).length < bs.length) := by omega
  rw [if_neg hlt, List.take_left, drop_append_left]

theorem decBytesL_enc (bs : Bytes) (n : Nat) (h : bs.length = n) (rest : Bytes) :
    decBytesL n (bs ++ rest) = .ok (bs, rest) := by
  rw [← h]
  exact decBytesL_len bs rest

theorem decBytesL_self (b : ByteArray) (rest : Bytes) (h : b.size = 32) :
    decBytesL 32 (bL b ++ rest) = .ok (bL b, rest) := by
  have hb : (bL b).length = 32 := by simp [bL, h]
  rw [← hb]
  exact decBytesL_len (bL b) rest

/-- `do`-notation plumbing: `simp` lemmas for `Bind.bind` on `Except`
(do-notation desugars to `Bind.bind`, not `Except.bind`).
The stdlib names differ across Lean versions, so this module carries its own. -/
@[simp] theorem bindE_ok {ε : Type} {α β : Type} (x : α) (f : α → Except ε β) :
    Bind.bind (Except.ok x) f = f x := rfl

@[simp] theorem bindE_err {ε : Type} {α β : Type} (e : ε) (f : α → Except ε β) :
    Bind.bind (Except.error e) f = Except.error e := rfl

/-- Read a length-prefixed byte string (`CScript` wire form:
CompactSize count + bytes), as a raw `ByteArray`. -/
def decScriptBL (l : Bytes) : Except SerError (ByteArray × Bytes) := do
  let (n, l1) ← decCS l
  let (bs, l2) ← decBytesL n l1
  .ok (bytesOfList bs, l2)

/-- Read a length-prefixed byte string as a `Script`. -/
def decScriptL (l : Bytes) : Except SerError (Script × Bytes) := do
  let (b, l2) ← decScriptBL l
  .ok (⟨b⟩, l2)

/-- Wire form of a `Script` under the bridge. -/
theorem bL_script_bytes (s : Script) : bL s.bytes = s.bytes.data.toList := rfl

theorem decScriptL_enc (s : Script) (rest : Bytes) (h : s.bytes.size ≤ MAX_SIZE) :
    decScriptL (encCSL s.bytes.size ++ (bL s.bytes ++ rest)) = .ok (s, rest) := by
  simp only [decScriptL, decScriptBL]
  rw [decCS_encCSL _ h]
  simp only [bindE_ok]
  rw [decBytesL_enc (bL s.bytes) s.bytes.size (by simp [bL]) _]
  simp only [bindE_ok, bytesOfList_bL]

/-- Read one `COutPoint`: 32-byte txid (LE on the wire) + `UInt32` n. -/
def decOutPointL (l : Bytes) : Except SerError (OutPoint × Bytes) := do
  let (hb, l1) ← decBytesL 32 l
  let (n, l2) ← decU32L l1
  .ok (⟨bytesOfList hb, n⟩, l2)

theorem decOutPointL_enc (o : OutPoint) (rest : Bytes) (h : o.hash.size = 32) :
    decOutPointL (bL o.hash ++ (encU32L o.n ++ rest)) = .ok (o, rest) := by
  simp only [decOutPointL, bindE_ok]
  rw [decBytesL_self _ _ h]
  simp only [bindE_ok, bytesOfList_bL]
  rw [decU32L_encU32L]
  simp only [bindE_ok]

/-- Read one `CTxIn` (primitives/transaction.h:64):
`prevout ‖ scriptSig ‖ nSequence`. -/
def decTxInL (l : Bytes) : Except SerError (TxIn × Bytes) := do
  let (o, l1) ← decOutPointL l
  let (s, l2) ← decScriptL l1
  let (q, l3) ← decU32L l2
  .ok (⟨o, s, q⟩, l3)

theorem bL_serU32 (x : UInt32) : bL (serU32 x) = encU32L x := by
  simp [serU32, bL, encU32L]

theorem bL_serTxIn (i : TxIn) :
    bL (serTxIn i) =
      bL i.prevout.hash ++ encU32L i.prevout.n ++ encCSL i.scriptSig.bytes.size
        ++ bL i.scriptSig.bytes ++ encU32L i.sequence := by
  simp only [serTxIn, bL_append, bL_serU32, bL_compactSizeEnc]

theorem decTxInL_enc (i : TxIn) (rest : Bytes)
    (h : i.prevout.hash.size = 32) (hs : i.scriptSig.bytes.size ≤ MAX_SIZE) :
    decTxInL (bL (serTxIn i) ++ rest) = .ok (i, rest) := by
  rw [bL_serTxIn]
  simp only [decTxInL, bindE_ok, List.append_assoc]
  rw [decOutPointL_enc i.prevout _ h]
  simp only [bindE_ok]
  rw [decScriptL_enc i.scriptSig _ hs]
  simp only [bindE_ok]
  rw [decU32L_encU32L]
  simp only [bindE_ok]

/-- Read one `CTxOut` (primitives/transaction.h:14 of SERIALIZE_METHODS):
`nValue (int64 LE) ‖ scriptPubKey`. -/
def decTxOutL (l : Bytes) : Except SerError (TxOut × Bytes) := do
  let (u, l1) ← decU64L l
  let (s, l2) ← decScriptL l1
  .ok (⟨u64ToAmt u, s⟩, l2)

theorem bL_serU64 (x : UInt64) : bL (serU64 x) = encU64L x := by
  simp [serU64, bL, encU64L]

theorem bL_serTxOut (o : TxOut) :
    bL (serTxOut o) =
      encU64L (UInt64.ofNat (amtToU64 o.value))
        ++ encCSL o.scriptPubKey.bytes.size ++ bL o.scriptPubKey.bytes := by
  simp only [serTxOut, bL_append, bL_serU64, bL_compactSizeEnc]

theorem decTxOutL_enc (o : TxOut) (rest : Bytes)
    (hv : 0 ≤ o.value) (hv2 : o.value < 9223372036854775808)
    (hs : o.scriptPubKey.bytes.size ≤ MAX_SIZE) :
    decTxOutL (bL (serTxOut o) ++ rest) = .ok (o, rest) := by
  rw [bL_serTxOut]
  simp only [decTxOutL, List.append_assoc]
  rw [decU64L_encU64L]
  simp only [bindE_ok]
  have hbound : amtToU64 o.value < 18446744073709551616 := by
    unfold amtToU64
    rw [if_neg (Int.not_lt.mpr hv)]
    have hv2n : o.value.toNat < 9223372036854775808 :=
      (Int.toNat_lt (n := 9223372036854775808) hv).mpr hv2
    exact Nat.lt_of_lt_of_le hv2n (by decide)
  have hnat : (UInt64.ofNat (amtToU64 o.value)).toNat = amtToU64 o.value := by
    rw [u64_ofNat_toNat, Nat.mod_eq_of_lt hbound]
  rw [hnat, u64ToAmt_amtToU64 o.value hv hv2]
  rw [decScriptL_enc o.scriptPubKey _ hs]
  simp only [bindE_ok]

/-- Repeat a decoder `k` times (Core's vector read:
count via `ReadCompactSize`, then that many elements). -/
def decN (dec : Bytes → Except SerError (α × Bytes)) :
    Nat → Bytes → Except SerError (List α × Bytes)
  | 0, l => .ok ([], l)
  | k+1, l => do
    let (a, l1) ← dec l
    let (as, l2) ← decN dec k l1
    .ok (a :: as, l2)

/-- Concatenated encodings, list form. -/
def encN (enc : α → Bytes) (xs : List α) : Bytes := xs.flatMap enc

/-- One witness stack item: CompactSize-length-prefixed bytes
(`CScriptWitness.stack`, BIP144). -/
def decItemL (l : Bytes) : Except SerError (ByteArray × Bytes) := decScriptBL l

/-- One witness stack: CompactSize count of items, then the items. -/
def decStackL (l : Bytes) : Except SerError (List ByteArray × Bytes) := do
  let (n, l1) ← decCS l
  decN decItemL n l1

/-- Roundtrip for `decN`/`encN`; the per-element law is only required for
elements of `xs` (the count vector). -/
theorem decN_enc {α : Type} {dec : Bytes → Except SerError (α × Bytes)} {enc : α → Bytes}
    (xs : List α)
    (H : ∀ a ∈ xs, ∀ rest : Bytes, dec (enc a ++ rest) = .ok (a, rest)) :
    ∀ (rest : Bytes), decN dec xs.length (xs.flatMap enc ++ rest) = .ok (xs, rest) := by
  induction xs with
  | nil => intro rest; rfl
  | cons a as ih =>
    intro rest
    have hH : ∀ x ∈ as, ∀ rest : Bytes, dec (enc x ++ rest) = .ok (x, rest) :=
      fun x hx r => H x (List.Mem.tail _ hx) r
    simp only [decN, List.length_cons, List.flatMap_cons, List.append_assoc]
    rw [H a (List.Mem.head _) (List.flatMap enc as ++ rest)]
    simp only [bindE_ok]
    rw [ih hH]
    simp only [bindE_ok]

/-- Inversion shape: whatever `decN` consumed re-encodes to what it read. -/
theorem decN_shape {α : Type} {dec : Bytes → Except SerError (α × Bytes)} {enc : α → Bytes}
    (Hshape : ∀ l a rest, dec l = .ok (a, rest) → l = enc a ++ rest) :
    ∀ k l xs rest, decN dec k l = .ok (xs, rest) → xs.length = k ∧ l = encN enc xs ++ rest := by
  intro k
  induction k with
  | zero =>
    intro l xs rest h
    simp only [decN] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨rfl, rfl⟩
  | succ k ih =>
    intro l xs rest h
    simp only [decN, bindE_ok] at h
    cases hd : dec l with
    | error e => rw [hd] at h; simp at h
    | ok p =>
      obtain ⟨a, l1⟩ := p
      rw [hd] at h
      simp only [bindE_ok] at h
      cases h2 : decN dec k l1 with
      | error e => rw [h2] at h; simp at h
      | ok q =>
        obtain ⟨as, l2⟩ := q
        rw [h2] at h
        simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        obtain ⟨ha, hrest⟩ := ih l1 as l2 h2
        refine ⟨by simp [ha], ?_⟩
        rw [Hshape l a l1 hd]
        simp [encN, ha, hrest]

/-! ## Witness section (TXV-014/015) -/

/-- One stack's wire form: CompactSize item count, then each item as
CompactSize-length-prefixed bytes (BIP144). -/
def encStackL (s : List ByteArray) : Bytes :=
  encCSL s.length ++ s.flatMap (fun item => encCSL item.size ++ bL item)

/-- `CTransaction::HasWitness()` (transaction.h): some input carries a
non-empty witness stack. In our `Tx` the stacks live in `tx.witness`,
one slot per `vin` (padded with empty stacks like Core's default
`CScriptWitness`). -/
def hasWitness (tx : Tx) : Bool :=
  (List.range tx.vin.length).any (fun i => !(tx.witness.getD i []).isEmpty)

/-- Witness encoding: the stack of input `i` is `tx.witness[i]` (empty when
absent), matching Core's per-`vin` iteration in `SerializeTransaction`. -/
def encStacksL (tx : Tx) : Bytes :=
  (List.range tx.vin.length).flatMap (fun i => encStackL (tx.witness.getD i []))

theorem decStackL_enc (s : List ByteArray) (rest : Bytes)
    (hc : s.length ≤ MAX_SIZE)
    (hi : ∀ item ∈ s, item.size ≤ MAX_SIZE) :
    decStackL (encStackL s ++ rest) = .ok (s, rest) := by
  simp only [decStackL, encStackL, List.append_assoc]
  rw [decCS_encCSL _ hc]
  simp only [bindE_ok]
  exact decN_enc s (fun item hm rest' => by
    simp only [decItemL, decScriptBL, List.append_assoc]
    rw [decCS_encCSL _ (hi item hm)]
    simp only [bindE_ok]
    rw [decBytesL_enc (bL item) item.size (by simp [bL]) _]
    simp only [bindE_ok, bytesOfList_bL]) rest

/-- A witness-carrying tx has a non-empty stack somewhere. -/
theorem witness_all_empty_of_hasWitness {tx : Tx} (hh : hasWitness tx = true)
    (hwlen : tx.witness.length = tx.vin.length) :
    tx.witness.all (fun s : List ByteArray => s.isEmpty) = false := by
  rw [hasWitness, List.any_eq_true] at hh
  obtain ⟨i, hi, hne⟩ := hh
  have hmem : tx.witness.getD i [] ∈ tx.witness :=
    getD_mem [] tx.witness i (by rw [hwlen]; exact List.mem_range.mp hi)
  cases hb : tx.witness.all (fun s : List ByteArray => s.isEmpty) with
  | false => rfl
  | true =>
    have hall : ∀ x ∈ tx.witness, x.isEmpty = true := List.all_eq_true.mp hb
    rw [hall _ hmem] at hne
    simp at hne

/-- If no input carries a witness stack, every in-range slot is empty. -/
theorem witness_getD_empty_of_not_hasWitness {tx : Tx} (hh : hasWitness tx = false)
    (hwlen : tx.witness.length = tx.vin.length) :
    tx.witness = List.replicate tx.vin.length [] := by
  have hget : ∀ i, i < tx.vin.length → tx.witness.getD i [] = ([] : List ByteArray) := by
    intro i hi
    cases hne : (tx.witness.getD i []).isEmpty with
    | true => exact List.isEmpty_iff.mp hne
    | false =>
      have h2 : hasWitness tx = true :=
        List.any_eq_true.mpr ⟨i, List.mem_range.mpr hi, by rw [hne]; simp⟩
      rw [hh] at h2
      simp at h2
  rw [list_eq_replicate_of_getD [] tx.witness tx.vin.length hwlen hget]

/-- map-then-flatMap collapses into one flatMap. -/
theorem flatMap_map {α β : Type} (f : α → β) (g : β → Bytes) (l : List α) :
    (List.map f l).flatMap g = l.flatMap (fun i => g (f i)) := by
  induction l with
  | nil => rfl
  | cons a l ih => simp [List.map_cons, List.flatMap_cons, ih]

/-- `encStacksL` encodes the `getD`-view of the witness slots. -/
theorem encStacksL_eq (tx : Tx) :
    encStacksL tx
      = ((List.range tx.vin.length).map (fun i => tx.witness.getD i [])).flatMap encStackL := by
  simp only [encStacksL, flatMap_map]

/-! ## Transaction framing (TXV-011/013) -/

/-- Read a `vin` vector: CompactSize count + that many `CTxIn`. -/
def decVinL (l : Bytes) : Except SerError (List TxIn × Bytes) := do
  let (n, l1) ← decCS l
  decN decTxInL n l1

/-- `UnserializeTransaction` (primitives/transaction.h:201-239 @ c50817f),
transliterated. Returns the tx and the unconsumed remainder.
SWT-037: extended serialization (vin==0 ⇒ marker/flag follow; flag&1 ⇒
per-input witness stacks after vout). SWT-038: marker/flag = 0x00/0x01
framing (flag ≠ 0 re-reads vin+vout; flag 0 = vin-empty short record).
SWT-039: superfluous witness record — flag with ALL stacks empty is a
serialization error. SWT-040: any flag byte ≠ 1 is an error (future
flags are hardforks). -/
@[rule "TXV-011", rule "TXV-013", rule "TXV-014", rule "TXV-015", rule "TXV-016",
  rule "SWT-037", rule "SWT-038", rule "SWT-039", rule "SWT-040"]
def decTxCore (l : Bytes) : Except SerError (Tx × Bytes) := do
  let (v, l1) ← decU32L l
  let (n, l2) ← decCS l1
  if n = 0 then
    -- The dummy: this byte was the SegWit marker, the next is the flag.
    let (flag, l3) ← decU8L l2
    if flag = 0 then
      -- Core reads NOTHING further here: vin stays empty, vout is not read.
      let (lt, l4) ← decU32L l3
      .ok (⟨UInt32.toInt32 v, [], [], lt, []⟩, l4)
    else
      -- Re-read vin (count + items) and vout, Core's "non-empty flags byte".
      let (vin, l4) ← decVinL l3
      let (m, l5) ← decCS l4
      let (vout, l6) ← decN decTxOutL m l5
      if flag.toNat % 2 = 1 then
        let (w, l7) ← decN decStackL vin.length l6
        if w.all (fun s : List ByteArray => s.isEmpty) then
          .error .superfluousWitness
        else if flag ≠ 1 then
          .error .unknownFlag
        else
          let (lt, l8) ← decU32L l7
          .ok (⟨UInt32.toInt32 v, vin, vout, lt, w⟩, l8)
      else if flag ≠ 1 then
        .error .unknownFlag
      else
        let (lt, l7) ← decU32L l6
        .ok (⟨UInt32.toInt32 v, vin, vout, lt, List.replicate vin.length []⟩, l7)
  else
    -- Count already consumed: read the vin items, then a normal vout.
    let (vin, l3) ← decN decTxInL n l2
    let (m, l4) ← decCS l3
    let (vout, l5) ← decN decTxOutL m l4
    let (lt, l6) ← decU32L l5
    .ok (⟨UInt32.toInt32 v, vin, vout, lt, List.replicate vin.length []⟩, l6)

/-- The full tx decode of a complete byte string: parse, then require
nothing left over (Core's `DecodeHexTx` rejects trailing data,
core_read.cpp). -/
def decTxFull (l : Bytes) : Except SerError Tx := do
  let (tx, rest) ← decTxCore l
  if rest.isEmpty then .ok tx else .error .badMarkerOrFlag

/-- Domain on which `decodeTx ∘ encodeTx = id` holds: counts and sizes
within `MAX_SIZE`, 32-byte prevout hashes, `int64`-representable
non-negative output values, and one witness slot per input. -/
def wireDomain (tx : Tx) : Prop :=
  0 < tx.vin.length
  ∧ tx.witness.length = tx.vin.length
  ∧ tx.vin.length ≤ MAX_SIZE
  ∧ tx.vout.length ≤ MAX_SIZE
  ∧ (∀ i ∈ tx.vin, i.prevout.hash.size = 32 ∧ i.scriptSig.bytes.size ≤ MAX_SIZE)
  ∧ (∀ o ∈ tx.vout, o.scriptPubKey.bytes.size ≤ MAX_SIZE ∧ 0 ≤ o.value
      ∧ o.value < 9223372036854775808)
  ∧ (∀ s ∈ tx.witness, s.length ≤ MAX_SIZE ∧ ∀ item ∈ s, item.size ≤ MAX_SIZE)

/-- The list-layer canonical encoding: extended (BIP144) format iff the tx
has a witness, else the base (no-witness) form. -/
def encTxL (tx : Tx) : Bytes :=
  if hasWitness tx then
    encU32L tx.version.toUInt32 ++ [0x00, 0x01]
      ++ encCSL tx.vin.length ++ tx.vin.flatMap (fun i => bL (serTxIn i))
      ++ encCSL tx.vout.length ++ tx.vout.flatMap (fun o => bL (serTxOut o))
      ++ encStacksL tx
      ++ encU32L tx.locktime
  else
    bL (serTx tx)

/-- Reading the SegWit marker byte as a CompactSize yields 0. -/
theorem decCS_zero (X : Bytes) : decCS ((0x00 : UInt8) :: X) = .ok (0, X) := by
  simp only [decCS, List.cons_append]
  rfl

theorem decU8L_cons (b : UInt8) (X : Bytes) : decU8L (b :: X) = .ok (b, X) := rfl

theorem decTxCore_encTxL (tx : Tx) (rest : Bytes) (h : wireDomain tx) :
    decTxCore (encTxL tx ++ rest) = .ok (tx, rest) := by
  obtain ⟨hv0, hwlen, hvinc, hvoutc, hvin, hvout, hwit⟩ := h
  -- shared per-element laws
  have H1 : ∀ a ∈ tx.vin, ∀ r, decTxInL (bL (serTxIn a) ++ r) = .ok (a, r) := by
    intro a ha r; exact decTxInL_enc a r (hvin a ha).1 (hvin a ha).2
  have H2 : ∀ o ∈ tx.vout, ∀ r, decTxOutL (bL (serTxOut o) ++ r) = .ok (o, r) := by
    intro o ho r
    obtain ⟨hsz, hval⟩ := hvout o ho
    exact decTxOutL_enc o r hval.1 hval.2 hsz
  -- the witness list is the getD-image of the index range
  have hwm : (List.range tx.vin.length).map (fun i => tx.witness.getD i []) = tx.witness := by
    rw [← hwlen]; exact list_eq_map_getD [] tx.witness
  unfold encTxL
  split
  · -- extended (BIP144) format
    rename_i hh
    simp only [List.append_assoc, decTxCore, bindE_ok]
    rw [decU32L_encU32L]
    simp only [bindE_ok, List.cons_append, List.nil_append, decCS_zero, decU8L_cons,
      reduceIte, decVinL, List.append_assoc]
    rw [decCS_encCSL _ hvinc]
    simp only [bindE_ok]
    rw [decN_enc tx.vin H1]
    simp only [bindE_ok, List.append_assoc]
    rw [decCS_encCSL _ hvoutc]
    simp only [bindE_ok]
    rw [decN_enc tx.vout H2]
    simp only [bindE_ok]
    rw [encStacksL_eq]
    have H3 : ∀ s ∈ (List.range tx.vin.length).map (fun i => tx.witness.getD i []),
        ∀ r, decStackL (encStackL s ++ r) = .ok (s, r) := by
      intro s hs r
      obtain ⟨i, hi, rfl⟩ := List.mem_map.mp hs
      obtain ⟨hs1, hs2⟩ := hwit _ (getD_mem [] tx.witness i
        (by rw [hwlen]; exact List.mem_range.mp hi))
      exact decStackL_enc _ r hs1 hs2
    have hcnt := decN_enc ((List.range tx.vin.length).map (fun i => tx.witness.getD i [])) H3
    rw [List.length_map, List.length_range] at hcnt
    rw [hcnt]
    simp only [bindE_ok]
    rw [hwm]
    have hW : ¬ (tx.witness.all (fun s : List ByteArray => s.isEmpty) = true) := by
      rw [witness_all_empty_of_hasWitness hh hwlen]; simp
    rw [if_neg hW, decU32L_encU32L]
    simp only [bindE_ok]
    try rfl
  · -- base (no-witness) format
    rename_i hh
    have hh2 : hasWitness tx = false := by
      simp only [Bool.not_eq_true] at hh; exact hh
    have hser : bL (serTx tx) = encU32L tx.version.toUInt32 ++ (encCSL tx.vin.length
        ++ (tx.vin.flatMap (fun i => bL (serTxIn i)) ++ (encCSL tx.vout.length
        ++ (tx.vout.flatMap (fun o => bL (serTxOut o)) ++ encU32L tx.locktime)))) := by
      simp only [serTx, bL_append, bL_serU32, bL_compactSizeEnc, bL_foldl_append,
        List.append_assoc, bL_empty, List.nil_append]
    have hwrep : tx.witness = List.replicate tx.vin.length [] :=
      witness_getD_empty_of_not_hasWitness hh2 hwlen
    rw [hser]
    simp only [List.append_assoc, decTxCore, bindE_ok]
    rw [decU32L_encU32L]
    simp only [bindE_ok]
    rw [decCS_encCSL _ hvinc]
    simp only [bindE_ok]
    rw [if_neg (by omega : ¬ (tx.vin.length = 0))]
    rw [decN_enc tx.vin H1]
    simp only [bindE_ok, List.append_assoc]
    rw [decCS_encCSL _ hvoutc]
    simp only [bindE_ok]
    rw [decN_enc tx.vout H2]
    simp only [bindE_ok]
    rw [decU32L_encU32L]
    simp only [bindE_ok]
    rw [← hwrep]
    try rfl

/-! ## Public ByteArray-level API (frozen interface members) -/

/-- Decode a CompactSize prefix at offset `i`; returns `(value, bytes
consumed)`. Reuses the prototype bootstrap decoder (`Bitcoin.Data.compactSizeDec`);
the canonicality laws (TXV-012) are proved over `decCS`/`encCSL` above. -/
def decodeCompactSize (b : ByteArray) (i : Nat) : Option (Nat × Nat) :=
  compactSizeDec b i

/-- Canonical CompactSize encoding (= the prototype `compactSizeEnc`). -/
def encodeCompactSize (n : Nat) : ByteArray :=
  compactSizeEnc n

/-- Full (witness-aware) transaction decode: `UnserializeTransaction`
(primitives/transaction.h:212-239 @ c50817f) over a complete byte string
(trailing data rejected, `DecodeHexTx` semantics). -/
def decodeTx (b : ByteArray) : Except SerError Tx :=
  decTxFull (bL b)

/-- Full (witness-aware) transaction encode: the exact inverse image of
`decodeTx`; txid is computed over `encodeTxNoWitness`. -/
def encodeTx (tx : Tx) : ByteArray :=
  bytesOfList (encTxL tx)

/-- Base (TX_NO_WITNESS) serialization — what txid is computed over. -/
def encodeTxNoWitness (tx : Tx) : ByteArray := serTx tx

theorem encCSL_zero : encCSL 0 = [0x00] := rfl

theorem u8_ofNat_self (b : UInt8) : b.toNat.toUInt8 = b := by
  apply UInt8.toNat_inj.mp
  have hr : (b.toNat.toUInt8).toNat = b.toNat % 256 := rfl
  have h : b.toNat < 256 := by simpa using b.toNat_lt_size
  rw [hr]
  omega

theorem getD_default_of_ge {α : Type} (d : α) :
    ∀ (l : List α) (i : Nat), l.length ≤ i → l.getD i d = d := by
  intro l
  induction l with
  | nil => intro i _; rfl
  | cons a l ih =>
    intro i h
    cases i with
    | zero =>
      have h1 : (a :: l).length = l.length + 1 := rfl
      simp only [h1] at h
      omega
    | succ j =>
      have h2 : (a :: l).getD (j + 1) d = l.getD j d := rfl
      rw [h2]
      exact ih j (by have h3 : (a :: l).length = l.length + 1 := rfl; simp only [h3] at h; omega)

/-- `List.getD` of a `replicate` is the replicated element (in range it is
the element itself, out of range the default — same value here). -/
theorem getD_replicate {α : Type} (d : α) :
    ∀ (n i : Nat), (List.replicate n d).getD i d = d := by
  intro n
  induction n with
  | zero => intro i; rfl
  | succ k ih =>
    intro i
    cases i with
    | zero => rfl
    | succ j =>
      have h2 : (List.replicate (k + 1) d).getD (j + 1) d = (List.replicate k d).getD j d := rfl
      rw [h2]
      exact ih j

theorem hasWitness_false_of_all_getD_empty {tx : Tx}
    (h : ∀ i, i < tx.vin.length → tx.witness.getD i [] = ([] : List ByteArray)) :
    hasWitness tx = false := by
  rw [hasWitness]
  simp only [List.any_eq_false]
  intro i hi hne
  rw [h i (List.mem_range.mp hi)] at hne
  simp at hne

theorem hasWitness_false_of_all_empty {tx : Tx}
    (hall : tx.witness.all (fun s : List ByteArray => s.isEmpty) = true) :
    hasWitness tx = false := by
  apply hasWitness_false_of_all_getD_empty
  intro i hi
  by_cases hlt : i < tx.witness.length
  · exact List.isEmpty_iff.mp (List.all_eq_true.mp hall _ (getD_mem [] tx.witness i hlt))
  · exact getD_default_of_ge [] tx.witness i (by omega)

theorem hasWitness_zero_vin (v : Int32) (lt : UInt32) :
    hasWitness (Tx.mk v [] [] lt []) = false := rfl

theorem hasWitness_of_witness_mem_nonempty {tx : Tx}
    (hwlen : tx.witness.length = tx.vin.length)
    (s : List ByteArray) (hs : s ∈ tx.witness) (hne : s.isEmpty = false) :
    hasWitness tx = true := by
  have hs2 : s ∈ (List.range tx.witness.length).map (fun i => tx.witness.getD i []) := by
    rw [list_eq_map_getD [] tx.witness]
    exact hs
  obtain ⟨i, hi, hgs⟩ := List.mem_map.mp hs2
  have hgs' : tx.witness.getD i [] = s := hgs
  rw [hasWitness, List.any_eq_true]
  exact ⟨i, by rw [← hwlen]; exact hi, by rw [hgs', hne]; rfl⟩

theorem bL_serTx (tx : Tx) :
    bL (serTx tx) = encU32L tx.version.toUInt32 ++ (encCSL tx.vin.length
      ++ (tx.vin.flatMap (fun i => bL (serTxIn i)) ++ (encCSL tx.vout.length
      ++ (tx.vout.flatMap (fun o => bL (serTxOut o)) ++ encU32L tx.locktime)))) := by
  simp only [serTx, bL_append, bL_serU32, bL_compactSizeEnc, bL_foldl_append,
    List.append_assoc, bL_empty, List.nil_append]

/-! ## Shape lemmas: a successful decode consumed the canonical encoding -/

theorem decU8L_shape (l : Bytes) (x : UInt8) (rest : Bytes)
    (h : decU8L l = .ok (x, rest)) : l = x :: rest := by
  cases l with
  | nil => simp [decU8L] at h
  | cons b l0 =>
    simp only [decU8L, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨hx, hrest⟩ := h
    subst hx
    subst hrest
    rfl

theorem decU32L_shape (l : Bytes) (x : UInt32) (rest : Bytes)
    (h : decU32L l = .ok (x, rest)) : l = encU32L x ++ rest := by
  cases l with
  | nil => simp [decU32L] at h
  | cons b0 l0 =>
    cases l0 with
    | nil => simp [decU32L] at h
    | cons b1 l1 =>
      cases l1 with
      | nil => simp [decU32L] at h
      | cons b2 l2 =>
        cases l2 with
        | nil => simp [decU32L] at h
        | cons b3 l3 =>
          simp only [decU32L, Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨hx, hrest⟩ := h
          subst hrest
          subst hx
          rw [encU32L_of_leNat b0 b1 b2 b3]
          rfl

theorem decU64L_shape (l : Bytes) (u : Nat) (rest : Bytes)
    (h : decU64L l = .ok (u, rest)) : l = encU64L (UInt64.ofNat u) ++ rest := by
  cases l with
  | nil => simp [decU64L] at h
  | cons b0 l0 =>
    cases l0 with
    | nil => simp [decU64L] at h
    | cons b1 l1 =>
      cases l1 with
      | nil => simp [decU64L] at h
      | cons b2 l2 =>
        cases l2 with
        | nil => simp [decU64L] at h
        | cons b3 l3 =>
          cases l3 with
          | nil => simp [decU64L] at h
          | cons b4 l4 =>
            cases l4 with
            | nil => simp [decU64L] at h
            | cons b5 l5 =>
              cases l5 with
              | nil => simp [decU64L] at h
              | cons b6 l6 =>
                cases l6 with
                | nil => simp [decU64L] at h
                | cons b7 l7 =>
                  simp only [decU64L, Except.ok.injEq, Prod.mk.injEq] at h
                  obtain ⟨hu, hrest⟩ := h
                  subst hrest
                  subst hu
                  rw [encU64L_of_leNat b0 b1 b2 b3 b4 b5 b6 b7]
                  rfl

theorem leNat8_lt (b0 b1 b2 b3 b4 b5 b6 b7 : UInt8) :
    b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))
      < 18446744073709551616 := by
  have h0 : b0.toNat < 256 := by simpa using b0.toNat_lt_size
  have h1 : b1.toNat < 256 := by simpa using b1.toNat_lt_size
  have h2 : b2.toNat < 256 := by simpa using b2.toNat_lt_size
  have h3 : b3.toNat < 256 := by simpa using b3.toNat_lt_size
  have h4 : b4.toNat < 256 := by simpa using b4.toNat_lt_size
  have h5 : b5.toNat < 256 := by simpa using b5.toNat_lt_size
  have h6 : b6.toNat < 256 := by simpa using b6.toNat_lt_size
  have h7 : b7.toNat < 256 := by simpa using b7.toNat_lt_size
  omega

theorem encCSL_fd (b0 b1 : UInt8) (hge : 0xfd ≤ b0.toNat + 256 * b1.toNat) :
    encCSL (b0.toNat + 256 * b1.toNat) = 0xfd :: b0 :: b1 :: [] := by
  have hb0 : b0.toNat < 256 := by simpa using b0.toNat_lt_size
  have hb1 : b1.toNat < 256 := by simpa using b1.toNat_lt_size
  have hle : b0.toNat + 256 * b1.toNat ≤ 0xffff := by omega
  have hge' : ¬ (b0.toNat + 256 * b1.toNat < 0xfd) := by omega
  simp only [encCSL, if_neg hge', if_pos hle]
  rw [encU16L_of_leNat b0 b1]

theorem encCSL_fe (b0 b1 b2 b3 : UInt8)
    (hge : 0x10000 ≤ b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))) :
    encCSL (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat)))
      = 0xfe :: b0 :: b1 :: b2 :: b3 :: [] := by
  have hb0 : b0.toNat < 256 := by simpa using b0.toNat_lt_size
  have hb1 : b1.toNat < 256 := by simpa using b1.toNat_lt_size
  have hb2 : b2.toNat < 256 := by simpa using b2.toNat_lt_size
  have hb3 : b3.toNat < 256 := by simpa using b3.toNat_lt_size
  have hge0 : ¬ (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat)) < 0xfd) := by
    omega
  have hge1 : ¬ (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat)) ≤ 0xffff) := by
    omega
  have hle : b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat)) ≤ 0xffffffff := by
    omega
  simp only [encCSL, if_neg hge0, if_neg hge1, if_pos hle]
  rw [encU32L_of_leNat b0 b1 b2 b3]

theorem encCSL_ff (b0 b1 b2 b3 b4 b5 b6 b7 : UInt8)
    (hge : 0x100000000 ≤ b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))) :
    encCSL (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat)))))))
      = 0xff :: b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: [] := by
  have hge0 : ¬ (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat)))))) < 0xfd) := by
    omega
  have hge1 : ¬ (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat)))))) ≤ 0xffff) := by
    omega
  have hge2 : ¬ (b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * (b3.toNat +
      256 * (b4.toNat + 256 * (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat)))))) ≤ 0xffffffff) := by
    omega
  simp only [encCSL, if_neg hge0, if_neg hge1, if_neg hge2]
  rw [encU64L_of_leNat b0 b1 b2 b3 b4 b5 b6 b7]

/-- Shape: a successfully decoded CompactSize was canonically encoded
(`decCS` rejects every non-canonical form, TXV-012). -/
theorem decCS_shape (l : Bytes) (n : Nat) (rest : Bytes)
    (h : decCS l = .ok (n, rest)) : l = encCSL n ++ rest := by
  cases l with
  | nil => simp [decCS] at h
  | cons first rest0 =>
    simp only [decCS] at h
    by_cases h1 : first.toNat < 0xfd
    · rw [if_pos h1] at h
      simp only [Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨hn, hrest⟩ := h
      subst hrest
      subst hn
      simp only [encCSL, if_pos h1]
      rw [u8_ofNat_self]
      rfl
    · rw [if_neg h1] at h
      by_cases h2 : first = 0xfd
      · rw [if_pos h2] at h
        cases rest0 with
        | nil => simp at h
        | cons b0 r0 =>
          cases r0 with
          | nil => simp at h
          | cons b1 r0 =>
            simp only [] at h
            by_cases hv : b0.toNat + 256 * b1.toNat < 0xfd
            · rw [if_pos hv] at h
              simp at h
            · rw [if_neg hv] at h
              simp only [Except.ok.injEq, Prod.mk.injEq] at h
              obtain ⟨hn, hrest⟩ := h
              subst hrest
              subst hn
              rw [encCSL_fd b0 b1 (by omega), h2]
              rfl
      · rw [if_neg h2] at h
        by_cases h3 : first = 0xfe
        · rw [if_pos h3] at h
          cases rest0 with
          | nil => simp at h
          | cons b0 r0 =>
            cases r0 with
            | nil => simp at h
            | cons b1 r0 =>
              cases r0 with
              | nil => simp at h
              | cons b2 r0 =>
                cases r0 with
                | nil => simp at h
                | cons b3 r0 =>
                  simp only [] at h
                  by_cases hv : b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))
                      < 0x10000
                  · rw [if_pos hv] at h
                    simp at h
                  · rw [if_neg hv] at h
                    by_cases hmax : MAX_SIZE <
                        b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 * b3.toNat))
                    · rw [if_pos hmax] at h
                      simp at h
                    · rw [if_neg hmax] at h
                      simp only [Except.ok.injEq, Prod.mk.injEq] at h
                      obtain ⟨hn, hrest⟩ := h
                      subst hrest
                      subst hn
                      rw [encCSL_fe b0 b1 b2 b3 (by omega), h3]
                      rfl
        · rw [if_neg h3] at h
          cases rest0 with
          | nil => simp at h
          | cons b0 r0 =>
            cases r0 with
            | nil => simp at h
            | cons b1 r0 =>
              cases r0 with
              | nil => simp at h
              | cons b2 r0 =>
                cases r0 with
                | nil => simp at h
                | cons b3 r0 =>
                  cases r0 with
                  | nil => simp at h
                  | cons b4 r0 =>
                    cases r0 with
                    | nil => simp at h
                    | cons b5 r0 =>
                      cases r0 with
                      | nil => simp at h
                      | cons b6 r0 =>
                        cases r0 with
                        | nil => simp at h
                        | cons b7 r0 =>
                          simp only [] at h
                          by_cases hv : b0.toNat + 256 * (b1.toNat + 256 * (b2.toNat + 256 *
                              (b3.toNat + 256 * (b4.toNat + 256 * (b5.toNat + 256 *
                                (b6.toNat + 256 * b7.toNat)))))) < 0x100000000
                          · rw [if_pos hv] at h
                            simp at h
                          · rw [if_neg hv] at h
                            by_cases hw : MAX_SIZE < b0.toNat + 256 * (b1.toNat + 256 *
                                (b2.toNat + 256 * (b3.toNat + 256 * (b4.toNat + 256 *
                                  (b5.toNat + 256 * (b6.toNat + 256 * b7.toNat))))))
                            · rw [if_pos hw] at h
                              simp at h
                            · rw [if_neg hw] at h
                              exfalso
                              have hM : MAX_SIZE = 33554432 := rfl
                              omega

theorem decBytesL_shape (n : Nat) (l : Bytes) (bs rest : Bytes)
    (h : decBytesL n l = .ok (bs, rest)) : l = bs ++ rest := by
  unfold decBytesL at h
  by_cases hlt : l.length < n
  · rw [if_pos hlt] at h
    simp at h
  · rw [if_neg hlt] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨hbs, hrest⟩ := h
    subst hbs
    subst hrest
    rw [List.take_append_drop]

/-- Inversion: a successful `decBytesL` read exactly `n` bytes. -/
theorem decBytesL_length (n : Nat) (l bs rest : Bytes)
    (h : decBytesL n l = .ok (bs, rest)) : bs.length = n := by
  unfold decBytesL at h
  by_cases hlt : l.length < n
  · rw [if_pos hlt] at h
    simp at h
  · rw [if_neg hlt] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨hbs, -⟩ := h
    subst hbs
    rw [List.length_take]
    omega

theorem decScriptBL_shape (l : Bytes) (b : ByteArray) (rest : Bytes)
    (h : decScriptBL l = .ok (b, rest)) :
    l = encCSL b.size ++ (bL b ++ rest) := by
  unfold decScriptBL at h
  cases hc : decCS l with
  | error => rw [hc] at h; rw [bindE_err] at h; simp at h
  | ok p =>
    obtain ⟨m, l1⟩ := p
    rw [hc] at h
    simp only [bindE_ok] at h
    have scs : l = encCSL m ++ l1 := decCS_shape l m l1 hc
    cases hb : decBytesL m l1 with
    | error => rw [hb] at h; rw [bindE_err] at h; simp at h
    | ok q =>
      obtain ⟨bs, l2⟩ := q
      rw [hb] at h
      simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨hbq, hrest⟩ := h
      subst hrest
      have sbs : l1 = bs ++ l2 := decBytesL_shape m l1 bs l2 hb
      have hlen : bs.length = m := decBytesL_length m l1 bs l2 hb
      have hsize : b.size = bs.length := by
        rw [← hbq]
        simp [bytesOfList]
      rw [scs, sbs, hsize, ← hlen, ← hbq, bL_bytesOfList]

theorem decScriptL_shape (l : Bytes) (s : Script) (rest : Bytes)
    (h : decScriptL l = .ok (s, rest)) :
    l = encCSL s.bytes.size ++ (bL s.bytes ++ rest) := by
  unfold decScriptL at h
  cases hc : decScriptBL l with
  | error => rw [hc] at h; rw [bindE_err] at h; simp at h
  | ok p =>
    obtain ⟨b, l2⟩ := p
    rw [hc] at h
    simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨hs, hrest⟩ := h
    subst hrest
    subst hs
    exact decScriptBL_shape l b l2 hc

theorem decOutPointL_shape (l : Bytes) (o : OutPoint) (rest : Bytes)
    (h : decOutPointL l = .ok (o, rest)) :
    l = bL o.hash ++ (encU32L o.n ++ rest) := by
  unfold decOutPointL at h
  cases hb : decBytesL 32 l with
  | error => rw [hb] at h; rw [bindE_err] at h; simp at h
  | ok p =>
    obtain ⟨bs, l1⟩ := p
    rw [hb] at h
    simp only [bindE_ok] at h
    have s32 : l = bs ++ l1 := decBytesL_shape 32 l bs l1 hb
    cases hn : decU32L l1 with
    | error => rw [hn] at h; rw [bindE_err] at h; simp at h
    | ok q =>
      obtain ⟨u, l2⟩ := q
      rw [hn] at h
      simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨ho, hrest⟩ := h
      subst hrest
      subst ho
      have sU : l1 = encU32L u ++ l2 := decU32L_shape l1 u l2 hn
      rw [s32, sU]
      simp only [bL_bytesOfList]

theorem decTxInL_shape (l : Bytes) (i : TxIn) (rest : Bytes)
    (h : decTxInL l = .ok (i, rest)) :
    l = bL (serTxIn i) ++ rest := by
  unfold decTxInL at h
  cases ho : decOutPointL l with
  | error => rw [ho] at h; rw [bindE_err] at h; simp at h
  | ok p =>
    obtain ⟨o, l1⟩ := p
    rw [ho] at h
    simp only [bindE_ok] at h
    have so := decOutPointL_shape l o l1 ho
    cases hs : decScriptL l1 with
    | error => rw [hs] at h; rw [bindE_err] at h; simp at h
    | ok p =>
      obtain ⟨s, l2⟩ := p
      rw [hs] at h
      simp only [bindE_ok] at h
      have ss := decScriptL_shape l1 s l2 hs
      cases hq : decU32L l2 with
      | error => rw [hq] at h; rw [bindE_err] at h; simp at h
      | ok p =>
        obtain ⟨q, l3⟩ := p
        rw [hq] at h
        simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨hi, hrest⟩ := h
        subst hrest
        subst hi
        have sq := decU32L_shape l2 q l3 hq
        rw [so, ss, sq, bL_serTxIn]
        simp only [List.append_assoc]

/-- Inversion: a successful `decU64L` read a value below `2^64`. -/
theorem decU64L_bound (l : Bytes) (u : Nat) (rest : Bytes)
    (h : decU64L l = .ok (u, rest)) : u < 18446744073709551616 := by
  cases l with
  | nil => simp [decU64L] at h
  | cons b0 l0 =>
    cases l0 with
    | nil => simp [decU64L] at h
    | cons b1 l1 =>
      cases l1 with
      | nil => simp [decU64L] at h
      | cons b2 l2 =>
        cases l2 with
        | nil => simp [decU64L] at h
        | cons b3 l3 =>
          cases l3 with
          | nil => simp [decU64L] at h
          | cons b4 l4 =>
            cases l4 with
            | nil => simp [decU64L] at h
            | cons b5 l5 =>
              cases l5 with
              | nil => simp [decU64L] at h
              | cons b6 l6 =>
                cases l6 with
                | nil => simp [decU64L] at h
                | cons b7 l7 =>
                  simp only [decU64L, Except.ok.injEq, Prod.mk.injEq] at h
                  obtain ⟨hu, -⟩ := h
                  subst hu
                  exact leNat8_lt b0 b1 b2 b3 b4 b5 b6 b7

/-- Wire form of one `TxOut` at the list layer; the value is kept in its
raw two's-complement `UInt64` form so the shape law is unconditional. -/
def encTxOutL (o : TxOut) : Bytes :=
  encU64L (UInt64.ofNat (amtToU64 o.value))
    ++ (encCSL o.scriptPubKey.bytes.size ++ bL o.scriptPubKey.bytes)

theorem encTxOutL_u64ToAmt (u : Nat) (s : Script) (hu : u < 18446744073709551616) :
    encTxOutL { value := u64ToAmt u, scriptPubKey := s }
      = encU64L (UInt64.ofNat u) ++ (encCSL s.bytes.size ++ bL s.bytes) := by
  unfold encTxOutL
  rw [amtToU64_u64ToAmt u hu]

theorem decTxOutL_shape (l : Bytes) (o : TxOut) (rest : Bytes)
    (h : decTxOutL l = .ok (o, rest)) :
    l = encTxOutL o ++ rest := by
  unfold decTxOutL at h
  cases hu : decU64L l with
  | error => rw [hu] at h; rw [bindE_err] at h; simp at h
  | ok p =>
    obtain ⟨u, l1⟩ := p
    rw [hu] at h
    simp only [bindE_ok] at h
    have su : l = encU64L (UInt64.ofNat u) ++ l1 := decU64L_shape l u l1 hu
    cases hsc : decScriptL l1 with
    | error => rw [hsc] at h; rw [bindE_err] at h; simp at h
    | ok q =>
      obtain ⟨s, l2⟩ := q
      rw [hsc] at h
      simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨ho, hrest⟩ := h
      subst hrest
      subst ho
      have ssc := decScriptL_shape l1 s l2 hsc
      rw [su, ssc, encTxOutL_u64ToAmt u s (decU64L_bound l u l1 hu)]
      simp only [List.append_assoc]

theorem flatMap_congr {α β : Type} {f g : α → List β} (l : List α)
    (h : ∀ x ∈ l, f x = g x) : l.flatMap f = l.flatMap g := by
  induction l with
  | nil => rfl
  | cons a l ih =>
    simp only [List.flatMap_cons]
    rw [h a (List.Mem.head _)]
    rw [ih (fun x hx => h x (List.Mem.tail _ hx))]

theorem encTxOutL_eq (o : TxOut) (_hv : 0 ≤ o.value) : encTxOutL o = bL (serTxOut o) := by
  unfold encTxOutL
  rw [bL_serTxOut]
  rfl

theorem decVinL_shape (l : Bytes) (xs : List TxIn) (rest : Bytes)
    (h : decVinL l = .ok (xs, rest)) :
    l = encCSL xs.length ++ (xs.flatMap (fun i => bL (serTxIn i)) ++ rest) := by
  unfold decVinL at h
  cases hc : decCS l with
  | error => rw [hc] at h; rw [bindE_err] at h; simp at h
  | ok p =>
    obtain ⟨m, l1⟩ := p
    rw [hc] at h
    simp only [bindE_ok] at h
    have scs : l = encCSL m ++ l1 := decCS_shape l m l1 hc
    cases hn : decN decTxInL m l1 with
    | error => rw [hn] at h; simp at h
    | ok q =>
      obtain ⟨ys, l2⟩ := q
      rw [hn] at h
      simp only [Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨hxs, hrest⟩ := h
      subst hrest
      rw [hxs] at hn
      obtain ⟨hlen, sN⟩ := decN_shape decTxInL_shape m l1 xs l2 hn
      rw [scs, sN, ← hlen]
      simp only [encN]

theorem decStackL_shape (l : Bytes) (s : List ByteArray) (rest : Bytes)
    (h : decStackL l = .ok (s, rest)) :
    l = encStackL s ++ rest := by
  unfold decStackL at h
  cases hc : decCS l with
  | error => rw [hc] at h; rw [bindE_err] at h; simp at h
  | ok p =>
    obtain ⟨m, l1⟩ := p
    rw [hc] at h
    simp only [bindE_ok] at h
    have scs : l = encCSL m ++ l1 := decCS_shape l m l1 hc
    have Hitem : ∀ (l' : Bytes) (it : ByteArray) (r : Bytes),
        decItemL l' = .ok (it, r) →
        l' = (fun item : ByteArray => encCSL item.size ++ bL item) it ++ r := by
      intro l' it r h'
      show l' = (encCSL it.size ++ bL it) ++ r
      rw [List.append_assoc]
      exact decScriptBL_shape l' it r h'
    cases hn : decN decItemL m l1 with
    | error => rw [hn] at h; simp at h
    | ok q =>
      obtain ⟨ys, l2⟩ := q
      rw [hn] at h
      simp only [Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨hxs, hrest⟩ := h
      subst hrest
      rw [hxs] at hn
      obtain ⟨hlen, sN⟩ := decN_shape Hitem m l1 s l2 hn
      rw [scs, sN, ← hlen]
      simp only [encN, encStackL, List.append_assoc]

/-! ## Inversion for the whole transaction decoder -/

/-- Inversion shape for `decTxCore`: a successful decode consumed exactly the
canonical encoding of its result (output values taken non-negative), leaving
`rest`. -/
theorem decTxCore_shape (l : Bytes) (tx : Tx) (rest : Bytes)
    (h : decTxCore l = .ok (tx, rest))
    (hval : ∀ o ∈ tx.vout, 0 ≤ o.value) :
    l = encTxL tx ++ rest := by
  unfold decTxCore at h
  cases hv : decU32L l with
  | error => rw [hv] at h; simp at h
  | ok p =>
    obtain ⟨v, l1⟩ := p
    rw [hv] at h
    simp only [bindE_ok] at h
    cases hn : decCS l1 with
    | error => rw [hn] at h; simp at h
    | ok q =>
      obtain ⟨n, l2⟩ := q
      rw [hn] at h
      simp only [bindE_ok] at h
      by_cases hn0 : n = 0
      · rw [if_pos hn0] at h
        subst hn0
        cases hf : decU8L l2 with
        | error => rw [hf] at h; simp at h
        | ok r =>
          obtain ⟨flag, l3⟩ := r
          rw [hf] at h
          simp only [bindE_ok] at h

          by_cases hf0 : flag = 0
          · -- marker + zero flag: the empty tx, witness skipped entirely
            rw [if_pos hf0] at h
            subst hf0
            cases ht : decU32L l3 with
            | error => rw [ht] at h; simp at h
            | ok s =>
              obtain ⟨lt, l4⟩ := s
              rw [ht] at h
              simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
              obtain ⟨htx, hrest⟩ := h
              subst hrest
              subst htx
              rw [decU32L_shape l v l1 hv, decCS_shape l1 0 l2 hn, encCSL_zero,
                  decU8L_shape l2 0 l3 hf, decU32L_shape l3 lt l4 ht]
              have hw0 : hasWitness (Tx.mk (UInt32.toInt32 v) [] [] lt []) = false :=
                hasWitness_zero_vin _ _
              have hc0 : ¬ (hasWitness (Tx.mk (UInt32.toInt32 v) [] [] lt []) = true) := by
                intro hh; rw [hw0] at hh; simp at hh
              unfold encTxL
              rw [if_neg hc0, bL_serTx]
              simp only [List.flatMap_nil, List.nil_append, List.append_assoc,
                List.length_nil]
              rfl
          · rw [if_neg hf0] at h
            cases hv2 : decVinL l3 with
            | error => rw [hv2] at h; simp at h
            | ok r =>
              obtain ⟨vin, l4⟩ := r
              rw [hv2] at h
              simp only [bindE_ok] at h

              cases hm : decCS l4 with
              | error => rw [hm] at h; simp at h
              | ok s =>
                obtain ⟨m, l5⟩ := s
                rw [hm] at h
                simp only [bindE_ok] at h

                cases ho : decN decTxOutL m l5 with
                | error => rw [ho] at h; simp at h
                | ok t =>
                  obtain ⟨vout, l6⟩ := t
                  rw [ho] at h
                  simp only [bindE_ok] at h

                  by_cases hpar : flag.toNat % 2 = 1
                  · rw [if_pos hpar] at h
                    cases hwv : decN decStackL vin.length l6 with
                    | error => rw [hwv] at h; simp at h
                    | ok u =>
                      obtain ⟨w, l7⟩ := u
                      rw [hwv] at h
                      simp only [bindE_ok] at h

                      by_cases hall : w.all (fun s : List ByteArray => s.isEmpty) = true
                      · rw [if_pos hall] at h; simp at h
                      · rw [if_neg hall] at h
                        by_cases hf1 : flag = 1
                        · rw [if_neg (show ¬ (flag ≠ 1) from fun hne => hne hf1)] at h
                          subst hf1
                          cases ht : decU32L l7 with
                          | error => rw [ht] at h; simp at h
                          | ok s' =>
                            obtain ⟨lt, l8⟩ := s'
                            rw [ht] at h
                            simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
                            obtain ⟨htx, hrest⟩ := h
                            subst hrest
                            subst htx
                            -- extended (BIP144) form
                            have hf' : w.all (fun s : List ByteArray => s.isEmpty) = false := by
                              cases hb : w.all (fun s : List ByteArray => s.isEmpty) with
                              | false => rfl
                              | true => exact absurd hb hall
                            obtain ⟨stk, hstk, hnstk⟩ := List.all_eq_false.mp hf'
                            have hnstk2 : stk.isEmpty = false := by
                              cases hb2 : stk.isEmpty with
                              | false => rfl
                              | true => exact absurd hb2 hnstk
                            obtain ⟨hlenw, sN_w⟩ :=
                              decN_shape decStackL_shape vin.length l6 w l7 hwv
                            obtain ⟨hleno, sN_o⟩ :=
                              decN_shape decTxOutL_shape m l5 vout l6 ho
                            have sN_w' : l6 = w.flatMap encStackL ++ l7 := sN_w
                            have sN_o' : l5 = vout.flatMap (fun o : TxOut => encTxOutL o) ++ l6 :=
                              sN_o
                            have Hvo : vout.flatMap (fun o : TxOut => encTxOutL o)
                                = vout.flatMap (fun o : TxOut => bL (serTxOut o)) :=
                              flatMap_congr vout (fun o ho => encTxOutL_eq o (hval o ho))
                            have hW : hasWitness (Tx.mk (UInt32.toInt32 v) vin vout lt w) = true :=
                              hasWitness_of_witness_mem_nonempty hlenw stk hstk hnstk2
                            have hwm : (List.range vin.length).map (fun i => w.getD i []) = w := by
                              rw [← hlenw]; exact list_eq_map_getD [] w
                            have e1 : (Tx.mk (UInt32.toInt32 v) vin vout lt w).version.toUInt32
                                = v := rfl
                            have e2 : (Tx.mk (UInt32.toInt32 v) vin vout lt w).vin = vin := rfl
                            have e3 : (Tx.mk (UInt32.toInt32 v) vin vout lt w).vout = vout := rfl
                            have e4 : (Tx.mk (UInt32.toInt32 v) vin vout lt w).locktime = lt :=
                              rfl
                            have e5 : (Tx.mk (UInt32.toInt32 v) vin vout lt w).witness = w :=
                              rfl
                            have henc : encTxL (Tx.mk (UInt32.toInt32 v) vin vout lt w)
                                = encU32L v ++ (0x00 :: 0x01 :: (encCSL vin.length
                                  ++ (vin.flatMap (fun i => bL (serTxIn i))
                                    ++ (encCSL vout.length
                                    ++ (vout.flatMap (fun o => bL (serTxOut o))
                                    ++ (w.flatMap encStackL ++ encU32L lt)))))) := by
                              unfold encTxL
                              rw [if_pos hW, e1, e2, e3, encStacksL_eq, e2, e5, hwm, e4]
                              simp only [List.append_assoc, List.cons_append, List.nil_append]
                            rw [decU32L_shape l v l1 hv, decCS_shape l1 0 l2 hn, encCSL_zero,
                                decU8L_shape l2 1 l3 hf, decVinL_shape l3 vin l4 hv2,
                                decCS_shape l4 m l5 hm, ← hleno, sN_o', Hvo, sN_w',
                                decU32L_shape l7 lt l8 ht, henc]
                            simp only [List.append_assoc, List.cons_append, List.nil_append]
                        · rw [if_pos hf1] at h; simp at h
                  · rw [if_neg hpar] at h
                    by_cases hf1 : flag = 1
                    · rw [if_neg (show ¬ (flag ≠ 1) from fun hne => hne hf1)] at h
                      subst hf1
                      exfalso
                      -- the even-parity branch succeeded only for flag = 1,
                      -- but flag = 1 is odd: this path is unreachable
                      exact absurd (by decide : UInt8.toNat (1:UInt8) % 2 = 1) hpar
                    · rw [if_pos hf1] at h; simp at h
      · rw [if_neg hn0] at h
        cases hv2 : decN decTxInL n l2 with
        | error => rw [hv2] at h; simp at h
        | ok r =>
          obtain ⟨vin, l3⟩ := r
          rw [hv2] at h
          simp only [bindE_ok] at h

          cases hm : decCS l3 with
          | error => rw [hm] at h; simp at h
          | ok s =>
            obtain ⟨m, l4⟩ := s
            rw [hm] at h
            simp only [bindE_ok] at h

            cases ho : decN decTxOutL m l4 with
            | error => rw [ho] at h; simp at h
            | ok t =>
              obtain ⟨vout, l5⟩ := t
              rw [ho] at h
              simp only [bindE_ok] at h

              cases ht : decU32L l5 with
              | error => rw [ht] at h; simp at h
              | ok s' =>
                obtain ⟨lt, l6⟩ := s'
                rw [ht] at h
                simp only [bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
                obtain ⟨htx, hrest⟩ := h
                subst hrest
                subst htx
                -- legacy form, witness = replicate
                obtain ⟨hlenv, sN_v⟩ := decN_shape decTxInL_shape n l2 vin l3 hv2
                obtain ⟨hleno, sN_o⟩ := decN_shape decTxOutL_shape m l4 vout l5 ho
                have sN_v' : l2 = vin.flatMap (fun i : TxIn => bL (serTxIn i)) ++ l3 := sN_v
                have sN_o' : l4 = vout.flatMap (fun o : TxOut => encTxOutL o) ++ l5 := sN_o
                have Hvo : vout.flatMap (fun o : TxOut => encTxOutL o)
                    = vout.flatMap (fun o : TxOut => bL (serTxOut o)) :=
                  flatMap_congr vout (fun o ho => encTxOutL_eq o (hval o ho))
                have hw0 : hasWitness (Tx.mk (UInt32.toInt32 v) vin vout lt
                    (List.replicate vin.length [])) = false :=
                  hasWitness_false_of_all_getD_empty
                    (fun i _ => getD_replicate [] vin.length i)
                have hc0 : ¬ (hasWitness (Tx.mk (UInt32.toInt32 v) vin vout lt
                    (List.replicate vin.length [])) = true) := by
                  intro hh; rw [hw0] at hh; simp at hh
                have e1 : (Tx.mk (UInt32.toInt32 v) vin vout lt
                    (List.replicate vin.length [])).version.toUInt32 = v := rfl
                have e2 : (Tx.mk (UInt32.toInt32 v) vin vout lt
                    (List.replicate vin.length [])).vin = vin := rfl
                have e3 : (Tx.mk (UInt32.toInt32 v) vin vout lt
                    (List.replicate vin.length [])).vout = vout := rfl
                have e4 : (Tx.mk (UInt32.toInt32 v) vin vout lt
                    (List.replicate vin.length [])).locktime = lt := rfl
                rw [decU32L_shape l v l1 hv, decCS_shape l1 n l2 hn, ← hlenv, sN_v',
                    decCS_shape l3 m l4 hm, ← hleno, sN_o', Hvo, decU32L_shape l5 lt l6 ht]
                unfold encTxL
                rw [if_neg hc0, bL_serTx, e1, e2, e3, e4]
                simp only [List.append_assoc, List.cons_append, List.nil_append]

/-! ## Block framing (BLK-001/002) -/

/-- 80-byte header wire form: `nVersion ‖ hashPrevBlock ‖ hashMerkleRoot ‖
nTime ‖ nBits ‖ nNonce` (primitives/block.h CBlockHeader SERIALIZE_METHODS
@c50817f). -/
def encHeaderL (h : Bitcoin.Chain.BlockHeader) : Bytes :=
  encU32L h.version.toUInt32 ++ bL h.hashPrevBlock ++ bL h.hashMerkleRoot
    ++ encU32L h.time ++ encU32L h.bits ++ encU32L h.nonce

/-- Header decoder: six fixed fields, prev/merkle hashes exactly 32 bytes. -/
def decHeaderL (l : Bytes) : Except SerError (Bitcoin.Chain.BlockHeader × Bytes) := do
  let (v, l1) ← decU32L l
  let (hp, l2) ← decBytesL 32 l1
  let (hm, l3) ← decBytesL 32 l2
  let (t, l4) ← decU32L l3
  let (bi, l5) ← decU32L l4
  let (nc, l6) ← decU32L l5
  .ok (⟨UInt32.toInt32 v, bytesOfList hp, bytesOfList hm, t, bi, nc⟩, l6)

theorem decHeaderL_enc (h : Bitcoin.Chain.BlockHeader) (rest : Bytes)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    decHeaderL (encHeaderL h ++ rest) = .ok (h, rest) := by
  simp only [encHeaderL, List.append_assoc, decHeaderL]
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decBytesL_self h.hashPrevBlock _ hp]
  simp only [bindE_ok]
  rw [decBytesL_self h.hashMerkleRoot _ hm]
  simp only [bindE_ok]
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  simp only [bytesOfList_bL]
  rfl

/-- 80-byte block header encode (BLK-001: field order is consensus). -/
def encodeBlockHeader (h : Bitcoin.Chain.BlockHeader) : ByteArray :=
  bytesOfList (encHeaderL h)

/-- 80-byte block header decode (BLK-001); trailing data rejected. -/
def decodeBlockHeader (b : ByteArray) : Except SerError Bitcoin.Chain.BlockHeader := do
  let (h, rest) ← decHeaderL (bL b)
  if rest.isEmpty then .ok h else .error .truncated

/-- **BLK-001**: `decode ∘ encode = id` on block headers with 32-byte hashes. -/
@[rule "BLK-001"]
theorem decodeBlockHeader_encodeBlockHeader (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    decodeBlockHeader (encodeBlockHeader h) = .ok h := by
  unfold decodeBlockHeader encodeBlockHeader
  rw [bL_bytesOfList, ← List.append_nil (encHeaderL h), decHeaderL_enc h [] hp hm]
  simp only [bindE_ok]
  simp

/-- **BLK-001 (field order and fixed size)**: the header wire form is exactly
`nVersion ‖ hashPrevBlock ‖ hashMerkleRoot ‖ nTime ‖ nBits ‖ nNonce` in that
order, and it is 80 bytes when both hashes are 32 bytes. This is the
statement the roundtrip theorem above does not expose. -/
@[rule "BLK-001"]
theorem encodeBlockHeader_fields (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    bL (encodeBlockHeader h) =
        encU32L h.version.toUInt32
          ++ (bL h.hashPrevBlock
          ++ (bL h.hashMerkleRoot
          ++ (encU32L h.time ++ (encU32L h.bits ++ encU32L h.nonce))))
      ∧ (encodeBlockHeader h).size = 80 := by
  constructor
  · simp [encodeBlockHeader, encHeaderL, List.append_assoc]
  · have hb : bL (encodeBlockHeader h) = encHeaderL h := by
      simp [encodeBlockHeader]
    have hlen : (bL (encodeBlockHeader h)).length = (encodeBlockHeader h).size := by
      simp [bL]
    have hp' : (bL h.hashPrevBlock).length = 32 := by simp [bL, hp]
    have hm' : (bL h.hashMerkleRoot).length = 32 := by simp [bL, hm]
    rw [← hlen, hb]
    simp [encHeaderL, encU32L, hp', hm', List.length_append]

/-- Block body wire form: header ‖ varint(txcount) ‖ txs (primitives/block.h
CBlock SERIALIZE_METHODS @c50817f; each tx in its witness-aware form). -/
def encBlockL (h : Bitcoin.Chain.BlockHeader) (txs : List Tx) : Bytes :=
  encHeaderL h ++ encCSL txs.length ++ txs.flatMap encTxL

/-- Block body decode (BLK-002): header, tx count, then that many txs via
`decTxCore` (witness framing handled per-tx). Returns the unconsumed
remainder for `applyBlock`. -/
def decBlockCore (l : Bytes) : Except SerError (Bitcoin.Chain.BlockHeader × List Tx × Bytes) := do
  let (h, l1) ← decHeaderL l
  let (k, l2) ← decCS l1
  let (txs, l3) ← decN decTxCore k l2
  .ok (h, txs, l3)

/-- Block encode: header ‖ varint(txcount) ‖ txs. -/
def encodeBlock (h : Bitcoin.Chain.BlockHeader) (txs : List Tx) : ByteArray :=
  bytesOfList (encBlockL h txs)

/-- Block decode (BLK-002) of a complete byte string; trailing data rejected. -/
def decodeBlock (b : ByteArray) : Except SerError (Bitcoin.Chain.BlockHeader × List Tx) := do
  let (h, txs, rest) ← decBlockCore (bL b)
  if rest.isEmpty then .ok (h, txs) else .error .truncated

/-- **BLK-002**: `decode ∘ encode = id` on blocks whose txs are all in the
wire domain. -/
@[rule "BLK-002"]
theorem decodeBlock_encodeBlock (h : Bitcoin.Chain.BlockHeader) (txs : List Tx)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32)
    (hk : txs.length ≤ MAX_SIZE) (hdom : ∀ t ∈ txs, wireDomain t) :
    decodeBlock (encodeBlock h txs) = .ok (h, txs) := by
  unfold decodeBlock encodeBlock encBlockL
  rw [bL_bytesOfList, ← List.append_nil (encHeaderL h ++ encCSL txs.length
    ++ txs.flatMap encTxL), List.append_assoc, List.append_assoc]
  simp only [decBlockCore, bindE_ok]
  rw [decHeaderL_enc h _ hp hm]
  simp only [bindE_ok]
  rw [decCS_encCSL txs.length hk]
  simp only [bindE_ok]
  rw [decN_enc txs (fun t ht r => decTxCore_encTxL t r (hdom t ht))]
  simp only [bindE_ok]
  simp

/-- **BLK-002 (framing)**: the block wire form is exactly
`header ‖ varint(txcount) ‖ txs`, with the header frame followed by the
canonical CompactSize count and then the transactions; decoding that byte
string consumes the header, the count, and all txs, leaving no remainder.
Unlike the roundtrip theorem above this names the framing and the count. -/
@[rule "BLK-002"]
theorem decodeBlockCore_encodeBlock_framing (h : Bitcoin.Chain.BlockHeader)
    (txs : List Tx) (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32)
    (hk : txs.length ≤ MAX_SIZE) (hdom : ∀ t ∈ txs, wireDomain t) :
    bL (encodeBlock h txs) = encHeaderL h ++ (encCSL txs.length ++ txs.flatMap encTxL)
      ∧ decBlockCore (encBlockL h txs) = .ok (h, txs, []) := by
  constructor
  · simp [encodeBlock, encBlockL, List.append_assoc]
  · unfold encBlockL
    simp only [decBlockCore, bindE_ok]
    rw [List.append_assoc, decHeaderL_enc h _ hp hm]
    simp only [bindE_ok]
    rw [decCS_encCSL txs.length hk]
    simp only [bindE_ok]
    rw [← List.append_nil (txs.flatMap encTxL)]
    rw [decN_enc txs (fun t ht r => decTxCore_encTxL t r (hdom t ht))]
    simp only [bindE_ok]

/-! ## Frozen exit-criterion theorems (T1/T2/T3) -/

/-- **T1 / TXV-011 (SER core law)**: `decode ∘ encode = id` on transactions
in the wire domain. -/
theorem decodeTx_encodeTx (tx : Tx) (h : wireDomain tx) :
    decodeTx (encodeTx tx) = .ok tx := by
  unfold decodeTx encodeTx decTxFull
  rw [bL_bytesOfList, ← List.append_nil (encTxL tx), decTxCore_encTxL tx [] h]
  simp only [bindE_ok]
  simp

/-- **T2**: re-encoding a successfully decoded tx is byte-stable (every
decodable tx decodes from its own canonical encoding; the only non-canonical
but decodable inputs are legacy forms of witness-free txs, which re-encode
to the same base bytes). -/
theorem encodeTx_decodeTx (b : ByteArray) (tx : Tx) (h : decodeTx b = .ok tx)
    (hval : ∀ o ∈ tx.vout, 0 ≤ o.value) :
    encodeTx tx = b := by
  unfold decodeTx decTxFull at h
  cases hc : decTxCore (bL b) with
  | error => rw [hc] at h; simp at h
  | ok p =>
    obtain ⟨tx', rest⟩ := p
    rw [hc] at h
    simp only [bindE_ok] at h
    by_cases rempty : rest.isEmpty = true
    · rw [if_pos rempty, Except.ok.injEq] at h
      have htx : tx' = tx := h
      subst htx
      have hshape := decTxCore_shape (bL b) _ rest hc hval
      have hrest0 : rest = [] := by
        cases rest with
        | nil => rfl
        | cons c cs => simp at rempty
      rw [hrest0, List.append_nil] at hshape
      unfold encodeTx
      rw [← hshape, bytesOfList_bL]
    · rw [if_neg rempty] at h; simp at h

/-- **T3 / TXV-015**: a decoded tx never carries the superfluous-witness
pattern (all-empty stacks under a set flag) — `decodeTx` rejects it instead,
so every decodable tx either has a real witness or is byte-identical to its
no-witness encoding. -/
theorem decodeTx_no_superfluous_witness (b : ByteArray) (tx : Tx)
    (h : decodeTx b = .ok tx) (hval : ∀ o ∈ tx.vout, 0 ≤ o.value) :
    ¬ (tx.witness.all (·.isEmpty) ∧ b ≠ encodeTxNoWitness tx) := by
  have henc := encodeTx_decodeTx b tx h hval
  by_cases hw : hasWitness tx = true
  · rintro ⟨hall, -⟩
    have h0 := hasWitness_false_of_all_empty hall
    rw [hw] at h0
    simp at h0
  · rintro ⟨-, hbne⟩
    have hc : ¬ (hasWitness tx = true) := hw
    refine hbne ?_
    rw [← henc]
    unfold encodeTx encodeTxNoWitness encTxL
    rw [if_neg hc, bytesOfList_bL]

end Bitcoin.Serialization
