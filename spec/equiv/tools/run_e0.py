#!/usr/bin/env python3
"""E0 smoke runner: Alive2 hello-world + negative control + SAW hello-world.

This does NOT fabricate a three-leg result. It runs exactly the artifacts that
exist in tools/tests/ and reports the three-leg shims as PENDING until
CONTRACT/CORE-IR/TWIN-IR/RUST-IR land them.

Usage:
  python3 tools/run_e0.py [--verbose] [--strict-e0]

Exit 0 means the TOOLS-side E0 probes are green. --strict-e0 additionally
requires the three-leg shim sources to exist (the full E0 triple).
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "tools" / "tests"
FINDINGS = ROOT / "findings" / "tools"

ALIVE_CANDIDATES = [
    "/opt/equiv-tools/alive-tv-v20.0",
    "/tmp/opencode/equiv-work/alive2/build/alive-tv",
]
SAW_CANDIDATES = [
    "/opt/equiv-tools/saw-1.6/bin/saw",
    "/tmp/opencode/equiv-work/saw/bin/saw",
]


def find_exe(name: str, candidates: list[str]) -> str | None:
    w = shutil.which(name)
    if w:
        return w
    for c in candidates:
        if Path(c).is_file() and os.access(c, os.X_OK):
            return c
    return None


def run(cmd: list[str], cwd: Path, env: dict | None = None, timeout: int = 600):
    try:
        p = subprocess.run(
            cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout, env=env
        )
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or "") + (e.stderr or "")
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
        return 124, out + f"\nTIMEOUT after {timeout}s"


def excerpt(out: str, verbose: bool, lines: int = 12) -> str:
    if verbose:
        return out
    ls = [ln for ln in out.splitlines() if ln.strip()]
    return "\n".join(ls[:lines] + (["..."] if len(ls) > lines else []))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true", help="print full tool logs")
    ap.add_argument("--strict-e0", action="store_true", help="fail unless three-leg shims exist")
    args = ap.parse_args()

    FINDINGS.mkdir(parents=True, exist_ok=True)
    alive = find_exe("alive-tv", ALIVE_CANDIDATES)
    saw = find_exe("saw", SAW_CANDIDATES)

    print("== E0 tool probes ==")
    print(f"  alive-tv: {alive or 'MISSING'}")
    print(f"  saw:      {saw or 'MISSING'}")

    results: list[tuple[str, str, bool, str]] = []

    # --- Alive2 positive ---
    if alive:
        rc, out = run([alive, "hello-a.ll", "hello-b.ll"], TESTS)
        (FINDINGS / "e0-alive2-positive.out").write_text(out)
        ok = (
            "Transformation seems to be correct" in out
            and "0 incorrect transformations" in out
            and "0 Alive2 errors" in out
        )
        results.append(("alive2 positive", "hello-a.ll vs hello-b.ll", ok, out))
    else:
        results.append(("alive2 positive", "hello-a.ll vs hello-b.ll", False, "tool missing"))

    # --- Alive2 negative control (exit code is NOT reliable) ---
    if alive:
        rc, out = run([alive, "hello-a.ll", "hello-bad.ll"], TESTS)
        (FINDINGS / "e0-alive2-negative.out").write_text(out)
        ok = (
            "Transformation doesn't verify" in out
            and "1 incorrect transformations" in out
            and ("Value mismatch" in out or "ERROR" in out)
        )
        # Record whether the exit code lies; this is a gate-design fact.
        results.append(("alive2 negative", "hello-a.ll vs hello-bad.ll", ok, out))
        print(f"  note: negative-control exit code = {rc} (0 is expected; parse output!)")
    else:
        results.append(("alive2 negative", "hello-a.ll vs hello-bad.ll", False, "tool missing"))

    # --- SAW positive ---
    if saw:
        env = dict(os.environ)
        saw_bin = str(Path(saw).resolve().parent)
        env["PATH"] = saw_bin + os.pathsep + env.get("PATH", "")
        rc, out = run([saw, "hello.saw"], TESTS, env=env)
        (FINDINGS / "e0-saw-positive.out").write_text(out)
        ok = rc == 0 and "SAW_E0_HELLO_OK" in out and out.count("Proof succeeded") >= 2
        results.append(("saw positive", "tools/tests/hello.saw", ok, out))
    else:
        results.append(("saw positive", "tools/tests/hello.saw", False, "tool missing"))

    print("\n== results ==")
    for name, target, ok, out in results:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}: {target}")
        if not ok or args.verbose:
            print("        " + excerpt(out, args.verbose).replace("\n", "\n        "))

    # --- three-leg shims: report, and only run an explicit triple script ---
    print("\n== three-leg E0 shims ==")
    legs = {"C": "core", "L": "twin", "R": "rust"}
    shim_sources: dict[str, list[Path]] = {}
    for leg, sub in legs.items():
        d = ROOT / "shims" / sub
        srcs = []
        if d.is_dir():
            for pat in ("*.c", "*.cc", "*.cpp", "*.rs"):
                srcs += sorted(d.glob(pat))
        shim_sources[leg] = srcs
        print(f"  {leg}: {'present: ' + ', '.join(p.name for p in srcs) if srcs else 'PENDING (no source in shims/' + sub + ')'}")

    # This is the only way run_e0.py will claim a triple: an explicit script
    # owned by CONTRACT/CORE-IR that prints E0_TRIPLE_OK. Merely having source
    # files is not a result.
    triple_script = TESTS / "e0-triple.sh"
    triple_ran = triple_green = False
    if triple_script.is_file():
        rc, out = run(["bash", str(triple_script)], ROOT)
        (FINDINGS / "e0-triple.out").write_text(out)
        triple_ran = True
        triple_green = rc == 0 and "E0_TRIPLE_OK" in out
        print(f"  triple script: {'GREEN' if triple_green else 'RED'} (rc={rc})")
        if not triple_green:
            print("        " + excerpt(out, args.verbose).replace("\n", "\n        "))
    else:
        print("  triple script: PENDING (tools/tests/e0-triple.sh not present)")

    tools_ok = all(ok for _, _, ok, _ in results)
    sources_present = all(bool(v) for v in shim_sources.values())

    print("\n== summary ==")
    print(f"  TOOLS probes: {'GREEN' if tools_ok else 'RED'}")
    if triple_green:
        print("  Three-leg hello-world: GREEN (executed by tools/tests/e0-triple.sh)")
    elif triple_ran:
        print("  Three-leg hello-world: RED (triple script ran but did not pass)")
    elif sources_present:
        print("  Three-leg hello-world: PRESENT but NOT EXECUTED")
    else:
        print("  Three-leg hello-world: PENDING (shim sources missing)")
    if not triple_green:
        if triple_ran:
            print("  next: the triple script ran; fill the STUB legs named above.")
            print("        A stub returning 3/UNKNOWN is not a pass.")
        else:
            print("  next: shim owners must provide tools/tests/e0-triple.sh printing")
            print("        E0_TRIPLE_OK after building/running C/L/R entry points.")
        if tools_ok:
            print("  RESULT: TOOLS READY; E0 TRIPLE PENDING")
            return 1 if args.strict_e0 else 0
        print("  RESULT: FAIL (tool probes red)")
        return 1
    print("  RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
