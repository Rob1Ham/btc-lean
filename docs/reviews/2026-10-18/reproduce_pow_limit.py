#!/usr/bin/env python3
"""Run unchanged pre-R07c Pow, Index and Capstone.Pow modules.

Only namespace identities change to coexist with current imports. Five full-
limit assertions must fail and seven controls pass; compile errors and timeouts
cannot count as a reproduction. This is a parameter-value regression.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "b1051aeea547e026c3ed738aaa567a1c80260d85"
SOURCES = ["Bitcoin/Block/Pow.lean", "Bitcoin/Block/Index.lean", "Bitcoin/Capstone/Pow.lean"]
FAILURES = {"retarget library uses full mainnet limit", "retarget parameters use full mainnet limit",
            "capstone uses full mainnet limit", "chain-work library uses full mainnet limit",
            "difficulty-one target is strictly below limit"}


def main():
    commit = subprocess.check_output(["git", "rev-parse", BEFORE+"^{commit}"], cwd=ROOT, text=True).strip()
    imports, parts, hashes = set(), [], {}
    for name in SOURCES:
        source = subprocess.check_output(["git", "show", commit+":spec/core/"+name], cwd=ROOT, text=True)
        hashes[name] = hashlib.sha256(source.encode()).hexdigest()
        imports.update(line for line in source.splitlines() if line.startswith("import "))
        source = "\n".join(line for line in source.splitlines() if not line.startswith("import "))
        for namespace in ["Bitcoin.Block.Pow", "Bitcoin.Block.Index", "Bitcoin.Capstone.Pow"]:
            source = source.replace(namespace, namespace+".BeforeLimit")
        parts.append(source)
    driver = (ROOT/"spec/core/Test/Capstone/PowLimit.lean").read_text()
    driver = "\n".join(line for line in driver.splitlines() if not line.startswith("import "))
    for namespace in ["Bitcoin.Block.Pow", "Bitcoin.Block.Index", "Bitcoin.Capstone.Pow"]:
        driver = driver.replace(namespace, namespace+".BeforeLimit")
    with tempfile.TemporaryDirectory(prefix="btc-pow-limit-before-") as folder:
        path = Path(folder)/"Before.lean"
        path.write_text("\n".join(sorted(imports))+"\n"+"\n".join(parts)+"\n"+driver)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)], cwd=ROOT/"spec/core",
                              capture_output=True, text=True, timeout=120)
    rows = re.findall(r"^\[(PASS|FAIL)\] (.*)$", proc.stdout, re.MULTILINE)
    if (proc.returncode != 1 or len(rows) != 12 or len({r[1] for r in rows}) != 12 or
            {r[1] for r in rows if r[0] == "FAIL"} != FAILURES or
            sum(r[0] == "PASS" for r in rows) != 7 or "error:" in proc.stdout):
        raise ValueError(proc.stdout+proc.stderr)
    for status, name in rows:
        print(f"[{status}] {name}")
    print(json.dumps(dict(baseline_commit=commit, sources_sha256=hashes, old_lean_exit=1,
                          expected_failures=5, passing_controls=7, reproduction="confirmed")))


if __name__ == "__main__":
    main()
