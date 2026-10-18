import Bitcoin.Block.Pow
import Bitcoin.Block.Index
import Bitcoin.Capstone.Pow

/-! I4-43/R07c: Core's full mainnet powLimit differs from the rounded
difficulty-1 compact target. Parameter-value regressions do not imply a
changed block verdict at a representable nBits value. -/

namespace Test.Capstone.PowLimit

open Bitcoin.Block.Pow Bitcoin.Chain

def run : IO UInt32 := do
  let full := 2^224 - 1
  let difficultyOne := compactTarget 0x1d00ffff
  let checks : List (String × Bool) :=
    [("retarget library uses full mainnet limit", powLimitMainnet == full),
     ("retarget parameters use full mainnet limit", mainnetParams.powLimit == full),
     ("capstone uses full mainnet limit", Bitcoin.Capstone.Pow.powLimit == full),
     ("chain-work library uses full mainnet limit", Bitcoin.Block.Index.powLimit == full),
     ("difficulty-one target is strictly below limit", difficultyOne < powLimitMainnet),
     ("capstone and retarget limits agree", Bitcoin.Capstone.Pow.powLimit == powLimitMainnet),
     ("chain-work and retarget limits agree", Bitcoin.Block.Index.powLimit == powLimitMainnet),
     ("full limit encodes as difficulty-one bits", getCompact full == 0x1d00ffff),
     ("parameter limit encodes as difficulty-one bits", getCompact mainnetParams.powLimit == 0x1d00ffff),
     ("difficulty-one target remains accepted", Bitcoin.Capstone.Pow.targetOk 0x1d00ffff),
     ("next larger compact target remains rejected", !Bitcoin.Capstone.Pow.targetOk 0x1d010000),
     ("retarget saturation preserves compact cap",
       calculateNextWorkRequired mainnetParams 0x1d00ffff 4838400 0 0x1d00ffff == 0x1d00ffff)]
  let mut failures := 0
  for (name, ok) in checks do
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}"
    if !ok then failures := failures + 1
  IO.println s!"pow-limit checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.PowLimit

def main : IO UInt32 := Test.Capstone.PowLimit.run
