import Bitcoin.Capstone.Block
import Test.Capstone.TaprootFixture

/-! R07d public regressions. Historical bytes are immutable; caller-supplied
UTXOs, alternate heights and ancestor windows are conditional test input.
See data/review/bip30/provenance.json. -/

namespace Test.Capstone.Bip30

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block Bitcoin.Capstone.Context
open Bitcoin.Capstone.Pow Bitcoin.Serialization

private def load (file parentFile : String) :
    IO (ByteArray × Bitcoin.Chain.BlockHeader × List Tx × Bitcoin.Chain.BlockHeader) := do
  let raw ← IO.FS.readBinFile file
  let (header, txs) ← Test.Capstone.TaprootFixture.decode raw
  let parentBytes ← IO.FS.readBinFile parentFile
  let parent ← match decodeBlockHeader parentBytes with
    | .error e => throw (IO.userError s!"parent fixture decode: {repr e}")
    | .ok h => pure h
  return (raw, header, txs, parent)

private def funded (txs : List Tx) : List (OutPoint × Coin) :=
  let cb := txs.getD 0 dummyTx
  txs.flatMap fun tx => if tx.isCoinBase then [] else
    tx.vin.mapIdx fun i input =>
      (input.prevout, ⟨if i == 0 then tx.getValueOut + cb.getValueOut else 0,
        0, false, ⟨List.toByteArray [0x51]⟩⟩)

private def overlap (txs : List Tx) : OutPoint × Coin :=
  (txidKey (txs.getD 0 dummyTx) OutPoint.null 0,
   ⟨1, 0, false, ⟨List.toByteArray [0x51]⟩⟩)

private def history (height : UInt32) (parent : Bitcoin.Chain.BlockHeader) : ChainContext :=
  { parentHeight := height.toNat-1
    headerAt := fun n => if n == height.toNat-1 then some parent
      else if n < height.toNat-1 then some { parent with time := 0 } else none
    nodeTime := 2000000000 }

private def ledgerCode : Except BlockError (List (OutPoint × Coin)) → String
  | .error BlockError.badTxnsBIP30 => "bad-txns-BIP30"
  | .error _ => "ledger-error"
  | .ok _ => "ok"

private def code : Except CapError CapReport → String
  | .error e => e.reason
  | .ok _ => "ok"

private def verdict (raw : ByteArray) (header parent : Bitcoin.Chain.BlockHeader)
    (height : UInt32) (coins : List (OutPoint × Coin)) (contextual : Bool) : String :=
  let state : CapState := { height := height, prevHash := header.hashPrevBlock, utxo := coins }
  code (if contextual then validateBlockInContext raw state (history height parent)
        else replayBlock raw state)

def publicChecks : IO (List (String × String × String)) := do
  let dir := "../data/review/bip30/"
  let (rawA, headerA, txsA, parentA) ← load (dir++"block91842.raw") (dir++"parent91841.header")
  let (rawB, headerB, txsB, parentB) ← load (dir++"block91880.raw") (dir++"parent91879.header")
  let (rawAlt, headerAlt, txsAlt, parentAlt) ← load "../data/review/script-flags/block170.raw"
    "../data/review/script-flags/parent169.header"
  let mut checks : List (String × String × String) := []
  for contextual in [false, true] do
    let mode := if contextual then "context" else "replay"
    let cases :=
      [("canonical repeat 91842", verdict rawA headerA parentA 91842
          (overlap txsA :: funded txsA) contextual, "ok"),
       ("canonical repeat 91880", verdict rawB headerB parentB 91880
          (overlap txsB :: funded txsB) contextual, "ok"),
       ("crossed repeat hash at 91842", verdict rawB headerB parentB 91842
          (overlap txsB :: funded txsB) contextual, "bad-txns-BIP30"),
       ("crossed repeat hash at 91880", verdict rawA headerA parentA 91880
          (overlap txsA :: funded txsA) contextual, "bad-txns-BIP30"),
       ("alternate hash collision at 91842", verdict rawAlt headerAlt parentAlt 91842
          (overlap txsAlt :: funded txsAlt) contextual, "bad-txns-BIP30"),
       ("alternate hash collision at 91880", verdict rawAlt headerAlt parentAlt 91880
          (overlap txsAlt :: funded txsAlt) contextual, "bad-txns-BIP30"),
       ("alternate no collision at 91842", verdict rawAlt headerAlt parentAlt 91842
          (funded txsAlt) contextual, "ok"),
       ("alternate no collision at 91880", verdict rawAlt headerAlt parentAlt 91880
          (funded txsAlt) contextual, "ok"),
       ("BIP30 precedes missing input", verdict rawAlt headerAlt parentAlt 91842
          [overlap txsAlt] contextual, "bad-txns-BIP30")]
    checks := checks ++ cases.map (fun (name, actual, expected) => (mode++" "++name, actual, expected))
  let (tapRaw, _, tapCoins) ← Test.Capstone.TaprootFixture.load
  let (tapHeader, tapTxs) ← Test.Capstone.TaprootFixture.decode tapRaw
  let ancestorBytes ← IO.FS.readBinFile (dir++"bip34-227931.header")
  let canonicalAncestor ← match decodeBlockHeader ancestorBytes with
    | .error e => throw (IO.userError s!"BIP34 fixture decode: {repr e}")
    | .ok h => pure h
  let base := Test.Capstone.TaprootFixture.context
  let pinned := { base with headerAt := fun n => if n == 227931 then some canonicalAncestor else base.headerAt n }
  let missing := { base with headerAt := fun n => if n == 227931 then none else base.headerAt n }
  let state := fun coins => ({ height := 709632, prevHash := tapHeader.hashPrevBlock, utxo := coins } : CapState)
  let collided := overlap tapTxs :: tapCoins
  checks := checks ++
    [("window replay collision needs ancestor", code (replayBlock tapRaw (state collided)), "context-missing-ancestor"),
     ("window noncanonical ancestor enforces BIP30",
       code (validateBlockInContext tapRaw (state collided) base), "bad-txns-BIP30"),
     ("window missing ancestor is unavailable",
       code (validateBlockInContext tapRaw (state collided) missing), "context-missing-ancestor"),
     ("window canonical ancestor permits collision",
       code (validateBlockInContext tapRaw (state collided) pinned), "ok"),
     ("window replay no collision needs no ancestor", code (replayBlock tapRaw (state tapCoins)), "ok"),
     ("window noncanonical ancestor no collision control",
       code (validateBlockInContext tapRaw (state tapCoins) base), "ok")]
  let ledgerState := overlap txsAlt :: funded txsAlt
  checks := checks ++
    [("ledger height-only exception accepts fork collision",
       ledgerCode (applyBlockExec ledgerState txsAlt 91842), "ok"),
     ("ledger exact own-hash rejects fork collision",
       ledgerCode (applyBlockExecTxid ledgerState txsAlt 91842 0 0), "bad-txns-BIP30"),
     ("ledger exact canonical repeat accepts",
       ledgerCode (applyBlockExecTxid ledgerState txsAlt 91842
         (BIP30_REPEAT_HASH_OF_HEIGHT 91842) BIP34_ACTIVATION_HASH), "ok")]
  return checks

def runPublic : IO UInt32 := do
  let checks ← publicChecks
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  IO.println s!"bip30-public checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.Bip30

def main : IO UInt32 := Test.Capstone.Bip30.runPublic
