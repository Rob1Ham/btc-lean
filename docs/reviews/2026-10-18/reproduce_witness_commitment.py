#!/usr/bin/env python3
"""Require twelve old public witness-verdict failures and seven controls.

The same byte fixtures and driver run against a namespaced pre-fix validator.
Compilation, missing fixture and timeout failures cannot count as reproductions.
"""

import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "8856247"


def main():
    commit = subprocess.check_output(["git", "rev-parse", BEFORE+"^{commit}"], cwd=ROOT, text=True).strip()
    source = subprocess.check_output(["git", "show", commit+":spec/core/Bitcoin/Capstone/Block.lean"],
                                     cwd=ROOT, text=True)
    driver = (ROOT/"spec/core/Test/Capstone/WitnessCommitment.lean").read_text()
    driver = "\n".join(line for line in driver.splitlines() if not line.startswith("import "))
    source = "import Bitcoin.Block.Params\n"+source+"\n"+driver
    source = source.replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeWitness")
    with tempfile.TemporaryDirectory(prefix="btc-witness-before-") as folder:
        path = Path(folder)/"Before.lean"
        path.write_text(source)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)], cwd=ROOT/"spec/core",
                              capture_output=True, text=True, timeout=120)
    rows = re.findall(r"^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$", proc.stdout, re.MULTILINE)
    expected = {prefix+" "+case for prefix in ["context", "replay"] for case in [
        "nonzero outputs at exact subsidy", "missing reserved item", "31-byte reserved item",
        "33-byte reserved item", "two reserved items", "last matching output binds actual reserved item"]}
    if (proc.returncode != 1 or len(rows) != 19 or len({r[1] for r in rows}) != 19 or
            {r[1] for r in rows if r[0] == "FAIL"} != expected or
            not all((r[2] == r[3]) == (r[0] == "PASS") for r in rows)):
        raise ValueError(proc.stdout+proc.stderr)
    for row in rows:
        print(f"[{row[0]}] {row[1]}: expected={row[2]}, actual={row[3]}")
    print(json.dumps(dict(baseline_commit=commit, old_lean_exit=1, expected_public_failures=12,
                          passing_controls=7, reproduction="confirmed")))


if __name__ == "__main__":
    main()
