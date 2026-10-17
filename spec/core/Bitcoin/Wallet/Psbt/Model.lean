import Bitcoin.Data.Tx
import Bitcoin.Serialization.Interface
import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Wallet.RuleAttr

/-!
# PSBT v0 — typed model

This module models the version-0 Partially Signed Bitcoin Transaction
format of BIP 174 as implemented by Bitcoin Core at the pinned tree
`src/psbt.h` / `src/psbt.cpp` (commit `cce32b168`).  PSBT version 2 is
deliberately **not** modelled; the v2 key types are recognised only
enough to reject them (see `Bitcoin.Wallet.Psbt.Decode`).

## What is modelled

* The five magic bytes `psbt\xff` (`src/psbt.h:33`).
* One global map, one map per transaction input and one map per
  transaction output, exactly as BIP 174 and Core lay them out.
* Every v0 key type Core implements for these maps: the unsigned
  transaction (`0x00`), global xpubs (`0x01`), non-witness and witness
  UTXOs (`0x00`/`0x01` per input), partial signatures (`0x02`),
  sighash type (`0x03`), redeem/witness scripts (`0x04`/`0x05`),
  BIP 32 derivations (`0x06`), final scriptSig/scriptWitness
  (`0x07`/`0x08`), the four preimage types (`0x0A`–`0x0D`), and the
  BIP 371 taproot fields (`0x13`–`0x18` on inputs, `0x05`–`0x07` on
  outputs).
* Unknown key-value pairs are preserved verbatim (raw key bytes
  including the key-type encoding, raw value bytes).  Core keeps the
  same representation (`std::map<std::vector<unsigned char>,...> unknown`,
  `src/psbt.h:321,953,1250`).
* The WellFormed predicate with one constructor per explicit violation
  (`Violation` below).

## What is NOT modelled

* **PSBT v2** (BIP 370).  Version-2 fields are rejected by the decoder.
* **Cryptographic validation of keys and signatures.**  Core checks
  `CPubKey::IsFullyValid()` for partial signatures and BIP 32 entries
  (`src/psbt.h:605-615,648-651,169-177`), and `CheckSignatureEncoding(... DERSIG |
  STRICTENC ...)` for partial signatures (`src/psbt.h:621-624`).  Here a
  public key is an opaque byte string whose length is checked
  (33 or 65 bytes), and a signature is an opaque non-empty byte string.
  The txid check on a non-witness UTXO is modelled (it is a hash, not
  a signature), but no signature is ever verified.
* **Taproot tree completeness.**  Core rebuilds the output tap tree and
  requires `TaprootBuilder::IsComplete()` (`src/psbt.h:1145-1175`); here
  the tree is a list of `(depth, leaf version, script)` triples whose
  encoding is preserved, without the builder check.
* MuSig2 fields (`0x1a`–`0x1c` on inputs, `0x08` on outputs): Core
  implements them (`src/psbt.h:71-73,85`), but they are outside the v0
  scope of this model and are preserved as unknown key-value pairs.
* Proprietary fields (`0xFC`): parsed by Core into `PSBTProprietary`
  (`src/psbt.h:99-108,900-909`) but preserved here as unknown pairs.
  This is lossless on the wire: Core re-emits `entry.key`/`entry.value`
  unchanged (`src/psbt.h:542-545`).
* Fee calculation, signing policy, dust, and any wallet policy choice.
* The PSBT file-size limit `MAX_FILE_SIZE_PSBT = 100'000'000`
  (`src/psbt.h:94`) is not enforced at this layer.

## Byte-level representation

`Bytes` is `List UInt8` (the proof vehicle used by
`Bitcoin.Serialization`), `ByteArray` is the public representation.  A
raw map entry `(key, value)` stores the key **without** its CompactSize
length prefix but **with** its key-type CompactSize encoding, matching
Core's `std::vector<unsigned char> key` after `s >> key`
(`src/psbt.h:568-572,914-916`).  Values are stored without their length prefix.
-/

namespace Bitcoin.Wallet.Psbt

open Bitcoin.Data
open Bitcoin.Serialization
open Bitcoin.Crypto.Seam.Hash (sha256d hash160)
open Bitcoin.Crypto.Seam.Hash.Sha256 (sha256)

/-! ## Wire constants (`src/psbt.h:33-86`) -/

/-- The five magic bytes `{'p','s','b','t',0xff}` (`src/psbt.h:33`). -/
def magicBytes : Bytes := [0x70, 0x73, 0x62, 0x74, 0xff]

/-- Map separator: a zero-length key, i.e. the single byte `0x00`
(`src/psbt.h:88-90`). -/
def separatorByte : UInt8 := 0x00

/-- Global key type `PSBT_GLOBAL_UNSIGNED_TX = 0x00` (`src/psbt.h:36`). -/
def GLOBAL_UNSIGNED_TX : Nat := 0x00
/-- Global key type `PSBT_GLOBAL_XPUB = 0x01` (`src/psbt.h:37`). -/
def GLOBAL_XPUB : Nat := 0x01
/-- Global key type `PSBT_GLOBAL_TX_VERSION = 0x02` (`src/psbt.h:38`);
v2-only, rejected in v0 (`src/psbt.h:1521-1523`). -/
def GLOBAL_TX_VERSION : Nat := 0x02
/-- Global key type `PSBT_GLOBAL_FALLBACK_LOCKTIME = 0x03`
(`src/psbt.h:39`); v2-only, rejected in v0. -/
def GLOBAL_FALLBACK_LOCKTIME : Nat := 0x03
/-- Global key type `PSBT_GLOBAL_INPUT_COUNT = 0x04` (`src/psbt.h:40`);
v2-only, rejected in v0. -/
def GLOBAL_INPUT_COUNT : Nat := 0x04
/-- Global key type `PSBT_GLOBAL_OUTPUT_COUNT = 0x05` (`src/psbt.h:41`);
v2-only, rejected in v0. -/
def GLOBAL_OUTPUT_COUNT : Nat := 0x05
/-- Global key type `PSBT_GLOBAL_TX_MODIFIABLE = 0x06` (`src/psbt.h:42`);
v2-only, rejected in v0. -/
def GLOBAL_TX_MODIFIABLE : Nat := 0x06
/-- Global key type `PSBT_GLOBAL_VERSION = 0xFB` (`src/psbt.h:43`). -/
def GLOBAL_VERSION : Nat := 0xFB
/-- Global key type `PSBT_GLOBAL_PROPRIETARY = 0xFC` (`src/psbt.h:44`);
preserved as an unknown pair. -/
def GLOBAL_PROPRIETARY : Nat := 0xFC

/-- Input key type `PSBT_IN_NON_WITNESS_UTXO = 0x00` (`src/psbt.h:47`). -/
def IN_NON_WITNESS_UTXO : Nat := 0x00
/-- Input key type `PSBT_IN_WITNESS_UTXO = 0x01` (`src/psbt.h:48`). -/
def IN_WITNESS_UTXO : Nat := 0x01
/-- Input key type `PSBT_IN_PARTIAL_SIG = 0x02` (`src/psbt.h:49`). -/
def IN_PARTIAL_SIG : Nat := 0x02
/-- Input key type `PSBT_IN_SIGHASH = 0x03` (`src/psbt.h:50`). -/
def IN_SIGHASH : Nat := 0x03
/-- Input key type `PSBT_IN_REDEEMSCRIPT = 0x04` (`src/psbt.h:51`). -/
def IN_REDEEMSCRIPT : Nat := 0x04
/-- Input key type `PSBT_IN_WITNESSSCRIPT = 0x05` (`src/psbt.h:52`). -/
def IN_WITNESSSCRIPT : Nat := 0x05
/-- Input key type `PSBT_IN_BIP32_DERIVATION = 0x06` (`src/psbt.h:53`). -/
def IN_BIP32_DERIVATION : Nat := 0x06
/-- Input key type `PSBT_IN_SCRIPTSIG = 0x07` (`src/psbt.h:54`). -/
def IN_SCRIPTSIG : Nat := 0x07
/-- Input key type `PSBT_IN_SCRIPTWITNESS = 0x08` (`src/psbt.h:55`). -/
def IN_SCRIPTWITNESS : Nat := 0x08
/-- Input key type `PSBT_IN_RIPEMD160 = 0x0A` (`src/psbt.h:56`). -/
def IN_RIPEMD160 : Nat := 0x0A
/-- Input key type `PSBT_IN_SHA256 = 0x0B` (`src/psbt.h:57`). -/
def IN_SHA256 : Nat := 0x0B
/-- Input key type `PSBT_IN_HASH160 = 0x0C` (`src/psbt.h:58`). -/
def IN_HASH160 : Nat := 0x0C
/-- Input key type `PSBT_IN_HASH256 = 0x0D` (`src/psbt.h:59`). -/
def IN_HASH256 : Nat := 0x0D
/-- Input key type `PSBT_IN_TAP_KEY_SIG = 0x13` (`src/psbt.h:64`). -/
def IN_TAP_KEY_SIG : Nat := 0x13
/-- Input key type `PSBT_IN_TAP_SCRIPT_SIG = 0x14` (`src/psbt.h:65`). -/
def IN_TAP_SCRIPT_SIG : Nat := 0x14
/-- Input key type `PSBT_IN_TAP_LEAF_SCRIPT = 0x15` (`src/psbt.h:66`). -/
def IN_TAP_LEAF_SCRIPT : Nat := 0x15
/-- Input key type `PSBT_IN_TAP_BIP32_DERIVATION = 0x16`
(`src/psbt.h:67`). -/
def IN_TAP_BIP32_DERIVATION : Nat := 0x16
/-- Input key type `PSBT_IN_TAP_INTERNAL_KEY = 0x17` (`src/psbt.h:68`). -/
def IN_TAP_INTERNAL_KEY : Nat := 0x17
/-- Input key type `PSBT_IN_TAP_MERKLE_ROOT = 0x18` (`src/psbt.h:69`). -/
def IN_TAP_MERKLE_ROOT : Nat := 0x18
/-- Input key type `PSBT_IN_PROPRIETARY = 0xFC` (`src/psbt.h:74`);
preserved as an unknown pair. -/
def IN_PROPRIETARY : Nat := 0xFC

/-- Output key type `PSBT_OUT_REDEEMSCRIPT = 0x00` (`src/psbt.h:75`). -/
def OUT_REDEEMSCRIPT : Nat := 0x00
/-- Output key type `PSBT_OUT_WITNESSSCRIPT = 0x01` (`src/psbt.h:76`). -/
def OUT_WITNESSSCRIPT : Nat := 0x01
/-- Output key type `PSBT_OUT_BIP32_DERIVATION = 0x02` (`src/psbt.h:77`). -/
def OUT_BIP32_DERIVATION : Nat := 0x02
/-- Output key type `PSBT_OUT_AMOUNT = 0x03` (`src/psbt.h:78`);
v2-only, rejected in v0. -/
def OUT_AMOUNT : Nat := 0x03
/-- Output key type `PSBT_OUT_SCRIPT = 0x04` (`src/psbt.h:79`);
v2-only, rejected in v0. -/
def OUT_SCRIPT : Nat := 0x04
/-- Output key type `PSBT_OUT_TAP_INTERNAL_KEY = 0x05`
(`src/psbt.h:80`). -/
def OUT_TAP_INTERNAL_KEY : Nat := 0x05
/-- Output key type `PSBT_OUT_TAP_TREE = 0x06` (`src/psbt.h:81`). -/
def OUT_TAP_TREE : Nat := 0x06
/-- Output key type `PSBT_OUT_TAP_BIP32_DERIVATION = 0x07`
(`src/psbt.h:82`). -/
def OUT_TAP_BIP32_DERIVATION : Nat := 0x07
/-- Output key type `PSBT_OUT_PROPRIETARY = 0xFC` (`src/psbt.h:86`);
preserved as an unknown pair. -/
def OUT_PROPRIETARY : Nat := 0xFC

/-! ## Map entries and typed field payloads -/

/-- A raw map entry: the key bytes including the CompactSize key-type
encoding (but not the key-length prefix) and the raw value bytes (not
including the value-length prefix).  This is Core's `key`/`value` pair
after `s >> key; ...; s >> val_bytes` (`src/psbt.h:568-572,914-916`). -/
abbrev RawKV := ByteArray × ByteArray

/-- A BIP 32 key origin: 4-byte fingerprint followed by a derivation
path of little-endian 32-bit indices (`KeyOriginInfo`,
`src/script/keyorigin.h`; serialized by `SerializeKeyOrigin`,
`src/psbt.h:186-194`).  In a BIP 32 derivation map entry this payload is
the value itself: the value length is the origin length, so there is no
additional inner length prefix. -/
structure KeyOrigin where
  fingerprint : ByteArray
  path : List UInt32
deriving Repr, BEq

/-- A global xpub entry.  `xpub` is the 78-byte
`BIP32_EXTKEY_WITH_VERSION_SIZE` blob that Core checks for
(`src/psbt.h:1452-1463`), re-emitted verbatim; its internal version,
depth, parent fingerprint, child number, chain code and public key are
not interpreted here. -/
structure XpubEntry where
  xpub : ByteArray
  origin : KeyOrigin
deriving Repr, BEq

/-- The global map of a v0 PSBT.  The unsigned transaction is mandatory
(`src/psbt.h:1515-1519`); its scriptSigs and witnesses must be empty
(`src/psbt.h:1400-1405`). -/
structure Global where
  /-- The unsigned transaction (`PSBT_GLOBAL_UNSIGNED_TX`). -/
  unsignedTx : Tx
  /-- Global xpub records (`PSBT_GLOBAL_XPUB`), one per xpub. -/
  xpubs : List XpubEntry
  /-- Unrecognised global key-value pairs, preserved verbatim. -/
  unknown : List RawKV
deriving Repr

/-- A taproot leaf script entry: the control block (key data), the
script and the leaf version (the last value byte, `src/psbt.h:812-828`). -/
structure TapLeafEntry where
  controlBlock : ByteArray
  script : ByteArray
  leafVersion : Nat
deriving Repr, BEq

/-- A taproot script-path signature entry: x-only key, leaf hash and
signature (`src/psbt.h:794-810`). -/
structure TapScriptSigEntry where
  xonly : ByteArray
  leafHash : ByteArray
  signature : ByteArray
deriving Repr, BEq

/-- A taproot BIP 32 derivation: x-only key, the leaf hashes it applies
to, and the key origin (`src/psbt.h:830-847`). -/
structure TapBip32Entry where
  xonly : ByteArray
  leafHashes : List ByteArray
  origin : KeyOrigin
deriving Repr, BEq

/-- One input map of a v0 PSBT.

`Option` distinguishes "field absent" from "field present with an empty
payload", which matters for byte-identical re-encoding: Core's writer
omits empty scripts and null outputs (`src/psbt.h:366-369,384-394,508-517`). -/
structure PsbtInput where
  /-- `PSBT_IN_NON_WITNESS_UTXO`: the full previous transaction in
  network serialization, written by Core *without* witness data
  (`src/psbt.h:362-365`). -/
  nonWitnessUtxo : Option Tx
  /-- `PSBT_IN_WITNESS_UTXO`: the spent output (`src/psbt.h:366-369`). -/
  witnessUtxo : Option TxOut
  /-- `PSBT_IN_PARTIAL_SIG`: public key and signature. -/
  partialSigs : List (ByteArray × ByteArray)
  /-- `PSBT_IN_SIGHASH`: 4-byte sighash type (`src/psbt.h:630-635`). -/
  sighashType : Option UInt32
  /-- `PSBT_IN_REDEEMSCRIPT`: raw redeem script bytes. -/
  redeemScript : Option ByteArray
  /-- `PSBT_IN_WITNESSSCRIPT`: raw witness script bytes. -/
  witnessScript : Option ByteArray
  /-- `PSBT_IN_BIP32_DERIVATION`: public key and origin. -/
  bip32Derivation : List (ByteArray × KeyOrigin)
  /-- `PSBT_IN_SCRIPTSIG`: finalized scriptSig bytes. -/
  finalScriptSig : Option ByteArray
  /-- `PSBT_IN_SCRIPTWITNESS`: finalized witness stack. -/
  finalScriptWitness : Option (List ByteArray)
  /-- `PSBT_IN_RIPEMD160`: 20-byte hash and preimage. -/
  ripemd160Preimages : List (ByteArray × ByteArray)
  /-- `PSBT_IN_SHA256`: 32-byte hash and preimage. -/
  sha256Preimages : List (ByteArray × ByteArray)
  /-- `PSBT_IN_HASH160`: 20-byte hash and preimage. -/
  hash160Preimages : List (ByteArray × ByteArray)
  /-- `PSBT_IN_HASH256`: 32-byte hash and preimage. -/
  hash256Preimages : List (ByteArray × ByteArray)
  /-- `PSBT_IN_TAP_KEY_SIG`: 64- or 65-byte Schnorr signature. -/
  tapKeySig : Option ByteArray
  /-- `PSBT_IN_TAP_SCRIPT_SIG`: script-path signatures. -/
  tapScriptSigs : List TapScriptSigEntry
  /-- `PSBT_IN_TAP_LEAF_SCRIPT`: leaf scripts with control blocks. -/
  tapLeafScripts : List TapLeafEntry
  /-- `PSBT_IN_TAP_BIP32_DERIVATION`: taproot key origins. -/
  tapBip32Derivation : List TapBip32Entry
  /-- `PSBT_IN_TAP_INTERNAL_KEY`: 32-byte x-only internal key. -/
  tapInternalKey : Option ByteArray
  /-- `PSBT_IN_TAP_MERKLE_ROOT`: 32-byte merkle root. -/
  tapMerkleRoot : Option ByteArray
  /-- Unrecognised input key-value pairs, preserved verbatim. -/
  unknown : List RawKV
deriving Repr

/-- One output map of a v0 PSBT.  In v0 the amount and script are not
part of the map; they come from the unsigned transaction
(`src/psbt.h:1597-1602`). -/
structure PsbtOutput where
  /-- `PSBT_OUT_REDEEMSCRIPT`. -/
  redeemScript : Option ByteArray
  /-- `PSBT_OUT_WITNESSSCRIPT`. -/
  witnessScript : Option ByteArray
  /-- `PSBT_OUT_BIP32_DERIVATION`. -/
  bip32Derivation : List (ByteArray × KeyOrigin)
  /-- `PSBT_OUT_TAP_INTERNAL_KEY`: 32-byte x-only key. -/
  tapInternalKey : Option ByteArray
  /-- `PSBT_OUT_TAP_TREE`: `(depth, leaf version, script)` triples. -/
  tapTree : List (Nat × Nat × ByteArray)
  /-- `PSBT_OUT_TAP_BIP32_DERIVATION`. -/
  tapBip32Derivation : List TapBip32Entry
  /-- Unrecognised output key-value pairs, preserved verbatim. -/
  unknown : List RawKV
deriving Repr

/-- A complete v0 PSBT: one global map, one input map per unsigned-tx
input, one output map per unsigned-tx output. -/
structure Psbt where
  /-- The global map. -/
  global : Global
  /-- The per-input maps, in unsigned-tx input order. -/
  inputs : List PsbtInput
  /-- The per-output maps, in unsigned-tx output order. -/
  outputs : List PsbtOutput
deriving Repr

/-! ## Helpers for key construction and script classification -/

/-- Build a raw key from a key type and its key data:
`<type as CompactSize> ‖ <key data>`.  For all types below `0xfd` (all
v0 types) the type encoding is one byte. -/
def keyOf (typ : Nat) (data : ByteArray) : ByteArray :=
  bytesOfList ([typ.toUInt8] ++ bL data)

/-- `CScript::IsPayToScriptHash()` shape: `OP_HASH160 0x14 <20 bytes>
OP_EQUAL` (`src/script/script.h`). -/
def isP2SH (s : ByteArray) : Bool :=
  match bL s with
  | 0xa9 :: 0x14 :: rest => rest.length = 21 && rest.getD 20 0x00 == 0x87
  | _ => false

/-- The 20-byte hash inside a P2SH script, if the shape matches. -/
def p2shHash (s : ByteArray) : Option ByteArray :=
  match bL s with
  | 0xa9 :: 0x14 :: rest =>
    if rest.length = 21 && rest.getD 20 0x00 == 0x87 then
      some (bytesOfList (rest.take 20))
    else none
  | _ => none

/-- A witness program of the shape `<version byte> <push len> <program>`;
the only version-0 length is 32 (`P2WSH`), see BIP 141.  Version and
program are returned so the predicate below can be precise. -/
def witnessProgram (s : ByteArray) : Option (UInt8 × ByteArray) :=
  match bL s with
  | v :: n :: rest =>
    if n.toNat = rest.length && n.toNat ≥ 2 && n.toNat ≤ 40 then
      some (v, bytesOfList rest)
    else none
  | _ => none

/-- The spent output for input `i`, following Core's precedence:
the non-witness UTXO if present, else the witness UTXO
(`PSBTInput::GetUTXO`, `src/psbt.cpp:267-283`).  Returns `none` when
the non-witness UTXO does not match the unsigned tx outpoint
(`src/psbt.cpp:269-276`) or when neither field is present. -/
@[walletRule "PSBT-019"]
def spentOutput (p : Psbt) (i : Nat) : Option TxOut :=
  match p.inputs[i]? with
  | none => none
  | some inp =>
    match p.global.unsignedTx.vin[i]? with
    | none => none
    | some ti =>
      match inp.nonWitnessUtxo with
      | some u =>
        if sha256d (serTx u) == ti.prevout.hash
           && ti.prevout.n.toNat < u.vout.length then
          u.vout[ti.prevout.n.toNat]?
        else none
      | none => inp.witnessUtxo

/-! ## Well-formedness: the explicit violation list -/

/-- One concrete way a v0 PSBT can violate the BIP 174 field
relationships.  Each constructor names the input it concerns (or the
map-level count) so a caller can report precisely what failed. -/
inductive Violation where
  /-- The unsigned transaction's scriptSigs are not all empty
  (`src/psbt.h:1400-1405`). -/
  | unsignedTxHasScriptSig (i : Nat)
  /-- The number of input maps differs from the unsigned tx's input
  count (`src/psbt.h:1593-1595`). -/
  | inputCountMismatch (want : Nat) (got : Nat)
  /-- The number of output maps differs from the unsigned tx's output
  count (`src/psbt.h:1608-1611`). -/
  | outputCountMismatch (want : Nat) (got : Nat)
  /-- `PSBT_IN_NON_WITNESS_UTXO` is present but its txid does not equal
  the input's prevout hash (`src/psbt.h:1571-1577`). -/
  | nonWitnessUtxoHashMismatch (i : Nat)
  /-- `PSBT_IN_NON_WITNESS_UTXO` is present but the prevout index is out
  of range (`src/psbt.h:1578-1580`). -/
  | nonWitnessUtxoIndexOutOfRange (i : Nat)
  /-- Both UTXO fields are present and the witness UTXO differs from the
  output selected by the non-witness UTXO.  BIP 174 allows both fields,
  but they must describe the same output. -/
  | witnessUtxoMismatch (i : Nat)
  /-- A redeem script is present but the spent script is not P2SH.
  BIP 174: the redeem script is required only for P2SH spends. -/
  | redeemScriptWithoutP2SH (i : Nat)
  /-- The redeem script's HASH160 does not equal the hash in the spent
  P2SH script (BIP 174 signer check). -/
  | redeemScriptHashMismatch (i : Nat)
  /-- A witness script is present but neither the spent script nor the
  redeem script is a witness program. -/
  | witnessScriptWithoutProgram (i : Nat)
  /-- The witness script's SHA256 does not equal the witness program
  (BIP 174 signer check). -/
  | witnessScriptHashMismatch (i : Nat)
  /-- A finalized input still carries signing material: partial
  signatures, sighash type, redeem/witness scripts, BIP 32 derivations
  or taproot signing fields.  Core's writer omits all of those once
  `final_script_sig`/`final_script_witness` is set
  (`src/psbt.h:371-506`), so such a map cannot round-trip. -/
  | finalizedWithSigningData (i : Nat)
deriving Repr, DecidableEq, BEq

/-- Violations contributed by the global map and by map counts. -/
def globalViolations (p : Psbt) : List Violation :=
  (p.global.unsignedTx.vin.zipIdx.filterMap fun (ti, k) =>
      if ti.scriptSig.bytes.isEmpty then none
      else some (.unsignedTxHasScriptSig k))
  ++ (if p.inputs.length = p.global.unsignedTx.vin.length then []
      else [.inputCountMismatch p.global.unsignedTx.vin.length p.inputs.length])
  ++ (if p.outputs.length = p.global.unsignedTx.vout.length then []
      else [.outputCountMismatch p.global.unsignedTx.vout.length p.outputs.length])

/-- The fields Core's writer suppresses once an input is finalized;
see `src/psbt.h:371` (`if (final_script_sig.empty() &&
final_script_witness.IsNull())`). -/
def hasSigningData (i : PsbtInput) : Bool :=
  !i.partialSigs.isEmpty || i.sighashType.isSome
  || i.redeemScript.isSome || i.witnessScript.isSome
  || !i.bip32Derivation.isEmpty
  || !i.tapScriptSigs.isEmpty || !i.tapLeafScripts.isEmpty
  || !i.tapBip32Derivation.isEmpty || i.tapInternalKey.isSome
  || i.tapMerkleRoot.isSome || i.tapKeySig.isSome

/-- `PSBTInputSigned`: a non-empty final scriptSig or a non-null final
scriptWitness (`src/psbt.cpp:547-550`). -/
def inputSigned (i : PsbtInput) : Bool :=
  (match i.finalScriptSig with
   | some s => !s.isEmpty
   | none => false)
  || (match i.finalScriptWitness with
      | some ws => !ws.isEmpty
      | none => false)

/-- Violations of one input map.  The script checks use the spent output
chosen by `spentOutput`; when no spent output is available the script
hashes cannot be checked, so only the "without program" violations are
reported. -/
def inputViolations (p : Psbt) (k : Nat) : List Violation :=
  match p.inputs[k]? with
  | none => []
  | some inp =>
    let ti := p.global.unsignedTx.vin[k]?
    let base : List Violation :=
      (match inp.nonWitnessUtxo, ti with
       | some u, some t =>
         (if sha256d (serTx u) == t.prevout.hash then [] else [.nonWitnessUtxoHashMismatch k])
         ++ (if t.prevout.n.toNat < u.vout.length then [] else [.nonWitnessUtxoIndexOutOfRange k])
       | _, _ => [])
      ++ (match inp.nonWitnessUtxo, inp.witnessUtxo, ti with
          | some u, some w, some t =>
            if t.prevout.n.toNat < u.vout.length then
              match u.vout[t.prevout.n.toNat]? with
              | some real =>
                if bL (serTxOut real) == bL (serTxOut w) then []
                else [.witnessUtxoMismatch k]
              | none => [.nonWitnessUtxoIndexOutOfRange k]
            else []
          | _, _, _ => [])
      ++ (if inputSigned inp && hasSigningData inp then [.finalizedWithSigningData k] else [])
    let spk := (spentOutput p k).map (fun o => o.scriptPubKey.bytes)
    let scriptChecks : List Violation :=
      match spk with
      | none => []
      | some s =>
        (match inp.redeemScript with
         | none => []
         | some rs =>
           if !isP2SH s then [.redeemScriptWithoutP2SH k]
           else match p2shHash s with
             | some h => if hash160 rs == h then [] else [.redeemScriptHashMismatch k]
             | none => [.redeemScriptWithoutP2SH k])
        ++ (match inp.witnessScript with
            | none => []
            | some ws =>
              let prog : Option ByteArray :=
                match witnessProgram s with
                | some (0x00, q) => some q
                | _ =>
                  match inp.redeemScript with
                  | some rs =>
                    match witnessProgram rs with
                    | some (0x00, q) => some q
                    | _ => none
                  | none => none
              match prog with
              | none => [.witnessScriptWithoutProgram k]
              | some q =>
                if sha256 ws == q then [] else [.witnessScriptHashMismatch k])
    base ++ scriptChecks

/-- Every violation of `p`, global and per-input, in input order. -/
def violations (p : Psbt) : List Violation :=
  globalViolations p
  ++ (List.range p.inputs.length).flatMap (inputViolations p)

/-- A PSBT is **well formed** when it has no violations.  This is the
domain of the lifecycle and round-trip statements: it enforces the BIP
174 field relationships that Core's decoder does not check itself
(script/UTXO consistency) plus the structural checks Core does perform
(counts, empty unsigned scriptSigs, finalized-input field exclusion).

Note what is *not* claimed: `WellFormed` says nothing about signature
validity, key validity on the curve, sighash acceptability, fee policy,
or whether the transaction is consensus-valid. -/
def WellFormed (p : Psbt) : Prop := violations p = []

/-- Executable form of `WellFormed`, convenient for tests. -/
def wellFormedB (p : Psbt) : Bool := (violations p).isEmpty

/-- The propositional and executable well-formedness predicates agree. -/
theorem wellFormed_iff (p : Psbt) : WellFormed p ↔ wellFormedB p = true := by
  unfold WellFormed wellFormedB
  exact (List.isEmpty_iff (l := violations p)).symm

/-! ## Finalization and extraction -/

/-- Replace an unsigned input's scriptSig by `finalScriptSig`, if present. -/
def fillTxIn (ti : TxIn) (i : PsbtInput) : TxIn :=
  { ti with scriptSig := ⟨i.finalScriptSig.getD ti.scriptSig.bytes⟩ }

/-- Fill the unsigned transaction with finalized scriptSigs (from the
input maps) and finalized witness stacks.  This is exactly
`FinalizeAndExtractPSBT`'s loop (`src/psbt.cpp:826-834`): copy the
unsigned tx, then overwrite `scriptSig` and `scriptWitness` per input. -/
def fillTx (tx : Tx) (ins : List PsbtInput) : Tx :=
  { tx with
    vin := List.zipWith fillTxIn tx.vin ins
    witness := ins.map (fun i => i.finalScriptWitness.getD []) }

/-- Every input carries a non-null final scriptSig or witness
(`PSBTInputSigned`, `src/psbt.cpp:547-550`).  `FinalizeAndExtractPSBT`
refuses to extract otherwise (`src/psbt.cpp:820-824`). -/
def allInputsSigned (p : Psbt) : Bool := p.inputs.all inputSigned

/-- Extraction: if every input is finalized, return the unsigned
transaction with the finalized scriptSigs and witnesses filled in;
otherwise `none`.  This is `FinalizeAndExtractPSBT` minus the signing
step, which is not modelled (`src/psbt.cpp:818-836`). -/
def extract (p : Psbt) : Option Tx :=
  if allInputsSigned p then
    some (fillTx p.global.unsignedTx p.inputs)
  else none

end Bitcoin.Wallet.Psbt
