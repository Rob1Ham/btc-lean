import Bitcoin.Capstone.Block
import Test.Capstone.TaprootFixture

/-! R07a: candidate-hash flags must reach script execution as well as costs.
Real block170/parent169 bytes are used with explicitly conditional height and
UTXO context; see data/review/script-flags/provenance.json. -/

namespace Test.Capstone.ScriptFlags

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block Bitcoin.Capstone.Context
open Bitcoin.Capstone.Pow Bitcoin.Serialization Bitcoin.Activation

private def height : UInt32 := 170060
private def result (r : Except CapError CapReport) : String :=
  match r with
  | .error e => e.reason
  | .ok report => s!"{if report.fullValidation then "ok" else "partial"}:{report.scriptOk}:{report.scriptUnjudged}"

def run : IO UInt32 := do
  let raw ← IO.FS.readBinFile "../data/review/script-flags/block170.raw"
  let parentRaw ← IO.FS.readBinFile "../data/review/script-flags/parent169.header"
  let (header, txs) ← match decodeBlock raw with
    | .error e => throw (IO.userError s!"block fixture decode: {repr e}")
    | .ok p => pure p
  let parent ← match decodeBlockHeader parentRaw with
    | .error e => throw (IO.userError s!"parent fixture decode: {repr e}")
    | .ok h => pure h
  let (cb, tx) ← match txs with
    | [cb, tx] => pure (cb, tx)
    | _ => throw (IO.userError "expected coinbase and one spend")
  let input ← match tx.vin with
    | [input] => pure input
    | _ => throw (IO.userError "expected one input")
  let redeem := input.scriptSig.bytes.extract 1 input.scriptSig.bytes.size
  let badSpk := List.toByteArray [0xa9, 20] ++ Bitcoin.Crypto.Seam.Hash.hash160 redeem ++
    List.toByteArray [0x87]
  let goodCoin : Coin := ⟨tx.getValueOut, 0, false, ⟨List.toByteArray [0x51]⟩⟩
  let badCoin := { goodCoin with scriptPubKey := ⟨badSpk⟩ }
  let state := fun (c : Coin) =>
    ({ height := height
       prevHash := header.hashPrevBlock
       utxo := [(input.prevout, c)] } : CapState)
  let ctx : ChainContext :=
    { parentHeight := height.toNat-1
      headerAt := fun n => if n == height.toNat-1 then some parent
        else if n < height.toNat-1 then some { parent with time := 0 } else none
      nodeTime := 2000000000 }
  let active := candidateScriptFlags height header
  let excepted := getBlockScriptFlagsP mainnetParams bip16ExceptionHash height
  let stage := fun h flags coin =>
    match applyBlockTransactionsWithSigops none h flags [cb, tx] [(input.prevout, coin)] with
    | .error e => e.reason
    | .ok ((_, ok, unjudged), _) => s!"ok:{ok}:{unjudged}"
  let (tapRaw, _, tapCoins) ← Test.Capstone.TaprootFixture.load
  let (tapHeader, tapTxs) ← Test.Capstone.TaprootFixture.decode tapRaw
  let altered := tapCoins.mapIdx fun i pair =>
    if i == 0 then (pair.1, { pair.2 with value := pair.2.value+1 }) else pair
  let tapActive := candidateScriptFlags 692261 tapHeader
  let tapExcepted := getBlockScriptFlagsP mainnetParams taprootExceptionHash 709632
  let tapStage := fun h flags coins =>
    match applyBlockTransactionsWithSigops none h flags tapTxs coins with
    | .error e => e.reason
    | .ok ((_, ok, unjudged), _) => s!"ok:{ok}:{unjudged}"
  let selectorData ← Test.Capstone.TaprootFixture.lift (Lean.Json.parse
    (← IO.FS.readFile "../data/review/script-flags/provenance.json"))
  let selectorRows ← Test.Capstone.TaprootFixture.arr selectorData "flagCases"
  let flagCode := fun (f : ScriptFlags) => String.intercalate ":"
    [toString f.p2sh, toString f.witness, toString f.taproot, toString f.dersig,
     toString f.cltv, toString f.csv, toString f.nullDummy]
  let selectorChecks ← selectorRows.mapM fun row => do
    let name ← Test.Capstone.TaprootFixture.str row "name"
    let digest := Test.Capstone.TaprootFixture.fromHex
      (← Test.Capstone.TaprootFixture.str row "hash")
    let hash := digest.data.foldl (fun n byte => n*256 + byte.toNat) 0
    let atHeight := (← Test.Capstone.TaprootFixture.nat row "height").toUInt32
    let expected ← Test.Capstone.TaprootFixture.str row "flags"
    pure ("selector "++name, flagCode (getBlockScriptFlagsP mainnetParams hash atHeight), expected)
  let checks : List (String × String × String) :=
    [("alternate hash retains P2SH flag", toString active.p2sh, "true"),
     ("named hash selects exception flags", toString excepted.p2sh, "false"),
     ("public replay valid control", result (replayBlockPartial raw (state goodCoin)), "partial:1:0"),
     ("public context valid control", result (validateBlockInContext raw (state goodCoin) ctx), "ok:1:0"),
     ("public replay alternate hash executes P2SH", result (replayBlockPartial raw (state badCoin)),
        "script-verify-error"),
     ("public context alternate hash executes P2SH",
        result (validateBlockInContext raw (state badCoin) ctx), "script-verify-error"),
     ("resource fold executes supplied active flags", stage height active badCoin, "script-verify-error"),
     ("resource fold executes supplied exception flags", stage 200 excepted badCoin, "ok:1:0"),
     ("alternate hash retains Taproot flag", toString tapActive.taproot, "true"),
     ("resource fold valid Taproot control", tapStage 692261 tapActive tapCoins, "ok:12:0"),
     ("resource fold alternate hash binds Taproot amount", tapStage 692261 tapActive altered,
        "script-verify-error"),
     ("resource fold applies named Taproot exception", tapStage 709632 tapExcepted altered, "ok:12:0")]
      ++ selectorChecks
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  IO.println s!"script-flag checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.ScriptFlags

def main : IO UInt32 := Test.Capstone.ScriptFlags.run
