import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Serialization.Interface
import Bitcoin.SigHash.Ops
import Bitcoin.Interpreter.Defs

/-!
# Bitcoin.SigHash.Digest — the two digest constructions (legacy + BIP143)

Ground truth @ cce32b168 (`src/script/interpreter.cpp`):

* Legacy: `CTransactionSignatureSerializer` :1259-1356 +
  `SignatureHash` :1609-1687 (non-WITNESS_V0 path). The preimage is a
  *modified transaction serialization*:
    - nVersion (4LE)
    - vin count = 1 if ANYONECANPAY else all; each input: prevout;
      scriptSig = ∅ for other inputs, else `SerializeScriptCode`
      (CompactSize-prefixed, OP_CODESEPARATOR-spliced — see `Ops.lean`);
      nSequence = 0 for other inputs under SINGLE/NONE, else actual
    - vout count = 0 if NONE, `nIn+1` if SINGLE, else all; each output is a
      NULL `CTxOut` (`nValue = −1` ⇒ 8×0xff, empty script) for
      `nOutput ≠ nIn` under SINGLE — **not** 8 zero bytes (W11 mirror finding)
    - nLockTime
  then the 4-byte LE hashtype, then double-SHA256.
* Tri-modal SIGHASH_SINGLE out-of-range (`nIn ≥ vout.size`):
  legacy ⇒ `uint256::ONE` (early return BEFORE any vin access;
  interpreter.cpp:1614-1622); BIP143 ⇒ zero `hashOutputs` (:1647-1653);
  BIP341 ⇒ fail-closed hashtype error (Review 3 — stub point below).
* BIP143 (`WITNESS_V0`, :1633-1670): the 10-field preimage
  version ‖ hashPrevouts ‖ hashSequence ‖ outpoint ‖ scriptCode ‖ amount ‖
  nSequence ‖ hashOutputs ‖ nLockTime ‖ hashtype, double-SHA256'd. The
  scriptCode enters RAW (CompactSize-prefixed, no FindAndDelete, no
  CODESEPARATOR removal — the caller supplies the right subscript).
* Byte order: `uint256::GetHex()` (how sighash.json prints digests) reverses
  the internal byte array; the consensus digest is the internal
  (SHA256d-output) order. W11-mirror-validated: 500/500 legacy + 7/7 BIP143.

Hash floor: W13's seam landed (commit e0b9c05) with real, executable
`sha256`/`sha256d` — `dshaL` routes through `Bitcoin.Crypto.Seam.sha256d`
(one implementation, seam-owned; the interim vendored `SigHash.Hash` copy
was retired). Everything is defined over the list vehicle (`Bytes`); the
ByteArray API bridges via W02's proved `bL`/`bytesOfList`.
-/

namespace Bitcoin.SigHash

open Bitcoin.Serialization (Bytes bL bytesOfList encCSL)
open Bitcoin.Data

/-! ## Wire-field serializers (list vehicle) -/

def serU32L (x : UInt32) : Bytes :=
  [x.toUInt8, (x >>> 8).toUInt8, (x >>> 16).toUInt8, (x >>> 24).toUInt8]

def serU64L (x : UInt64) : Bytes :=
  [x.toUInt8, (x >>> 8).toUInt8, (x >>> 16).toUInt8, (x >>> 24).toUInt8,
   (x >>> 32).toUInt8, (x >>> 40).toUInt8, (x >>> 48).toUInt8, (x >>> 56).toUInt8]

/-- `int64_t` wire serialization of a `CAmount` — two's-complement LE, total
in `Amount := Int` (negative values wrap exactly as `int64_t` reinterprets;
consensus keeps amounts in `MoneyRange`, and WITNESS_V0 requires `amount ≥ 0`
— SWT-055 — else Core asserts). -/
def serAmountL (v : Amount) : Bytes := serU64L (UInt64.ofInt v)

/-- `COutPoint` (32-byte LE txid + 4-byte LE n). -/
def serOutpointL (o : OutPoint) : Bytes := bL o.hash ++ serU32L o.n

/-- NULL `CTxOut` (`CTxOut::SetNull`: `nValue = −1`, empty script). -/
def serNullTxOutL : Bytes := serU64L 0xFFFFFFFFFFFFFFFF ++ encCSL 0

/-- A live `CTxOut`. -/
def serTxOutL (o : TxOut) : Bytes :=
  serAmountL o.value ++ encCSL o.scriptPubKey.bytes.size ++ bL o.scriptPubKey.bytes

/-- Double-SHA256 of a list-level preimage, via W13's seam hash floor
(`Bitcoin.Crypto.Seam.sha256d` — real, vector-verified; see Seam/Hash.lean).
SWT-052: BIP143 digests and sub-hashes are SHA256d (HashWriter::GetHash). -/
@[rule "SWT-052"]
def dshaL (l : Bytes) : ByteArray := Bitcoin.Crypto.Seam.sha256d (bytesOfList l)

/-- 32 zero bytes — the `uint256{}` of BIP143's zero sub-hashes. -/
def zeroHashL : Bytes := (List.range 32).map (fun _ => 0)

/-- The legacy-SINGLE overflow constant, exactly Core's `uint256::ONE` in
internal byte order: `01` followed by 31 zero bytes (FIX-L-SIGHASH2,
INV-078). The constant is shared with the frozen interface's
`SINGLE_OVERFLOW_ONE` (the two are definitionally equal). -/
@[rule "INV-078"]
def singleOverflowOneB : ByteArray :=
  bytesOfList (0x01 :: List.replicate 31 0x00)

/-- Core's `uint256::ONE` in internal byte order: `01` followed by 31
zero bytes (`uint256.cpp:35 const uint256 uint256::ONE(1);` +
`uint256.h:40 constexpr explicit base_blob(uint8_t v) : m_data{v} {}`,
which value-initializes the remaining limbs to zero). -/
@[rule "INV-078"]
def uint256OneCoreB : ByteArray :=
  bytesOfList (0x01 :: List.replicate 31 0x00)

/-- **INV-078**: the overflow constant returned by the out-of-range-SINGLE
arm is exactly Core's `uint256::ONE`. -/
@[rule "INV-078"]
theorem singleOverflowOneB_eq_uint256OneCoreB :
    singleOverflowOneB = uint256OneCoreB := by rfl

/-! ## Hashtype classification (`interpreter.cpp:1263-1269, 1614-1622`) -/

/-- Base class: `(nHashType & 0x1f)` — 0x02 = NONE, 0x03 = SINGLE, else ALL-like. -/
inductive HtBase where
  | all | noneHt | singleHt
deriving Repr, DecidableEq, BEq

/-- `(nHashType & 0x1f)` classification, all three cases (totality proved in
`htBase_cover`). Core tests `fHashSingle/fHashNone := (nHashType & 0x1f) == …`
(:1278-1279); EVERY other 5-bit value behaves as ALL — the case split below
is exhaustive by construction. -/
def htBase (ht : UInt32) : HtBase :=
  if (ht &&& 0x1f) == 0x03 then .singleHt
  else if (ht &&& 0x1f) == 0x02 then .noneHt
  else .all

/-- `(nHashType & 0x80) != 0` — ANYONECANPAY bit passed through from the
last signature byte (interpreter.cpp:1712-1713). -/
@[rule "SCR-111"]
def htAcp (ht : UInt32) : Bool := (ht &&& 0x80) != 0

/-- The 8-row hashtype matrix (base × ACP), as Core's serializer sees it. -/
def htClass (ht : UInt32) : HtBase × Bool := (htBase ht, htAcp ht)

/-- Every hashtype classifies (the match is exhaustive: two decisions over
`Bool`-valued predicates, all four combinations covered). -/
@[rule "INV-055"]
theorem htBase_cover (ht : UInt32) :
    htBase ht = .singleHt ∨ htBase ht = .noneHt ∨ htBase ht = .all := by
  unfold htBase
  split
  · exact Or.inl rfl
  · split
    · exact Or.inr (Or.inl rfl)
    · exact Or.inr (Or.inr rfl)

/-- **INV-055** (defined-set form, SCR-105): `IsDefinedHashtype`
(interpreter.cpp:162-167) accepts exactly the six trailing hashtype bytes
`{0x01,0x02,0x03}` (ALL/NONE/SINGLE) with or without the ANYONECANPAY
`0x80` bit. This is the validity statement the classifier `htBase_cover`
alone does not make: the defined set is `{ALL,NONE,SINGLE} × ACP`, and
every other byte (including `0x00`, `0x04`, and `0x40`) is rejected. -/
@[rule "INV-055"]
theorem isDefinedHashtype_iff_defined_set (sig : ByteArray) :
    Bitcoin.Interpreter.isDefinedHashtype sig = true ↔
      sig.size ≠ 0 ∧
        (let b := (Bitcoin.Interpreter.byteOr sig (sig.size - 1)).toNat
         b = 0x01 ∨ b = 0x02 ∨ b = 0x03 ∨
           b = 0x81 ∨ b = 0x82 ∨ b = 0x83) := by
  unfold Bitcoin.Interpreter.isDefinedHashtype
  by_cases h : sig.size = 0
  · simp [h]
  · rw [if_neg h, decide_eq_true_iff]
    have hb : ((Bitcoin.Interpreter.byteOr sig (sig.size - 1)).toNat &&& 0x7f)
        = (Bitcoin.Interpreter.byteOr sig (sig.size - 1)).toNat % 128 := by
      rw [show (0x7f : Nat) = 2 ^ 7 - 1 by rfl,
        Nat.and_two_pow_sub_one_eq_mod]
    rw [hb]
    have hlt : (Bitcoin.Interpreter.byteOr sig (sig.size - 1)).toNat < 256 :=
      (Bitcoin.Interpreter.byteOr sig (sig.size - 1)).toNat_lt_size
    constructor
    · intro hd
      exact ⟨h, by omega⟩
    · rintro ⟨_, hset⟩
      omega

/-! ## Legacy digest -/

/-- The modified-vin/vout serialization of
`CTransactionSignatureSerializer::Serialize` (:1337-1356). Inputs beyond
`tx.vin` (and outputs beyond `tx.vout`) use a NULL record — totalization of
Core's `assert(nIn < txTo.vin.size())` precondition, which the interpreter
guarantees; consensus-reachable calls always index in range. -/
def legacyPreimageL (tx : Tx) (nIn : Nat) (scriptCode : Bytes) (ht : UInt32) : Bytes :=
  let acp := htAcp ht
  let single := htBase ht = .singleHt
  let none := htBase ht = .noneHt
  let dummyIn : TxIn := ⟨OutPoint.null, Script.empty, 0⟩
  let dummyOut : TxOut := ⟨0, Script.empty⟩
  let nInputs := if acp then 1 else tx.vin.length
  let serInput (nInput : Nat) : Bytes :=
    let ni := if acp then nIn else nInput
    let i := tx.vin.getD ni dummyIn
    serOutpointL i.prevout
      ++ (if ni ≠ nIn then encCSL 0
          else serializeScriptCodeL scriptCode)
      ++ (if ni ≠ nIn ∧ (single ∨ none) then serU32L 0 else serU32L i.sequence)
  let nOutputs := if none then 0 else if single then nIn + 1 else tx.vout.length
  let serOutput (nOutput : Nat) : Bytes :=
    if single ∧ nOutput ≠ nIn then serNullTxOutL
    else serTxOutL (tx.vout.getD nOutput dummyOut)
  serU32L tx.version.toUInt32
    ++ encCSL nInputs
    ++ (List.range nInputs).foldl (fun acc k => acc ++ serInput k) []
    ++ encCSL nOutputs
    ++ (List.range nOutputs).foldl (fun acc k => acc ++ serOutput k) []
    ++ serU32L tx.locktime

/-- Full legacy message = modified serialization ‖ 4-byte LE hashtype
(:1684-1686 `ss << nHashType`). -/
def legacyMsgL (tx : Tx) (nIn : Nat) (scriptCode : Bytes) (ht : UInt32) : Bytes :=
  legacyPreimageL tx nIn scriptCode ht ++ serU32L ht

/-- Legacy digest (SigVersion::BASE). The out-of-range SINGLE early return
(:1614-1622) fires BEFORE any input indexing; an out-of-range `nIn` (Core:
`assert`ed, consensus-unreachable) totalizes to the zero hash. -/
@[rule "INV-078"]
def signatureHashLegacyImpl (tx : Tx) (nIn : Nat) (scriptCode : Bytes) (ht : UInt32) : ByteArray :=
  if htBase ht = .singleHt ∧ tx.vout.length ≤ nIn then singleOverflowOneB
  else if tx.vin.length ≤ nIn then bytesOfList zeroHashL
  else dshaL (legacyMsgL tx nIn scriptCode ht)

/-- **INV-078** (theorem face): the legacy `SignatureHash` (SigVersion::BASE)
is the full tri-modal construction — out-of-range SIGHASH_SINGLE ⇒
`uint256::ONE`; otherwise an out-of-range input index ⇒ the zero
totalization; otherwise `SHA256d(modified serialization ‖ hashtype)`. -/
@[rule "INV-078"]
theorem signatureHashLegacyImpl_eq_cases (tx : Tx) (nIn : Nat)
    (scriptCode : Bytes) (ht : UInt32) :
    signatureHashLegacyImpl tx nIn scriptCode ht =
      (if htBase ht = .singleHt ∧ tx.vout.length ≤ nIn then singleOverflowOneB
       else if tx.vin.length ≤ nIn then bytesOfList zeroHashL
       else dshaL (legacyMsgL tx nIn scriptCode ht)) := rfl

/-- **INV-078** (construction + early-return order): an out-of-range
SIGHASH_SINGLE returns the overflow constant (`singleOverflowOneB`) — the
early return fires BEFORE any `vin` indexing, so this holds even when
`nIn` is also outside `tx.vin`. The constant is exactly Core's
`uint256::ONE` (`01 00 … 00`), see
`singleOverflowOneB_eq_uint256OneCoreB`. -/
@[rule "INV-078"]
theorem signatureHashLegacyImpl_single_overflow (tx : Tx) (nIn : Nat)
    (scriptCode : Bytes) (ht : UInt32)
    (hs : htBase ht = .singleHt) (ho : tx.vout.length ≤ nIn) :
    signatureHashLegacyImpl tx nIn scriptCode ht = singleOverflowOneB := by
  simp [signatureHashLegacyImpl, hs, ho]

/-- **INV-078**: outside the SINGLE overflow arm, an in-range input yields
the double-SHA256 of the modified transaction serialization with the
4-byte LE hashtype suffix (`legacyMsgL`). -/
@[rule "INV-078"]
theorem signatureHashLegacyImpl_in_range (tx : Tx) (nIn : Nat)
    (scriptCode : Bytes) (ht : UInt32)
    (hnot : ¬ (htBase ht = .singleHt ∧ tx.vout.length ≤ nIn))
    (hin : nIn < tx.vin.length) :
    signatureHashLegacyImpl tx nIn scriptCode ht =
      dshaL (legacyMsgL tx nIn scriptCode ht) := by
  simp [signatureHashLegacyImpl, hnot, Nat.not_le.mpr hin]

/-! ## BIP143 digest (`interpreter.cpp:1633-1670`) -/

/-- `hashPrevouts` (:1639-1641): dSHA256 of all outpoints, zero if ACP. -/
def hashPrevoutsL (tx : Tx) (ht : UInt32) : Bytes :=
  if htAcp ht then zeroHashL
  else bL (dshaL (
    (tx.vin.foldl (fun acc i => acc ++ serOutpointL i.prevout) [])))

/-- `hashSequence` (:1643-1645): dSHA256 of all nSequence, zero if ACP or
SINGLE or NONE. -/
def hashSequenceL (tx : Tx) (ht : UInt32) : Bytes :=
  if htAcp ht ∨ htBase ht = .singleHt ∨ htBase ht = .noneHt then zeroHashL
  else bL (dshaL (
    (tx.vin.foldl (fun acc i => acc ++ serU32L i.sequence) [])))

/-- `hashOutputs` (:1647-1653): dSHA256 of all outputs; SINGLE in range ⇒
dSHA256 of the single output at nIn; otherwise ZERO (not uint256::ONE —
the tri-modal SIGHASH_SINGLE, BIP143 branch; rule SCR-141/SWT-046). -/
def hashOutputsL (tx : Tx) (nIn : Nat) (ht : UInt32) : Bytes :=
  match htBase ht with
  | .singleHt =>
      if nIn < tx.vout.length then
        bL (dshaL ( (serTxOutL (tx.vout.getD nIn ⟨0, Script.empty⟩))))
      else zeroHashL
  | .noneHt => zeroHashL
  | .all => bL (dshaL (
      (tx.vout.foldl (fun acc o => acc ++ serTxOutL o) [])))

/-- The 10-field BIP143 preimage (:1660-1670), in order. `amount` = the spent
output's value (field 6; BIP143's raison d'être — commits cold wallets to the
amount being spent). -/
@[rule "SWT-050", rule "SWT-051", rule "SCR-140"]
def bip143MsgL (tx : Tx) (nIn : Nat) (scriptCode : Bytes) (ht : UInt32) (amount : Amount) : Bytes :=
  -- SWT-050: the 8-byte LE spent amount inside the digest (`serAmountL`).
  -- SWT-051: the digest ends with the 4-byte LE hashtype (`serU32L ht`),
  -- appended unconditionally (no cache short-circuit in the model).
  let i := tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩
  serU32L tx.version.toUInt32
    ++ hashPrevoutsL tx ht
    ++ hashSequenceL tx ht
    ++ serOutpointL i.prevout
    ++ encCSL scriptCode.length ++ scriptCode
    ++ serAmountL amount
    ++ serU32L i.sequence
    ++ hashOutputsL tx nIn ht
    ++ serU32L tx.locktime
    ++ serU32L ht

/-- BIP143 digest (SigVersion::WITNESS_V0). Out-of-range `nIn` totalizes to
the zero hash (Core: `assert(nIn < txTo.vin.size())`); Core's `amount ≥ 0`
missing-data assert is the caller's obligation (SWT-055; negative amounts
serialize two's-complement, see `serAmountL`). SWT-042: the 10-field
preimage structure (version, 3 sub-hashes, outpoint, scriptCode, amount,
sequence, outputs-hash, locktime, hashtype). -/
@[rule "SWT-042"]
def signatureHashBip143Impl (tx : Tx) (nIn : Nat) (scriptCode : Bytes) (ht : UInt32)
    (amount : Amount) : ByteArray :=
  if tx.vin.length ≤ nIn then bytesOfList zeroHashL
  else dshaL (bip143MsgL tx nIn scriptCode ht amount)

/-! ## Witness-v0 scriptCode construction (`interpreter.cpp:1949-1958`) -/

/-- P2WPKH scriptCode re-derivation (:1952): from the 20-byte witness
program — `CScript() << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY
<< OP_CHECKSIG`, i.e. `0x76 0xa9 0x14 {pkh} 0x88 0xac`. The hash comes from
the scriptPubKey, not from the witness pubkey (the executed OP_EQUALVERIFY
checks the witness pubkey against it). The CompactSize length prefix is
added by the digest serialization itself (`bip143MsgL`), matching
`CTxOut`-style script serialization. -/
def p2wpkhScriptCodeL (pkh : Bytes) : Bytes :=
  [0x76, 0xa9, 0x14] ++ pkh ++ [0x88, 0xac]

/-- P2WSH scriptCode = the witness script itself (`pbegincodehash`
subscript, BIP143:43-44) — **no** `FindAndDelete`, unexecuted
OP_CODESEPARATORs retained. The only size rule: the 10,000-byte
`MAX_SCRIPT_SIZE` applies to the witnessScript as EXECUTED
(:438-440) — a `VerifyWitnessProgram` reject BEFORE any signature check;
there is no scriptCode size limit for hashing. -/
def witnessScriptSizeOk (script : Bytes) : Bool := script.length ≤ 10000

/-- Convenience entry: BIP143 digest for a P2WPKH program (20-byte pkh). -/
def signatureHashBip143P2wpkh (tx : Tx) (nIn : Nat) (pkh : Bytes) (ht : UInt32)
    (amount : Amount) : ByteArray :=
  signatureHashBip143Impl tx nIn (p2wpkhScriptCodeL pkh) ht amount

end Bitcoin.SigHash
