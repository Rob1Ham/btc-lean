#!/usr/bin/env python3
"""Report SCR coverage for the three-leg LLVM equivalence ledger.

Reads ``spec/db/rules.yaml`` (the 183-row SCR coverage oracle) and
``spec/db/equiv-cells.yaml`` (one ledger entry per SCR row), then prints:

  (a) total SCR rows in rules.yaml
  (b) how many have status != planned (plus the status breakdown)
  (c) SCR rows missing from the ledger
  (d) ledger ids that are not SCR rows in rules.yaml
  (e) a per-family breakdown

With ``--strict`` the command exits non-zero unless every SCR row is
adjudicated:
  * every rules.yaml SCR id appears exactly once in the ledger;
  * no ledger id is absent from rules.yaml;
  * every status is in the documented enum;
  * no row is still ``planned``;
  * ``gap`` and ``unjudged-seam`` rows have a non-empty ``gap_note``;
  * green rows list at least one cell and carry the matching tool record
    (``alive2`` and/or ``saw``);
  * every row's family is declared in the top-level ``families`` section.

Without ``--strict`` the report is informational and exits 0 unless an input
is missing or malformed. Requires PyYAML; exits 2 with a clear message if it
is unavailable.

Usage:
    python3 spec/equiv/results/scripts/coverage_report.py
    python3 spec/equiv/results/scripts/coverage_report.py --strict
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter, OrderedDict
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on a bare host
    sys.stderr.write(
        "coverage_report.py: missing dependency PyYAML.\n"
        "Install it (e.g. `python3 -m pip install PyYAML`) and re-run.\n"
    )
    raise SystemExit(2)


STATUSES = {
    "planned",
    "alive2-green",
    "saw-green",
    "both-green",
    "unjudged-seam",
    "gap",
}
GREEN_STATUSES = {"alive2-green", "saw-green", "both-green"}

HERE = Path(__file__).resolve().parent
EQUIV_DIR = HERE.parent.parent
REPO_ROOT = EQUIV_DIR.parent.parent
RULES_PATH = REPO_ROOT / "spec" / "db" / "rules.yaml"
LEDGER_PATH = REPO_ROOT / "spec" / "db" / "equiv-cells.yaml"
CELLS_DIR = EQUIV_DIR / "cells"

sys.path.insert(0, str(HERE))
import update_ledger as cellscan  # noqa: E402  (same directory)

UNASSIGNED = "(unassigned)"


def die(message: str) -> "NoReturn":
    sys.stderr.write(f"coverage_report.py: {message}\n")
    raise SystemExit(2)


def load_yaml(path: Path) -> dict:
    if not path.is_file():
        die(f"missing input file: {path}")
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        die(f"cannot parse {path}: {exc}")
    if not isinstance(data, dict):
        die(f"{path} must contain a YAML mapping at the top level")
    return data


def has_record(value) -> bool:
    return value not in (None, "", {}, [])


def show(ids: list[str], limit: int = 20) -> str:
    if not ids:
        return "none"
    if len(ids) <= limit:
        return ", ".join(ids)
    return ", ".join(ids[:limit]) + f" ... (+{len(ids) - limit} more)"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit 1 unless every SCR row is adjudicated",
    )
    args = parser.parse_args(argv)

    rules_data = load_yaml(RULES_PATH)
    ledger_data = load_yaml(LEDGER_PATH)

    rules = rules_data.get("rules")
    ledger_rows = ledger_data.get("rows")
    if not isinstance(rules, list):
        die(f"{RULES_PATH}: `rules` must be a list")
    if not isinstance(ledger_rows, list):
        die(f"{LEDGER_PATH}: `rows` must be a list")

    rule_ids = [
        str(row["id"])
        for row in rules
        if isinstance(row, dict) and str(row.get("id", "")).startswith("SCR-")
    ]
    rule_set = set(rule_ids)
    ledger_ids = [
        str(row.get("id"))
        for row in ledger_rows
        if isinstance(row, dict) and row.get("id")
    ]
    ledger_set = set(ledger_ids)

    ledger_dupes = sorted(
        rule_id for rule_id, count in Counter(ledger_ids).items() if count > 1
    )
    missing = [rule_id for rule_id in rule_ids if rule_id not in ledger_set]
    unknown = [rule_id for rule_id in ledger_ids if rule_id not in rule_set]

    matched = [row for row in ledger_rows if str(row.get("id")) in rule_set]
    statuses = Counter(str(row.get("status")) for row in matched)
    planned = statuses.get("planned", 0)
    non_planned = len(matched) - planned
    green = sum(statuses.get(status, 0) for status in GREEN_STATUSES)
    gauged = statuses.get("unjudged-seam", 0)
    gaps = statuses.get("gap", 0)
    invalid = [
        str(row.get("id"))
        for row in matched
        if str(row.get("status")) not in STATUSES
    ]

    families_declared = ledger_data.get("families")
    if not isinstance(families_declared, list):
        families_declared = []
    family_order: list[str] = []
    family_titles: dict[str, str] = {}
    declared_family_rows: dict[str, int] = {}
    for family in families_declared:
        if not isinstance(family, dict) or not family.get("id"):
            continue
        family_id = str(family["id"])
        family_order.append(family_id)
        family_titles[family_id] = str(family.get("title", family_id))
        if isinstance(family.get("rows"), int):
            declared_family_rows[family_id] = family["rows"]

    # Per-family counts over ledger entries. Keep declared order, then extras.
    buckets: "OrderedDict[str, Counter]" = OrderedDict()
    for family_id in family_order:
        buckets[family_id] = Counter()
    for row in ledger_rows:
        family_id = str(row.get("family") or UNASSIGNED)
        if family_id not in buckets:
            buckets[family_id] = Counter()
        status = str(row.get("status"))
        bucket = buckets[family_id]
        bucket["rows"] += 1
        if status in GREEN_STATUSES:
            bucket["green"] += 1
        elif status == "planned":
            bucket["planned"] += 1
        elif status == "unjudged-seam":
            bucket["unjudged"] += 1
        elif status == "gap":
            bucket["gap"] += 1
        else:
            bucket["other"] += 1

    pct = (100.0 * non_planned / len(rule_ids)) if rule_ids else 0.0
    total = len(rule_ids)

    print("SCR coverage report")
    print("===================")
    print(
        f"rules:  spec/db/rules.yaml ({len(rules)} rows; {total} SCR-*)"
    )
    print(
        f"ledger: spec/db/equiv-cells.yaml "
        f"({len(ledger_rows)} rows; {len(family_order)} families)"
    )
    print()
    print(f"(a) SCR rows in rules.yaml: {total}")
    print(
        f"(b) SCR rows with status != planned: {non_planned} of {total} "
        f"({pct:.1f}%)"
    )
    print(
        f"    green: {green}   gap: {gaps}   unjudged-seam: {gauged}   "
        f"planned: {planned}   invalid: {len(invalid)}"
    )
    if invalid:
        print(f"    invalid status ids: {show(sorted(invalid))}")
    print(f"(c) SCR rows missing from ledger: {show(missing)}")
    print(f"(d) ledger ids not in rules.yaml: {show(sorted(unknown))}")
    if ledger_dupes:
        print(f"    duplicate ledger ids: {show(ledger_dupes)}")

    print()
    print("(e) per-family breakdown:")
    print(
        f"{'family':<22} {'rows':>5} {'green':>6} {'planned':>8} "
        f"{'unjudged':>9} {'gap':>4} {'other':>6}"
    )
    print("-" * 66)
    totals = Counter()
    for family_id, bucket in buckets.items():
        totals.update(bucket)
        print(
            f"{family_id:<22} {bucket['rows']:>5} {bucket['green']:>6} "
            f"{bucket['planned']:>8} {bucket['unjudged']:>9} "
            f"{bucket['gap']:>4} {bucket['other']:>6}"
        )
    print("-" * 66)
    print(
        f"{'TOTAL':<22} {totals['rows']:>5} {totals['green']:>6} "
        f"{totals['planned']:>8} {totals['unjudged']:>9} "
        f"{totals['gap']:>4} {totals['other']:>6}"
    )
    # Scan cell records once; used by the footer and by the green-row checks.
    cell_records, _cell_issues = cellscan.scan_cells(CELLS_DIR, rule_set)

    print()
    print(
        f"cell records scanned: {len(cell_records)} "
        f"(malformed: {sum(1 for cell in cell_records if cell.issues)})"
    )

    issues: list[str] = []
    if missing:
        issues.append(
            f"{len(missing)} SCR row(s) missing from ledger: {show(missing)}"
        )
    if unknown:
        issues.append(
            f"{len(unknown)} ledger id(s) not in rules.yaml: {show(sorted(unknown))}"
        )
    if ledger_dupes:
        issues.append(f"{len(ledger_dupes)} duplicate ledger id(s): {show(ledger_dupes)}")
    if invalid:
        issues.append(f"{len(invalid)} invalid status value(s): {show(sorted(invalid))}")
    if planned:
        planned_ids = sorted(
            str(row.get("id"))
            for row in matched
            if str(row.get("status")) == "planned"
        )
        issues.append(f"{planned} SCR row(s) still planned: {show(planned_ids)}")

    undeclared_families = sorted(
        {
            str(row.get("family") or UNASSIGNED)
            for row in ledger_rows
            if str(row.get("family") or UNASSIGNED) not in family_order
        }
    )
    if undeclared_families:
        issues.append(
            "family id(s) absent from top-level families: "
            + show(undeclared_families)
        )

    for row in ledger_rows:
        rule_id = str(row.get("id"))
        status = str(row.get("status"))
        note = row.get("gap_note")
        cells = row.get("cells")
        if status in {"gap", "unjudged-seam"}:
            if not isinstance(note, str) or not note.strip():
                issues.append(f"{rule_id}: {status} without a non-empty gap_note")
        if status in GREEN_STATUSES:
            if not isinstance(cells, list) or not cells:
                issues.append(f"{rule_id}: {status} without a non-empty cells list")
            if status in {"alive2-green", "both-green"} and not has_record(
                row.get("alive2")
            ):
                issues.append(f"{rule_id}: {status} but no alive2 record")
            if status in {"saw-green", "both-green"} and not has_record(row.get("saw")):
                issues.append(f"{rule_id}: {status} but no saw record")

    # Green rows must be backed by real cell records, not just a non-empty
    # `cells` list. This is the hard no-false-green check.
    cells_by_rel = {cell.rel: cell for cell in cell_records}

    def resolve_cell(ref: str, row: dict):
        candidate = Path(str(ref))
        if candidate.is_absolute():
            try:
                rel = candidate.resolve().relative_to(CELLS_DIR.resolve()).as_posix()
            except ValueError:
                return None
            return cells_by_rel.get(rel)
        rel = candidate.as_posix()
        if rel in cells_by_rel:
            return cells_by_rel[rel]
        family = str(row.get("family") or "")
        if family and f"{family}/{rel}" in cells_by_rel:
            return cells_by_rel[f"{family}/{rel}"]
        return None

    for row in ledger_rows:
        rule_id = str(row.get("id"))
        status = str(row.get("status"))
        if status not in GREEN_STATUSES or rule_id not in rule_set:
            continue
        cells = row.get("cells")
        if not isinstance(cells, list) or not cells:
            continue  # already reported above
        resolved = []
        for ref in cells:
            cell = resolve_cell(str(ref), row)
            if cell is None:
                issues.append(
                    f"{rule_id}: {status} cites missing cell record {ref!r} "
                    "(expected cells/<family>/<cell>/spec.md)"
                )
                continue
            if cell.issues:
                issues.append(
                    f"{rule_id}: {status} cites malformed cell {cell.rel}: "
                    f"{cell.issues[0]}"
                )
                continue
            if rule_id not in cell.scr_rows:
                issues.append(
                    f"{rule_id}: cell {cell.rel} does not list this row in "
                    "spec.md `scr_rows`"
                )
                continue
            resolved.append(cell)
        if status in {"alive2-green", "both-green"} and not any(
            cell.alive2.state == "green" for cell in resolved
        ):
            issues.append(
                f"{rule_id}: {status} but no cited cell has an Alive2 success "
                "marker in alive2/result.txt"
            )
        if status in {"saw-green", "both-green"} and not any(
            cell.saw.state == "green" for cell in resolved
        ):
            issues.append(
                f"{rule_id}: {status} but no cited cell has a SAW success "
                "marker in saw/result.txt"
            )

    # An unjudged-seam row that names cells must cite a cell that declares the
    # seam (DECISION-lax-ecdsa.md + finding).
    for row in ledger_rows:
        rule_id = str(row.get("id"))
        if str(row.get("status")) != "unjudged-seam" or rule_id not in rule_set:
            continue
        cells = row.get("cells")
        if not isinstance(cells, list) or not cells:
            continue
        if not any(
            (cell := resolve_cell(str(ref), row)) is not None and cell.seam_note
            for ref in cells
        ):
            issues.append(
                f"{rule_id}: unjudged-seam cells do not include a cell "
                "declaring `unjudged_seam` (DECISION-lax-ecdsa.md + finding)"
            )

    # Declared family row counts are a consistency check on the generator.
    for family_id, declared in declared_family_rows.items():
        actual = buckets.get(family_id, Counter())["rows"]
        if declared != actual:
            issues.append(
                f"family {family_id}: declared rows={declared} but ledger has {actual}"
            )

    print()
    if args.strict:
        if issues:
            print(f"strict: FAIL ({len(issues)} issue(s))")
            for issue in issues:
                print(f"  - {issue}")
            return 1
        print(
            f"strict: PASS - all {total} SCR rows adjudicated "
            "(green, unjudged-seam, or filed gap)"
        )
        return 0

    print("strict: not evaluated (re-run with --strict)")
    if issues:
        print(f"pending issues: {len(issues)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
