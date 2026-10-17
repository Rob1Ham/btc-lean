import Bitcoin.RuleAttr
import Bitcoin.Data.Tx

/-!
# Bitcoin.Consensus.TxCheck

Stateless transaction checks — a direct transliteration of
`CheckTransaction` in `src/consensus/tx_check.cpp`
(Bitcoin Core @ cce32b1682d86076ee71c10f9788c48d44458a263).

Every failure carries the exact Core rejection reason string so the
traceability matrix (rule-ID database) can reference it.
-/


namespace Bitcoin.Consensus

open Bitcoin.Data

/-- Constants from `src/consensus/consensus.h`. -/
def WITNESS_SCALE_FACTOR : Nat := 4
def MAX_BLOCK_WEIGHT : Nat := 4000000
def MIN_CB_LENGTH : Nat := 2      -- `bad-cb-length` bounds
def MAX_CB_LENGTH : Nat := 100

/-- Rejection reasons, one per Core failure return in `CheckTransaction`. -/
inductive TxCheckError where
  | vinEmpty          -- "bad-txns-vin-empty"
  | voutEmpty         -- "bad-txns-vout-empty"
  | oversize          -- "bad-txns-oversize"
  | voutNegative      -- "bad-txns-vout-negative"      (CVE-2010-5139)
  | voutTooLarge      -- "bad-txns-vout-toolarge"
  | txoutTotalTooLarge -- "bad-txns-txouttotal-toolarge"
  | inputsDuplicate   -- "bad-txns-inputs-duplicate"   (CVE-2018-17144)
  | cbLength          -- "bad-cb-length"
  | prevoutNull       -- "bad-txns-prevout-null"
deriving Repr, DecidableEq

/-- Core loops a `std::set<COutPoint>`; we do the O(n²) pairwise scan
Core explicitly comments on (tx_check.cpp:56). BLK-031 (`bad-txns-inputs-duplicate`,
CVE-2018-17144) — no two inputs of one tx share an outpoint. -/
@[rule "BLK-031"]
def hasDupPrevouts : List TxIn → Bool
  | [] => false
  | i :: rest => rest.any (fun j => j.prevout == i.prevout) || hasDupPrevouts rest

/-- BIP141 weight model, replicated from the frozen W01 interface to keep
this module below `DataLaws` in the import graph. `txWeightL tx` is
*definitionally* `Bitcoin.DataLaws.txWeight tx` (same subterms: `serTx`
from `Bitcoin.Data.Tx`, the BIP144 framing of `serWitnessStack` /
`serTxWithWitness` from `DataLaws/Interface.lean:46-73`). -/
private def serWitnessStackW (s : List ByteArray) : ByteArray :=
  compactSizeEnc s.length ++
    s.foldl (fun acc item => acc ++ compactSizeEnc item.size ++ item) ByteArray.empty

private def serTxWithWitnessW (tx : Tx) : ByteArray :=
  serU32 tx.version.toUInt32
    ++ (ByteArray.empty.push 0x00).push 0x01
    ++ compactSizeEnc tx.vin.length
    ++ tx.vin.foldl (fun acc i => acc ++ serTxIn i) ByteArray.empty
    ++ compactSizeEnc tx.vout.length
    ++ tx.vout.foldl (fun acc o => acc ++ serTxOut o) ByteArray.empty
    ++ (List.range tx.vin.length).foldl
         (fun acc i => acc ++ serWitnessStackW (tx.witness.getD i [])) ByteArray.empty
    ++ serU32 tx.locktime

/-- `GetTransactionWeight` (consensus/validation.h:139-142):
`weight = base·(WITNESS_SCALE_FACTOR−1) + total`. BIP141. This is the
BLOCK weight metric; `CheckTransaction`'s stateless oversize gate uses
`txStrippedWeightL` below, not this. -/
def txWeightL (tx : Tx) : Nat :=
  3 * serTxSize tx + (serTxWithWitnessW tx).size

/-- Core's `CheckTransaction` oversize gate (`consensus/tx_check.cpp:27-29`
@cce32b168): `GetSerializeSize(TX_NO_WITNESS(tx)) * WITNESS_SCALE_FACTOR`
— witness data and the BIP144 marker/flag are deliberately excluded. -/
def txStrippedWeightL (tx : Tx) : Nat :=
  serTxSize tx * WITNESS_SCALE_FACTOR

/-- `CheckTransaction` (`consensus/tx_check.cpp:23`).

Traceability: this single function implements the stateless-check rows
INV-001..009 and TXV-001..009 of the rule DB (`spec/db/rules.yaml`);
INV-003/TXV-003 (oversize) use Core's stripped-size gate
`4 * serTxSize tx > MAX_BLOCK_WEIGHT` (`txStrippedWeightL`, F-TS04-001).
The BIP141 transaction weight `txWeightL = 3·base + total` is kept for
block-weight consumers and is no longer the stateless gate. -/
@[rule "INV-001", rule "INV-002", rule "INV-004", rule "INV-005",
  rule "INV-006", rule "INV-007", rule "INV-008", rule "INV-009",
  rule "TXV-001", rule "TXV-002", rule "TXV-004", rule "TXV-005",
  rule "TXV-006", rule "TXV-007", rule "TXV-008", rule "TXV-009", rule "BLK-032"]
def checkTransaction (tx : Tx) : Option TxCheckError :=
  if tx.vin.isEmpty then some .vinEmpty                          -- bad-txns-vin-empty
  else if tx.vout.isEmpty then some .voutEmpty                   -- bad-txns-vout-empty
  else if txStrippedWeightL tx > MAX_BLOCK_WEIGHT then some .oversize
  else if let some e := checkOutputs tx.vout 0 then some e
  else if hasDupPrevouts tx.vin then some .inputsDuplicate
  else if tx.isCoinBase then
    let len := match tx.vin with
      | [i] => i.scriptSig.bytes.size
      | _ => 0
    if len < MIN_CB_LENGTH || len > MAX_CB_LENGTH then some .cbLength else none
  else
    if tx.vin.any (fun i => i.prevout.isNull) then some .prevoutNull else none
where
  /-- The negative/overflow output loop (CVE-2018-17153-style accumulation
  guard; Core comment cites CVE-2010-5139 for the negative check). -/
  checkOutputs : List TxOut → Amount → Option TxCheckError
    | [], _ => none
    | o :: rest, acc =>
        if o.value < 0 then some .voutNegative
        else if o.value > MAX_MONEY then some .voutTooLarge
        else
          let acc' := acc + o.value
          if ¬ MoneyRange acc' then some .txoutTotalTooLarge
          else checkOutputs rest acc'

end Bitcoin.Consensus
