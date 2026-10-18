import Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2
import Test.Capstone.TaprootFixture

/-! R19: a Boolean Schnorr compatibility assembly must preserve ECDSA.
These are the two valid ECDSA inputs of the official fully signed BIP341 tx. -/
namespace Test.Capstone.SchnorrAssembly
open Bitcoin.Data Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Capstone.Block
open Bitcoin.Capstone.RealChecker Test.Capstone.TaprootFixture

private def code : VerifyOutcome → String
  | .ok => "pass"
  | .unjudged => "unjudged"
  | .fail e => reprStr e

def run : IO UInt32 := do
  let (raw, _, coins) ← load
  let (_, txs) ← decode raw
  let tx := txs.getD 1 dummyTx
  let outputs := (coins.take 9).map fun (_, c) => (⟨c.value, c.scriptPubKey⟩ : TxOut)
  let mut count := 0
  let mut failures := 0
  for i in [2, 5] do
    let coin := (coins.getD i (OutPoint.null, ⟨0, 0, false, Script.empty⟩)).2
    let input := tx.vin.getD i Bitcoin.Capstone.RealChecker.dummyTxIn
    let checker := Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2.realCheckerFullOf2 ⟨tx, outputs⟩ i i coin.value
    let control := realCheckerFullOf tx i coin.value
    for (name, chk) in [(s!"compatibility ECDSA input {i}", checker),
                        (s!"production ECDSA control {i}", control)] do
      let actual := code (verifyScriptFull 1000 (getBlockScriptFlags 709632) default
        input.scriptSig.bytes coin.scriptPubKey.bytes (witnessAt tx i) chk)
      let ok := actual == "pass"
      IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected=pass, actual={actual}"
      count := count+1
      if !ok then failures := failures+1
  IO.println s!"schnorr-assembly checks={count} failures={failures}"
  return if failures == 0 then 0 else 1
end Test.Capstone.SchnorrAssembly

def main : IO UInt32 := Test.Capstone.SchnorrAssembly.run
