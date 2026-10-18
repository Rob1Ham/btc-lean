#!/usr/bin/env python3
"""Require the old public validator's two sigop over-budget false accepts.

Uses unchanged mined fixtures and a namespaced copy of the pre-fix entry.
It requires two named failures and two positive controls; compilation or
fixture errors cannot satisfy the reproduction.
"""

import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "732efdf"


def main():
    commit = subprocess.check_output(["git", "rev-parse", BEFORE + "^{commit}"], cwd=ROOT, text=True).strip()
    source = subprocess.check_output(["git", "show", commit + ":spec/core/Bitcoin/Capstone/Block.lean"],
                                     cwd=ROOT, text=True)
    source = source.replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeSigopBudget")
    source += r'''
open Bitcoin.Data Bitcoin.Capstone.BeforeSigopBudget Bitcoin.Capstone.Context
open Bitcoin.Capstone.Pow
def main : IO UInt32 := do
  let genesis := Bitcoin.Block.Params.genesisHeader
  let st : CapState := { height := 1, prevHash := headerHash genesis, utxo := [] }
  let ctx : ChainContext :=
    { parentHeight := 0
      headerAt := fun n => if n = 0 then some genesis else none
      nodeTime := 2000000000 }
  let atLimit ← IO.FS.readBinFile "../data/review/sigop-budget/at-limit.raw"
  let overLimit ← IO.FS.readBinFile "../data/review/sigop-budget/over-limit.raw"
  let verdict := fun (raw : ByteArray) (contextual : Bool) =>
    match (if contextual then validateBlockInContext raw st ctx else replayBlock raw st) with
    | .error e => e.reason
    | .ok _ => "ok"
  let checks :=
    [("contextual exact limit", verdict atLimit true, "ok"),
     ("contextual above limit", verdict overLimit true, "bad-blk-sigops"),
     ("replay exact limit", verdict atLimit false, "ok"),
     ("replay above limit", verdict overLimit false, "bad-blk-sigops")]
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  return if failures == 0 then 0 else 1
'''
    # Params is only needed by the test driver; original model imports remain intact.
    source = "import Bitcoin.Block.Params\n" + source
    with tempfile.TemporaryDirectory(prefix="btc-budget-before-") as folder:
        path = Path(folder)/"Before.lean"
        path.write_text(source)
        result = subprocess.run(["lake", "env", "lean", "--run", str(path)],
                                cwd=ROOT/"spec/core", capture_output=True, text=True, timeout=120)
    rows = re.findall(r"^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$", result.stdout, re.MULTILINE)
    expected_failures = {"contextual above limit", "replay above limit"}
    if (result.returncode != 1 or len(rows) != 4 or len({r[1] for r in rows}) != 4 or
        {r[1] for r in rows if r[0] == "FAIL"} != expected_failures or
        not all((r[2] == r[3]) == (r[0] == "PASS") for r in rows)):
        raise ValueError(result.stdout + result.stderr)
    print(result.stdout, end="")
    print(json.dumps({"baseline_commit": commit, "old_lean_exit": 1,
                      "expected_public_failures": 2, "passing_controls": 2,
                      "reproduction": "confirmed"}))


if __name__ == "__main__":
    main()
