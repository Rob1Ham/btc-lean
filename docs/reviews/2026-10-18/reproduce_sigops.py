#!/usr/bin/env python3
"""Reproduce the 18 sigop counting failures at the pre-repair commit.

Needs the pinned Lean toolchain on PATH. Builds only the dependency-free
core in a temporary directory, then requires all 28 expected named results;
a setup, build or elaboration error cannot count as a reproduced defect.
"""

import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = "51b3b95c2e28543a8620854ecd34a152a6128206"
SUBJECT = "Reconcile upstream sentinel proof and historical build counts"
FAILURES = {
    "accurate per-CMS lookback", "inaccurate CMS is twenty",
    "trailing OP_N adds nothing", "intervening opcode clears lookback",
    "truncated direct push retains prefix", "truncated PUSHDATA1 length retains prefix",
    "truncated PUSHDATA1 payload retains prefix", "truncated PUSHDATA2 length retains prefix",
    "truncated PUSHDATA4 length retains prefix", "P2SH redeem bytes are counted directly",
    "P2SH valid redeem prefix survives", "P2SH non-push prefix is rejected",
    "block P2SH non-push prefix is rejected", "witness P2WSH retains valid prefix",
    "wrapped witness requires push-only", "wrapped P2WPKH counts without witness",
    "native P2WPKH counts without witness", "wrapped P2WSH accurate count",
}


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def main():
    before = subprocess.check_output(["git", "rev-parse", BEFORE + "^{commit}"], cwd=ROOT, text=True).strip()
    subject = subprocess.check_output(["git", "show", "-s", "--format=%s", before], cwd=ROOT, text=True).strip()
    require(subject == SUBJECT, (before, subject))
    source = (ROOT/"spec/core/Test/Capstone/Sigops.lean").read_text()
    # The 28 cross-version raw/per-input cases are kept together. The newer
    # wrapper API did not exist before the repair and is checked separately.
    a = source.index("private def flaggedCost")
    b = source.index("private def checks", a)
    source = source[:a] + source[b:]
    a = source.index("  for (name, got, expected) in wrapperChecks do")
    b = source.index("  IO.println s!\"sigop checks=", a)
    source = source[:a] + source[b:]
    source = source.replace("checks.length + wrapperChecks.length", "checks.length")
    archive = subprocess.check_output(["git", "archive", before, "spec/core"], cwd=ROOT)
    with tempfile.TemporaryDirectory(prefix="btc-sigops-before-") as folder:
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(folder, filter="data")
        core = Path(folder)/"spec/core"
        (core/"Test/Capstone/Sigops.lean").write_text(source)
        build = subprocess.run(["lake", "build", "Bitcoin.Interpreter.Rules", "Bitcoin.Block.Sigops",
                                "Bitcoin.TxValidation.SigOpsCost"], cwd=core, text=True,
                               capture_output=True, timeout=180)
        if build.returncode:
            raise RuntimeError("Baseline build failed:\n" + build.stdout + build.stderr)
        run = subprocess.run(["lake", "env", "lean", "--run", "Test/Capstone/Sigops.lean"],
                             cwd=core, text=True, capture_output=True, timeout=120)
    results = re.findall(r"^\[(PASS|FAIL)\] (.*): expected=(\d+), actual=(\d+)$", run.stdout, re.MULTILINE)
    require(run.returncode == 1 and len(results) == 28 and len({r[1] for r in results}) == 28, run.stdout + run.stderr)
    require({r[1] for r in results if r[0] == "FAIL"} == FAILURES, results)
    require(all((int(r[2]) == int(r[3])) == (r[0] == "PASS") for r in results), results)
    print(run.stdout, end="")
    print(json.dumps({"baseline_commit": before, "expected_failures": 18, "passing_controls": 10,
                      "baseline_lean_exit": run.returncode, "reproduction": "confirmed"}))


if __name__ == "__main__":
    main()
