#!/usr/bin/env python3
"""Run the cell suite under cells/<family>/<cell>/.

Conventions discovered here (CELLS may extend them):
  cells/<family>/<cell>/alive2/run.sh          -> executed in alive2/
  cells/<family>/<cell>/alive2/*.ll (exactly 2) -> alive-tv src.ll tgt.ll
  cells/<family>/<cell>/saw/run.sh             -> executed in saw/
  cells/<family>/<cell>/saw/*.saw (exactly 1)   -> saw <file>

If a cell has only a record file and no runner, it is reported TODO rather
than treated as green. Alive2's exit code is ignored for correctness (it is 0
even for counterexamples); its report text is parsed instead.

E0 has no cells yet, so this prints SKIP and exits 0.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CELLS = ROOT / "cells"

ALIVE_CANDIDATES = [
    "/opt/equiv-tools/alive-tv-v20.0",
    "/tmp/opencode/equiv-work/alive2/build/alive-tv",
]
SAW_CANDIDATES = [
    "/opt/equiv-tools/saw-1.6/bin/saw",
    "/tmp/opencode/equiv-work/saw/bin/saw",
]
RECORD_NAMES = (
    "spec.md",
    "record.yaml",
    "record.json",
    "cell.yaml",
    "cell.json",
    "meta.yaml",
    "meta.json",
)


def find_exe(name: str, candidates: list[str]) -> str | None:
    w = shutil.which(name)
    if w:
        return w
    for c in candidates:
        p = Path(c)
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None


def run(cmd: list[str], cwd: Path, env: dict | None = None, timeout: int = 1800):
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


def recorded_status(cell: Path) -> str | None:
    for name in RECORD_NAMES:
        p = cell / name
        if not p.is_file():
            continue
        try:
            import yaml  # type: ignore

            text = p.read_text()
            if name == "spec.md":
                # The cell schema is YAML front matter, not a full YAML file.
                if not text.startswith("---"):
                    return None
                text = text.split("---", 2)[1]
            doc = yaml.safe_load(text)
            if isinstance(doc, dict):
                for key in ("status", "tool_status"):
                    if doc.get(key):
                        return str(doc[key])
        except Exception:
            return None
    return None




def tool_body(text: str) -> str:
    """Drop cell-runner annotation lines; a comment saying "no Proof failed"
    must not be read as a failure.  The tool output proper has no leading #."""
    return "\n".join(ln for ln in text.splitlines() if not ln.lstrip().startswith("#"))


def run_alive2(cell: Path, alive: str | None, verbose: bool):
    d = cell / "alive2"
    if not d.is_dir():
        return None
    if (d / "run.sh").is_file():
        rc, out = run(["bash", "run.sh"], d)
        # The gate wrapper writes the tool output to result.txt and exits with
        # the cell status; its stdout is only the leaf-build log.
        rp = d / "result.txt"
        recorded = rp.read_text(errors="replace") if rp.is_file() else ""
        body = tool_body(recorded)
        ok = (
            rc == 0
            and "STATUS=alive2-green" in recorded
            and "Transformation seems to be correct" in body
            and "0 incorrect transformations" in body
        )
        return ok, f"run.sh rc={rc}, result.txt", recorded or out
    lls = sorted(d.glob("*.ll"))
    if len(lls) != 2:
        return None
    if not alive:
        return False, "alive-tv missing", ""
    rc, out = run([alive, lls[0].name, lls[1].name], d)
    body = tool_body(out)
    ok = (
        "Transformation seems to be correct" in body
        and "0 incorrect transformations" in body
        and "0 Alive2 errors" in body
    )
    return ok, f"alive-tv {lls[0].name} {lls[1].name} (rc={rc}, exit code ignored)", out


def run_saw(cell: Path, saw: str | None, verbose: bool):
    d = cell / "saw"
    if not d.is_dir():
        return None
    if (d / "run.sh").is_file():
        env = dict(os.environ)
        if saw:
            env["PATH"] = str(Path(saw).resolve().parent) + os.pathsep + env.get("PATH", "")
        rc, out = run(["bash", "run.sh"], d, env=env)
        rp = d / "result.txt"
        recorded = rp.read_text(errors="replace") if rp.is_file() else ""
        body = tool_body(recorded)
        ok = (
            rc == 0
            and "STATUS=saw-green" in recorded
            and "Proof succeeded" in body
            and "Proof failed" not in body
        )
        return ok, f"run.sh rc={rc}, result.txt", recorded or out
    saws = sorted(d.glob("*.saw"))
    if len(saws) != 1:
        return None
    if not saw:
        return False, "saw missing", ""
    env = dict(os.environ)
    env["PATH"] = str(Path(saw).resolve().parent) + os.pathsep + env.get("PATH", "")
    rc, out = run([saw, saws[0].name], d, env=env)
    body = tool_body(out)
    ok = rc == 0 and "Proof succeeded" in body and "Proof failed" not in body
    return ok, f"saw {saws[0].name} (rc={rc})", out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--timeout", type=int, default=1800)
    args = ap.parse_args()

    if not CELLS.is_dir():
        print(f"SKIP: no cells directory at {CELLS}")
        return 0
    cells = sorted(
        p
        for p in CELLS.glob("*/*")
        if p.is_dir()
        and not any(part.startswith("_") for part in p.relative_to(CELLS).parts)
        and p.name not in {"logs", "saw", "alive2", "build", "witnesses", "behavior"}
    )
    if not cells:
        print("SKIP: no cells under cells/<family>/<cell>/ (E0: expected)")
        print("      CELLS role has not landed any cell yet; nothing was run.")
        return 0

    alive = find_exe("alive-tv", ALIVE_CANDIDATES)
    saw = find_exe("saw", SAW_CANDIDATES)
    print(f"alive-tv: {alive or 'MISSING'}")
    print(f"saw:      {saw or 'MISSING'}")
    print(f"cells:    {len(cells)}\n")

    npass = nfail = ntodo = 0
    for cell in cells:
        rel = cell.relative_to(CELLS)
        print(f"== {rel} ==")
        rec = recorded_status(cell)
        if rec:
            print(f"  recorded status: {rec}")

        a = run_alive2(cell, alive, args.verbose)
        s = run_saw(cell, saw, args.verbose)
        if a is None and s is None:
            ntodo += 1
            print("  TODO: no alive2/ or saw/ runner present" + (f" (record: {rec})" if rec else ""))
            continue

        for label, r in (("alive2", a), ("saw", s)):
            if r is None:
                print(f"  {label}: TODO (no runner)")
                continue
            ok, why, out = r
            print(f"  {label}: {'PASS' if ok else 'FAIL'} — {why}")
            if not ok or args.verbose:
                tail = [ln for ln in out.splitlines() if ln.strip()][:10]
                for ln in tail:
                    print("      " + ln)
        ran = [r for r in (a, s) if r is not None]
        if any(not ok for ok, _, _ in ran):
            nfail += 1
        elif ran:
            npass += 1
        else:
            ntodo += 1
        print()

    print(f"summary: {npass} cell(s) with >=1 green tool, {nfail} red, {ntodo} TODO")
    return 0 if nfail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
