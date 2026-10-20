#!/usr/bin/env python3
"""Publish the E6 disposition inventory: every non-green SCR row and the
specific gap/seam note that was filed in spec/db/equiv-cells.yaml.

Output: findings/coverage/F-E6-GAPS.md

The ledger is the source of truth; this report is a human-readable index.  It
does not promote, dismiss, or invent any row.
"""
from __future__ import annotations

from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
EQ = HERE.parent.parent
REPO = EQ.parent.parent
LEDGER = REPO / "spec" / "db" / "equiv-cells.yaml"
OUT = EQ / "findings" / "coverage" / "F-E6-GAPS.md"


def main() -> int:
    doc = yaml.safe_load(LEDGER.read_text())
    rows = doc["rows"]
    green = [r for r in rows if r.get("status") == "both-green"]
    seam = [r for r in rows if r.get("status") == "unjudged-seam"]
    gap = [r for r in rows if r.get("status") == "gap"]
    planned = [r for r in rows if r.get("status") == "planned"]
    other = [
        r
        for r in rows
        if r.get("status")
        not in {"both-green", "unjudged-seam", "gap", "planned"}
    ]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# E6 coverage dispositions",
        "",
        "Generated from `spec/db/equiv-cells.yaml` by",
        "`results/scripts/build_gap_report.py`. This is an index of the filed",
        "dispositions, not a new claim. Green rows are listed for completeness.",
        "",
        f"- green: **{len(green)}**",
        f"- unjudged seam: **{len(seam)}**",
        f"- filed gap: **{len(gap)}**",
        f"- still planned: **{len(planned)}**",
        f"- other: **{len(other)}**",
        "",
        "## Green rows",
        "",
        "| SCR | family | cells |",
        "|---|---|---|",
    ]
    for r in green:
        cells = ", ".join(f"`{c}`" for c in (r.get("cells") or []))
        lines.append(f"| {r['id']} | {r.get('family','')} | {cells} |")
    lines += ["", "## Unjudged seams", "", "| SCR | family | disposition |", "|---|---|---|"]
    for r in seam:
        note = str(r.get("gap_note") or "").replace("|", "\\|")
        lines.append(f"| {r['id']} | {r.get('family','')} | {note} |")
    lines += ["", "## Filed gaps", "", "| SCR | family | disposition |", "|---|---|---|"]
    for r in gap:
        note = str(r.get("gap_note") or "").replace("|", "\\|")
        lines.append(f"| {r['id']} | {r.get('family','')} | {note} |")
    if planned or other:
        lines += ["", "## Not adjudicated", "", "| SCR | status |", "|---|---|"]
        for r in planned + other:
            lines.append(f"| {r['id']} | {r.get('status')} |")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT} ({len(green)} green, {len(seam)} seam, {len(gap)} gap, {len(planned)} planned)")
    return 1 if planned or other else 0


if __name__ == "__main__":
    raise SystemExit(main())
