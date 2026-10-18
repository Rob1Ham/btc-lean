#!/usr/bin/env python3
"""Require six old script-flag routing failures and twenty controls.

Runs the shared driver against the unchanged namespaced pre-R07a block validator.
Compilation errors, timeouts and incomplete output cannot count as evidence.
"""

import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "eac345fa1b9a7b65f47b91007725b79b27cb18ea"


def main():
    commit = subprocess.check_output(["git", "rev-parse", BEFORE+"^{commit}"], cwd=ROOT, text=True).strip()
    source = subprocess.check_output(["git", "show", commit+":spec/core/Bitcoin/Capstone/Block.lean"],
                                     cwd=ROOT, text=True)
    driver = (ROOT/"spec/core/Test/Capstone/ScriptFlags.lean").read_text()
    extra_imports = "\n".join(line for line in driver.splitlines() if line.startswith("import "))
    driver = "\n".join(line for line in driver.splitlines() if not line.startswith("import "))
    source = (source+"\n"+driver).replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeScriptFlags")
    source = extra_imports+"\n"+source
    with tempfile.TemporaryDirectory(prefix="btc-script-flags-before-") as folder:
        path = Path(folder)/"Before.lean"
        path.write_text(source)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)], cwd=ROOT/"spec/core",
                              capture_output=True, text=True, timeout=120)
    rows = re.findall(r"^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$", proc.stdout, re.MULTILINE)
    expected = {"public replay alternate hash executes P2SH",
                "public context alternate hash executes P2SH",
                "resource fold executes supplied active flags",
                "resource fold executes supplied exception flags",
                "resource fold alternate hash binds Taproot amount",
                "resource fold applies named Taproot exception"}
    controls = {"alternate hash retains P2SH flag", "named hash selects exception flags",
                "public replay valid control", "public context valid control",
                "alternate hash retains Taproot flag", "resource fold valid Taproot control"}
    selector_names = {"P2SH alternate", "P2SH named", "Taproot alternate", "Taproot named",
                      "buried flags survive P2SH replacement", "Taproot replacement before buried gates",
                      "DERSIG before", "DERSIG at", "CLTV before", "CLTV at", "CSV before", "CSV at",
                      "NULLDUMMY before", "NULLDUMMY at"}
    controls |= {"selector "+name for name in selector_names}
    if (proc.returncode != 1 or len(rows) != 26 or len({r[1] for r in rows}) != 26 or
            {r[1] for r in rows if r[0] == "FAIL"} != expected or
            {r[1] for r in rows if r[0] == "PASS"} != controls or
            not all((r[2] == r[3]) == (r[0] == "PASS") for r in rows)):
        raise ValueError(proc.stdout+proc.stderr)
    for row in rows:
        print(f"[{row[0]}] {row[1]}: expected={row[2]}, actual={row[3]}")
    print(json.dumps(dict(baseline_commit=commit, old_lean_exit=1, expected_failures=6,
                          passing_controls=20, reproduction="confirmed")))


if __name__ == "__main__":
    main()
