#!/usr/bin/env python3
"""Run R03's stage/public cases against the committed pre-R03 engine.

The old Block.lean is compiled unchanged apart from its namespace. An adapter
routes the new contextual-stage name to the old funded stage, which had no
BIP68 input. Exactly nine behavioral failures and 23 passing controls are
required. Compiler/setup failures cannot count as reproduced defects.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BASELINE = "db87aca"
SOURCE = "spec/core/Bitcoin/Capstone/Block.lean"


def main() -> int:
    sha = subprocess.check_output(["git", "rev-parse", BASELINE], cwd=ROOT, text=True).strip()
    old = subprocess.check_output(["git", "show", f"{sha}:{SOURCE}"], cwd=ROOT, text=True)
    print(f"baseline={sha} source_sha256={hashlib.sha256(old.encode()).hexdigest()}", flush=True)
    old = old.replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeR03")
    test = (ROOT / "spec/core/Test/Capstone/Finality.lean").read_text()
    test = test[test.index("/-!"):test.index("def run : IO UInt32")]
    test = test.replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeR03")
    adapter = """
namespace Bitcoin.Capstone.BeforeR03
def applyContextualBlockTransactions (_ : Bitcoin.Capstone.Context.ChainContext)
    (_ : Bitcoin.Capstone.Context.HeaderFacts) (height : UInt32)
    (txs : List Bitcoin.Data.Tx) (l : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin)) :
    Except CapError (List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin) × Nat × Nat) :=
  applyBlockTransactions height txs l
end Bitcoin.Capstone.BeforeR03
"""
    runner = """
def run : IO UInt32 := do
  let rejected ← publicReject
  let checks := stageChecks ++ absoluteChecks ++
    [("public serialized block enforces absolute finality before UTXOs", rejected, "bad-txns-nonfinal")]
  let results ← checks.mapM fun (name, actual, expected) => do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    return ok
  return if results.all id then 0 else 1
end Test.Capstone.Finality
def main : IO UInt32 := Test.Capstone.Finality.run
"""
    with tempfile.TemporaryDirectory(prefix="btc-lean-r03-before-") as tmp:
        path = Path(tmp) / "Baseline.lean"
        path.write_text("import Bitcoin.Block.Params\n" + old + adapter + test + runner)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)],
                              cwd=ROOT / "spec/core", text=True, capture_output=True, timeout=120)
    print(proc.stdout, end="")
    print(proc.stderr, end="")
    checks = [line for line in proc.stdout.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    failures = [line[len("[FAIL] "):].split(": expected=", 1)[0]
                for line in checks if line.startswith("[FAIL]")]
    expected = [
        "height lock last invalid block", "time lock 511-second boundary rejects",
        "wire ffffffff version is unsigned in pinned Core", "same-block height lock one rejects",
        "same-block time lock one rejects", "relative finality precedes script failure",
        "time lock missing old window is unavailable", "two inputs cannot truncate an unsatisfied second lock",
        "public serialized block enforces absolute finality before UTXOs",
    ]
    if proc.returncode != 1 or len(checks) != 32 or failures != expected:
        raise SystemExit("R03 reproduction failed: expected exactly nine behavioral failures and 23 passing controls")
    print("R03 baseline reproduction: nine stage/public failures confirmed; 23 controls pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
