#!/usr/bin/env python3
"""Adjudicate every still-`planned` SCR row as green (already derived) or a
filed gap / unjudged seam.

This script never invents a green.  It only fills rows that no cell covers,
and each note names the row, the missing family evidence, and the concrete
blocker.  The E4 seam inventory (findings/e4/seams.yaml, if present) supplies
the witness-v0/tapscript/taproot seam reasons.

Usage:
  python3 results/scripts/adjudicate.py --check
  python3 results/scripts/adjudicate.py --write
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
EQ = HERE.parent.parent
REPO = EQ.parent.parent
LEDGER = REPO / "spec" / "db" / "equiv-cells.yaml"
RULES = REPO / "spec" / "db" / "rules.yaml"
SEAMS = EQ / "findings" / "e4" / "seams.yaml"

SEAM_FAMILIES = {"witness-v0", "tapscript", "tapscript-reimport"}

FAMILY_BLOCKER = {
    "exec-verify": (
        "whole VerifyScript/EvalScript path is the E5 scoped residual "
        "(findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row"
    ),
    "push-encoding": (
        "no push-encoding cell was built for this row; E1/E2 leaves cover "
        "only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is "
        "recorded separately (F-DIV-001)"
    ),
    "stack-ops": (
        "E1 cells cover only the listed branches; the missing underflow/OOB/"
        "budget branch for this row is named in the cell notes"
    ),
    "control-flow": (
        "E2 control cell covers SCR-069/071/072 only; this row's branch, "
        "signature version, or policy flag is not modeled"
    ),
    "numeric": (
        "E2 numeric attempt did not produce a cell for this row; the "
        "CScriptNum/opcode path is not proved"
    ),
    "hash-ops": (
        "E2 hash attempt treats the hash primitive as an opaque shared "
        "external; same-hash is a premise, not an IR proof, and this row's "
        "composition is not a green cell"
    ),
    "checksig": (
        "E3 checksig attempt is conditional on the same abstract crypto "
        "checker; R has no typed ScriptError and a single-input/flags=0 "
        "domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell"
    ),
    "checkmultisig": (
        "E3 CMS attempt did not cover this row; R is domain-limited "
        "(F-HARNESS-002), and the CMS loop/error-enum equality is not a "
        "green cell"
    ),
    "locktime": (
        "no locktime cell was built; CLTV/CSV need the transaction context "
        "and the E2/E4 harness does not model it"
    ),
    "disabled-opcodes": (
        "no disabled-opcode cell was built; the twin does not expose this "
        "opcode and the base/tapscript split is not modeled"
    ),
    "limits": (
        "no bounded limit cell covers this row; the E2 limit attempt does "
        "not exercise this boundary/placement"
    ),
    "policy-flags": (
        "flags are fixed at 0 in the bounded harness; this policy-flag row "
        "is not exercised"
    ),
}

DEFAULT_SEAM = (
    "full VerifyWitnessProgram/EvalScript dispatch, control-block, annex, "
    "OP_SUCCESS or sigops seam is not modeled in a bounded cell; see the E4 "
    "seam inventory (findings/e4/seams.md) and do not read this as a green"
)


def load_seams() -> dict[str, tuple[str, str]]:
    doc = None
    if SEAMS.is_file():
        doc = yaml.safe_load(SEAMS.read_text())
    else:
        md = SEAMS.with_suffix(".md")
        if md.is_file():
            text = md.read_text()
            import re

            m = re.search(r"```ya?ml\s*(.*?)```", text, re.S)
            if m:
                doc = yaml.safe_load(m.group(1))
    if not doc:
        return {}
    root = doc.get("seam_inventory") if isinstance(doc, dict) else doc
    if not isinstance(root, dict):
        return {}
    out: dict[str, tuple[str, str]] = {}
    for key in ("unjudged_seam", "gap", "judged"):
        for row in root.get(key) or []:
            rid = str(row.get("id") or row.get("scr") or "")
            note = str(row.get("note") or row.get("reason") or "").strip()
            if rid.startswith("SCR-") and note:
                status = str(row.get("status") or key)
                if status == "unjudged_seam":
                    status = "unjudged-seam"
                out[rid] = (status, note)
    return out


def note_for(row: dict, seams: dict[str, tuple[str, str]]) -> tuple[str, str]:
    rid = str(row["id"])
    fam = str(row.get("family") or "")
    summary = str(row.get("summary") or "").strip().replace("\n", " ")
    prefix = f"{rid} ({summary[:160]}): "
    if rid == "SCR-045":
        return (
            "unjudged-seam",
            f"{prefix}F-DIV-001 seam — Lean eager parseWire "
            "vs Core streaming GetOp changes the error kind on malformed tails; "
            "excluded per findings/cross/F-DIV-001-eager-parse.md. This is a "
            "model seam, not a tool failure.",
        )
    if rid in seams:
        status, reason = seams[rid]
        if status in {"gap", "unjudged-seam", "both-green"}:
            # A planned row may not already be both-green; treat that as a
            # seam inventory inconsistency rather than silently promoting it.
            if status == "both-green":
                return ("gap", prefix + reason + " (inventory says judged; ledger has no green cell)")
            return (status, prefix + reason)
    if fam in SEAM_FAMILIES:
        return ("unjudged-seam", prefix + DEFAULT_SEAM)
    blocker = FAMILY_BLOCKER.get(
        fam,
        "no bounded cell was built for this row in the E1-E5 attempt; "
        "the family blocker is recorded in findings/coverage/F-E6-GAPS.md",
    )
    return ("gap", prefix + blocker + ". No green is claimed.")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if not (args.write or args.check):
        ap.error("choose --write or --check")

    doc = yaml.safe_load(LEDGER.read_text())
    rows = doc.get("rows") or []
    seams = load_seams()
    changes = []
    for row in rows:
        if str(row.get("status")) != "planned":
            continue
        status, note = note_for(row, seams)
        row["status"] = status
        row["gap_note"] = note
        row["alive2"] = row.get("alive2")
        row["saw"] = row.get("saw")
        changes.append((row["id"], status))
    if changes:
        print("adjudication changes:")
        for rid, status in changes:
            print(f"  {rid}: planned -> {status}")
    else:
        print("no planned rows remain")

    planned = [r["id"] for r in rows if str(r.get("status")) == "planned"]
    if planned:
        print(f"ERROR: {len(planned)} planned rows remain: {planned[:8]}", file=sys.stderr)
        return 1
    if args.write:
        LEDGER.write_text(
            yaml.safe_dump(doc, sort_keys=False, width=120, allow_unicode=True)
        )
        print(f"wrote {LEDGER}")
    else:
        print(f"check: all {len(rows)} rows adjudicated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
