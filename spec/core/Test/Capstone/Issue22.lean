import Bitcoin.Capstone.Block
import Test.Capstone.TaprootFixture

/-! Issue 22 regression: the single next-block entry point derives its
header/clock context from the checked chain view, and the context-free
diagnostic adapter never reports full validation. -/

namespace Test.Capstone.Issue22

open Bitcoin.Data Bitcoin.Capstone.Block Bitcoin.Capstone.Context Bitcoin.Capstone.Pow
open Test.Capstone.TaprootFixture

private def result : Except CapError CapReport → String
  | .error e => e.reason
  | .ok r => s!"ok:{r.fullValidation}:{r.scriptUnjudged}"

def run : IO UInt32 := do
  let (raw, _, coins) ← load
  let cs : ChainState :=
    { height := 709632
      prevHash := headerHash Bitcoin.Block.Params.genesisHeader
      utxo := coins
      headers := context.headerAt
      nodeTime := context.nodeTime }
  let viaNext := validateNextBlock raw cs
  let viaContext := validateBlockInContext raw (state coins) context
  let partialReport := replayBlockPartial raw (state coins)
  let checks : List (String × String × String) :=
    [("single entry point equals contextual pipeline", result viaNext, "ok:true:0"),
     ("single entry point equals explicit context control", result viaNext, result viaContext),
     ("context-free adapter is explicitly partial", result partialReport, "ok:false:0")]
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  IO.println s!"issue22 checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.Issue22

def main : IO UInt32 := Test.Capstone.Issue22.run
