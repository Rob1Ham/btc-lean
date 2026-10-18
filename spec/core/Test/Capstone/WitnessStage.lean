import Bitcoin.Capstone.Block
import Bitcoin.Block.Params

/-! Witness-stage cases that do not require remining changed transaction
outputs. Monetary rejection is exercised separately on the actual funded
stage, so amount independence cannot silently bypass reward/value checks. -/

namespace Test.Capstone.WitnessStage

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle

private def reason (result : Except CapError Unit) : String :=
  match result with | .error e => e.reason | .ok _ => "ok"

private def funded (cb : Tx) : String :=
  match applyBlockTransactionsWithSigops none 481824 {} [cb] [] with
  | .error e => e.reason
  | .ok _ => "ok"

def run : IO UInt32 := do
  let raw ← IO.FS.readBinFile "../data/review/witness-commitment/nonzero.raw"
  let (_, txs) ← match decodeBlock raw with
    | .error e => throw (IO.userError s!"fixture decode: {repr e}")
    | .ok p => pure p
  let cb ← match txs with
    | [cb] => pure cb
    | _ => throw (IO.userError "expected one coinbase")
  let test := fun active cb => reason (checkWitnessCommitment active [cb] cb)
  let noWitness := { cb with witness := [] }
  let noCommitment := { cb with vout := [{ value := 0, scriptPubKey := Script.empty }] }
  let reversed := { cb with vout := cb.vout.reverse, witness := [[Bitcoin.Data.zeroBytes 32]] }
  let zeroValues := { cb with vout := cb.vout.map (fun out => { out with value := 0 }) }
  let excessive := { cb with vout := cb.vout.map (fun out => { out with value := out.value+1 }) }
  let negative := { cb with vout := cb.vout.map (fun out => { out with value := -1 }) }
  let checks :=
    [("zero values also bind", test true zeroValues, "ok"),
     ("reversing outputs changes selected commitment", test true reversed, "ok"),
     ("preactivation rejects witness", test false cb, "unexpected-witness"),
     ("preactivation ignores commitment without witness", test false noWitness, "ok"),
     ("absent commitment with witness", test true noCommitment, "unexpected-witness"),
     ("absent commitment without witness", test true { noCommitment with witness := [] }, "ok"),
     ("short prefix is not a commitment", test true { cb with
        vout := [{ value := 0, scriptPubKey := ⟨wcm ++ Bitcoin.Data.zeroBytes 31⟩ }] }, "unexpected-witness"),
     ("witness check ignores excessive amounts", test true excessive, "ok"),
     ("funded stage rejects excessive reward", funded excessive, "bad-cb-amount"),
     ("witness check ignores negative amounts", test true negative, "ok"),
     ("stateless gate rejects negative amounts", funded negative, "bad-txns-vout-negative"),
     ("funded exact nonzero subsidy", funded cb, "ok")]
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  IO.println s!"witness-stage checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.WitnessStage

def main : IO UInt32 := Test.Capstone.WitnessStage.run
