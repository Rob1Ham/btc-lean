import Bitcoin.Wallet.Psbt.Decode
import Bitcoin.Wallet.RuleAttr

/-!
# PSBT v0 — canonical encoding

The encoder emits the byte string that BIP 174 calls canonical: inside
every map the key-value pairs are sorted lexicographically by their raw
key bytes (the key type CompactSize first, then key data), exactly as
Core's `std::map<std::vector<unsigned char>,...>` iteration does for
the `unknown` maps (`src/psbt.h:548-552,1056-1060,1327-1331`) and as BIP 174's
"key-value pairs ... in ascending order" rule requires.

For the standard v0 fields, Core's writer emits the fields in this
ascending order:

* global: `0x00`, `0x01`, [`0xFB` if version > 0], `0xFC`, unknown
  (`src/psbt.h:1271-1344`);
* input: `0x00`, `0x01`, then `0x02`–`0x08`, `0x0A`–`0x0D`, `0x13`–`0x18`,
  `0x1a`–`0x1c`, `0xFC`, unknown (`src/psbt.h:359-555`);
* output: `0x00`, `0x01`, `0x02`, `0x05`–`0x08`, `0xFC`, unknown
  (`src/psbt.h:983-1063`).

Core's output-map writer places `0xFC` before `0x05`–`0x08`
(`src/psbt.h:1009-1013`), and both Core map writers put all standard
fields before the `unknown` map (`src/psbt.h:548-552,1056-1060,
1327-1331`).  A Core-produced map can therefore be out of key order when
it contains proprietary entries or an unknown key type below a standard
type.  This encoder sorts every map by raw key, as BIP 174's canonical
order requires; the byte-identical comparison with Core in
`Bitcoin.Wallet.Psbt.Tests` is restricted to vectors with no proprietary
entries, with unknown key types above all standard types actually present,
and with at most one global xpub.  (Core orders multiple xpubs by key
origin, not by the raw xpub key, `src/psbt.h:1285-1292`.)  `Canonical`
below describes this encoder's key order and the fields Core's writer
drops; it is not a transcription of Core's writer order.

Fields Core omits when empty are omitted here as well, so re-encoding a
canonical PSBT is byte-identical:

* empty scripts (`!redeem_script.empty()`, `src/psbt.h:384-394`);
* an empty final scriptSig / null final witness (`src/psbt.h:508-517`);
* a null witness UTXO / null x-only keys / null merkle root
  (`src/psbt.h:366-369,459-468`);
* an empty taproot key signature and an empty output tap tree
  (`src/psbt.h:423-427,1021-1032`).

## What is NOT modelled

Canonicality is a statement about this model's maps.  It does not claim
that Core would *produce* the same bytes for a PSBT whose fields this
model stores as unknown pairs, and it says nothing about signature,
policy or consensus validity.  See `Bitcoin.Wallet.Psbt.Model` for the
full not-modelled list.
-/

namespace Bitcoin.Wallet.Psbt

open Bitcoin.Data
open Bitcoin.Serialization

/-! ## Byte-level map encoding -/

/-- One map entry: `<keylen CompactSize> <key> <valuelen CompactSize>
<value>`. -/
def encKVL (kv : RawKV) : Bytes :=
  encCSL kv.1.size ++ bL kv.1 ++ encCSL kv.2.size ++ bL kv.2

/-- The body of a map: all entries concatenated. -/
def encMapBodyL (kvs : List RawKV) : Bytes := kvs.flatMap encKVL

/-- A complete map: body followed by the `0x00` separator. -/
def encMapL (kvs : List RawKV) : Bytes := encMapBodyL kvs ++ [separatorByte]

/-! ## Key/value printers -/

/-- Raw (unprefixed) key-origin payload: 4-byte fingerprint then 4-byte
little-endian path indices (`SerializeKeyOrigin`, `src/psbt.h:186-194`). -/
def encOriginPayload (o : KeyOrigin) : Bytes :=
  bL o.fingerprint ++ o.path.flatMap encU32L

/-- A BIP 32 derivation value: the bare origin payload.  The map value
length is the origin length (`SerializeHDKeypath`, `src/psbt.h:196-202`),
so no extra prefix is written here. -/
def encHDKeypathValue (o : KeyOrigin) : ByteArray :=
  bytesOfList (encOriginPayload o)

/-- A taproot BIP 32 derivation value: CompactSize leaf-hash count, the
32-byte hashes, then the raw origin (`src/psbt.h:451-455`). -/
def encTapBip32Value (hashes : List ByteArray) (o : KeyOrigin) : ByteArray :=
  bytesOfList (encCSL hashes.length
    ++ hashes.flatMap bL
    ++ encOriginPayload o)

/-- A taproot leaf-script value: script bytes then the leaf version
(`src/psbt.h:437-444`). -/
def encTapLeafValue (script : ByteArray) (leafVersion : Nat) : ByteArray :=
  script ++ bytesOfList [leafVersion.toUInt8]

/-- An output tap-tree value: repeated `(depth u8, leaf version u8,
CompactSize script length, script)` (`src/psbt.h:1021-1032`). -/
def encTapTreeValue (tree : List (Nat × Nat × ByteArray)) : ByteArray :=
  bytesOfList (tree.flatMap fun (depth, ver, script) =>
    [depth.toUInt8, ver.toUInt8] ++ encCSL script.size ++ bL script)

/-- `CTxOut::IsNull()`: value `-1` and an empty script
(`primitives/transaction.h`). -/
def txOutIsNull (o : TxOut) : Bool :=
  o.value == -1 && o.scriptPubKey.bytes.isEmpty

/-- `XOnlyPubKey::IsNull()` / `uint256::IsNull()`: 32 zero bytes. -/
def isZero32 (b : ByteArray) : Bool :=
  b.size = 32 && (bL b).all (fun x => x == 0)

/-- A single-key entry, or nothing. -/
def kvSingle? (typ : Nat) (v : ByteArray) : List RawKV :=
  [(keyOf typ ByteArray.empty, v)]

/-- A keyed entry. -/
def kvData (typ : Nat) (d : ByteArray) (v : ByteArray) : RawKV :=
  (keyOf typ d, v)

/-- A script-valued entry, omitted when the script is empty
(`src/psbt.h:384-394`). -/
def kvScript (typ : Nat) (s : Option ByteArray) : List RawKV :=
  match s with
  | none => []
  | some b => if b.isEmpty then [] else kvSingle? typ b

/-! ## Map projections -/

/-- The global key-value pairs of a PSBT (before sorting). -/
def globalKVs (g : Global) : List RawKV :=
  (keyOf GLOBAL_UNSIGNED_TX ByteArray.empty, encodeTxNoWitness g.unsignedTx)
  :: ((g.xpubs.map fun x => (keyOf GLOBAL_XPUB x.xpub, encHDKeypathValue x.origin))
      ++ g.unknown)

/-- The key-value pairs of one input map (before sorting). -/
@[walletRule "PSBT-010", walletRule "PSBT-011", walletRule "PSBT-013", walletRule "PSBT-016"]
def inputKVs (i : PsbtInput) : List RawKV :=
  (match i.nonWitnessUtxo with
   | some u => kvSingle? IN_NON_WITNESS_UTXO (encodeTxNoWitness u)
   | none => [])
  ++ (match i.witnessUtxo with
      | some o => if txOutIsNull o then [] else kvSingle? IN_WITNESS_UTXO (serTxOut o)
      | none => [])
  ++ i.partialSigs.map (fun (pk, sig) => kvData IN_PARTIAL_SIG pk sig)
  ++ (match i.sighashType with
      | some s => kvSingle? IN_SIGHASH (bytesOfList (encU32L s))
      | none => [])
  ++ kvScript IN_REDEEMSCRIPT i.redeemScript
  ++ kvScript IN_WITNESSSCRIPT i.witnessScript
  ++ i.bip32Derivation.map (fun (pk, o) => kvData IN_BIP32_DERIVATION pk (encHDKeypathValue o))
  ++ kvScript IN_SCRIPTSIG i.finalScriptSig
  ++ (match i.finalScriptWitness with
      | some ws => if ws.isEmpty then [] else kvSingle? IN_SCRIPTWITNESS (bytesOfList (encStackL ws))
      | none => [])
  ++ i.ripemd160Preimages.map (fun (h, p) => kvData IN_RIPEMD160 h p)
  ++ i.sha256Preimages.map (fun (h, p) => kvData IN_SHA256 h p)
  ++ i.hash160Preimages.map (fun (h, p) => kvData IN_HASH160 h p)
  ++ i.hash256Preimages.map (fun (h, p) => kvData IN_HASH256 h p)
  ++ (match i.tapKeySig with
      | some s => if s.isEmpty then [] else kvSingle? IN_TAP_KEY_SIG s
      | none => [])
  ++ i.tapScriptSigs.map (fun e =>
      kvData IN_TAP_SCRIPT_SIG (e.xonly ++ e.leafHash) e.signature)
  ++ i.tapLeafScripts.map (fun e =>
      kvData IN_TAP_LEAF_SCRIPT e.controlBlock (encTapLeafValue e.script e.leafVersion))
  ++ i.tapBip32Derivation.map (fun e =>
      kvData IN_TAP_BIP32_DERIVATION e.xonly (encTapBip32Value e.leafHashes e.origin))
  ++ (match i.tapInternalKey with
      | some k => if isZero32 k then [] else kvSingle? IN_TAP_INTERNAL_KEY k
      | none => [])
  ++ (match i.tapMerkleRoot with
      | some r => if isZero32 r then [] else kvSingle? IN_TAP_MERKLE_ROOT r
      | none => [])
  ++ i.unknown

/-- The key-value pairs of one output map (before sorting). -/
def outputKVs (o : PsbtOutput) : List RawKV :=
  kvScript OUT_REDEEMSCRIPT o.redeemScript
  ++ kvScript OUT_WITNESSSCRIPT o.witnessScript
  ++ o.bip32Derivation.map (fun (pk, ko) => kvData OUT_BIP32_DERIVATION pk (encHDKeypathValue ko))
  ++ (match o.tapInternalKey with
      | some k => if isZero32 k then [] else kvSingle? OUT_TAP_INTERNAL_KEY k
      | none => [])
  ++ (match o.tapTree with
      | [] => []
      | t => kvSingle? OUT_TAP_TREE (encTapTreeValue t))
  ++ o.tapBip32Derivation.map (fun e =>
      kvData OUT_TAP_BIP32_DERIVATION e.xonly (encTapBip32Value e.leafHashes e.origin))
  ++ o.unknown

/-! ## Sorting -/

/-- Lexicographic comparison of two raw keys (Core's
`std::vector<unsigned char>::operator<`). -/
def bytesLt : List UInt8 → List UInt8 → Bool
  | [], [] => false
  | [], _ => true
  | _, [] => false
  | a :: as, b :: bs =>
    if a < b then true else if b < a then false else bytesLt as bs

/-- Insert `kv` into a key-sorted list, keeping the order stable. -/
def insertKV (kv : RawKV) : List RawKV → List RawKV
  | [] => [kv]
  | x :: xs => if bytesLt (bL kv.1) (bL x.1) then kv :: x :: xs else x :: insertKV kv xs

/-- Insertion sort by raw key. -/
def sortKVs (kvs : List RawKV) : List RawKV := kvs.foldr insertKV []

/-- Adjacent keys are strictly increasing. -/
def strictlySorted : List RawKV → Bool
  | [] => true
  | [_] => true
  | a :: b :: rest => bytesLt (bL a.1) (bL b.1) && strictlySorted (b :: rest)

/-- Sizes representable by a CompactSize at the map layer. -/
def kvSizesOk (kvs : List RawKV) : Bool :=
  kvs.all fun kv => kv.1.size ≤ Bitcoin.Serialization.MAX_SIZE && kv.2.size ≤ Bitcoin.Serialization.MAX_SIZE && !kv.1.isEmpty

/-- A map is canonical when every key/value length fits a CompactSize,
keys are non-empty and strictly ascending. -/
def canonicalMap (kvs : List RawKV) : Bool :=
  kvSizesOk kvs && strictlySorted kvs

/-- Non-empty script option. -/
def scriptCanonical (s : Option ByteArray) : Bool :=
  match s with
  | none => true
  | some b => !b.isEmpty

/-- Canonical optional x-only key / merkle root: absent or non-zero. -/
def key32Canonical (s : Option ByteArray) : Bool :=
  match s with
  | none => true
  | some b => b.size = 32 && !isZero32 b

/-- Canonical optional witness stack: absent or non-empty. -/
def stackCanonical (s : Option (List ByteArray)) : Bool :=
  match s with
  | none => true
  | some ws => !ws.isEmpty

/-- Canonical optional transaction: absent or witness-free (Core writes
`TX_NO_WITNESS` for the non-witness UTXO, `src/psbt.h:362-365`). -/
def txCanonical (s : Option Tx) : Bool :=
  match s with
  | none => true
  | some tx => !hasWitness tx

/-- Canonical optional UTXO: absent or not `CTxOut::IsNull()`. -/
def utxoCanonical (s : Option TxOut) : Bool :=
  match s with
  | none => true
  | some o => !txOutIsNull o

/-- Input canonicality beyond map ordering. -/
def inputCanonical (i : PsbtInput) : Bool :=
  scriptCanonical i.redeemScript && scriptCanonical i.witnessScript
  && scriptCanonical i.finalScriptSig && stackCanonical i.finalScriptWitness
  && key32Canonical i.tapInternalKey && key32Canonical i.tapMerkleRoot
  && txCanonical i.nonWitnessUtxo && utxoCanonical i.witnessUtxo
  && canonicalMap (inputKVs i)

/-- Output canonicality beyond map ordering. -/
def outputCanonical (o : PsbtOutput) : Bool :=
  scriptCanonical o.redeemScript && scriptCanonical o.witnessScript
  && key32Canonical o.tapInternalKey && canonicalMap (outputKVs o)

/-- The canonical predicate: well formed, every map key-sorted, and no
field present that Core's writer would drop.  This is the domain of
`encode ∘ decode = id`. -/
def canonicalB (p : Psbt) : Bool :=
  wellFormedB p && canonicalMap (globalKVs p.global)
  && p.inputs.all inputCanonical && p.outputs.all outputCanonical

/-- `Canonical p` is the propositional form of `canonicalB p`. -/
def Canonical (p : Psbt) : Prop := canonicalB p = true

/-! ## Whole-file encoder -/

/-- Canonical PSBT bytes: magic, the sorted global map, the sorted input
maps in unsigned-tx order, the sorted output maps in unsigned-tx order. -/
def encode (p : Psbt) : ByteArray :=
  bytesOfList (magicBytes
    ++ encMapL (sortKVs (globalKVs p.global))
    ++ p.inputs.flatMap (fun i => encMapL (sortKVs (inputKVs i)))
    ++ p.outputs.flatMap (fun o => encMapL (sortKVs (outputKVs o))))

/-! ## Framing laws -/

/-- `decKV` inverts `encKVL` when both lengths fit a CompactSize. -/
theorem decKV_encKVL (kv : RawKV) (rest : Bytes)
    (hk : kv.1.size ≤ Bitcoin.Serialization.MAX_SIZE) (hv : kv.2.size ≤ Bitcoin.Serialization.MAX_SIZE) :
    decKV (encKVL kv ++ rest) = .ok (kv, rest) := by
  simp only [encKVL, List.append_assoc]
  unfold decKV decCsP decBytesP
  rw [decCS_encCSL _ hk]
  simp only [bindE_ok]
  rw [decBytesL_enc (bL kv.1) kv.1.size (by simp [bL])]
  simp only [bindE_ok, bytesOfList_bL]
  rw [decCS_encCSL _ hv]
  simp only [bindE_ok]
  rw [decBytesL_enc (bL kv.2) kv.2.size (by simp [bL])]
  simp only [bindE_ok, bytesOfList_bL]

/-- For `n > 0`, the canonical CompactSize starts with a non-zero byte. -/
theorem encCSL_head_ne_zero {n : Nat} (h : 0 < n) :
    ∃ b bs, encCSL n = b :: bs ∧ b ≠ 0 := by
  unfold encCSL
  by_cases h1 : n < 0xfd
  · refine ⟨n.toUInt8, [], by simp [h1], ?_⟩
    intro hb
    have : n.toUInt8.toNat = 0 := by rw [hb]; rfl
    have h2 : n.toUInt8.toNat = n := by
      rw [show n.toUInt8.toNat = n % 256 from rfl, Nat.mod_eq_of_lt (by omega)]
    omega
  · by_cases h2 : n ≤ 0xffff
    · exact ⟨0xfd, encU16L n.toUInt16, by simp [h1, h2], by decide⟩
    · by_cases h3 : n ≤ 0xffffffff
      · exact ⟨0xfe, encU32L n.toUInt32, by simp [h1, h2, h3], by decide⟩
      · exact ⟨0xff, encU64L n.toUInt64, by simp [h1, h2, h3], by decide⟩

/-- A non-empty key encodes to a non-zero first byte, so a map parser
cannot mistake an entry for the separator. -/
theorem encKVL_head_ne_zero (kv : RawKV) (h : !kv.1.isEmpty = true) :
    ∃ b rest, encKVL kv = b :: rest ∧ b ≠ 0 := by
  have hpos : 0 < kv.1.size := by
    have h2 : kv.1.isEmpty = false := by simpa using h
    by_cases hp : 0 < kv.1.size
    · exact hp
    · have h0 : kv.1.size = 0 := by omega
      rw [ByteArray.size_eq_zero_iff] at h0
      rw [h0] at h2
      simp [ByteArray.isEmpty] at h2
  obtain ⟨b, bs, hcs, hb0⟩ := encCSL_head_ne_zero hpos
  refine ⟨b, bs ++ bL kv.1 ++ encCSL kv.2.size ++ bL kv.2, ?_, hb0⟩
  unfold encKVL
  rw [hcs]
  simp [List.append_assoc]

/-- `decMapGo` inverts map body plus separator, with enough fuel. -/
theorem decMapGo_encMapBodyL (kvs : List RawKV) :
    ∀ (fuel : Nat) (rest : Bytes), kvs.length + 1 ≤ fuel →
      (∀ kv ∈ kvs, kv.1.size ≤ Bitcoin.Serialization.MAX_SIZE
        ∧ kv.2.size ≤ Bitcoin.Serialization.MAX_SIZE ∧ !kv.1.isEmpty = true) →
      decMapGo fuel (encMapBodyL kvs ++ [separatorByte] ++ rest)
        = .ok (kvs, rest) := by
  induction kvs with
  | nil =>
    intro fuel rest hf _
    cases fuel with
    | zero => omega
    | succ f =>
      simp only [encMapBodyL, List.flatMap_nil, List.nil_append]
      change decMapGo (f + 1) ((0 : UInt8) :: rest) = .ok ([], rest)
      rw [decMapGo.eq_3]
  | cons kv kvs ih =>
    intro fuel rest hf hgood
    obtain ⟨hk, hv, hne⟩ := hgood kv (by simp)
    have hgood' : ∀ x ∈ kvs, x.1.size ≤ Bitcoin.Serialization.MAX_SIZE
        ∧ x.2.size ≤ Bitcoin.Serialization.MAX_SIZE ∧ !x.1.isEmpty = true :=
      fun x hx => hgood x (List.mem_cons_of_mem _ hx)
    cases fuel with
    | zero => omega
    | succ f =>
      have hf' : kvs.length + 1 ≤ f := by
        simp only [List.length_cons] at hf
        omega
      obtain ⟨b, rest', hshape, hb0⟩ := encKVL_head_ne_zero kv hne
      let X : Bytes := encMapBodyL (kv :: kvs) ++ [separatorByte] ++ rest
      have hX : X = encKVL kv ++ (encMapBodyL kvs ++ [separatorByte] ++ rest) := by
        simp only [X, encMapBodyL, List.flatMap_cons, List.append_assoc]
      have hne0 : X ≠ [] := by
        rw [hX, hshape]
        simp
      have hn0 : ∀ r, X = 0 :: r → False := by
        intro r hr
        rw [hX, hshape] at hr
        simp only [List.cons_append] at hr
        injection hr with hb _
        exact hb0 hb
      rw [decMapGo.eq_4 X f hne0 hn0]
      rw [hX, decKV_encKVL kv (encMapBodyL kvs ++ [separatorByte] ++ rest) hk hv]
      simp only [bindE_ok]
      rw [ih f rest hf' hgood']
      simp only [bindE_ok]


/-- Inversion shape for `decKV`: a successful parse consumed exactly its
canonical encoding. -/
theorem decKV_shape (l : Bytes) (kv : RawKV) (rest : Bytes)
    (h : decKV l = .ok (kv, rest)) : l = encKVL kv ++ rest := by
  unfold decKV at h
  cases hc : decCS l with
  | error e => simp [decCsP, hc] at h
  | ok p =>
    obtain ⟨klen, l1⟩ := p
    simp only [decCsP, hc, bindE_ok] at h
    cases hb : decBytesL klen l1 with
    | error e => simp [decBytesP, hb] at h
    | ok q =>
      obtain ⟨kb, l2⟩ := q
      simp only [decBytesP, hb, bindE_ok] at h
      cases hc2 : decCS l2 with
      | error e => simp [hc2] at h
      | ok p2 =>
        obtain ⟨vlen, l3⟩ := p2
        simp only [hc2, bindE_ok] at h
        cases hb2 : decBytesL vlen l3 with
        | error e => simp [hb2] at h
        | ok q2 =>
          obtain ⟨vb, l4⟩ := q2
          simp only [hb2, bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨hkv, hrest⟩ := h
          subst hrest
          subst hkv
          have s1 := decCS_shape l klen l1 hc
          have s2 := decBytesL_shape klen l1 kb l2 hb
          have s3 := decCS_shape l2 vlen l3 hc2
          have s4 := decBytesL_shape vlen l3 vb l4 hb2
          have hklen : klen = kb.length := (decBytesL_length klen l1 kb l2 hb).symm
          have hvlen : vlen = vb.length := (decBytesL_length vlen l3 vb l4 hb2).symm
          unfold encKVL
          have hbk : (bytesOfList kb).data.toList = kb := by
            simpa [bL] using bL_bytesOfList kb
          have hbv : (bytesOfList vb).data.toList = vb := by
            simpa [bL] using bL_bytesOfList vb
          have hszk : (bytesOfList kb).size = kb.length := by
            simp [bytesOfList, List.size_toByteArray]
          have hszv : (bytesOfList vb).size = vb.length := by
            simp [bytesOfList, List.size_toByteArray]
          simp only [bL]
          rw [s1, s2, s3, s4, hklen, hvlen, hbk, hbv, hszk, hszv]
          simp only [List.append_assoc]


/-- Inversion shape for `decMapGo`: a successful parse of a map re-encodes
to the input prefix, with the separator reinserted. -/
theorem decMapGo_shape : ∀ (fuel : Nat) (l : Bytes) (kvs : List RawKV) (rest : Bytes),
    decMapGo fuel l = .ok (kvs, rest) →
    l = encMapBodyL kvs ++ separatorByte :: rest := by
  intro fuel
  induction fuel with
  | zero =>
    intro l kvs rest h
    rw [decMapGo.eq_1] at h
    simp at h
  | succ f ih =>
    intro l kvs rest h
    cases l with
    | nil =>
      rw [decMapGo.eq_2] at h
      simp at h
    | cons b bs =>
      by_cases hb : b = 0
      · subst hb
        rw [decMapGo.eq_3] at h
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        simp [encMapBodyL, separatorByte]
      · have hne : (b :: bs) ≠ [] := by simp
        have hn0 : ∀ r, (b :: bs) = 0 :: r → False := by
          intro r hr
          injection hr with h0 _
          exact hb h0
        rw [decMapGo.eq_4 _ _ hne hn0] at h
        cases hd : decKV (b :: bs) with
        | error e => rw [hd] at h; simp at h
        | ok p =>
          obtain ⟨kv, l1⟩ := p
          rw [hd] at h
          simp only [bindE_ok] at h
          cases hm : decMapGo f l1 with
          | error e => rw [hm] at h; simp at h
          | ok q =>
            obtain ⟨kvs', rest'⟩ := q
            simp only [hm, bindE_ok, Except.ok.injEq, Prod.mk.injEq] at h
            obtain ⟨rfl, rfl⟩ := h
            rw [decKV_shape _ _ _ hd, ih l1 kvs' rest' hm]
            simp only [encMapBodyL, List.flatMap_cons, List.append_assoc]


/-- Inversion shape for `decMapL`. -/
theorem decMapL_shape (l : Bytes) (kvs : List RawKV) (rest : Bytes)
    (h : decMapL l = .ok (kvs, rest)) :
    l = encMapL kvs ++ rest := by
  unfold decMapL at h
  rw [decMapGo_shape l.length l kvs rest h]
  simp [encMapL, List.append_assoc]

end Bitcoin.Wallet.Psbt
