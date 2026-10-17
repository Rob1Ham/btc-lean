import Bitcoin.Wallet.Psbt.Model
import Bitcoin.Wallet.RuleAttr

/-!
# PSBT v0 — decoding

A byte-level decoder for the version-0 PSBT maps modelled in
`Bitcoin.Wallet.Psbt.Model`.  The framing follows Core's
`PartiallySignedTransaction::Unserialize` (`src/psbt.h:1347-1612`),
`PSBTInput::Unserialize` (`src/psbt.h:558-935`) and
`PSBTOutput::Unserialize` (`src/psbt.h:1066-1235`):

* each map is a sequence of `<keylen CompactSize> <key bytes>
  <valuelen CompactSize> <value bytes>` entries terminated by a single
  `0x00` separator (`src/psbt.h:568-584,914-923`);
* duplicate raw keys are rejected (`src/psbt.h:581-584`, and the same
  in both map decoders);
* key-type decoding uses the same canonical CompactSize rules as
  `ReadCompactSize` (non-minimal forms and values above `MAX_SIZE`
  rejected, `src/serialize.h`);
* the global map is followed by exactly `vin.size()` input maps and
  `vout.size()` output maps (`src/psbt.h:1561-1611`);
* trailing bytes after the last map are an error
  (`DecodeRawPSBT`, `src/psbt.cpp:876-878`).

Errors are separate constructors so callers can distinguish a
truncation, an over-long CompactSize, a non-canonical CompactSize, a
duplicate key, a bad key/value size, an unsupported v2 field, a
trailing byte, and a malformed value.

## What is NOT modelled

The decoder deliberately does **not** perform Core's cryptographic
checks (`CPubKey::IsFullyValid`, DER signature encoding) nor signature
verification; those are listed in the model docstring.  It does perform
the structural checks Core performs during unserialization and the
non-witness-UTXO/outpoint consistency check (`src/psbt.h:1571-1589`).
-/

namespace Bitcoin.Wallet.Psbt

open Bitcoin.Data
open Bitcoin.Serialization
open Bitcoin.Crypto.Seam.Hash (sha256d)

/-- Decoding failures.  `truncated` means the byte string ended inside a
field; `missingSeparator` means a map ended without its `0x00`
terminator (`src/psbt.h:921-923`); `trailingBytes` means data remained
after the last expected map (`src/psbt.cpp:876-878`). -/
inductive PsbtError where
  /-- The five magic bytes are not `psbt\xff` (`src/psbt.h:1349-1352`). -/
  | badMagic
  /-- Input ended inside a length prefix, key, value or map. -/
  | truncated
  /-- A map ended without the `0x00` separator. -/
  | missingSeparator
  /-- Bytes remained after the last output map. -/
  | trailingBytes
  /-- A CompactSize was encoded non-minimally (TXV-012 analogue). -/
  | nonCanonicalCompactSize
  /-- A CompactSize exceeded `MAX_SIZE` (`src/serialize.h:35`). -/
  | compactSizeTooLong
  /-- A CompactSize prefix had an unexpected form. -/
  | badCompactSize
  /-- The same raw key occurred twice in one map. -/
  | duplicateKey (key : ByteArray)
  /-- A key did not start with a decodable CompactSize key type. -/
  | badKeyEncoding (key : ByteArray)
  /-- A key had the wrong length for its type. -/
  | badKeySize (field : String) (expected : Nat) (actual : Nat)
  /-- A key data field had a length outside the accepted set. -/
  | badKeyDataSize (field : String) (actual : Nat)
  /-- A value was malformed (inner framing, length constraints, ...). -/
  | malformedValue (field : String) (reason : String)
  /-- The global unsigned transaction was missing (`src/psbt.h:1515-1519`). -/
  | missingUnsignedTx
  /-- The unsigned transaction carried non-empty scriptSigs
  (`src/psbt.h:1400-1405`). -/
  | unsignedTxHasScriptSig (index : Nat)
  /-- A PSBT version other than 0 was requested (`src/psbt.h:1537-1555`). -/
  | unsupportedVersion (version : Nat)
  /-- A PSBT v2 key type appeared in a v0 file (`src/psbt.h:1520-1535`). -/
  | v2FieldInV0 (typ : Nat)
  /-- The non-witness UTXO txid differs from the input's prevout. -/
  | nonWitnessUtxoHashMismatch (index : Nat)
  /-- The non-witness UTXO has no output at the input's prevout index. -/
  | nonWitnessUtxoIndexOutOfRange (index : Nat)
deriving Repr, DecidableEq

/-- Map a serialization-layer CompactSize error into a PSBT error,
keeping the three failure classes distinct. -/
def ofSerError : SerError → PsbtError
  | .truncated => .truncated
  | .compactSizeNonMinimal => .nonCanonicalCompactSize
  | .compactSizeTooLong => .compactSizeTooLong
  | _ => .badCompactSize

/-- CompactSize decode at the PSBT layer. -/
def decCsP (l : Bytes) : Except PsbtError (Nat × Bytes) :=
  match decCS l with
  | .ok p => .ok p
  | .error e => .error (ofSerError e)

/-- Take exactly `n` bytes at the PSBT layer. -/
def decBytesP (n : Nat) (l : Bytes) : Except PsbtError (Bytes × Bytes) :=
  match decBytesL n l with
  | .ok p => .ok p
  | .error e => .error (ofSerError e)

/-- One map entry: key length, key, value length, value
(`src/psbt.h:568-583,914-916`). -/
def decKV (l : Bytes) : Except PsbtError (RawKV × Bytes) := do
  let (klen, l1) ← decCsP l
  let (kb, l2) ← decBytesP klen l1
  let (vlen, l3) ← decCsP l2
  let (vb, l4) ← decBytesP vlen l3
  .ok ((bytesOfList kb, bytesOfList vb), l4)

/-- Fuel-driven map parser.  A key of length zero *is* the separator
(`src/psbt.h:574-579`); every entry consumes at least two bytes, so the
input length is a sufficient fuel for `decMapL`. -/
def decMapGo : Nat → Bytes → Except PsbtError (List RawKV × Bytes)
  | 0, _ => .error .missingSeparator
  | _ + 1, [] => .error .missingSeparator
  | _ + 1, (0x00 : UInt8) :: rest => .ok ([], rest)
  | fuel + 1, l => do
    let (kv, l1) ← decKV l
    let (kvs, l2) ← decMapGo fuel l1
    .ok (kv :: kvs, l2)

/-- Parse a map body up to and including the `0x00` separator, with the
input length as fuel. -/
def decMapL (l : Bytes) : Except PsbtError (List RawKV × Bytes) :=
  decMapGo l.length l

/-- First raw key that occurs twice, if any. -/
def findDuplicate : List RawKV → Option ByteArray
  | [] => none
  | (k, _) :: rest =>
    if rest.any (fun kv => kv.1 == k) then some k else findDuplicate rest

/-- Split a raw key into its CompactSize key type and the remaining key
data, exactly as `ReadCompactSize(skey)` does in Core
(`src/psbt.h:586-589`). -/
def typeAndData (k : ByteArray) : Option (Nat × ByteArray) :=
  match decCS (bL k) with
  | .ok (t, rest) => some (t, bytesOfList rest)
  | .error _ => none

/-- Every key must start with a decodable CompactSize type. -/
def checkKeyEncoding : List RawKV → Except PsbtError Unit
  | [] => .ok ()
  | kv :: rest =>
    match typeAndData kv.1 with
    | some _ => checkKeyEncoding rest
    | none => .error (.badKeyEncoding kv.1)

/-- Parse a map, reject duplicate keys and malformed key encodings. -/
def decMapChecked (l : Bytes) : Except PsbtError (List RawKV × Bytes) := do
  let (kvs, rest) ← decMapL l
  checkKeyEncoding kvs
  match findDuplicate kvs with
  | some k => .error (.duplicateKey k)
  | none => .ok (kvs, rest)

/-- All entries whose key type equals `typ`, as `(key data, value)` in
wire order.  Duplicate raw keys have already been excluded. -/
def entriesOfType (typ : Nat) (kvs : List RawKV) : List (ByteArray × ByteArray) :=
  kvs.filterMap fun kv =>
    match typeAndData kv.1 with
    | some (t, d) => if t = typ then some (d, kv.2) else none
    | none => none

/-- Name of a single-key field type, if `t` is one of `fields`. -/
def singleFieldName (fields : List (Nat × String)) (t : Nat) : Option String :=
  (fields.find? fun p => p.1 = t).map (fun p => p.2)

/-- Core's `ExpectedKeySize(..., 1)` for single-key fields: the key data
must be empty (`src/psbt.h:595-604,630-647,653-663,783-792,849-858` for
inputs and `src/psbt.h:1102-1112,1139-1147` for outputs).  Enforcing it
here also prevents an invalid single-key entry from silently disappearing
into the model. -/
def checkSingleKeyData (fields : List (Nat × String)) : List RawKV → Except PsbtError Unit
  | [] => .ok ()
  | kv :: rest =>
    match typeAndData kv.1 with
    | none => checkSingleKeyData fields rest
    | some (t, d) =>
      match singleFieldName fields t with
      | none => checkSingleKeyData fields rest
      | some name =>
        if d.isEmpty then checkSingleKeyData fields rest
        else .error (.badKeySize name 0 d.size)

/-- The value of the (at most one) entry of type `typ`. -/
def valueOfType (typ : Nat) (kvs : List RawKV) : Option ByteArray :=
  (entriesOfType typ kvs).head?.map (·.2)

/-- Key data of the (at most one) entry of type `typ`. -/
def keyDataOfType (typ : Nat) (kvs : List RawKV) : Option ByteArray :=
  (entriesOfType typ kvs).head?.map (·.1)

/-! ## Small value parsers -/

/-- A value that must be exactly `n` bytes. -/
def expectLen (field : String) (n : Nat) (v : ByteArray) : Except PsbtError ByteArray :=
  if v.size = n then .ok v else .error (.badKeyDataSize field v.size)

/-- A value parser with no internal framing: the raw bytes are the value. -/
def parseRaw (_field : String) (v : ByteArray) : Except PsbtError ByteArray := .ok v

/-- Parse one little-endian 32-bit value (sighash type, `int` in Core,
`src/psbt.h:630-635`). -/
def parseU32Value (field : String) (v : ByteArray) : Except PsbtError UInt32 := do
  let (x, rest) ← match decU32L (bL v) with
    | .ok p => .ok p
    | .error e => .error (ofSerError e)
  if rest.isEmpty then .ok x else .error (.malformedValue field "trailing bytes")

/-- Parse a `CTxOut` value (`UnserializeFromVector(s, witness_utxo)`,
`src/psbt.h:601-604`). -/
def parseTxOutValue (v : ByteArray) : Except PsbtError TxOut := do
  let (o, rest) ← match decTxOutL (bL v) with
    | .ok p => .ok p
    | .error e => .error (ofSerError e)
  if rest.isEmpty then .ok o else .error (.malformedValue "witness utxo" "trailing bytes")

/-- Parse a transaction value.  Core accepts the witness-aware
serialization here (`TX_WITH_WITNESS`, `src/psbt.h:594-599`) but writes
it back without witness; the canonical predicate in
`Bitcoin.Wallet.Psbt.Encode` therefore excludes witness-bearing values. -/
def parseTxValue (v : ByteArray) : Except PsbtError Tx := do
  let (tx, rest) ← match decTxCore (bL v) with
    | .ok p => .ok p
    | .error e => .error (ofSerError e)
  if rest.isEmpty then .ok tx else .error (.malformedValue "transaction" "trailing bytes")

/-- Parse a final witness stack: CompactSize item count followed by
CompactSize-prefixed items (`CScriptWitness::stack`,
`src/psbt.h:659-663`). -/
def parseStackValue (v : ByteArray) : Except PsbtError (List ByteArray) := do
  let (ws, rest) ← match decStackL (bL v) with
    | .ok p => .ok p
    | .error e => .error (ofSerError e)
  if rest.isEmpty then .ok ws else .error (.malformedValue "script witness" "trailing bytes")

/-- Parse a key origin from exactly the bytes given (no length prefix).
Core requires the length to be a non-zero multiple of four
(`DeserializeKeyOrigin`, `src/psbt.h:139-156`). -/
def parseOriginRaw (field : String) (l : Bytes) : Except PsbtError KeyOrigin :=
  if l.isEmpty then .error (.malformedValue field "empty key origin")
  else if l.length % 4 ≠ 0 then
    .error (.malformedValue field "key origin length is not a multiple of 4")
  else
    let fp := bytesOfList (l.take 4)
    let rest := l.drop 4
    let path : List UInt32 :=
      (List.range (rest.length / 4)).map fun i =>
        UInt32.ofNat (leNat ((rest.drop (4 * i)).take 4))
    .ok ⟨fp, path⟩

/-- Parse a BIP 32 derivation value: the bare key origin.  Core's
`SerializeHDKeypath` writes the origin length and then the origin
(`src/psbt.h:196-202`); that length is the map value length, so the
stored value has no second prefix. -/
def parseHDKeypath (field : String) (v : ByteArray) : Except PsbtError KeyOrigin :=
  parseOriginRaw field (bL v)

/-- Parse a taproot BIP 32 derivation value: CompactSize count, that many
32-byte leaf hashes, then a raw key origin (`src/psbt.h:830-847`). -/
def parseTapBip32Value (v : ByteArray) : Except PsbtError (List ByteArray × KeyOrigin) := do
  let (n, l1) ← decCsP (bL v)
  let rec hashes : Nat → Bytes → Except PsbtError (List ByteArray × Bytes)
    | 0, l => .ok ([], l)
    | k + 1, l => do
      let (h, l1) ← decBytesP 32 l
      let (hs, l2) ← hashes k l1
      .ok (bytesOfList h :: hs, l2)
  let (hs, l2) ← hashes n l1
  let origin ← parseOriginRaw "taproot bip32 derivation" l2
  .ok (hs, origin)

/-! ## Typed map parsers -/

/-- `PSBT_GLOBAL_VERSION` must be absent or zero for a v0 file; Core
rejects versions above `PSBT_HIGHEST_VERSION = 2` and has no version 1
(`src/psbt.h:1476-1485,1537-1540,1557-1559`). -/
@[walletRule "PSBT-007"]
def checkGlobalVersion (kvs : List RawKV) : Except PsbtError Unit :=
  match valueOfType GLOBAL_VERSION kvs with
  | none => .ok ()
  | some v =>
    match parseU32Value "global version" v with
    | .ok 0 => .ok ()
    | .ok n => .error (.unsupportedVersion n.toNat)
    | .error e => .error e

/-- Reject the v2 global fields in a v0 file (`src/psbt.h:1520-1535`). -/
@[walletRule "PSBT-006"]
def rejectGlobalV2 : List RawKV → Except PsbtError Unit
  | [] => .ok ()
  | kv :: rest =>
    match typeAndData kv.1 with
    | some (t, _) =>
      if t = GLOBAL_TX_VERSION || t = GLOBAL_FALLBACK_LOCKTIME
         || t = GLOBAL_INPUT_COUNT || t = GLOBAL_OUTPUT_COUNT
         || t = GLOBAL_TX_MODIFIABLE then
        .error (.v2FieldInV0 t)
      else rejectGlobalV2 rest
    | none => .ok ()

/-- Is `t` a global type this model interprets (as opposed to preserving
as an unknown pair)?  `PSBT_GLOBAL_VERSION` is interpreted only to
accept zero and is not re-emitted, matching Core's writer
(`src/psbt.h:1315-1319`). -/
def isKnownGlobalType (t : Nat) : Bool :=
  t = GLOBAL_UNSIGNED_TX || t = GLOBAL_XPUB || t = GLOBAL_VERSION

/-- Parse the global map. -/
@[walletRule "PSBT-004"]
def parseGlobal (kvs : List RawKV) : Except PsbtError Global := do
  rejectGlobalV2 kvs
  checkSingleKeyData
    [(GLOBAL_UNSIGNED_TX, "global unsigned tx"),
     (GLOBAL_VERSION, "global version")] kvs
  checkGlobalVersion kvs
  let txV ← match valueOfType GLOBAL_UNSIGNED_TX kvs with
    | none => .error .missingUnsignedTx
    | some v => .ok v
  let tx ← parseTxValue txV
  if hasWitness tx then
    .error (.malformedValue "unsigned transaction" "unsigned transaction must not carry witness data")
  else
    let rec checkSigs : Nat → List TxIn → Except PsbtError Unit
      | _, [] => .ok ()
      | k, ti :: rest =>
        if ti.scriptSig.bytes.isEmpty then checkSigs (k + 1) rest
        else .error (.unsignedTxHasScriptSig k)
    checkSigs 0 tx.vin
    let rec xpubs : List (ByteArray × ByteArray) → Except PsbtError (List XpubEntry)
      | [] => .ok []
      | (d, v) :: rest => do
        if d.size = 78 then
          let origin ← parseHDKeypath "global xpub" v
          let more ← xpubs rest
          .ok (⟨d, origin⟩ :: more)
        else .error (.badKeyDataSize "global xpub" d.size)
    let xs ← xpubs (entriesOfType GLOBAL_XPUB kvs)
    let unknown := kvs.filter fun kv =>
      match typeAndData kv.1 with
      | some (t, _) => !isKnownGlobalType t
      | none => false
    .ok { unsignedTx := tx, xpubs := xs, unknown := unknown }

/-- Reject v2 input fields in a v0 file (`src/psbt.h:725-781`). -/
def rejectInputV2 : List RawKV → Except PsbtError Unit
  | [] => .ok ()
  | kv :: rest =>
    match typeAndData kv.1 with
    | some (t, _) =>
      if t = 0x0e || t = 0x0f || t = 0x10 || t = 0x11 || t = 0x12 then
        .error (.v2FieldInV0 t)
      else rejectInputV2 rest
    | none => .ok ()

/-- Input types this model interprets.  Proprietary (`0xFC`) and MuSig2
(`0x1a`–`0x1c`) are intentionally excluded and preserved as unknown. -/
def isKnownInputType (t : Nat) : Bool :=
  t = IN_NON_WITNESS_UTXO || t = IN_WITNESS_UTXO || t = IN_PARTIAL_SIG
  || t = IN_SIGHASH || t = IN_REDEEMSCRIPT || t = IN_WITNESSSCRIPT
  || t = IN_BIP32_DERIVATION || t = IN_SCRIPTSIG || t = IN_SCRIPTWITNESS
  || t = IN_RIPEMD160 || t = IN_SHA256 || t = IN_HASH160 || t = IN_HASH256
  || t = IN_TAP_KEY_SIG || t = IN_TAP_SCRIPT_SIG || t = IN_TAP_LEAF_SCRIPT
  || t = IN_TAP_BIP32_DERIVATION || t = IN_TAP_INTERNAL_KEY
  || t = IN_TAP_MERKLE_ROOT

/-- Parse a single-key optional value. -/
def parseOptOfType (typ : Nat) (kvs : List RawKV)
    (f : ByteArray → Except PsbtError α) : Except PsbtError (Option α) :=
  match valueOfType typ kvs with
  | none => .ok none
  | some v => do
    let a ← f v
    .ok (some a)

/-- Parse all entries of one type via `f keydata value`, preserving wire
order. -/
def parseAllOfType (typ : Nat) (kvs : List RawKV)
    (f : ByteArray → ByteArray → Except PsbtError α) : Except PsbtError (List α) :=
  let rec go : List (ByteArray × ByteArray) → Except PsbtError (List α)
    | [] => .ok []
    | (d, v) :: rest => do
      let a ← f d v
      let more ← go rest
      .ok (a :: more)
  go (entriesOfType typ kvs)

/-- Parse an input map. -/
def parseInput (kvs : List RawKV) : Except PsbtError PsbtInput := do
  rejectInputV2 kvs
  checkSingleKeyData
    [(IN_NON_WITNESS_UTXO, "input non-witness utxo"),
     (IN_WITNESS_UTXO, "input witness utxo"),
     (IN_SIGHASH, "input sighash type"),
     (IN_REDEEMSCRIPT, "input redeem script"),
     (IN_WITNESSSCRIPT, "input witness script"),
     (IN_SCRIPTSIG, "input final scriptSig"),
     (IN_SCRIPTWITNESS, "input final scriptWitness"),
     (IN_TAP_KEY_SIG, "input taproot key signature"),
     (IN_TAP_INTERNAL_KEY, "input taproot internal key"),
     (IN_TAP_MERKLE_ROOT, "input taproot merkle root")] kvs
  let nonWitnessUtxo ← parseOptOfType IN_NON_WITNESS_UTXO kvs parseTxValue
  -- Core stores the output and its writer omits it when `CTxOut::IsNull()`
  -- (`src/psbt.h:366-369`, `IsNull` in `primitives/transaction.h`).
  let witnessUtxo ← match valueOfType IN_WITNESS_UTXO kvs with
    | none => .ok none
    | some v => do
      let o ← parseTxOutValue v
      if o.value == -1 && o.scriptPubKey.bytes.isEmpty then .ok none else .ok (some o)
  let partialSigs ← parseAllOfType IN_PARTIAL_SIG kvs fun d v => do
    if d.size = 33 || d.size = 65 then
      if v.isEmpty then .error (.malformedValue "partial signature" "empty signature")
      else .ok (d, v)
    else .error (.badKeyDataSize "partial signature pubkey" d.size)
  let sighashType ← parseOptOfType IN_SIGHASH kvs (parseU32Value "sighash type")
  let redeemScript ← parseOptOfType IN_REDEEMSCRIPT kvs (parseRaw "redeem script")
  let witnessScript ← parseOptOfType IN_WITNESSSCRIPT kvs (parseRaw "witness script")
  let bip32Derivation ← parseAllOfType IN_BIP32_DERIVATION kvs fun d v => do
    if d.size = 33 || d.size = 65 then
      let o ← parseHDKeypath "bip32 derivation" v
      .ok (d, o)
    else .error (.badKeyDataSize "bip32 derivation pubkey" d.size)
  let finalScriptSig ← parseOptOfType IN_SCRIPTSIG kvs (parseRaw "final scriptSig")
  let finalScriptWitness ← parseOptOfType IN_SCRIPTWITNESS kvs parseStackValue
  let ripemd160Preimages ← parseAllOfType IN_RIPEMD160 kvs fun d v =>
    if d.size = 20 then .ok (d, v) else .error (.badKeyDataSize "ripemd160 preimage hash" d.size)
  let sha256Preimages ← parseAllOfType IN_SHA256 kvs fun d v =>
    if d.size = 32 then .ok (d, v) else .error (.badKeyDataSize "sha256 preimage hash" d.size)
  let hash160Preimages ← parseAllOfType IN_HASH160 kvs fun d v =>
    if d.size = 20 then .ok (d, v) else .error (.badKeyDataSize "hash160 preimage hash" d.size)
  let hash256Preimages ← parseAllOfType IN_HASH256 kvs fun d v =>
    if d.size = 32 then .ok (d, v) else .error (.badKeyDataSize "hash256 preimage hash" d.size)
  let tapKeySig ← parseOptOfType IN_TAP_KEY_SIG kvs fun v =>
    if v.size = 64 || v.size = 65 then .ok v
    else .error (.malformedValue "taproot key signature" "signature is not 64 or 65 bytes")
  let tapScriptSigs ← parseAllOfType IN_TAP_SCRIPT_SIG kvs fun d v => do
    if d.size = 64 then
      if v.size = 64 || v.size = 65 then
        .ok ⟨bytesOfList ((bL d).take 32), bytesOfList ((bL d).drop 32), v⟩
      else .error (.malformedValue "taproot script signature" "signature is not 64 or 65 bytes")
    else .error (.badKeyDataSize "taproot script signature key" d.size)
  let tapLeafScripts ← parseAllOfType IN_TAP_LEAF_SCRIPT kvs fun d v => do
    if d.size ≥ 33 && (d.size - 1) % 32 = 0 then
      if v.isEmpty then .error (.malformedValue "taproot leaf script" "empty value")
      else
        let vl := bL v
        .ok ⟨d, bytesOfList vl.dropLast, vl.getLast!.toNat⟩
    else .error (.badKeyDataSize "taproot leaf script control block" d.size)
  let tapBip32Derivation ← parseAllOfType IN_TAP_BIP32_DERIVATION kvs fun d v => do
    if d.size = 32 then
      let (hs, o) ← parseTapBip32Value v
      .ok ⟨d, hs, o⟩
    else .error (.badKeyDataSize "taproot bip32 derivation key" d.size)
  let tapInternalKey ← parseOptOfType IN_TAP_INTERNAL_KEY kvs (expectLen "taproot internal key" 32)
  let tapMerkleRoot ← parseOptOfType IN_TAP_MERKLE_ROOT kvs (expectLen "taproot merkle root" 32)
  let unknown := kvs.filter fun kv =>
    match typeAndData kv.1 with
    | some (t, _) => !isKnownInputType t
    | none => false
  .ok { nonWitnessUtxo := nonWitnessUtxo
        witnessUtxo := witnessUtxo
        partialSigs := partialSigs
        sighashType := sighashType
        redeemScript := redeemScript
        witnessScript := witnessScript
        bip32Derivation := bip32Derivation
        finalScriptSig := finalScriptSig
        finalScriptWitness := finalScriptWitness
        ripemd160Preimages := ripemd160Preimages
        sha256Preimages := sha256Preimages
        hash160Preimages := hash160Preimages
        hash256Preimages := hash256Preimages
        tapKeySig := tapKeySig
        tapScriptSigs := tapScriptSigs
        tapLeafScripts := tapLeafScripts
        tapBip32Derivation := tapBip32Derivation
        tapInternalKey := tapInternalKey
        tapMerkleRoot := tapMerkleRoot
        unknown := unknown }

/-- Reject v2 output fields in a v0 file (`src/psbt.h:1119-1138`). -/
def rejectOutputV2 : List RawKV → Except PsbtError Unit
  | [] => .ok ()
  | kv :: rest =>
    match typeAndData kv.1 with
    | some (t, _) =>
      if t = OUT_AMOUNT || t = OUT_SCRIPT then .error (.v2FieldInV0 t)
      else rejectOutputV2 rest
    | none => .ok ()

/-- Output types this model interprets.  Proprietary (`0xFC`) and MuSig2
(`0x08`) are preserved as unknown. -/
def isKnownOutputType (t : Nat) : Bool :=
  t = OUT_REDEEMSCRIPT || t = OUT_WITNESSSCRIPT || t = OUT_BIP32_DERIVATION
  || t = OUT_TAP_INTERNAL_KEY || t = OUT_TAP_TREE || t = OUT_TAP_BIP32_DERIVATION

/-- Parse a taproot tree value: repeated `depth u8, leaf version u8,
CompactSize script length, script bytes` (`src/psbt.h:1145-1175`).  The
`TaprootBuilder` completeness check is not modelled. -/
def parseTapTree (v : ByteArray) : Except PsbtError (List (Nat × Nat × ByteArray)) :=
  if v.isEmpty then
    .error (.malformedValue "output tap tree" "empty tree")
  else
    let rec go : Nat → Bytes → Except PsbtError (List (Nat × Nat × ByteArray))
      | 0, [] => .ok []
      | 0, _ => .error (.malformedValue "output tap tree" "trailing bytes")
      | _ + 1, [] => .ok []
      | fuel + 1, depth :: lv :: rest => do
        let (n, l1) ← decCsP rest
        let (sc, l2) ← decBytesP n l1
        let more ← go fuel l2
        .ok ((depth.toNat, lv.toNat, bytesOfList sc) :: more)
      | _ + 1, _ => .error (.malformedValue "output tap tree" "truncated leaf")
    go (bL v).length (bL v)

/-- Parse an output map. -/
def parseOutput (kvs : List RawKV) : Except PsbtError PsbtOutput := do
  rejectOutputV2 kvs
  checkSingleKeyData
    [(OUT_REDEEMSCRIPT, "output redeem script"),
     (OUT_WITNESSSCRIPT, "output witness script"),
     (OUT_TAP_INTERNAL_KEY, "output taproot internal key"),
     (OUT_TAP_TREE, "output taproot tree")] kvs
  let redeemScript ← parseOptOfType OUT_REDEEMSCRIPT kvs (parseRaw "output redeem script")
  let witnessScript ← parseOptOfType OUT_WITNESSSCRIPT kvs (parseRaw "output witness script")
  let bip32Derivation ← parseAllOfType OUT_BIP32_DERIVATION kvs fun d v => do
    if d.size = 33 || d.size = 65 then
      let o ← parseHDKeypath "output bip32 derivation" v
      .ok (d, o)
    else .error (.badKeyDataSize "output bip32 derivation pubkey" d.size)
  let tapInternalKey ← parseOptOfType OUT_TAP_INTERNAL_KEY kvs
    (expectLen "output taproot internal key" 32)
  let tapTree ← parseOptOfType OUT_TAP_TREE kvs parseTapTree
  let tapBip32Derivation ← parseAllOfType OUT_TAP_BIP32_DERIVATION kvs fun d v => do
    if d.size = 32 then
      let (hs, o) ← parseTapBip32Value v
      .ok ⟨d, hs, o⟩
    else .error (.badKeyDataSize "output taproot bip32 derivation key" d.size)
  let unknown := kvs.filter fun kv =>
    match typeAndData kv.1 with
    | some (t, _) => !isKnownOutputType t
    | none => false
  .ok { redeemScript := redeemScript
        witnessScript := witnessScript
        bip32Derivation := bip32Derivation
        tapInternalKey := tapInternalKey
        tapTree := tapTree.getD []
        tapBip32Derivation := tapBip32Derivation
        unknown := unknown }

/-! ## Whole-file decoder -/

/-- Decode `n` consecutive maps. -/
def decNMaps : Nat → Bytes → Except PsbtError (List (List RawKV) × Bytes)
  | 0, l => .ok ([], l)
  | _ + 1, [] => .error .truncated
  | n + 1, l => do
    let (m, l1) ← decMapChecked l
    let (ms, l2) ← decNMaps n l1
    .ok (m :: ms, l2)

/-- Core's v0 non-witness-UTXO consistency check: the txid must equal the
input's prevout hash and the prevout index must exist
(`src/psbt.h:1571-1589`). -/
def checkUtxos (tx : Tx) : Nat → List PsbtInput → Except PsbtError Unit
  | _, [] => .ok ()
  | k, inp :: rest =>
    match tx.vin[k]? with
    | none => .error (.malformedValue "input maps" "more input maps than inputs")
    | some ti =>
      match inp.nonWitnessUtxo with
      | none => checkUtxos tx (k + 1) rest
      | some u =>
        if sha256d (serTx u) == ti.prevout.hash then
          if ti.prevout.n.toNat < u.vout.length then checkUtxos tx (k + 1) rest
          else .error (.nonWitnessUtxoIndexOutOfRange k)
        else .error (.nonWitnessUtxoHashMismatch k)

/-- Parse a complete PSBT byte string.  The magic bytes are checked,
then one global map, `vin.size()` input maps and `vout.size()` output
maps; any remaining byte is a `trailingBytes` error
(`src/psbt.cpp:876-878`). -/
def decode (b : ByteArray) : Except PsbtError Psbt := do
  let l := bL b
  if l.take 5 = magicBytes then
    let (gkvs, l1) ← decMapChecked (l.drop 5)
    let g ← parseGlobal gkvs
    let (ikvss, l2) ← decNMaps g.unsignedTx.vin.length l1
    let (okvss, l3) ← decNMaps g.unsignedTx.vout.length l2
    if l3.isEmpty then
      let rec parseIns : List (List RawKV) → Except PsbtError (List PsbtInput)
        | [] => .ok []
        | m :: ms => do
          let i ← parseInput m
          let is ← parseIns ms
          .ok (i :: is)
      let rec parseOuts : List (List RawKV) → Except PsbtError (List PsbtOutput)
        | [] => .ok []
        | m :: ms => do
          let o ← parseOutput m
          let os ← parseOuts ms
          .ok (o :: os)
      let ins ← parseIns ikvss
      let outs ← parseOuts okvss
      checkUtxos g.unsignedTx 0 ins
      .ok { global := g, inputs := ins, outputs := outs }
    else .error .trailingBytes
  else .error .badMagic

end Bitcoin.Wallet.Psbt
