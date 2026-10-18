import Bitcoin.Capstone.Block
import Bitcoin.Block.Params

/-! R05 public-byte regressions. The mined candidate has genuine difficulty-one
PoW and a BIP34 height of 481824. The supplied ancestor index is conditional
test input, not a claim that the header is on a valid mainnet chain. Mutating
only coinbase witness data leaves the header, txid and merkle root unchanged. -/

namespace Test.Capstone.WitnessCommitment

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Capstone.Block
open Bitcoin.Capstone.Context Bitcoin.Capstone.Pow Bitcoin.Capstone.Merkle
open Bitcoin.Block.Params

private def bytes (n : Nat) (b : UInt8 := 1) : ByteArray :=
  List.toByteArray (List.replicate n b)

private def context : ChainContext :=
  { parentHeight := 481823
    headerAt := fun n => if n < 481824 then
      some (if n = 479808 then { genesisHeader with time := genesisHeader.time - 1209600 }
        else genesisHeader) else none
    nodeTime := 2000000000 }

private def state : CapState :=
  { height := 481824, prevHash := headerHash genesisHeader, utxo := [] }

private def verdict (raw : ByteArray) (contextual : Bool) : String :=
  match (if contextual then validateBlockInContext raw state context else replayBlock raw state) with
  | .error e => e.reason
  | .ok r => s!"ok:{r.txs}:{r.sigOpBudgetChecked}"

def run : IO UInt32 := do
  let raw ← IO.FS.readBinFile "../data/review/witness-commitment/nonzero.raw"
  let (header, txs) ← match decodeBlock raw with
    | .error e => throw (IO.userError s!"fixture decode failed: {repr e}")
    | .ok p => pure p
  let cb ← match txs with
    | [cb] => pure cb
    | _ => throw (IO.userError "expected exactly one coinbase")
  let variant := fun witness => encodeBlock header [{ cb with witness := witness }]
  let variants : List (String × ByteArray × String) :=
    [("nonzero outputs at exact subsidy", raw, "ok:1:true"),
     ("missing reserved item", variant [], "bad-witness-nonce-size"),
     ("31-byte reserved item", variant [[bytes 31]], "bad-witness-nonce-size"),
     ("33-byte reserved item", variant [[bytes 33]], "bad-witness-nonce-size"),
     ("two reserved items", variant [[bytes 32, bytes 0]], "bad-witness-nonce-size"),
     ("last matching output binds actual reserved item", variant [[bytes 32 0]],
       "bad-witness-merkle-match")]
  let mut failures := 0
  let mut count := 0
  for contextual in [false, true] do
    for (name, input, expected) in variants do
      let actual := verdict input contextual
      let ok := actual == expected
      IO.println s!"[{if ok then "PASS" else "FAIL"}] {if contextual then "context" else "replay"} {name}: expected={expected}, actual={actual}"
      count := count + 1
      if !ok then failures := failures + 1
  -- These checks identify the fixture's otherwise easy-to-miss premises.
  let controls :=
    [("fixture selected output has trailing bytes", (witnessCommitmentOutput cb).map (·.size) == some 39),
     ("fixture old value gate rejects", commitmentValueZero cb == false),
     ("fixture reserved item is nonzero", witnessReservedValue cb == some (bytes 32)),
     ("fixture commitment equation binds", witnessCommitmentOk txs cb),
     ("fixture highest matching output is selected", witnessCommitmentOutput cb == (cb.vout[1]?).map (·.scriptPubKey.bytes)),
     ("fixture header proof of work is valid", targetOk header.bits && powOk header),
     ("fixture supplied context checks", (checkHeaderContext context state.height state.prevHash header).isOk)]
  for (name, ok) in controls do
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected=true, actual={ok}"
    count := count + 1
    if !ok then failures := failures + 1
  IO.println s!"witness-commitment checks={count} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.WitnessCommitment

def main : IO UInt32 := Test.Capstone.WitnessCommitment.run
