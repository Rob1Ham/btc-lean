import Bitcoin.RuleAttr
import Bitcoin.Data.Basic
import Bitcoin.Data.Script

/-!
# Bitcoin.Data.Tx

Transaction primitives: `COutPoint`, `CTxIn`, `CTxOut`, `CTxWitness`,
`CTransaction` (`src/primitives/transaction.h`) and the base
(no-witness) serializer of `src/primitives/transaction.cpp`
(`CTransaction::Serialize`).

The txid-relevant serialization is exactly `TX_NO_WITNESS`.
-/


namespace Bitcoin.Data

/-! ## `COutPoint` (`primitives/transaction.h:16`) -/

/-- `NULL_INDEX = 0xFFFFFFFF` (`transaction.h:14`). -/
def NULL_INDEX : UInt32 := 0xFFFFFFFF

structure OutPoint where
  hash : ByteArray    -- 32-byte txid, little-endian on the wire
  n : UInt32
deriving Repr

/-- `n` zero bytes — e.g. the 32-byte null txid of a coinbase input. -/
def zeroBytes (n : Nat) : ByteArray :=
  (List.range n).foldl (fun acc _ => acc.push 0) ByteArray.empty

/-- `COutPoint::IsNull()` requires the hash to be 32 zero bytes
(`uint256::IsNull`, `primitives/transaction.h:43`). -/
def OutPoint.isNull (o : OutPoint) : Bool :=
  o.n = NULL_INDEX ∧ o.hash.size = 32 ∧
  (List.range o.hash.size).all (fun i => o.hash.get! i == 0)

def OutPoint.null : OutPoint := ⟨zeroBytes 32, NULL_INDEX⟩

instance : BEq OutPoint where
  beq a b := bytesBEq a.hash b.hash && a.n == b.n

/-! ## `CTxIn` / `CTxOut` / witness (`primitives/transaction.h:120,163,196`) -/

structure TxIn where
  prevout : OutPoint
  scriptSig : Script
  sequence : UInt32      -- SEQUENCE_FINAL = 0xFFFFFFFF
deriving Repr

structure TxOut where
  value : Amount         -- CAmount nValue
  scriptPubKey : Script
deriving Repr

/-- Witness stack for one input (`CTxWitness`); one entry per `vin`. -/
abbrev WitnessStack := List ByteArray

/-! ## `CTransaction` (`primitives/transaction.h:279`) -/

structure Tx where
  version : Int32
  vin : List TxIn
  vout : List TxOut
  locktime : UInt32
  witness : List WitnessStack   -- parsed but not serialized by the PoC
deriving Repr

/-- `CTransaction::IsCoinBase()` (`transaction.h:347`). Implements
rule-DB rows INV-010 / TXV-010. -/
@[rule "INV-010", rule "TXV-010"]
def Tx.isCoinBase (tx : Tx) : Bool :=
  match tx.vin with
  | [i] => i.prevout.isNull
  | _ => false

/-- **INV-010 / TXV-010 face**: the classification predicate holds exactly
for a transaction with one input whose prevout is null (`transaction.h:347`:
`vin.size() == 1 && vin[0].prevout.IsNull()`). This is the theorem face of
`Tx.isCoinBase`; the definition alone cannot entail the row claim. -/
@[rule "INV-010"]
theorem Tx.isCoinBase_iff (tx : Tx) :
    tx.isCoinBase = true ↔
      ∃ i : TxIn, tx.vin = [i] ∧ i.prevout.isNull = true := by
  unfold Tx.isCoinBase
  cases tx.vin with
  | nil => simp
  | cons i rest =>
    cases rest with
    | nil => simp
    | cons j rest => simp

/-- **INV-010 / TXV-010 reject face**: a transaction with two or more
inputs is never a coinbase (`vin.size() == 1` fails). -/
@[rule "INV-010"]
theorem Tx.not_isCoinBase_of_two (tx : Tx) (h : 2 ≤ tx.vin.length) :
    tx.isCoinBase = false := by
  unfold Tx.isCoinBase
  cases hvin : tx.vin with
  | nil =>
    rw [hvin] at h
  | cons a rest =>
    cases hrest : rest with
    | nil =>
      rw [hvin, hrest] at h
      simp at h
    | cons b rest => rfl

/-- **INV-010 / TXV-010 reject face**: a transaction with no inputs is
never a coinbase. -/
@[rule "INV-010"]
theorem Tx.not_isCoinBase_nil (tx : Tx) (h : tx.vin = []) :
    tx.isCoinBase = false := by
  simp [Tx.isCoinBase, h]

/-- `CTransaction::GetValueOut()` (`primitives/transaction.cpp`).
The PoC returns a `Nat` sum; callers check `MoneyRange` first via
`checkTransaction`, mirroring the invariant order in `tx_check.cpp`. -/
def Tx.getValueOut (tx : Tx) : Amount :=
  tx.vout.foldl (fun acc o => acc + o.value) 0

/-! ## Base serialization (`CTransaction::Serialize`, TX_NO_WITNESS) -/

def serTxIn (i : TxIn) : ByteArray :=
  i.prevout.hash ++ serU32 i.prevout.n ++ compactSizeEnc i.scriptSig.bytes.size
    ++ i.scriptSig.bytes ++ serU32 i.sequence

/-- Core serializes the raw `int64_t` bit pattern, so negative values are
written in two's complement (not clamped/folded). Aligned with
`Bitcoin.Serialization.amtToU64`. -/
def serTxOut (o : TxOut) : ByteArray :=
  serU64 (UInt64.ofNat (amtToU64 o.value))
    ++ compactSizeEnc o.scriptPubKey.bytes.size ++ o.scriptPubKey.bytes

/-- Serialize the base transaction (what txid is computed over). -/
def serTx (tx : Tx) : ByteArray :=
  serU32 tx.version.toUInt32
    ++ compactSizeEnc tx.vin.length
    ++ tx.vin.foldl (fun acc i => acc ++ serTxIn i) ByteArray.empty
    ++ compactSizeEnc tx.vout.length
    ++ tx.vout.foldl (fun acc o => acc ++ serTxOut o) ByteArray.empty
    ++ serU32 tx.locktime

/-- Approximate `::GetSerializeSize(TX_NO_WITNESS(tx))` used by the
oversize rule in `tx_check.cpp`. -/
def serTxSize (tx : Tx) : Nat := (serTx tx).size

end Bitcoin.Data
