#!/usr/bin/env python3
"""Execute unchanged pre-R18 interpreter/checker/public transaction engine.

Only namespace identities change so old definitions coexist with current
imports. The runtime driver is shared with the repaired engine. Compile errors,
timeouts and incomplete output cannot count as the six expected failures.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "ca85fcda99f8f0045bb1fb730f157e43c4960985"
SOURCES = ["Bitcoin/Interpreter/Defs.lean", "Bitcoin/Capstone/RealChecker.lean",
           "Bitcoin/Capstone/Block.lean"]
FAILURES = {"wire ffffffff version", "wire fffffffe version", "wire 80000000 version",
            "wire 80000001 version", "high-bit version time equality",
            "high-bit version reserved sequence bits"}


def main():
    commit = subprocess.check_output(["git", "rev-parse", BEFORE+"^{commit}"], cwd=ROOT, text=True).strip()
    imports, parts, hashes = set(), [], {}
    for name in SOURCES:
        source = subprocess.check_output(["git", "show", commit+":spec/core/"+name], cwd=ROOT, text=True)
        hashes[name] = hashlib.sha256(source.encode()).hexdigest()
        imports.update(line for line in source.splitlines() if line.startswith("import "))
        source = "\n".join(line for line in source.splitlines() if not line.startswith("import "))
        source = source.replace("Bitcoin.Interpreter", "Bitcoin.Interpreter.BeforeCsv")
        source = source.replace("Bitcoin.Capstone.RealChecker", "Bitcoin.Capstone.BeforeCsvChecker")
        source = source.replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeCsvBlock")
        parts.append(source)
    driver = (ROOT/"spec/core/Test/Capstone/CsvVersion.lean").read_text()
    driver = "\n".join(line for line in driver.splitlines() if not line.startswith("import "))
    driver = driver.replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeCsvBlock")
    driver = driver.replace("Bitcoin.Interpreter", "Bitcoin.Interpreter.BeforeCsv")
    with tempfile.TemporaryDirectory(prefix="btc-csv-version-before-") as folder:
        path = Path(folder)/"Before.lean"
        path.write_text("\n".join(sorted(imports))+"\n"+"\n".join(parts)+"\n"+driver)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)], cwd=ROOT/"spec/core",
                              capture_output=True, text=True, timeout=180)
    rows = re.findall(r"^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$", proc.stdout, re.MULTILINE)
    if (proc.returncode != 1 or len(rows) != 18 or len({r[1] for r in rows}) != 18 or
            {r[1] for r in rows if r[0] == "FAIL"} != FAILURES or
            sum(r[0] == "PASS" for r in rows) != 12 or
            not all((r[2] == r[3]) == (r[0] == "PASS") for r in rows)):
        raise ValueError(proc.stdout+proc.stderr)
    for row in rows:
        print(f"[{row[0]}] {row[1]}: expected={row[2]}, actual={row[3]}")
    print(json.dumps(dict(baseline_commit=commit, sources_sha256=hashes, old_lean_exit=1,
                          expected_failures=6, passing_controls=12, reproduction="confirmed")))


if __name__ == "__main__":
    main()
