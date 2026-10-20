#!/usr/bin/env python3
"""Run one catalogue mutant against one existing cell and produce an admissible
record.

This is the wave64 extension of ``run_mutant.py``.  Unlike the E1 runner it is
generic over the target file and the expected cell, and it completes the
protocol fields the earlier runs left pending:

  * baseline B-gate (both tools green, repeated for determinism);
  * a *pre-execution* witness declaration written before the mutation is
    applied;
  * the mutation applied only through ``mutate.py`` (never by hand);
  * raw tool logs and result files copied into ``runs/<label>-<stamp>/``;
  * the mutant outcome, concrete witness, log hashes, operator and revert time
    written into the mutant JSON record;
  * revert, target-hash equality, and a green post-revert baseline.

A build failure, a missing result file, a raw tool crash, or a failed baseline
is classified ``INVALID`` -- never ``KILLED`` (PROTOCOL.md 2.5).

Usage:
  python3 spec/equiv/cells/_redteam/run_mutant_admissible.py \
      --mutation M-E3-002 --target-kind e3-cell \
      --target spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp \
      --cell e3-cms/C-L-cms-1of1 \
      --witness-plan "cell_cms_nulldummy: dummy=0x55, null_dummy=true -> ..."
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
EQ = HERE.parents[1]              # spec/equiv
ROOT = HERE.parents[3]            # repo root
MUTATE = HERE / "mutate.py"
RUNS = HERE / "runs"
OPERATOR = "wave64/48-mutations-e3e4 (subagent)"

TOOLS = ("alive2", "saw")


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str | None:
    return sha_bytes(path.read_bytes()) if path.is_file() else None


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def status_from(path: Path) -> str:
    if not path.is_file():
        return "missing"
    for line in reversed(path.read_text(errors="replace").splitlines()):
        if line.startswith("STATUS="):
            return line.split("=", 1)[1].strip()
    return "no-status"


def is_green(status: str, tool: str) -> bool:
    return status.startswith(f"{tool}-green")


def sh(cmd: list[str], cwd: Path, log: Path, timeout: int) -> tuple[int, str]:
    p = subprocess.run(
        cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout
    )
    text = p.stdout + p.stderr
    log.write_text(text)
    return p.returncode, text


def extract_alive2_witness(result: Path) -> str:
    if not result.is_file():
        return ""
    text = result.read_text(errors="replace")
    # Prefer the concrete return-value mismatch, which is the kill witness.
    pairs = list(re.finditer(
        r"^Source value:.*\nTarget value:.*$", text, re.MULTILINE
    ))
    if pairs:
        picked: list[str] = []
        for m in pairs[-2:]:
            head = text.rfind("=====", 0, m.start())
            fn = ""
            if head != -1:
                line_end = text.find("\n", head)
                fn = text[head:line_end].strip()
            picked.append((fn + "\n" if fn else "") + m.group(0))
        return "\n\n".join(picked)
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if "Transformation doesn't verify" in line or "ERROR:" in line:
            return "\n".join(lines[i:i + 14]).strip()
    return ""


def extract_saw_witness(result: Path) -> str:
    if not result.is_file():
        return ""
    text = result.read_text(errors="replace")
    m = re.search(
        r"-{10}Counterexample-{10}\n(.*?)\n-{10,}", text, re.DOTALL
    )
    if m:
        return m.group(1).strip()
    if "Proof failed" in text:
        return "Proof failed (no counterexample block in the raw log)"
    return ""


def run_cell(cell: Path, tag: str, run_dir: Path, timeout: int) -> dict:
    """Run both tools for one stage; return observed statuses and log hashes."""
    observed: dict = {}
    for tool in TOOLS:
        script = cell / tool / "run.sh"
        result = cell / tool / "result.txt"
        log = run_dir / f"{tag}-{tool}.log"
        result_copy = run_dir / f"{tag}-{tool}-result.txt"
        # A stale green result must not be mistaken for a fresh run.
        result.unlink(missing_ok=True)
        rc, _ = sh(["bash", "run.sh"], cell / tool, log, timeout)
        status = status_from(result)
        if result.is_file():
            result_copy.write_bytes(result.read_bytes())
        observed[tool] = {
            "exit_code": rc,
            "status": status,
            "result_path": str(result.relative_to(ROOT)),
            "result_sha256": sha_file(result),
            "log": str(log.relative_to(ROOT)),
            "log_sha256": sha_file(log),
        }
    return observed


def green_pair(observed: dict) -> bool:
    return all(is_green(observed[t]["status"], t) for t in TOOLS)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mutation", required=True)
    ap.add_argument("--target-kind", required=True,
                    choices=["twin", "core-copy", "rust-copy", "e3-cell", "e4-cell"])
    ap.add_argument("--target", required=True,
                    help="target source file, relative to the repo root or absolute")
    ap.add_argument("--cell", required=True,
                    help="cell id relative to spec/equiv/cells, e.g. e3-cms/C-L-cms-1of1")
    ap.add_argument("--witness-plan", required=True,
                    help="concrete witness and expected baseline/mutant observable, "
                         "declared BEFORE the mutation is applied")
    ap.add_argument("--timeout", type=int, default=1800)
    args = ap.parse_args()

    target = Path(args.target)
    if not target.is_absolute():
        target = ROOT / target
    target = target.resolve()
    try:
        target.relative_to(ROOT)
    except ValueError:
        print(f"REFUSED: target outside repo: {target}", file=sys.stderr)
        return 3
    cell = (EQ / "cells" / args.cell).resolve()
    try:
        cell.relative_to(ROOT)
    except ValueError:
        print(f"REFUSED: cell outside repo: {cell}", file=sys.stderr)
        return 3
    for tool in TOOLS:
        if not (cell / tool / "run.sh").is_file():
            print(f"REFUSED: missing {cell / tool / 'run.sh'}", file=sys.stderr)
            return 3

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    label = f"{args.mutation}-{args.target_kind}"
    run_dir = RUNS / f"{label}-{stamp}"
    run_dir.mkdir(parents=True, exist_ok=False)

    spec_file = cell / "spec.md"
    spec_sha_before = sha_file(spec_file)
    target_sha_before = sha_file(target)
    head = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
        capture_output=True, text=True,
    ).stdout.strip()
    git_status_before = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain"],
        capture_output=True, text=True,
    ).stdout

    def rel(p: Path | None) -> str | None:
        if p is None:
            return None
        try:
            return str(p.relative_to(ROOT))
        except ValueError:
            return str(p)

    print(f"[{label}] baseline B-gate (both tools, unmutated)")
    base = run_cell(cell, "baseline-before", run_dir, args.timeout)
    if not green_pair(base):
        meta = {
            "mutant_id": args.mutation, "target_kind": args.target_kind,
            "classification": "INVALID", "reason": "baseline not green",
            "baseline": base,
        }
        (run_dir / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
        print("INVALID: baseline not green; mutation not applied", file=sys.stderr)
        return 1

    # Declare the witness BEFORE touching the source (PROTOCOL.md 2.6 / B7).
    dry = subprocess.run(
        [sys.executable, str(MUTATE), "--target", str(target),
         "--mutation", args.mutation, "--target-kind", args.target_kind,
         "--dry-run"],
        cwd=str(ROOT), capture_output=True, text=True, timeout=120,
    )
    (run_dir / "dry-run.log").write_text(dry.stdout + dry.stderr)
    plan = [
        f"# Pre-execution mutant plan {label}",
        "",
        f"- time: {stamp}",
        f"- mutation: `{args.mutation}` / `{args.target_kind}`",
        f"- target: `{rel(target)}`",
        f"- target sha256 before: `{target_sha_before}`",
        f"- expected cell: `cells/{args.cell}`",
        f"- cell spec sha256 before: `{spec_sha_before}`",
        f"- baseline before: alive2=`{base['alive2']['status']}`, "
        f"saw=`{base['saw']['status']}`",
        "",
        "## Declared witness (written before mutation)",
        "",
        args.witness_plan.strip(),
        "",
        "## Declared mutation diff (mutate.py --dry-run)",
        "",
        "```diff",
        dry.stdout.strip(),
        "```",
        "",
    ]
    (run_dir / "plan.md").write_text("\n".join(plan) + "\n")

    record_path: Path | None = None
    revert_out = ""
    reverted = False
    try:
        print(f"[{label}] applying mutation via mutate.py")
        apply = subprocess.run(
            [sys.executable, str(MUTATE), "--target", str(target),
             "--mutation", args.mutation, "--target-kind", args.target_kind],
            cwd=str(ROOT), capture_output=True, text=True, timeout=120,
        )
        (run_dir / "apply.log").write_text(apply.stdout + apply.stderr)
        if apply.returncode != 0:
            raise RuntimeError(f"mutate.py apply failed: {apply.stderr.strip()}")
        for line in apply.stdout.splitlines():
            if line.startswith("record:"):
                record_path = Path(line.split(":", 1)[1].strip())
        if record_path is None or not record_path.is_file():
            raise RuntimeError("mutate.py did not report a record path")

        target_sha_mutant = sha_file(target)
        if target_sha_mutant == target_sha_before:
            raise RuntimeError("mutation produced no target hash change")

        print(f"[{label}] mutant run (both tools)")
        mutant = run_cell(cell, "mutant", run_dir, args.timeout)
        alive2_witness = extract_alive2_witness(
            run_dir / "mutant-alive2-result.txt")
        saw_witness = extract_saw_witness(run_dir / "mutant-saw-result.txt")
        witness = "\n".join(
            s for s in (
                f"alive2:\n{alive2_witness}" if alive2_witness else "",
                f"saw:\n{saw_witness}" if saw_witness else "",
            ) if s
        )
    finally:
        if record_path is not None:
            print(f"[{label}] reverting via mutate.py")
            revert = subprocess.run(
                [sys.executable, str(MUTATE), "--revert", str(record_path)],
                cwd=str(ROOT), capture_output=True, text=True, timeout=120,
            )
            revert_out = revert.stdout + revert.stderr
            (run_dir / "revert.log").write_text(revert_out)
            reverted = (
                revert.returncode == 0 and sha_file(target) == target_sha_before
            )

    print(f"[{label}] post-revert baseline")
    post = run_cell(cell, "baseline-after", run_dir, args.timeout)
    spec_sha_after = sha_file(spec_file)
    baseline_ok = green_pair(post) and reverted
    spec_ok = spec_sha_before == spec_sha_after

    mutant_present = all(
        mutant[t]["status"] not in ("missing", "no-status") for t in TOOLS
    )
    mutant_green = green_pair(mutant)
    if not reverted or not baseline_ok or not spec_ok or not mutant_present:
        classification = "INVALID"
    elif mutant_green:
        classification = "SURVIVED"
    else:
        classification = "KILLED"

    log_hashes = []
    for f in sorted(run_dir.iterdir()):
        if f.is_file() and f.name != "meta.json":
            log_hashes.append(f"{sha_file(f)}  {rel(f)}")

    meta = {
        "schema": "redteam-mutant-run-v2",
        "mutant_id": args.mutation,
        "target_kind": args.target_kind,
        "cell": f"cells/{args.cell}",
        "operator": OPERATOR,
        "git_head": head,
        "git_status_before": git_status_before.splitlines(),
        "target": rel(target),
        "target_sha256_before": target_sha_before,
        "target_sha256_mutant": target_sha_mutant,
        "target_sha256_after_revert": sha_file(target),
        "cell_spec_sha256_before": spec_sha_before,
        "cell_spec_sha256_after": spec_sha_after,
        "witness_plan": args.witness_plan.strip(),
        "baseline_before": base,
        "mutant": mutant,
        "baseline_after": post,
        "reverted": reverted,
        "revert_output": revert_out.strip(),
        "classification": classification,
        "witness": witness,
        "log_hashes": log_hashes,
        "record": rel(record_path) if record_path else None,
        "run_dir": rel(run_dir),
        "started_at_utc": stamp,
    }
    (run_dir / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")

    commands = [
        f"bash {rel(cell / 'alive2' / 'run.sh')}   # baseline/mutant/post",
        f"bash {rel(cell / 'saw' / 'run.sh')}",
        f"python3 {rel(MUTATE)} --target {rel(target)} "
        f"--mutation {args.mutation} --target-kind {args.target_kind}",
        f"python3 {rel(MUTATE)} --revert {rel(record_path) if record_path else '<record>'}",
    ]
    report = [
        f"# Admissible mutant run {label}",
        "",
        f"- **time:** {stamp}",
        f"- **mutation:** `{args.mutation}` / `{args.target_kind}`",
        f"- **expected cell:** `cells/{args.cell}`",
        f"- **target:** `{rel(target)}`",
        f"- **operator:** {OPERATOR}",
        f"- **git head:** `{head}`",
        f"- **classification:** **{classification}**",
        "",
        "## B-gate (before)",
        "",
        f"- target sha256: `{target_sha_before}`",
        f"- cell spec sha256: `{spec_sha_before}`",
        f"- alive2: `{base['alive2']['status']}` (exit {base['alive2']['exit_code']})",
        f"- saw: `{base['saw']['status']}` (exit {base['saw']['exit_code']})",
        "",
        "## Declared witness (before execution)",
        "",
        args.witness_plan.strip(),
        "",
        "## Exact commands",
        "",
        "```sh",
        *commands,
        "```",
        "",
        "## Mutation diff",
        "",
        "```diff",
        dry.stdout.strip(),
        "```",
        "",
        "## Mutant result",
        "",
        f"- target sha256 mutant: `{target_sha_mutant}`",
        f"- alive2: `{mutant['alive2']['status']}` "
        f"(exit {mutant['alive2']['exit_code']})",
        f"- saw: `{mutant['saw']['status']}` "
        f"(exit {mutant['saw']['exit_code']})",
        "",
        "### Concrete witness",
        "",
        "```",
        witness or "(none extracted; see raw result files)",
        "```",
        "",
        "### Raw logs",
        "",
        *[f"- `{h.split('  ', 1)[1]}`" for h in log_hashes
          if "/mutant-" in h],
        "",
        "## Revert and post-revert baseline",
        "",
        f"- reverted: `{reverted}`",
        f"- target sha256 after revert: `{sha_file(target)}`",
        f"- alive2: `{post['alive2']['status']}` "
        f"(exit {post['alive2']['exit_code']})",
        f"- saw: `{post['saw']['status']}` "
        f"(exit {post['saw']['exit_code']})",
        f"- cell spec sha256 after: `{spec_sha_after}`",
        "",
        "```text",
        revert_out.strip(),
        "```",
        "",
        "## Log hashes",
        "",
        "```text",
        *log_hashes,
        "```",
        "",
        "## Scope",
        "",
        "This is an L-leg (transliteration) proof-sensitivity kill on the named",
        "bounded cell. It is not a model-site or core-copy kill, does not promote",
        "any SCR row, and does not turn the partial cell into a row-green claim.",
        "",
    ]
    report_path = run_dir / "report.md"
    report_path.write_text("\n".join(report) + "\n")

    if record_path is not None:
        rec = json.loads(record_path.read_text())
        rec.update({
            "status": "reverted" if reverted else "applied",
            "outcome": classification.lower(),
            "classification": classification,
            "observed": {
                "baseline_before": {t: base[t]["status"] for t in TOOLS},
                "mutant": {t: mutant[t]["status"] for t in TOOLS},
                "baseline_after": {t: post[t]["status"] for t in TOOLS},
                "exit_codes_mutant": {t: mutant[t]["exit_code"] for t in TOOLS},
                "cell": f"cells/{args.cell}",
            },
            "witness": witness,
            "log_hashes": log_hashes,
            "operator": OPERATOR,
            "reverted_at_utc": utc_now() if reverted else None,
            "run_report": rel(report_path),
            "run_meta": rel(run_dir / "meta.json"),
        })
        record_path.write_text(json.dumps(rec, indent=2, sort_keys=True) + "\n")

    print(f"{classification}: {label} -> {rel(report_path)}")
    print(f"  mutant: alive2={mutant['alive2']['status']} "
          f"saw={mutant['saw']['status']}; reverted={reverted}; "
          f"baseline_ok={baseline_ok}")
    return 0 if classification == "KILLED" else 1


if __name__ == "__main__":
    raise SystemExit(main())
