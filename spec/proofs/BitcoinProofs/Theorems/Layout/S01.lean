/-
# BitcoinProofs.Theorems.Layout.S01 — byte-exact tx wire-layout offsets

VERIFIED (theorem + python3 cross-check): every `L*`/`S*` theorem below is a
byte-exact field-offset statement over the byte list `bL (encodeTx tx)` of the
frozen ByteArray encoder `Bitcoin.Serialization.encodeTx`: slicing bytes
`[o, o+n)` out of the encoding yields exactly the claimed field bytes.

Ground truth (Core @ cce32b168):
* `primitives/transaction.h:279` `CTransaction` fields; `SerializeTransaction`
  writes version (4B LE), then — TX_NO_WITNESS — vin count (CompactSize),
  per-input `COutPoint` (32B hash ‖ 4B LE `n`), CompactSize-prefixed
  `scriptSig`, 4B LE sequence; vout count; per-output 8B LE `nValue` +
  CompactSize-prefixed `scriptPubKey`; 4B LE locktime.
* BIP144 extended format: marker `0x00` + flag `0x01` after version, witness
  stacks (CompactSize item count, each item CompactSize-length-prefixed)
  after vout, locktime last.
* Wire model: `serTx`/`serTxIn`/`serTxOut` (Bitcoin.Data.Tx:86-99),
  `encTxL`/`encStacksL` (Bitcoin.Serialization.Interface:1016,882).

Cross-check: scratch/S01/crosscheck.py re-encodes a concrete 1-in-1-out tx
with and without witness via python3 `struct.pack` and asserts each offset
claim at the stated byte positions.

AXIOMS: see scratch/S01/axioms.out (`#print axioms` — no sorryAx). All 17
theorems sorry-free.
-/

import Bitcoin.Serialization.Interface

namespace BitcoinProofs.Layout

open Bitcoin.Serialization Bitcoin.Data

/-! ### Slicing helpers -/

private theorem encU32L_len (x : UInt32) : (encU32L x).length = 4 := rfl
private theorem encU64L_len (x : UInt64) : (encU64L x).length = 8 := rfl

private theorem take_app_eq {α : Type} {a b : List α} {n : Nat} (h : a.length = n) :
    (a ++ b).take n = a := by
  simp [h]

private theorem drop_app_eq {α : Type} {a b : List α} {n : Nat} (h : a.length = n) :
    (a ++ b).drop n = b := by
  simp [h]

private theorem drop2_take {α : Type} {a b e : List α} {k n1 n2 : Nat}
    (ha : a.length = n1) (hb : b.length = n2) :
    ((a ++ (b ++ e)).drop (n1 + n2)).take k = e.take k := by
  subst ha; subst hb
  rw [← List.drop_drop, drop_app_eq rfl, drop_app_eq rfl]

private theorem drop3_take {α : Type} {a b c e : List α} {k n1 n2 n3 : Nat}
    (ha : a.length = n1) (hb : b.length = n2) (hc : c.length = n3) :
    ((a ++ (b ++ (c ++ e))).drop (n1 + n2 + n3)).take k = e.take k := by
  subst ha; subst hb; subst hc
  simp only [Nat.add_assoc]
  rw [← List.drop_drop, drop_app_eq rfl, ← List.drop_drop, drop_app_eq rfl,
    drop_app_eq rfl]

private theorem drop4_take {α : Type} {a b c d e : List α} {k n1 n2 n3 n4 : Nat}
    (ha : a.length = n1) (hb : b.length = n2) (hc : c.length = n3) (hd : d.length = n4) :
    ((a ++ (b ++ (c ++ (d ++ e)))).drop (n1 + n2 + n3 + n4)).take k = e.take k := by
  subst ha; subst hb; subst hc; subst hd
  simp only [Nat.add_assoc]
  rw [← List.drop_drop, drop_app_eq rfl, ← List.drop_drop, drop_app_eq rfl,
    ← List.drop_drop, drop_app_eq rfl, drop_app_eq rfl]

private theorem drop5_take {α : Type} {a b c d e f : List α} {k n1 n2 n3 n4 n5 : Nat}
    (ha : a.length = n1) (hb : b.length = n2) (hc : c.length = n3) (hd : d.length = n4)
    (he : e.length = n5) :
    ((a ++ (b ++ (c ++ (d ++ (e ++ f))))).drop (n1 + n2 + n3 + n4 + n5)).take k
      = f.take k := by
  subst ha; subst hb; subst hc; subst hd; subst he
  simp only [Nat.add_assoc]
  rw [← List.drop_drop, drop_app_eq rfl, ← List.drop_drop, drop_app_eq rfl,
    ← List.drop_drop, drop_app_eq rfl, ← List.drop_drop, drop_app_eq rfl,
    drop_app_eq rfl]

private theorem drop6_take {α : Type} {a b c d e f g : List α}
    {k n1 n2 n3 n4 n5 n6 : Nat}
    (ha : a.length = n1) (hb : b.length = n2) (hc : c.length = n3) (hd : d.length = n4)
    (he : e.length = n5) (hf : f.length = n6) :
    ((a ++ (b ++ (c ++ (d ++ (e ++ (f ++ g)))))).drop
        (n1 + n2 + n3 + n4 + n5 + n6)).take k
      = g.take k := by
  subst ha; subst hb; subst hc; subst hd; subst he; subst hf
  simp only [Nat.add_assoc]
  rw [← List.drop_drop, drop_app_eq rfl, ← List.drop_drop, drop_app_eq rfl,
    ← List.drop_drop, drop_app_eq rfl, ← List.drop_drop, drop_app_eq rfl,
    ← List.drop_drop, drop_app_eq rfl, drop_app_eq rfl]

/-- Right-associated per-input layout (`bL_serTxIn` re-associated). -/
private theorem bL_serTxIn' (i : TxIn) :
    bL (serTxIn i) =
      bL i.prevout.hash ++
        (encU32L i.prevout.n ++
          (encCSL i.scriptSig.bytes.size ++
            (bL i.scriptSig.bytes ++ encU32L i.sequence))) := by
  rw [bL_serTxIn]
  simp [List.append_assoc]

/-- Right-associated per-output layout (`bL_serTxOut` re-associated). -/
private theorem bL_serTxOut' (o : TxOut) :
    bL (serTxOut o) =
      encU64L (UInt64.ofNat (amtToU64 o.value)) ++
        (encCSL o.scriptPubKey.bytes.size ++ bL o.scriptPubKey.bytes) := by
  rw [bL_serTxOut]
  simp [List.append_assoc]

/-! ### The base serialization, split by field -/

/-- S1 — Byte list of the base (TX_NO_WITNESS) encoding, fully split by
field: version ‖ cs(vin.count) ‖ flat(vin) ‖ cs(vout.count) ‖ flat(vout) ‖
locktime. -/
theorem encodeTx_base_split (tx : Tx) (h : hasWitness tx = false) :
    bL (encodeTx tx) =
      encU32L tx.version.toUInt32 ++
        (encCSL tx.vin.length ++
          (tx.vin.flatMap (fun i => bL (serTxIn i)) ++
            (encCSL tx.vout.length ++
              (tx.vout.flatMap (fun o => bL (serTxOut o)) ++ encU32L tx.locktime)))) := by
  rw [encodeTx, bL_bytesOfList, encTxL, h]
  simp only [Bool.false_eq_true, ite_false]
  simp only [serTx, bL_append, bL_serU32, bL_compactSizeEnc, bL_foldl_append,
    List.append_assoc, bL_empty, List.nil_append]

/-- L1 — Version: bytes `[0, 4)` of the base encoding are the 4-byte
little-endian version. -/
theorem version_prefix (tx : Tx) (h : hasWitness tx = false) :
    (bL (encodeTx tx)).take 4 = encU32L tx.version.toUInt32 := by
  rw [encodeTx_base_split tx h]
  apply take_app_eq
  exact encU32L_len _

/-- L2 — Version low byte: byte 0 of the base encoding is `version`
truncated to `UInt8` (little-endian: low byte first). -/
theorem version_byte0 (tx : Tx) (h : hasWitness tx = false) :
    ((bL (encodeTx tx)).take 4)[0]? = some tx.version.toUInt32.toUInt8 := by
  rw [version_prefix tx h]
  simp [encU32L]

/-- L3 — vin count: bytes `[4, 4 + |cs(vin.count)|)` are exactly the
CompactSize encoding of the input count. -/
theorem vinCount_prefix (tx : Tx) (h : hasWitness tx = false) :
    ((bL (encodeTx tx)).drop 4).take (encCSL tx.vin.length).length
      = encCSL tx.vin.length := by
  rw [encodeTx_base_split tx h, drop_app_eq (encU32L_len _)]
  apply take_app_eq
  rfl

/-- L4 — vin count, small case: for `< 0xfd` inputs the count field is the
single byte `vin.count` at offset 4. -/
theorem vinCount_byte_small (tx : Tx) (h : hasWitness tx = false)
    (hc : tx.vin.length < 0xfd) :
    ((bL (encodeTx tx)).drop 4).take 1 = [tx.vin.length.toUInt8] := by
  rw [encodeTx_base_split tx h, drop_app_eq (encU32L_len _)]
  have hB : (encCSL tx.vin.length).length = 1 := by simp [encCSL, hc]
  rw [take_app_eq hB]
  simp [encCSL, hc]

/-- L5 — vin region: bytes `[4 + |cs(vin.count)|, 4 + |cs(vin.count)| +
|flat(vin)|)` are exactly the concatenated per-input encodings. -/
theorem vinRegion_prefix (tx : Tx) (h : hasWitness tx = false) :
    ((bL (encodeTx tx)).drop (4 + (encCSL tx.vin.length).length)).take
        (tx.vin.flatMap (fun i => bL (serTxIn i))).length
      = tx.vin.flatMap (fun i => bL (serTxIn i)) := by
  rw [encodeTx_base_split tx h,
    drop2_take (encU32L_len _)
      (rfl : (encCSL tx.vin.length).length = (encCSL tx.vin.length).length)]
  apply take_app_eq
  rfl

/-- L6 — per-input: bytes `[32, 36)` of `serTxIn i` are the outpoint index
`n`, little-endian (the 32-byte prevout hash occupies `[0, 32)`). -/
theorem txIn_prevoutN_slice (i : TxIn) (hh : i.prevout.hash.size = 32) :
    ((bL (serTxIn i)).drop 32).take 4 = encU32L i.prevout.n := by
  rw [bL_serTxIn', drop_app_eq (show (bL i.prevout.hash).length = 32 from hh)]
  apply take_app_eq
  exact encU32L_len _

/-- L7 — per-input: bytes `[36, 36 + |cs(scriptSig)|)` of `serTxIn i` are
the CompactSize scriptSig prefix (the scriptSig body follows at
`36 + |cs(scriptSig)|`). -/
theorem txIn_scriptSig_prefix (i : TxIn) (hh : i.prevout.hash.size = 32) :
    ((bL (serTxIn i)).drop 36).take (encCSL i.scriptSig.bytes.size).length
      = encCSL i.scriptSig.bytes.size := by
  rw [bL_serTxIn', ← List.drop_drop (j := 32) (i := 4),
    drop_app_eq (show (bL i.prevout.hash).length = 32 from hh),
    drop_app_eq (encU32L_len _)]
  apply take_app_eq
  rfl

/-- L8 — per-output: bytes `[0, 8)` of `serTxOut o` are the 8-byte
little-endian value. -/
theorem txOut_value_slice (o : TxOut) :
    (bL (serTxOut o)).take 8 = encU64L (UInt64.ofNat (amtToU64 o.value)) := by
  rw [bL_serTxOut']
  apply take_app_eq
  exact encU64L_len _

/-- L9 — per-output: bytes `[8, 8 + |cs(spk)|)` of `serTxOut o` are the
CompactSize scriptPubKey prefix. -/
theorem txOut_scriptPubKey_prefix (o : TxOut) :
    ((bL (serTxOut o)).drop 8).take (encCSL o.scriptPubKey.bytes.size).length
      = encCSL o.scriptPubKey.bytes.size := by
  rw [bL_serTxOut', drop_app_eq (encU64L_len _)]
  apply take_app_eq
  rfl

/-! ### Transaction-level offsets (first input / first output / locktime) -/

/-- L10 — first outpoint hash: with a single-byte vin count, bytes
`[5, 37)` of the base encoding are the 32-byte prevout hash of input 0. -/
theorem firstPrevoutHash_slice (tx : Tx) (h : hasWitness tx = false)
    (i : TxIn) (is : List TxIn) (his : tx.vin = i :: is)
    (hh : i.prevout.hash.size = 32) :
    ((bL (encodeTx tx)).drop (4 + (encCSL tx.vin.length).length)).take 32
      = bL i.prevout.hash := by
  rw [encodeTx_base_split tx h,
    drop2_take (encU32L_len _)
      (rfl : (encCSL tx.vin.length).length = (encCSL tx.vin.length).length),
    his, List.flatMap_cons, bL_serTxIn']
  simp only [List.append_assoc]
  apply take_app_eq
  exact hh

/-- L11 — first scriptSig prefix: with a single-byte vin count, bytes
`[41, 41 + |cs(scriptSig₀)|)` of the base encoding are the CompactSize
prefix of input 0's scriptSig. -/
theorem firstScriptSig_prefix (tx : Tx) (h : hasWitness tx = false)
    (i : TxIn) (is : List TxIn) (his : tx.vin = i :: is)
    (hh : i.prevout.hash.size = 32) :
    ((bL (encodeTx tx)).drop (4 + (encCSL tx.vin.length).length + 36)).take
        (encCSL i.scriptSig.bytes.size).length
      = encCSL i.scriptSig.bytes.size := by
  rw [encodeTx_base_split tx h, his, List.flatMap_cons, bL_serTxIn']
  simp only [List.append_assoc]
  have h36 : 4 + (encCSL (i :: is).length).length + 32 + 4
      = 4 + (encCSL (i :: is).length).length + 36 := by omega
  rw [h36, drop4_take (encU32L_len _)
    (rfl : (encCSL (i :: is).length).length = (encCSL (i :: is).length).length)
    (show (bL i.prevout.hash).length = 32 from hh) (encU32L_len _)]
  apply take_app_eq
  rfl

/-- L12 — first output value: bytes `[4 + |cs(vin.count)| + |flat(vin)| +
|cs(vout.count)|, … + 8)` of the base encoding are the 8-byte
little-endian value of output 0. -/
theorem firstTxOutValue_slice (tx : Tx) (h : hasWitness tx = false)
    (o : TxOut) (os : List TxOut) (hos : tx.vout = o :: os) :
    ((bL (encodeTx tx)).drop (4 + (encCSL tx.vin.length).length
        + (tx.vin.flatMap (fun i => bL (serTxIn i))).length
        + (encCSL tx.vout.length).length)).take 8
      = encU64L (UInt64.ofNat (amtToU64 o.value)) := by
  rw [encodeTx_base_split tx h,
    drop4_take (encU32L_len _)
      (rfl : (encCSL tx.vin.length).length = (encCSL tx.vin.length).length)
      rfl rfl, hos, List.flatMap_cons, bL_serTxOut']
  simp only [List.append_assoc]
  apply take_app_eq
  exact encU64L_len _

/-- L13 — locktime: bytes `[4 + |cs(vin.count)| + |flat(vin)| +
|cs(vout.count)| + |flat(vout)|, … + 4)` — the trailing 4 bytes of the
base encoding — are the little-endian locktime. -/
theorem locktime_slice (tx : Tx) (h : hasWitness tx = false) :
    ((bL (encodeTx tx)).drop (4 + (encCSL tx.vin.length).length
        + (tx.vin.flatMap (fun i => bL (serTxIn i))).length
        + (encCSL tx.vout.length).length
        + (tx.vout.flatMap (fun o => bL (serTxOut o))).length)).take 4
      = encU32L tx.locktime := by
  rw [encodeTx_base_split tx h,
    drop5_take (encU32L_len _)
      (rfl : (encCSL tx.vin.length).length = (encCSL tx.vin.length).length)
      rfl rfl rfl]
  rfl

/-! ### SegWit framing (BIP144 extended format) -/

/-- S2 — extended-format split: when the tx has a witness, the byte list is
version ‖ [marker, flag] ‖ cs(vin.count) ‖ flat(vin) ‖ cs(vout.count) ‖
flat(vout) ‖ witness stacks ‖ locktime. -/
theorem encodeTx_ext_split (tx : Tx) (h : hasWitness tx = true) :
    bL (encodeTx tx) =
      encU32L tx.version.toUInt32 ++
        ([0x00, 0x01] ++
          (encCSL tx.vin.length ++
            (tx.vin.flatMap (fun i => bL (serTxIn i)) ++
              (encCSL tx.vout.length ++
                (tx.vout.flatMap (fun o => bL (serTxOut o)) ++
                  (encStacksL tx ++ encU32L tx.locktime)))))) := by
  rw [encodeTx, bL_bytesOfList, encTxL, if_pos h]
  simp only [List.append_assoc, serTx, bL_append, bL_serU32, bL_compactSizeEnc,
    bL_foldl_append, bL_empty, List.nil_append]

/-- L14 — SegWit marker/flag: when the tx has a witness, bytes `[4, 6)` of
the encoding are exactly the marker `0x00` and flag `0x01`. -/
theorem segwitMarkerFlag_slice (tx : Tx) (h : hasWitness tx = true) :
    ((bL (encodeTx tx)).drop 4).take 2 = [0x00, 0x01] := by
  rw [encodeTx_ext_split tx h, drop_app_eq (encU32L_len _)]
  apply take_app_eq
  rfl

/-- L15 — SegWit witness region: in the extended format, bytes
`[6 + |cs(vin.count)| + |flat(vin)| + |cs(vout.count)| + |flat(vout)|,
… + |witness|)` are exactly `encStacksL tx` (CompactSize-prefixed stacks,
one per input), with the locktime trailing. -/
theorem witnessRegion_slice (tx : Tx) (h : hasWitness tx = true) :
    ((bL (encodeTx tx)).drop (4 + 2 + (encCSL tx.vin.length).length
        + (tx.vin.flatMap (fun i => bL (serTxIn i))).length
        + (encCSL tx.vout.length).length
        + (tx.vout.flatMap (fun o => bL (serTxOut o))).length)).take
        (encStacksL tx).length
      = encStacksL tx := by
  rw [encodeTx_ext_split tx h,
    show 4 + 2 + (encCSL tx.vin.length).length
        + (tx.vin.flatMap (fun i => bL (serTxIn i))).length
        + (encCSL tx.vout.length).length
        + (tx.vout.flatMap (fun o => bL (serTxOut o))).length
      = 4 + ([0x00, 0x01] : Bytes).length + (encCSL tx.vin.length).length
        + (tx.vin.flatMap (fun i => bL (serTxIn i))).length
        + (encCSL tx.vout.length).length
        + (tx.vout.flatMap (fun o => bL (serTxOut o))).length from by simp,
    drop6_take (encU32L_len _) rfl rfl rfl rfl rfl]
  apply take_app_eq
  rfl

end BitcoinProofs.Layout
