import Bitcoin.Wallet.Psbt.Encode

/-!
# PSBT v0 — inversion and lifecycle laws

This module states and proves the parts of the round-trip and lifecycle
story that are cheap, and records the remaining obligations as explicit
propositions (`decodeEncodeTarget`, `encodeDecodeTarget`) with a TODO
list.  Nothing here is assumed: any statement that is not proved is a
`def ... : Prop`, never a `sorry`.

## What is proved

* Inversion of the printable payloads used by the encoder: raw bytes,
  fixed-length values, 32-bit integers, key origins and BIP 32
  derivations, transaction outputs, full transactions (base
  serialization), and witness stacks.
* Map-body framing: `decMapL` returns exactly the entries of
  `encMapL` when every entry can be framed (`MapWireOK`).
* Lifecycle: finalizing an input is idempotent, preserves the UTXO and
  unknown fields, and makes the input signed; extraction returns the
  unsigned transaction with the final scriptSigs/witnesses filled in and
  preserves the unsigned transaction's version, locktime, outputs and
  outpoints.

## What is NOT proved here

The two whole-file round-trip statements are stated as targets.  Their
proof needs, at minimum:

1. `MapWireOK` for every projected map, derived from `Canonical`
   (lengths below `MAX_SIZE`, non-empty keys);
2. injectivity of the key/value framing: `encKVL` must be shown
   injective (both length prefixes and the payloads are fixed by
   `decKV_shape` plus `decCS_encCSL`);
3. duplicate-freedom for sorted maps: `strictlySorted` implies
   `findDuplicate = none` (`src/psbt.h:581-584`);
4. completeness of the typed parsers: every standard field of a
   canonical PSBT is reconstructed exactly, including taproot leaf
   scripts and output tap trees (see `parseTapTree`), and every unknown
   pair is preserved;
5. the structural checks in `decode` accept `encode p` when `p` is
   canonical: empty unsigned scriptSigs, matching input/output counts,
   no v2 field, non-witness UTXO hash/index agreement;
6. that `Canonical` excludes exactly the values the writer drops
   (explicit zero global version, empty scripts, null UTXOs, zero
   x-only keys, empty witness stacks), so decoding re-encodes to the
   same bytes.

`Canonical` is intentionally an *encoder-side* predicate; it does not
try to describe arbitrary byte strings that Core happens to accept.
-/

namespace Bitcoin.Wallet.Psbt

open Bitcoin.Data
open Bitcoin.Serialization

/-! ## Framing of a list of map entries -/

/-- Entries that can be framed and re-read: both byte strings fit a
CompactSize and the key is non-empty, so it cannot be mistaken for the
`0x00` map separator. -/
def MapWireOK (kvs : List RawKV) : Prop :=
  ∀ kv ∈ kvs, kv.1.size ≤ Bitcoin.Serialization.MAX_SIZE
    ∧ kv.2.size ≤ Bitcoin.Serialization.MAX_SIZE
    ∧ !kv.1.isEmpty = true

/-- The canonical CompactSize of any number has positive length. -/
theorem encCSL_length_pos (n : Nat) : 0 < (encCSL n).length := by
  unfold encCSL
  by_cases h1 : n < 0xfd
  · simp [h1]
  · by_cases h2 : n ≤ 0xffff
    · simp [h1, h2]
    · by_cases h3 : n ≤ 0xffffffff
      · simp [h1, h2, h3]
      · simp [h1, h2, h3]

/-- A little-endian 32-bit word occupies four bytes. -/
theorem encU32L_length (x : UInt32) : (encU32L x).length = 4 := by
  simp [encU32L]

/-- One framed entry occupies at least one byte. -/
theorem encKVL_length_pos (kv : RawKV) : 0 < (encKVL kv).length := by
  unfold encKVL
  have := encCSL_length_pos kv.1.size
  simp only [List.length_append]
  omega

/-- A map body is at least as long as its entry count (each entry
contributes a key length and a value length). -/
theorem encMapBodyL_length (kvs : List RawKV) :
    kvs.length ≤ (encMapBodyL kvs).length := by
  induction kvs with
  | nil => simp
  | cons kv rest ih =>
    have h := encKVL_length_pos kv
    simp only [encMapBodyL, List.flatMap_cons, List.length_append, List.length_cons] at ih ⊢
    omega

/-- `decMapL` inverts `encMapL` on framable entries.  This is the
per-map half of `decode ∘ encode = id`. -/
theorem decMapL_encMapL (kvs : List RawKV) (h : MapWireOK kvs) :
    decMapL (encMapL kvs) = .ok (kvs, []) := by
  unfold decMapL encMapL
  rw [List.length_append]
  have hlen : kvs.length + 1 ≤ (encMapBodyL kvs).length + 1 := by
    have := encMapBodyL_length kvs
    omega
  have hgo := decMapGo_encMapBodyL kvs ((encMapBodyL kvs).length + 1) [] hlen h
  simpa using hgo

/-! ## Payload printers and parsers -/

/-- Raw-byte values are their own encoding. -/
theorem parseRaw_enc (field : String) (v : ByteArray) :
    parseRaw field v = .ok v := rfl

/-- Take exactly the bytes that are present: `decBytesL` with the length
supplied by the list itself consumes all of it. -/
theorem decBytesL_len_self (bs : Bytes) :
    decBytesL bs.length bs = .ok (bs, []) := by
  simpa using decBytesL_enc bs bs.length rfl []

/-- A value of exactly `n` bytes is accepted by `expectLen`. -/
theorem expectLen_enc (field : String) (n : Nat) (v : ByteArray) (h : v.size = n) :
    expectLen field n v = .ok v := by
  unfold expectLen
  rw [ite_eq_left h]

/-- A 32-bit little-endian value round-trips. -/
theorem parseU32Value_enc (field : String) (x : UInt32) :
    parseU32Value field (bytesOfList (encU32L x)) = .ok x := by
  unfold parseU32Value
  rw [bL_bytesOfList]
  rw [show encU32L x = encU32L x ++ [] from (List.append_nil _).symm]
  rw [decU32L_encU32L x []]
  simp

/-- A transaction output round-trips when its amount and script are
representable (`CTxOut` wire domain, `src/serialize.h`). -/
theorem parseTxOutValue_enc (o : TxOut) (hv : 0 ≤ o.value)
    (hv2 : o.value < 9223372036854775808)
    (hs : o.scriptPubKey.bytes.size ≤ Bitcoin.Serialization.MAX_SIZE) :
    parseTxOutValue (serTxOut o) = .ok o := by
  unfold parseTxOutValue
  rw [show bL (serTxOut o) = bL (serTxOut o) ++ [] from (List.append_nil _).symm]
  rw [decTxOutL_enc o [] hv hv2 hs]
  simp

/-- A base-serialized transaction round-trips.  The transaction must be
in `wireDomain` and must not carry witness data: the global unsigned
transaction is always written with `TX_NO_WITNESS`
(`src/psbt.h:362-365`). -/
theorem parseTxValue_enc (tx : Tx) (h : wireDomain tx) (hw : hasWitness tx = false) :
    parseTxValue (encodeTxNoWitness tx) = .ok tx := by
  unfold parseTxValue encodeTxNoWitness
  have hdec := decTxCore_encTxL tx [] h
  rw [encTxL, ite_eq_right (by simp [hw])] at hdec
  rw [show bL (serTx tx) = bL (serTx tx) ++ [] from (List.append_nil _).symm]
  rw [hdec]
  simp

/-- A finalized witness stack round-trips. -/
theorem parseStackValue_enc (s : List ByteArray)
    (hc : s.length ≤ Bitcoin.Serialization.MAX_SIZE)
    (hi : ∀ item ∈ s, item.size ≤ Bitcoin.Serialization.MAX_SIZE) :
    parseStackValue (bytesOfList (encStackL s)) = .ok s := by
  unfold parseStackValue
  rw [bL_bytesOfList]
  rw [show encStackL s = encStackL s ++ [] from (List.append_nil _).symm]
  rw [decStackL_enc s [] hc hi]
  simp

/-! ## Key origins and BIP 32 derivations -/

/-- The index-wise reconstruction inside `parseOriginRaw` recovers the
path encoded by `encOriginPayload`. -/
theorem originPath_map (path : List UInt32) :
    (List.range ((path.flatMap encU32L).length / 4)).map
        (fun i => UInt32.ofNat
          (leNat (((path.flatMap encU32L).drop (4 * i)).take 4))) = path := by
  induction path with
  | nil => simp
  | cons a as ih =>
    have hlen : ((a :: as).flatMap encU32L).length
        = 4 + (as.flatMap encU32L).length := by
      simp [List.flatMap, encU32L_length]
    rw [hlen]
    have hdiv : (4 + (as.flatMap encU32L).length) / 4
        = (as.flatMap encU32L).length / 4 + 1 := by omega
    rw [hdiv, List.range_succ_eq_map]
    simp only [List.map_cons]
    rw [List.cons.injEq]
    constructor
    · -- the first index selects the first path element
      have ht : List.take 4 (encU32L a ++ as.flatMap encU32L) = encU32L a := by
        rw [show 4 = (encU32L a).length from (encU32L_length a).symm, List.take_left]
      change UInt32.ofNat
        (leNat (List.take 4 (encU32L a ++ as.flatMap encU32L))) = a
      simp [ht, leNat_encU32L, UInt32.ofNat_toNat]
    · -- index `i+1` selects the same element as index `i` of the tail
      have hstep : ∀ i : Nat,
          List.drop (4 * (i + 1)) (encU32L a ++ as.flatMap encU32L)
            = List.drop (4 * i) (as.flatMap encU32L) := by
        intro i
        rw [show 4 * (i + 1) = 4 + 4 * i by omega]
        rw [List.drop_append]
        have h4 : (encU32L a).length = 4 := encU32L_length a
        rw [h4, List.drop_eq_nil_of_le (by omega)]
        have hidx : 4 + 4 * i - 4 = 4 * i := by omega
        rw [hidx, List.nil_append]
      rw [List.map_map]
      rw [List.map_congr_left (l := List.range ((as.flatMap encU32L).length / 4))
        (f := (fun i => UInt32.ofNat
          (leNat ((((a :: as).flatMap encU32L).drop (4 * i)).take 4))) ∘ Nat.succ)
        (g := fun i => UInt32.ofNat
          (leNat (((as.flatMap encU32L).drop (4 * i)).take 4))) ?_]
      · exact ih
      · intro i _
        simp only [Function.comp_apply]
        change UInt32.ofNat (leNat (List.take 4 (List.drop (4 * (i + 1))
          (encU32L a ++ as.flatMap encU32L)))) =
            UInt32.ofNat (leNat (List.take 4 (List.drop (4 * i)
              (as.flatMap encU32L))))
        rw [hstep i]

/-- A key origin with a 4-byte fingerprint round-trips through the raw
payload printer (`SerializeKeyOrigin`, `src/psbt.h:186-194`). -/
theorem parseOriginRaw_encOriginPayload (field : String) (o : KeyOrigin)
    (hfp : o.fingerprint.size = 4) :
    parseOriginRaw field (encOriginPayload o) = .ok o := by
  have hflen : (bL o.fingerprint).length = 4 := by simp [bL, hfp]
  have hlen : (encOriginPayload o).length = 4 + 4 * o.path.length := by
    unfold encOriginPayload
    rw [List.length_append, hflen, List.length_flatMap]
    simp [encU32L_length, List.map_const', List.sum_replicate_nat]
    omega
  have hpos : 0 < (encOriginPayload o).length := by rw [hlen]; omega
  have hne : (encOriginPayload o).isEmpty = false := by
    cases h : (encOriginPayload o).isEmpty with
    | false => rfl
    | true =>
      have hnil : encOriginPayload o = [] := List.isEmpty_iff.mp h
      rw [hnil] at hpos
      simp at hpos
  unfold parseOriginRaw
  rw [ite_eq_right (by simp [hne]),
      ite_eq_right (by rw [hlen]; omega)]
  dsimp only
  have htake : List.take 4 (encOriginPayload o) = bL o.fingerprint := by
    unfold encOriginPayload
    rw [← hflen, List.take_left]
  have hdrop : List.drop 4 (encOriginPayload o) = o.path.flatMap encU32L := by
    unfold encOriginPayload
    rw [← hflen, List.drop_left]
  rw [htake, hdrop, originPath_map]
  simp [bytesOfList_bL]

/-- A BIP 32 derivation value round-trips
(`SerializeHDKeypath`, `src/psbt.h:196-202`). -/
theorem parseHDKeypath_enc (field : String) (o : KeyOrigin)
    (hfp : o.fingerprint.size = 4) :
    parseHDKeypath field (encHDKeypathValue o) = .ok o := by
  unfold parseHDKeypath encHDKeypathValue
  rw [bL_bytesOfList]
  exact parseOriginRaw_encOriginPayload field o hfp

/-! ## Lifecycle: finalization -/

/-- Finalize one input: install the final scriptSig and witness stack,
and drop the signing material that Core's writer suppresses once an
input is finalized (`src/psbt.h:371-506`).  UTXOs and unknown pairs are
preserved, because Core keeps them (`src/psbt.h:362-369,548-552`). -/
def finalizeInput (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) : PsbtInput :=
  { i with
    partialSigs := []
    sighashType := none
    redeemScript := none
    witnessScript := none
    bip32Derivation := []
    finalScriptSig := if scriptSig.isEmpty then none else some scriptSig
    finalScriptWitness := if witness.isEmpty then none else some witness
    tapKeySig := none
    tapScriptSigs := []
    tapLeafScripts := []
    tapBip32Derivation := []
    tapInternalKey := none
    tapMerkleRoot := none }

/-- Finalization is idempotent. -/
theorem finalizeInput_idempotent (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) :
    finalizeInput (finalizeInput i scriptSig witness) scriptSig witness
      = finalizeInput i scriptSig witness := rfl

/-- Finalization preserves the non-witness UTXO. -/
theorem finalizeInput_nonWitnessUtxo (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) :
    (finalizeInput i scriptSig witness).nonWitnessUtxo = i.nonWitnessUtxo := rfl

/-- Finalization preserves the witness UTXO. -/
theorem finalizeInput_witnessUtxo (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) :
    (finalizeInput i scriptSig witness).witnessUtxo = i.witnessUtxo := rfl

/-- Finalization preserves unknown key-value pairs. -/
theorem finalizeInput_unknown (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) :
    (finalizeInput i scriptSig witness).unknown = i.unknown := rfl

/-- A finalized input with a non-empty final scriptSig or witness stack
is signed (`PSBTInputSigned`, `src/psbt.cpp:547-550`). -/
theorem finalizeInput_signed (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray)
    (h : scriptSig.isEmpty = false ∨ witness.isEmpty = false) :
    inputSigned (finalizeInput i scriptSig witness) = true := by
  rcases h with h | h <;> simp [inputSigned, finalizeInput, h]

/-! ## Lifecycle: extraction -/

/-- `fillTx` changes only the input scriptSigs and the witness stacks. -/
theorem fillTx_version (tx : Tx) (ins : List PsbtInput) :
    (fillTx tx ins).version = tx.version := rfl

/-- `fillTx` preserves the locktime. -/
theorem fillTx_locktime (tx : Tx) (ins : List PsbtInput) :
    (fillTx tx ins).locktime = tx.locktime := rfl

/-- `fillTx` preserves every output. -/
theorem fillTx_vout (tx : Tx) (ins : List PsbtInput) :
    (fillTx tx ins).vout = tx.vout := rfl

/-- When the two lists have the same length, projecting the first
component of a `zipWith` is a plain `map` of that component. -/
theorem zipWith_prevout_eq (as : List TxIn) (bs : List PsbtInput)
    (h : bs.length = as.length) :
    List.zipWith (fun (x : TxIn) (_ : PsbtInput) => x.prevout) as bs
      = List.map (fun i => i.prevout) as := by
  induction as generalizing bs with
  | nil =>
    cases bs with
    | nil => simp
    | cons _ _ => simp at h
  | cons a as ih =>
    cases bs with
    | nil => simp at h
    | cons b bs =>
      simp only [List.length_cons] at h
      simp only [List.zipWith_cons_cons, List.map_cons]
      exact congrArg (List.cons a.prevout) (ih bs (by omega))

/-- Projecting the previous outpoint after `fillTxIn` is the same as
projecting it before: `fillTxIn` only changes `scriptSig`. -/
theorem map_prevout_zipWith_fillTxIn (as : List TxIn) (bs : List PsbtInput) :
    List.map (fun i => i.prevout) (List.zipWith fillTxIn as bs)
      = List.zipWith (fun (x : TxIn) (_ : PsbtInput) => x.prevout) as bs := by
  induction as generalizing bs with
  | nil => cases bs <;> simp
  | cons a as ih =>
    cases bs with
    | nil => simp
    | cons b bs => simp [fillTxIn, ih]

/-- When the input-map list has the unsigned transaction's length,
`fillTx` preserves every outpoint: it only overwrites `scriptSig` and
the witness stack. -/
theorem fillTx_prevouts (tx : Tx) (ins : List PsbtInput)
    (hlen : ins.length = tx.vin.length) :
    (fillTx tx ins).vin.map (fun i => i.prevout)
      = tx.vin.map (fun i => i.prevout) := by
  obtain ⟨version, vin, vout, locktime, witness⟩ := tx
  induction vin generalizing ins with
  | nil =>
    cases ins with
    | nil => simp [fillTx]
    | cons _ _ => simp at hlen
  | cons a as ih =>
    cases ins with
    | nil => simp at hlen
    | cons b bs =>
      simp only [List.length_cons] at hlen
      simp only [fillTx, List.zipWith_cons_cons, List.map_cons, fillTxIn]
      rw [map_prevout_zipWith_fillTxIn]
      exact congrArg (List.cons a.prevout) (zipWith_prevout_eq as bs (by omega))

/-- The output of `extract` is the unsigned transaction with the final
scriptSigs and witness stacks filled in: extraction preserves the
version, locktime and outputs, and (when the map counts agree) every
outpoint.  This is the precise content of "extract = unsigned tx
filled" (`FinalizeAndExtractPSBT`, `src/psbt.cpp:818-836`). -/
theorem extract_preserves_unsigned (p : Psbt) (tx : Tx)
    (h : extract p = some tx)
    (hlen : p.inputs.length = p.global.unsignedTx.vin.length) :
    tx.version = p.global.unsignedTx.version
      ∧ tx.locktime = p.global.unsignedTx.locktime
      ∧ tx.vout = p.global.unsignedTx.vout
      ∧ tx.vin.map (fun i => i.prevout)
          = p.global.unsignedTx.vin.map (fun i => i.prevout) := by
  unfold extract at h
  split at h
  · simp only [Option.some.injEq] at h
    subst h
    exact ⟨rfl, rfl, rfl, fillTx_prevouts _ _ hlen⟩
  · simp at h

/-- Extraction succeeds exactly when every input is signed, and the
result is `fillTx` (`src/psbt.cpp:820-834`). -/
theorem extract_some (p : Psbt) (h : allInputsSigned p = true) :
    extract p = some (fillTx p.global.unsignedTx p.inputs) := by
  unfold extract
  rw [ite_eq_left h]

/-- Extraction fails when some input is not signed. -/
theorem extract_none (p : Psbt) (h : allInputsSigned p = false) :
    extract p = none := by
  unfold extract
  rw [ite_eq_right (by simp [h])]

/-- Extracting after finalizing a single-input PSBT yields exactly the
unsigned transaction with that input's final scriptSig/witness filled
in. -/
theorem extract_single_finalized (tx : Tx) (i : PsbtInput)
    (scriptSig : ByteArray) (witness : List ByteArray)
    (h : scriptSig.isEmpty = false ∨ witness.isEmpty = false) :
    extract ⟨⟨tx, [], []⟩, [finalizeInput i scriptSig witness], []⟩
      = some (fillTx tx [finalizeInput i scriptSig witness]) := by
  apply extract_some
  simp [allInputsSigned, finalizeInput_signed i scriptSig witness h]

/-! ## Whole-file round-trip targets -/

/-- **Target.**  Decoding the canonical encoding of a canonical PSBT
recovers the model exactly. -/
def decodeEncodeTarget : Prop :=
  ∀ p : Psbt, Canonical p → decode (encode p) = .ok p

/-- Byte strings that are the canonical encoding of some canonical
PSBT. -/
def CanonicalBytes (b : ByteArray) : Prop :=
  ∃ p : Psbt, Canonical p ∧ b = encode p

/-- **Target.**  Re-encoding canonical bytes is the identity: `decode`
followed by `encode` loses nothing on the image of `encode`. -/
def encodeDecodeTarget : Prop :=
  ∀ (b : ByteArray) (p : Psbt),
    CanonicalBytes b → decode b = .ok p → encode p = b

/-! ### TODO for the two targets

The following proof obligations are not discharged in this phase; they
are listed here so the gap is explicit rather than hidden in a `sorry`.

* `canonical_mapwire`: `Canonical p` implies `MapWireOK` for
  `globalKVs p.global`, each `inputKVs i`, and each `outputKVs o`.
* `encKVL_injective`: distinct entries with framable sizes have
  distinct encodings (needed to turn `decMapGo_shape` into equality of
  entry lists).
* `strictlySorted_no_dup`: `strictlySorted kvs = true` implies
  `findDuplicate kvs = none`.
* `parse_*_enc` for the remaining value families: taproot leaf scripts,
  output tap trees, taproot BIP 32 derivations, and the preimage maps.
* `check_*`: the structural checks in `decode` (empty unsigned
  scriptSigs, counts, v2 rejection, non-witness UTXO hash/index) hold
  for `encode p` when `p` is `Canonical`.
* `canonical_no_dropped_fields`: `Canonical` rules out exactly the
  fields the writer normalises away (zero global version, empty scripts,
  null UTXOs, zero x-only keys, empty witness stacks), which is what
  makes `encode ∘ decode` the identity on canonical bytes.
-/

end Bitcoin.Wallet.Psbt
