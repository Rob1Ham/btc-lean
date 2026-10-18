import Test.Capstone.TaprootFixture

/-! Real BIP341/BIP342 signatures at the public per-input and transaction
entries, including all-prevout binding, annexes, CODESEPARATOR and budget. -/
namespace Test.Capstone.TaprootInputs
open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block Bitcoin.Interpreter
open Test.Capstone.TaprootFixture

private def error (e : ExecError) : String := reprStr e
private def outputs (coins : List (OutPoint × Coin)) : List TxOut :=
  coins.map fun (_, c) => ⟨c.value, c.scriptPubKey⟩
private def withWitness (tx : Tx) (i : Nat) (items : WitnessStack) : Tx :=
  { tx with witness := tx.witness.set i items }
private def flip (b : ByteArray) : ByteArray := b.set! 0 ((b.get! 0) ^^^ 1)
private def input (tx : Tx) (i : Nat) (coins : List (OutPoint × Coin))
    (cache : Option (List TxOut)) : String :=
  verdict (verifyInput 709632 tx i (coins.getD i (OutPoint.null, ⟨0, 0, false, Script.empty⟩)).2 0 i cache)

def run : IO UInt32 := do
  let (raw, metadata, coins) ← load
  let (_, txs) ← decode raw
  let official := (txs.getD 1 dummyTx)
  let cache := outputs (coins.take 9)
  let mut checks : List (String × String × String) := []
  for i in [0, 1, 3, 4, 6, 7, 8] do
    checks := checks ++ [(s!"official key-path input {i}", input official i coins (some cache), "pass")]
  let sig := (witnessAt official 0)[0]!
  let changedOther := cache.set 2 { cache[2]! with value := (cache[2]!).value + 1 }
  let changedOtherScript := cache.set 2 { cache[2]! with scriptPubKey := Script.empty }
  checks := checks ++
    [("missing full cache is explicitly incomplete", input official 0 coins none, "unjudged"),
     ("truncated cache is explicitly incomplete", input official 0 coins (some (cache.drop 1)), "unjudged"),
     ("non-ANYONECANPAY binds another input amount", input official 0 coins (some changedOther), error .schnorrSig),
     ("non-ANYONECANPAY binds another input script", input official 0 coins (some changedOtherScript), error .schnorrSig),
     ("ANYONECANPAY permits another input amount", input official 1 coins (some changedOther), "pass"),
     ("ANYONECANPAY permits another input script", input official 1 coins (some changedOtherScript), "pass"),
     ("signature bit flip is rejected", input (withWitness official 0 [flip sig]) 0 coins (some cache), error .schnorrSig),
     ("63-byte signature rejects before unavailable data", input (withWitness official 0 [sig.extract 0 63]) 0 coins none, error .schnorrSigSize),
     ("66-byte signature size", input (withWitness official 0 [sig ++ List.toByteArray [1]]) 0 coins (some cache), error .schnorrSigSize),
     ("explicit default hashtype rejects before unavailable data", input (withWitness official 0 [sig.extract 0 64 ++ List.toByteArray [0]]) 0 coins none, error .schnorrSigHashtype),
     ("invalid hashtype rejects before unavailable data", input (withWitness official 0 [sig.extract 0 64 ++ List.toByteArray [4]]) 0 coins none, error .schnorrSigHashtype),
     ("SINGLE without matching output rejects before unavailable data",
       input { official with vout := [] } 0 coins none, error .schnorrSigHashtype),
     ("annex added without resigning rejects", input (withWitness official 0 [sig, List.toByteArray [0x50, 0x99]]) 0 coins (some cache), error .schnorrSig)]
  let annexTx ← transaction (fromHex (← str metadata "keyPathAnnexTx"))
  checks := checks ++ [("real key-path annex signature", input annexTx 0 coins (some cache), "pass"),
    ("annex mutation invalidates signature", input (withWitness annexTx 0
      [(witnessAt annexTx 0)[0]!, List.toByteArray [0x50, 0x98]]) 0 coins (some cache), error .schnorrSig)]
  for row in ← arr metadata "extraCases" do
    let tx ← transaction (fromHex (← str row "rawTx"))
    let c : Coin := ⟨Int.ofNat (← nat row "amount"), 100, false,
      ⟨fromHex (← str row "scriptPubKey")⟩⟩
    let expected ← str row "expected"
    checks := checks ++ [(← str row "name", verdict (verifyInput 709632 tx 0 c 0 0
      (some [⟨c.value, c.scriptPubKey⟩])), if expected == "pass" then "pass" else error .schnorrSig)]
  let mut view := coins
  for i in [1, 2, 3, 4] do
    let tx := (txs.getD i dummyTx)
    match applyTx 709632 tx i view with
    | .error e => checks := checks ++ [(s!"live-view transaction {i}", e.reason, "pass")]
    | .ok (next, okN, unjN) =>
      checks := checks ++ [(s!"live-view transaction {i}", s!"{okN}:{unjN}",
        if i = 1 then "9:0" else "1:0")]
      view := next
  let lastWitness := witnessAt (txs.getD 4 dummyTx) 0
  checks := checks ++ [("budget includes stack-count prefix", toString (witnessSerSize lastWitness), "150"),
    ("budget exact four-signature boundary", toString (witnessSerSize lastWitness + 50), "200"),
    ("252/253 stack-count boundary", toString (witnessSerSize (List.replicate 252 ByteArray.empty)), "253"),
    ("253 stack-count uses three-byte CompactSize", toString (witnessSerSize (List.replicate 253 ByteArray.empty)), "256")]
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  IO.println s!"taproot-input checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1
end Test.Capstone.TaprootInputs

def main : IO UInt32 := Test.Capstone.TaprootInputs.run
