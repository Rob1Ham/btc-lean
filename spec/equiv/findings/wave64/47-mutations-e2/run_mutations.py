#!/usr/bin/env python3
"""Run the required E2 mutants against existing E2/numeric/flow/limit cells.

This is a self-contained red-team harness.  It never edits the working tree's
cells: for every run it materialises a byte-identical `git archive HEAD
spec/equiv` copy under `.work/`, verifies the target hash against HEAD, applies
one exact-text semantic mutation there, runs the existing cell scripts, and
reverts.  Mutant records and raw tool output are written under this findings
directory.

Usage:
  python3 run_mutations.py --all
  python3 run_mutations.py --id M-E2-001
  python3 run_mutations.py --list

Exit code 0 only if every selected run has: baseline green, a named tool
failure with a mismatch/counterexample in the actual output, a verified revert,
and a green post-revert baseline.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent          # .../findings/wave64/47-mutations-e2
EQ = HERE.parents[2]                            # .../spec/equiv
ROOT = HERE.parents[4]                          # repo root
WORK = ROOT / ".work"
SCRATCH_EQ = WORK / "spec" / "equiv"
RUNS = HERE / "runs"
MUTANTS = HERE / "mutants"


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def sha256_file(p: Path) -> str:
    return sha256_bytes(p.read_bytes())


def run(cmd: str, cwd: Path, timeout: int = 2400) -> tuple[int, str]:
    p = subprocess.run(
        cmd, shell=True, cwd=str(cwd), stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True, timeout=timeout,
    )
    return p.returncode, p.stdout


def status_from(path: Path) -> str:
    if not path.is_file():
        return "missing"
    for line in reversed(path.read_text(errors="replace").splitlines()):
        if line.startswith("STATUS="):
            return line.split("=", 1)[1].strip()
    return "no-status"


def prepare_scratch() -> None:
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    rc, out = run("git archive HEAD spec/equiv | tar -x -C .work", ROOT)
    if rc != 0:
        raise SystemExit(f"git archive failed: {out}")
    if not SCRATCH_EQ.is_dir():
        raise SystemExit("scratch spec/equiv missing")


def head_bytes(rel: str) -> bytes:
    p = subprocess.run(
        ["git", "show", f"HEAD:spec/equiv/{rel}"], cwd=str(ROOT),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    )
    return p.stdout


def verify_copy_matches_head(rel: str) -> None:
    target = SCRATCH_EQ / rel
    expected = head_bytes(rel)
    actual = target.read_bytes()
    if sha256_bytes(actual) != sha256_bytes(expected):
        raise SystemExit(f"scratch target {rel} does not match HEAD")


def unified(before: str, after: str, rel: str) -> str:
    return "".join(difflib.unified_diff(
        before.splitlines(keepends=True),
        after.splitlines(keepends=True),
        fromfile=f"a/spec/equiv/{rel}",
        tofile=f"b/spec/equiv/{rel}",
    ))


def alive2_blocks(text: str) -> list[dict]:
    """One record per `alive-tv` invocation in a runner result."""
    out: list[dict] = []
    parts = re.split(r"(?m)^# command: ", text)
    for part in parts[1:]:
        cmd = part.splitlines()[0]
        m = re.search(r"c_(cell_[A-Za-z0-9_]+)\.ll", cmd)
        fn = m.group(1) if m else cmd
        out.append({
            "function": fn,
            "command": cmd,
            "correct": "Transformation seems to be correct" in part,
            "mismatch": "Transformation doesn't verify" in part,
            "error": "ERROR:" in part,
        })
    return out


def excerpt_alive2(text: str) -> str:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if "Transformation doesn't verify!" in line:
            start = max(0, i - 2)
            end = min(len(lines), i + 18)
            return "\n".join(lines[start:end])
    return ""


def excerpt_saw(text: str) -> str:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("Proof failed."):
            start = max(0, i - 28)
            return "\n".join(lines[start:i + 1])
    return ""


def saw_counts(text: str) -> tuple[int, int]:
    return (
        sum(1 for l in text.splitlines() if l.startswith("Proof succeeded!")),
        sum(1 for l in text.splitlines() if l.startswith("Proof failed.")),
    )


def write(path: Path, data: str | bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, bytes):
        path.write_bytes(data)
    else:
        path.write_text(data)


SPECS = [
    {
        "run_id": "M-E2-001-core-slice",
        "catalogue_id": "M-E2-001",
        "site": "core-slice",
        "family": "e2-flow",
        "cell": "control-flow/C-L-casttobool",
        "catalogue_cell": "cells/e2-flow/negzero-if",
        "target": "cells/control-flow/C-L-casttobool/src/c_leaf.cpp",
        "description": (
            "CastToBool treats negative zero (0x80) as true: drop the "
            "`i == n-1 && vch[i] == 0x80` special case from the line-cited "
            "Core excerpt."
        ),
        "find": (
            "      if (i == n - 1 && vch[i] == 0x80)\n"
            "        return false;\n"
        ),
        "replace": (
            "      // M-E2-001 mutant: negative zero is treated as true\n"
        ),
        "expected": (
            "Alive2 C-vs-L must report a value mismatch for cell_cast_len1 at "
            "b0=0x80; SAW must fail the C cell_cast_len1 proof against the "
            "independent cast1 predicate (0x80 => false). Witness: element "
            "length 1, byte 0x80; baseline C returns 0, mutant returns 1."
        ),
        "witness_input": "len=1, b0=0x80",
    },
    {
        "run_id": "M-E2-002-core-slice",
        "catalogue_id": "M-E2-002",
        "site": "core-slice",
        "family": "e2-numeric",
        "cell": "numeric/C-L-unary-4byte",
        "catalogue_cell": "cells/e2-numeric/num-4byte-boundary",
        "target": "cells/numeric/C-L-unary-4byte/src/c_leaf.cpp",
        "description": (
            "CScriptNum operand width bound 4 -> 5: the C excerpt passes "
            "nMaxNumSize=5, so a 5-byte operand is accepted in base arithmetic."
        ),
        "find": (
            "if (!decode_num(p, len, /*fRequireMinimal=*/false, 4, bn, err))"
        ),
        "replace": (
            "if (!decode_num(p, len, /*fRequireMinimal=*/false, 5, bn, err))"
            "  // M-E2-002 mutant: 5-byte operand accepted"
        ),
        "expected": (
            "Alive2 C-vs-L must report a value mismatch at operand length 5 "
            "(C accepts, L returns SCRIPTNUM); SAW must fail the C proof "
            "against the independent decodeOk predicate (L <= 4). Witness: "
            "cell_1add, lb=5, content 0; baseline error 4 (SCRIPTNUM), mutant "
            "pushes 1."
        ),
        "witness_input": "len=5, w=0, OP_1ADD",
    },
    {
        "run_id": "M-E2-004-core-slice",
        "catalogue_id": "M-E2-004",
        "site": "core-slice",
        "family": "e2-numeric",
        "cell": "e2-numeric/within-boundary",
        "catalogue_cell": "cells/e2-numeric/within-boundary",
        "target": "cells/e2-numeric/within-boundary/src/c_leaf.cpp",
        "description": (
            "OP_WITHIN max boundary is inclusive (<=) instead of exclusive (<) "
            "in the line-cited Core excerpt."
        ),
        "find": "const bool v = (b <= a && a < c);",
        "replace": (
            "const bool v = (b <= a && a <= c);  // M-E2-004 mutant: inclusive max"
        ),
        "expected": (
            "Alive2 C-vs-L must report a value mismatch on a triple where "
            "x == max; SAW must fail the C proof against the independent "
            "within predicate (min <= x < max). Witness: x=5, min=1, max=5; "
            "baseline EVAL_FALSE, mutant vchTrue."
        ),
        "witness_input": "av=5, bv=1, cv=5",
    },
    {
        "run_id": "M-E2-004-model",
        "catalogue_id": "M-E2-004",
        "site": "model",
        "family": "e2-numeric",
        "cell": "e2-numeric/within-boundary",
        "catalogue_cell": "cells/e2-numeric/within-boundary",
        "target": "twin/ops_ir.py",
        "description": (
            "OP_WITHIN max boundary is inclusive (<=) in the twin IR "
            "generator; the cell regenerates the L leg from twin/ops_ir.py, so "
            "the mutant reaches build/twin_ops.h."
        ),
        "find": '"return st_push_num(st.stack, (b <= a && a < c) ? 1 : 0);",',
        "replace": (
            '"return st_push_num(st.stack, (b <= a && a <= c) ? 1 : 0); '
            '// M-E2-004 mutant: inclusive max",'
        ),
        "expected": (
            "Same observable as M-E2-004-core-slice, but the L leg is the "
            "mutant. Alive2 C-vs-L must report a value mismatch; SAW must fail "
            "the L proof. Witness: x=5, min=1, max=5. The regenerated "
            "build/twin_ops.h must contain the mutated comparison."
        ),
        "witness_input": "av=5, bv=1, cv=5",
        "generated": "cells/e2-numeric/within-boundary/build/twin_ops.h",
        "generated_marker": "return st_push_num(st.stack, (b <= a && a <= c)",
    },
    {
        "run_id": "M-E2-005-core-slice",
        "catalogue_id": "M-E2-005",
        "site": "core-slice",
        "family": "e2-flow",
        "cell": "limits/C-L-opcount",
        "catalogue_cell": "cells/e2-flow/opcount-201",
        "target": "cells/limits/C-L-opcount/src/c_leaf.cpp",
        "description": (
            "OP_COUNT threshold 201 -> 200: the C excerpt rejects when the "
            "charged count is >= 201 instead of > 201."
        ),
        "find": "if (nOpCount > LIM_MAX_OPS_PER_SCRIPT) {",
        "replace": (
            "if (nOpCount >= LIM_MAX_OPS_PER_SCRIPT) {"
            "  // M-E2-005 mutant: threshold 200"
        ),
        "expected": (
            "Alive2 C-vs-L must report a value mismatch at a charged count of "
            "201; SAW must fail the C proof against the independent 201 "
            "budget. Witness: incoming opCount=200, wire=0x8e, sv=BASE, "
            "fExec=0; baseline DISABLED_OPCODE (budget admits 201), mutant "
            "OP_COUNT."
        ),
        "witness_input": "opCount=200, wire=0x8e, fExec=0, sv=BASE",
    },
]


def get_spec(run_id: str) -> dict:
    for s in SPECS:
        if s["run_id"] == run_id:
            return s
    raise SystemExit(f"unknown run id {run_id!r}; use --list")


def execute(spec: dict) -> bool:
    run_dir = RUNS / spec["run_id"]
    if run_dir.exists():
        raise SystemExit(f"run directory already exists: {run_dir}")
    run_dir.mkdir(parents=True)

    prepare_scratch()
    rel = spec["target"]
    verify_copy_matches_head(rel)
    target = SCRATCH_EQ / rel
    original_bytes = target.read_bytes()
    original_text = original_bytes.decode("utf-8")
    before_sha = sha256_bytes(original_bytes)

    cell = spec["cell"]
    cell_dir = SCRATCH_EQ / "cells" / cell
    commands = {
        "alive2": f"cd spec/equiv && bash cells/{cell}/alive2/run.sh",
        "saw": f"cd spec/equiv && bash cells/{cell}/saw/run.sh",
    }

    def leg(which: str, tag: str) -> tuple[int, str, str]:
        # The command string starts with `cd spec/equiv`, so run it from the
        # repository-root copy, not from spec/equiv itself.
        rc, out = run(commands[which], WORK)
        res = cell_dir / which / "result.txt"
        text = res.read_text(errors="replace") if res.is_file() else ""
        write(run_dir / f"{which}-{tag}.stdout.txt", out)
        write(run_dir / f"{which}-{tag}.result.txt", text)
        return rc, out, status_from(res)

    record: dict = {
        "schema": "redteam-mutant-run-v1",
        "run_id": spec["run_id"],
        "mutant_id": spec["catalogue_id"],
        "site": spec["site"],
        "family": spec["family"],
        "cell": f"cells/{cell}",
        "catalogue_cell": spec["catalogue_cell"],
        "description": spec["description"],
        "target": rel,
        "target_sha256_before": before_sha,
        "target_sha256_after": None,
        "find": spec["find"],
        "replace": spec["replace"],
        "diff": None,
        "commands": commands,
        "expected_detection": spec["expected"],
        "witness_input": spec["witness_input"],
        "head_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=str(ROOT), text=True
        ).strip(),
        "scratch_root": str(WORK.relative_to(ROOT)),
        "baseline": {},
        "mutant": {},
        "post_revert": {},
        "revert_verified": False,
        "classification": "INVALID",
        "caught": False,
        "operator": "wave64/47-mutations-e2",
        "started_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }

    # ---- baseline -------------------------------------------------------
    for which in ("alive2", "saw"):
        rc, out, st = leg(which, "baseline")
        record["baseline"][which] = {"rc": rc, "status": st}
    base_ok = all(
        record["baseline"][w]["status"] == f"{w}-green"
        and record["baseline"][w]["rc"] == 0
        for w in ("alive2", "saw")
    )
    if not base_ok:
        record["classification"] = "INVALID-BASELINE-NOT-GREEN"
        finish(spec, run_dir, record)
        return False

    generated_baseline = None
    if spec.get("generated"):
        gp = SCRATCH_EQ / spec["generated"]
        generated_baseline = gp.read_bytes()
        write(run_dir / "generated-baseline.h", generated_baseline)

    # ---- apply ----------------------------------------------------------
    count = original_text.count(spec["find"])
    if count != 1:
        record["classification"] = f"INVALID-ANCHOR-COUNT-{count}"
        finish(spec, run_dir, record)
        return False
    mutated_text = original_text.replace(spec["find"], spec["replace"], 1)
    after_bytes = mutated_text.encode("utf-8")
    target.write_bytes(after_bytes)
    after_sha = sha256_file(target)
    record["target_sha256_after"] = after_sha
    record["diff"] = unified(original_text, mutated_text, rel)
    write(run_dir / "target.diff", record["diff"])

    # ---- mutant ---------------------------------------------------------
    try:
        for which in ("alive2", "saw"):
            rc, out, st = leg(which, "mutant")
            path = run_dir / f"{which}-mutant.result.txt"
            text = path.read_text(errors="replace") if path.is_file() else ""
            rec = {"rc": rc, "status": st}
            if which == "alive2":
                rec["blocks"] = alive2_blocks(text)
                rec["failure_excerpt"] = excerpt_alive2(text)
            else:
                ok, bad = saw_counts(text)
                rec["proofs_succeeded"] = ok
                rec["proofs_failed"] = bad
                rec["failure_excerpt"] = excerpt_saw(text)
            record["mutant"][which] = rec

        if spec.get("generated"):
            gp = SCRATCH_EQ / spec["generated"]
            generated_mutant = gp.read_bytes()
            write(run_dir / "generated-mutant.h", generated_mutant)
            gd = unified(
                generated_baseline.decode("utf-8", "replace"),
                generated_mutant.decode("utf-8", "replace"),
                spec["generated"],
            )
            write(run_dir / "generated-twin.diff", gd)
            record["generated_diff"] = gd
            marker = spec.get("generated_marker")
            record["generated_contains_mutant"] = bool(
                marker and marker in generated_mutant.decode("utf-8", "replace")
            )
    finally:
        # ---- revert -----------------------------------------------------
        target.write_bytes(original_bytes)
        record["revert_verified"] = sha256_file(target) == before_sha

    # ---- post-revert baseline ------------------------------------------
    for which in ("alive2", "saw"):
        rc, out, st = leg(which, "post-revert")
        record["post_revert"][which] = {"rc": rc, "status": st}
    post_ok = all(
        record["post_revert"][w]["status"] == f"{w}-green"
        and record["post_revert"][w]["rc"] == 0
        for w in ("alive2", "saw")
    )

    # ---- classify -------------------------------------------------------
    a = record["mutant"]["alive2"]
    s = record["mutant"]["saw"]
    alive_caught = (
        a["status"] != "alive2-green"
        and any(b["mismatch"] and b["error"] for b in a.get("blocks", []))
    )
    saw_caught = (
        s["status"] != "saw-green"
        and s.get("proofs_failed", 0) > 0
        and "Counterexample" in s.get("failure_excerpt", "")
    )
    record["caught_by"] = {
        "alive2": alive_caught,
        "saw": saw_caught,
    }
    record["caught"] = alive_caught or saw_caught
    harness_rc_ok = all(
        record["mutant"][w]["rc"] in (0, 1) for w in ("alive2", "saw")
    )
    if not harness_rc_ok:
        record["classification"] = "INVALID-HARNESS-RC"
    elif not record["revert_verified"]:
        record["classification"] = "INVALID-REVERT-FAILED"
    elif not post_ok:
        record["classification"] = "INVALID-POST-REVERT-NOT-GREEN"
    elif record["caught"]:
        record["classification"] = "KILLED"
    else:
        record["classification"] = "SURVIVED"

    finish(spec, run_dir, record)
    return record["classification"] == "KILLED"


def finish(spec: dict, run_dir: Path, record: dict) -> None:
    record["finished_at_utc"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    write(run_dir / "mutant.json", json.dumps(record, indent=2, sort_keys=True) + "\n")

    lines = [
        f"# {record['run_id']} — {record['mutant_id']} ({record['site']})",
        "",
        f"- Cell: `{record['cell']}` (catalogue cell `{record['catalogue_cell']}`)",
        f"- Target: `spec/equiv/{record['target']}`",
        f"- HEAD: `{record['head_commit']}`",
        f"- Execution root: byte-identical `git archive HEAD spec/equiv` copy under "
        f"`{record['scratch_root']}/spec/equiv` (target hash verified against HEAD before mutation).",
        f"- Classification: **{record['classification']}**",
        f"- Caught: `{record['caught']}` by "
        f"`{', '.join(k for k, v in record.get('caught_by', {}).items() if v) or 'none'}`",
        "",
        "## Mutation",
        "",
        "```diff",
        (record.get("diff") or "").rstrip(),
        "```",
        "",
        f"- sha256 before: `{record['target_sha256_before']}`",
        f"- sha256 after: `{record['target_sha256_after']}`",
        "",
        "## Command",
        "",
        "```sh",
        record["commands"]["alive2"],
        record["commands"]["saw"],
        "```",
        "",
        "## Expected detection",
        "",
        record["expected_detection"],
        "",
        f"Witness input: `{record['witness_input']}`",
        "",
        "## Actual output",
        "",
        "| leg | baseline | mutant | post-revert |",
        "|---|---|---|---|",
        f"| alive2 | {record['baseline']['alive2']['status']} | "
        f"{record['mutant']['alive2']['status']} | {record['post_revert']['alive2']['status']} |",
        f"| saw | {record['baseline']['saw']['status']} | "
        f"{record['mutant']['saw']['status']} | {record['post_revert']['saw']['status']} |",
        "",
    ]
    blocks = record["mutant"]["alive2"].get("blocks", [])
    if blocks:
        lines += ["Alive2 per-function result:", "", "| function | correct | mismatch |",
                  "|---|---|---|"]
        for b in blocks:
            lines.append(f"| `{b['function']}` | {b['correct']} | {b['mismatch']} |")
        lines.append("")
    if record["mutant"]["alive2"].get("failure_excerpt"):
        lines += ["Alive2 failure excerpt:", "", "```text",
                  record["mutant"]["alive2"]["failure_excerpt"], "```", ""]
    if record["mutant"]["saw"].get("failure_excerpt"):
        lines += [f"SAW: {record['mutant']['saw'].get('proofs_succeeded')} succeeded, "
                  f"{record['mutant']['saw'].get('proofs_failed')} failed.", "",
                  "```text", record["mutant"]["saw"]["failure_excerpt"], "```", ""]
    if record.get("generated_diff"):
        lines += ["Generated L-leg diff (`build/twin_ops.h`, regenerated by the "
                  "cell build from `twin/ops_ir.py`):", "", "```diff",
                  record["generated_diff"].rstrip(), "```", ""]
    lines += [
        "## Revert",
        "",
        f"- Revert hash matches before: `{record['revert_verified']}`",
        f"- Post-revert baseline green: `{all(record['post_revert'][w]['status'] == f'{w}-green' for w in ('alive2','saw'))}`",
        "",
        "Raw logs and result files are in this directory. The working tree's "
        "cells were never edited; only the archive copy was.",
        "",
    ]
    write(run_dir / "result.md", "\n".join(lines))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--id", help="run id, e.g. M-E2-001-core-slice")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    if args.list:
        for s in SPECS:
            print(f"{s['run_id']:28s} {s['catalogue_id']:9s} {s['cell']}")
        return 0
    selected = SPECS if args.all else [get_spec(args.id)]
    ok = True
    for spec in selected:
        print(f"=== {spec['run_id']} ({spec['cell']}) ===", flush=True)
        try:
            result = execute(spec)
        except Exception as e:  # noqa: BLE001 - report, never fabricate a pass
            print(f"ERROR {spec['run_id']}: {e}", file=sys.stderr)
            result = False
        ok = ok and result
    if WORK.exists():
        shutil.rmtree(WORK)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
