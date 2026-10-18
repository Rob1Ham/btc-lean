#!/usr/bin/env python3
"""Reproduce R04's five public-path failures against the committed old validator.

Run after building the current core, with pinned Lean/Lake on PATH. The old
validator is compiled verbatim except for its namespace. A small adapter
discards the context argument, matching the old API's lack of such input.
The current test's public cases then execute that old validator. Success of
this reproduction means exactly five behavioral failures and two controls;
compiler/setup failures cannot count as a reproduced defect.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BASELINE = "140e8efd4877dea9510832cb04cc6fb38ddd49a8"
SOURCE = "spec/core/Bitcoin/Capstone/Block.lean"


def main() -> int:
    old = subprocess.check_output(["git", "show", f"{BASELINE}:{SOURCE}"], cwd=ROOT, text=True)
    print(f"baseline={BASELINE} source_sha256={hashlib.sha256(old.encode()).hexdigest()}", flush=True)
    old = old.replace("Bitcoin.Capstone.Block", "Bitcoin.Capstone.BeforeR04")
    test = (ROOT / "spec/core/Test/Capstone/HeaderContext.lean").read_text()
    test = test[test.index("/-!"):test.index("private def helperChecks")]
    # Coverage reporting did not exist in the old CapReport; it is tested
    # separately on current source, not simulated in the baseline adapter.
    start, end = test.index("private def reportContext"), test.index("private def header :")
    test = test[:start] + test[end:]
    test = test.replace("open Bitcoin.Capstone.Block", "open Bitcoin.Capstone.BeforeR04")
    adapter = """
namespace Bitcoin.Capstone.BeforeR04
def validateBlockInContext (raw : ByteArray) (st : CapState)
    (_ : Bitcoin.Capstone.Context.ChainContext) : Except CapError CapReport :=
  validateBlock raw st
end Bitcoin.Capstone.BeforeR04
"""
    runner = """
def run : IO UInt32 := do
  let results ← publicChecks.mapM fun (name, actual, expected) => do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    return ok
  return if results.all id then 0 else 1
end Test.Capstone.HeaderContext
def main : IO UInt32 := Test.Capstone.HeaderContext.run
"""
    with tempfile.TemporaryDirectory(prefix="btc-lean-r04-before-") as tmp:
        path = Path(tmp) / "Baseline.lean"
        path.write_text("import Bitcoin.Capstone.Context\nimport Bitcoin.Block.Params\n" + old + adapter + test + runner)
        proc = subprocess.run(["lake", "env", "lean", "--run", str(path)],
                              cwd=ROOT / "spec/core", text=True, capture_output=True, timeout=60)
    print(proc.stdout, end="")
    print(proc.stderr, end="")
    checks = [line for line in proc.stdout.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    expected_failures = [
        "public node-clock plus 7201 rejects",
        "public expected retarget bits reject a difficulty-1 candidate",
        "public sparse MTP history is unavailable",
        "public parent height must match candidate",
        "public missing parent is unavailable",
    ]
    failures = [line[len("[FAIL] "):].split(": expected=", 1)[0]
                for line in checks if line.startswith("[FAIL]")]
    if proc.returncode != 1 or len(checks) != 7 or failures != expected_failures:
        raise SystemExit("R04 reproduction failed: expected exactly five behavioral failures and two passing controls")
    print("R04 baseline reproduction: five public-path defects confirmed; two valid controls pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
