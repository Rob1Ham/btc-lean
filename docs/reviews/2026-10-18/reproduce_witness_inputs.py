#!/usr/bin/env python3
"""Require nine old native-witness bypass failures and three controls.

Runs the unchanged driver against a namespaced pre-R06 block validator.
Compilation errors, timeouts and incomplete output cannot count as evidence.
"""

import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "62d11c6"


def main():
    commit = subprocess.check_output(["git", "rev-parse", BEFORE+"^{commit}"], cwd=ROOT, text=True).strip()
    source = subprocess.check_output(["git", "show", commit+":spec/core/Bitcoin/Capstone/Block.lean"],
                                     cwd=ROOT, text=True)
    driver = (ROOT/"spec/core/Test/Capstone/WitnessInputs.lean").read_text()
    driver = "\n".join(line for line in driver.splitlines() if not line.startswith("import "))
    source = (source+"\n"+driver).replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeWitnessInputs")
    with tempfile.TemporaryDirectory(prefix="btc-witness-input-before-") as folder:
        path = Path(folder)/"Before.lean"
        path.write_text(source)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)], cwd=ROOT/"spec/core",
                              capture_output=True, text=True, timeout=120)
    rows = re.findall(r"^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$", proc.stdout, re.MULTILINE)
    expected = {"native v1 nonempty scriptSig", "active Taproot empty witness",
                "scriptSig execution precedes witness dispatch", "future witness nonempty scriptSig",
                "future version empty witness is permitted", "v1 non-32-byte program is upgradable",
                "retroactive Taproot flags reject an empty earlier-height witness",
                "bad control size is adjudicable", "wrong script-path program binding"}
    controls = {"legacy true script control", "v0 program length control", "v0 witness count control"}
    if (proc.returncode != 1 or len(rows) != 12 or len({r[1] for r in rows}) != 12 or
            {r[1] for r in rows if r[0] == "FAIL"} != expected or
            {r[1] for r in rows if r[0] == "PASS"} != controls or
            not all((r[2] == r[3]) == (r[0] == "PASS") for r in rows)):
        raise ValueError(proc.stdout+proc.stderr)
    for row in rows:
        print(f"[{row[0]}] {row[1]}: expected={row[2]}, actual={row[3]}")
    print(json.dumps(dict(baseline_commit=commit, old_lean_exit=1, expected_failures=9,
                          passing_controls=3, reproduction="confirmed")))


if __name__ == "__main__":
    main()
