import Bitcoin.Capstone.Block
import Bitcoin.Block.Params
import Lean.Data.Json.Parser

/-! Shared strict fixture decoding. All ancestor and UTXO state is supplied
conditional test input. Official public test keys have no monetary value. -/
namespace Test.Capstone.TaprootFixture
open Bitcoin.Data Bitcoin.Ledger Bitcoin.Serialization Bitcoin.Capstone.Block
open Bitcoin.Capstone.Context Bitcoin.Capstone.Pow Bitcoin.Block.Params
open Lean

def fromHex (s : String) : ByteArray :=
  List.toByteArray ((s.toList.toArray.toList.zipIdx).filterMap fun (c, i) =>
    if i % 2 = 0 then
      let digit := fun ch => if ch ≥ '0' && ch ≤ '9' then ch.toNat - 48
        else ch.toNat - 87
      some ((digit c * 16 + digit (s.toList.getD (i+1) '0')).toUInt8)
    else none)

def lift (e : Except String α) : IO α :=
  match e with
  | .ok x => pure x
  | .error e => throw (IO.userError e)
def field (j : Json) (key : String) : IO Json := lift (j.getObjVal? key)
def str (j : Json) (key : String) : IO String := field j key >>= fun x => lift x.getStr?
def nat (j : Json) (key : String) : IO Nat := field j key >>= fun x => lift x.getNat?
def arr (j : Json) (key : String) : IO (List Json) :=
  field j key >>= fun x => return (← lift x.getArr?).toList

def load : IO (ByteArray × Json × List (OutPoint × Coin)) := do
  let dir := "../data/review/taproot-validation/"
  let raw ← IO.FS.readBinFile (dir ++ "valid.raw")
  let metadata ← lift (Json.parse (← IO.FS.readFile (dir ++ "provenance.json")))
  let rows ← arr metadata "initialCoins"
  let coins ← rows.mapM fun row => do
    let outpoint : OutPoint := ⟨fromHex (← str row "txid"), (← nat row "n").toUInt32⟩
    let coin : Coin := ⟨Int.ofNat (← nat row "amount"), 100, false,
      ⟨fromHex (← str row "scriptPubKey")⟩⟩
    return (outpoint, coin)
  return (raw, metadata, coins)

def decode (raw : ByteArray) : IO (Bitcoin.Chain.BlockHeader × List Tx) :=
  match decodeBlock raw with
  | .error e => throw (IO.userError s!"block decode: {repr e}")
  | .ok x => pure x

def transaction (raw : ByteArray) : IO Tx :=
  match decodeTx raw with
  | .error e => throw (IO.userError s!"tx decode: {repr e}")
  | .ok x => pure x

def context : ChainContext :=
  { parentHeight := 709631
    headerAt := fun n => if n < 709632 then
      some (if n = 707616 then { genesisHeader with time := genesisHeader.time - 1209600 }
        else if n < 1000 then { genesisHeader with time := genesisHeader.time - 50000000 }
        else genesisHeader) else none
    nodeTime := 2000000000 }

def state (coins : List (OutPoint × Coin)) : CapState :=
  { height := 709632, prevHash := headerHash genesisHeader, utxo := coins }

def verdict : InputVerdict → String
  | .pass => "pass"
  | .unjudgedTaproot => "unjudged"
  | .fail (.scriptFail _ _ e) => reprStr e
  | .fail e => e.reason
end Test.Capstone.TaprootFixture
