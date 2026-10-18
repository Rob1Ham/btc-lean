#!/usr/bin/env python3
"""Require thirteen old public BIP30 failures and eleven controls.

Runs the shared driver against the unchanged namespaced pre-R07d block validator.
Compilation errors, timeouts and incomplete output cannot count as evidence.
"""

import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "3623588e52969b683fc1c0c9a1984f813db93ec5"


def main():
    commit = subprocess.check_output(["git", "rev-parse", BEFORE+"^{commit}"], cwd=ROOT, text=True).strip()
    source = subprocess.check_output(["git", "show", commit+":spec/core/Bitcoin/Capstone/Block.lean"],
                                     cwd=ROOT, text=True)
    driver = (ROOT/"spec/core/Test/Capstone/Bip30.lean").read_text()
    extra_imports = "\n".join(line for line in driver.splitlines() if line.startswith("import "))
    driver = "\n".join(line for line in driver.splitlines() if not line.startswith("import "))
    source = (source+"\n"+driver).replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeBip30")
    source = extra_imports+"\n"+source
    with tempfile.TemporaryDirectory(prefix="btc-bip30-before-") as folder:
        path = Path(folder)/"Before.lean"
        path.write_text(source)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)], cwd=ROOT/"spec/core",
                              capture_output=True, text=True, timeout=120)
    rows = re.findall(r"^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$", proc.stdout, re.MULTILINE)
    expected = {mode+" "+name for mode in ["replay", "context"] for name in
                ["crossed repeat hash at 91842", "crossed repeat hash at 91880",
                 "alternate hash collision at 91842", "alternate hash collision at 91880",
                 "BIP30 precedes missing input"]}
    expected |= {"window replay collision needs ancestor", "window noncanonical ancestor enforces BIP30",
                 "window missing ancestor is unavailable"}
    controls = {mode+" "+name for mode in ["replay", "context"] for name in
                ["canonical repeat 91842", "canonical repeat 91880",
                 "alternate no collision at 91842", "alternate no collision at 91880"]}
    controls |= {"window canonical ancestor permits collision", "window replay no collision needs no ancestor",
                 "window noncanonical ancestor no collision control"}
    if (proc.returncode != 1 or len(rows) != 24 or len({r[1] for r in rows}) != 24 or
            {r[1] for r in rows if r[0] == "FAIL"} != expected or
            {r[1] for r in rows if r[0] == "PASS"} != controls or
            not all((r[2] == r[3]) == (r[0] == "PASS") for r in rows)):
        raise ValueError(proc.stdout+proc.stderr)
    for row in rows:
        print(f"[{row[0]}] {row[1]}: expected={row[2]}, actual={row[3]}")
    print(json.dumps(dict(baseline_commit=commit, old_lean_exit=1, expected_failures=13,
                          passing_controls=11, reproduction="confirmed")))


if __name__ == "__main__":
    main()
