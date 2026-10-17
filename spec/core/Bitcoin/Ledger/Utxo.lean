import Bitcoin.Data.Tx

/-!
# Bitcoin.Ledger.Utxo

The PoC's UTXO model: an **abstract function** `OutPoint → Option Coin`,
with one concrete executable representation (association list) plus the
abstraction lemma tying them together. See report 10 for the full
options analysis and migration story.
-/


namespace Bitcoin.Ledger

open Bitcoin.Data

/-- A coin: an unspent output (`src/coins.h`, `Coin`).
Height is needed for BIP34-style maturity; the PoC only models the value
and the script. BLK-101: value + script + creation height + coinbase bit
(31+1 bits on disk; explicit fields here). -/
@[rule "BLK-101", rule "INV-114"]
structure Coin where
  value : Amount
  height : UInt32
  isCoinbase : Bool
  scriptPubKey : Script
deriving Repr, BEq

/-- The abstract UTXO set: a partial function from outpoints to coins.
This is the type the **theorems** are stated over. -/
def UtxoSet := OutPoint → Option Coin

/-- Executable representation, milestone M0: association list. -/
def UtxoList := List (OutPoint × Coin)

def utxoLookup (l : UtxoList) (o : OutPoint) : Option Coin :=
  match l.find? (fun p => p.1 == o) with
  | some ⟨_, c⟩ => some c
  | none => none

/-- Apply a transaction to the ledger view: remove spent prevouts
(CCoinsViewCache::SpendCoin) and add `index`-th output as new coin
(CCoinsViewCache::AddCoin). Total function: invalid spends are no-ops
here — real validation gates this behind `checkTransaction` +
`CheckTxInputs`. -/
def applyTx (l : UtxoList) (tx : Tx) : UtxoList :=
  let spent := l.filter (fun p => ¬ (tx.vin.any (fun i => i.prevout == p.1)))
  let newCoins := (List.range tx.vout.length).map (fun k =>
    let o := tx.vout.getD k ⟨0, Script.empty⟩
    -- placeholder key = OutPoint.null; real key = (txid, k) once txid lands (M1)
    (OutPoint.null, ⟨o.value, 0, false, o.scriptPubKey⟩))
  spent ++ newCoins

end Bitcoin.Ledger
