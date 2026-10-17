#!/usr/bin/env python3
"""gate_census.py — gate 5: rules.yaml parses and the census contract holds.

Contract (RC32 closure, f212597 / ddbbf29):
  * exactly 726 rows, unique ids;
  * 0 rows with status `implemented` (every proven row was flipped);
  * 0 rows with status `planned`;
  * the remaining rows are exactly `proven` + `obsolete`.

This is a *strict* gate: adding or removing a row, or reintroducing an
implemented/planned status, fails until this constant and the closure
documents are deliberately updated in the same commit.

Usage: python3 spec/scripts/gate_census.py [spec/db/rules.yaml]
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent.parent
DEFAULT_DB = REPO / "spec" / "db" / "rules.yaml"
EXPECTED_ROWS = 726
EXPECTED_STATUS = {"proven": 676, "obsolete": 50, "implemented": 0, "planned": 0}


def main() -> int:
    db = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DB
    try:
        data = yaml.safe_load(db.read_text())
    except Exception as exc:  # noqa: BLE001 — report the parser error verbatim
        print(f"gate-census: yaml.safe_load FAILED: {exc}", file=sys.stderr)
        return 1

    rows = data.get("rules") if isinstance(data, dict) else None
    if not isinstance(rows, list):
        print("gate-census: top-level `rules:` list missing", file=sys.stderr)
        return 1

    ids = [r.get("id") for r in rows]
    dupes = sorted(k for k, n in Counter(ids).items() if n > 1)
    statuses = Counter(r.get("status") for r in rows)
    counts = {k: statuses.get(k, 0) for k in EXPECTED_STATUS}
    unknown = sorted(set(statuses) - set(EXPECTED_STATUS))

    print(f"gate-census: {db} — {len(rows)} rows, {len(set(ids))} unique ids")
    print("  status: " + ", ".join(f"{k}={counts[k]}" for k in EXPECTED_STATUS))

    rc = 0
    if len(rows) != EXPECTED_ROWS:
        print(f"gate-census: FAIL expected {EXPECTED_ROWS} rows, got {len(rows)}",
              file=sys.stderr)
        rc = 1
    if dupes:
        print(f"gate-census: FAIL duplicate ids: {dupes}", file=sys.stderr)
        rc = 1
    for status, expected in EXPECTED_STATUS.items():
        if counts[status] != expected:
            print(f"gate-census: FAIL {status}={counts[status]}, expected {expected}",
                  file=sys.stderr)
            rc = 1
    if unknown:
        print(f"gate-census: FAIL unknown statuses: {unknown}", file=sys.stderr)
        rc = 1
    if rc == 0:
        print("gate-census: OK (726 rows; 676 proven / 50 obsolete / "
              "0 implemented / 0 planned)")
    return rc


if __name__ == "__main__":
    sys.exit(main())
