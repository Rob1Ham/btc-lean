#!/usr/bin/env python3
"""Run one E1 mutant against its expected gate cell and record the kill.

The mutation is applied only through `mutate.py` (never by editing a source
directly).  The expected cell is rebuilt from the mutant source, both tools are
run, and the run fails unless at least one tool reports a non-green result.
The source is then reverted and the baseline is re-run green.

Usage:
  python3 cells/_redteam/run_mutant.py \
      --mutation M-E1-001 --target-kind twin \
      --cell e1-stack/swap-order --fn cell_swap_order
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
EQ = HERE.parents[1]
MUTATE = HERE / "mutate.py"
RUNS = HERE / "runs"

TARGETS = {
    "twin": EQ / "twin" / "ops_ir.py",
    "core-copy": EQ / "cells" / "_tools" / "gate" / "c_leaf.cpp",
}


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def sh(cmd: list[str], cwd: Path, timeout: int = 900) -> tuple[int, str]:
    p = subprocess.run(
        cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout
    )
    return p.returncode, p.stdout + p.stderr


def status_from(path: Path) -> str:
    if not path.is_file():
        return "missing"
    text = path.read_text(errors="replace")
    for line in reversed(text.splitlines()):
        if line.startswith("STATUS="):
            return line.split("=", 1)[1]
    return "no-status"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mutation", required=True)
    ap.add_argument("--target-kind", required=True, choices=sorted(TARGETS))
    ap.add_argument("--cell", required=True, help="e1-stack/swap-order")
    ap.add_argument("--fn", required=True, help="cell_swap_order")
    args = ap.parse_args()

    cell = EQ / "cells" / args.cell
    target = TARGETS[args.target_kind]
    RUNS.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    label = f"{args.mutation}-{args.target_kind}"

    baseline_target = sha(target)
    baseline_alive = sha(cell / "alive2" / "result.txt") if (cell / "alive2" / "result.txt").exists() else None
    baseline_saw = sha(cell / "saw" / "result.txt") if (cell / "saw" / "result.txt").exists() else None

    # Baseline must be green before mutation.
    rc_a, out_a = sh(["bash", "run.sh"], cell / "alive2")
    rc_s, out_s = sh(["bash", "run.sh"], cell / "saw")
    base_a = status_from(cell / "alive2" / "result.txt")
    base_s = status_from(cell / "saw" / "result.txt")
    if base_a != "alive2-green" or base_s != "saw-green":
        print(f"BASELINE NOT GREEN: alive2={base_a} saw={base_s}", file=sys.stderr)
        return 1

    rc, apply_out = sh(
        [
            sys.executable,
            str(MUTATE),
            "--target",
            str(target),
            "--mutation",
            args.mutation,
            "--target-kind",
            args.target_kind,
        ],
        EQ,
    )
    if rc != 0:
        print(apply_out, file=sys.stderr)
        return 1
    record = None
    for line in apply_out.splitlines():
        if line.startswith("record:"):
            record = line.split(":", 1)[1].strip()
    if not record:
        print("no mutant record path in mutate.py output", file=sys.stderr)
        return 1

    mutant_target = sha(target)
    mutant_a = mutant_s = "not-run"
    try:
        rc_a, out_a = sh(["bash", "run.sh"], cell / "alive2")
        rc_s, out_s = sh(["bash", "run.sh"], cell / "saw")
        mutant_a = status_from(cell / "alive2" / "result.txt")
        mutant_s = status_from(cell / "saw" / "result.txt")
    finally:
        rc_r, revert_out = sh([sys.executable, str(MUTATE), "--revert", record], EQ)
        reverted = rc_r == 0 and sha(target) == baseline_target

    # Re-run baseline after revert.
    rc_a2, out_a2 = sh(["bash", "run.sh"], cell / "alive2")
    rc_s2, out_s2 = sh(["bash", "run.sh"], cell / "saw")
    post_a = status_from(cell / "alive2" / "result.txt")
    post_s = status_from(cell / "saw" / "result.txt")
    baseline_ok = post_a == "alive2-green" and post_s == "saw-green"

    killed = (mutant_a != "alive2-green") or (mutant_s != "saw-green")
    ok = killed and reverted and baseline_ok and mutant_target != baseline_target

    report = RUNS / f"{label}-{stamp}.md"
    lines = [
        f"# Mutant run {label}",
        "",
        f"- **time:** {stamp}",
        f"- **mutation:** `{args.mutation}` / `{args.target_kind}`",
        f"- **target:** `{target.relative_to(EQ)}`",
        f"- **target sha256 before:** `{baseline_target}`",
        f"- **target sha256 mutant:** `{mutant_target}`",
        f"- **record:** `{record}`",
        f"- **expected cell:** `cells/{args.cell}` (`{args.fn}`)",
        "",
        "## Result",
        "",
        f"- baseline before: alive2=`{base_a}`, saw=`{base_s}`",
        f"- mutant: alive2=`{mutant_a}`, saw=`{mutant_s}`",
        f"- reverted: `{reverted}`; baseline after revert: alive2=`{post_a}`, saw=`{post_s}`",
        f"- **{'KILLED' if killed else 'SURVIVED'}** (at least one tool non-green required)",
        "",
        "## Mutant result tails",
        "",
        "### Alive2",
        "```",
        (cell / "alive2" / "result.txt").read_text(errors="replace")[-1200:].strip(),
        "```",
        "",
        "### SAW",
        "```",
        (cell / "saw" / "result.txt").read_text(errors="replace")[-1200:].strip(),
        "```",
        "",
        "## Revert",
        "",
        "```",
        revert_out.strip()[-800:],
        "```",
        "",
    ]
    report.write_text("\n".join(lines) + "\n")
    print(f"{'KILLED' if killed else 'SURVIVED'}: {label} -> {report}")
    print(f"  mutant: alive2={mutant_a} saw={mutant_s}; reverted={reverted}; baseline_ok={baseline_ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
