#!/usr/bin/env python3
"""Check the Core-anchor surface for every proven consensus row.

This is a traceability check, not a translation proof.  It enforces the
mechanical part of issue 22 section 4:

* every proven row with ``consensus: true`` names a Core source anchor;
* the anchor ends in the pinned Core commit ``@cce32b168``;
* every such row has a non-empty ``lean_target``;
* no out-of-ledger row is still marked ``consensus: true``.

The semantic claim -- that the Lean statement is the Core function's accept
and reject relation -- is reviewed in ``docs/CORE-CORRESPONDENCE.md`` and
``docs/RESIDUALS.md``; this script does not pretend to prove it.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "spec" / "db" / "rules.yaml"
PIN = "@cce32b168"
OUT_OF_LEDGER = {"INV-046", "SCR-008", "INV-114", "INV-115", "INV-119", "INV-138"}


def main() -> int:
    rows = yaml.safe_load(DB.read_text())["rules"]
    problems: list[str] = []
    checked = 0
    for row in rows:
        if row.get("status") != "proven":
            continue
        rid = row.get("id", "<missing-id>")
        if row.get("consensus") is False:
            continue
        if rid in OUT_OF_LEDGER:
            problems.append(f"{rid}: out-of-ledger row is still consensus: true")
            continue
        checked += 1
        core_ref = str(row.get("core_ref") or "")
        if not core_ref:
            problems.append(f"{rid}: missing core_ref")
        elif PIN not in core_ref:
            problems.append(f"{rid}: core_ref is not pinned at {PIN}: {core_ref}")
        if not str(row.get("lean_target") or "").strip():
            problems.append(f"{rid}: missing lean_target")
    if problems:
        print(f"core-correspondence: FAIL ({len(problems)} problems)", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1
    print(f"core-correspondence: OK ({checked} proven consensus rows carry a pinned Core anchor and a Lean target)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
