import Test.Capstone.TaprootFixture

/-! Public serialized-byte regression. Real difficulty-one PoW and real
Schnorr/ECDSA signatures; supplied ancestor/UTXO state is conditional. Two
spends consume outputs created earlier in this very block. -/
namespace Test.Capstone.TaprootBlocks
open Bitcoin.Data Bitcoin.Capstone.Block Test.Capstone.TaprootFixture

def run : IO UInt32 := do
  let (raw, _, coins) ← load
  let changedAmount := coins.zipIdx |>.map fun ((point, coin), i) =>
    (point, if i = 0 then { coin with value := coin.value + 1 } else coin)
  let changedProgram := coins.zipIdx |>.map fun ((point, coin), i) =>
    (point, if i = 9 then { coin with scriptPubKey :=
      ⟨List.toByteArray ([0x51, 0x20] ++ List.replicate 32 0xff)⟩ } else coin)
  let cases := [("real signed key/script paths and same-block cache", coins, "ok:12:0"),
    ("key-path signature binds actual previous amount", changedAmount, "script-verify-error"),
    ("script path binds actual previous output key", changedProgram, "script-verify-error"),
    ("missing coin is rejected before scripts", coins.drop 1, "bad-txns-inputs-missingorspent")]
  let mut failures := 0
  let mut count := 0
  for contextual in [false, true] do
    for (name, view, expected) in cases do
      let result := if contextual then validateBlockInContext raw (state view) context
        else replayBlockPartial raw (state view)
      let actual := match result with
        | .error e => e.reason
        | .ok r => s!"{if r.fullValidation then "ok" else "partial"}:{r.scriptOk}:{r.scriptUnjudged}"
      let expected := if !contextual then expected.replace "ok:" "partial:" else expected
      let ok := actual == expected
      IO.println s!"[{if ok then "PASS" else "FAIL"}] {if contextual then "context" else "replay"} {name}: expected={expected}, actual={actual}"
      count := count+1
      if !ok then failures := failures+1
  IO.println s!"taproot-block checks={count} failures={failures}"
  return if failures == 0 then 0 else 1
end Test.Capstone.TaprootBlocks

def main : IO UInt32 := Test.Capstone.TaprootBlocks.run
