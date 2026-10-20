#!/usr/bin/env python3
"""Regenerate spec/db/equiv-cells.yaml from spec/db/rules.yaml.

Contract
--------
* Input census: ``spec/db/rules.yaml`` (generated; pinned at Core cce32b168).
* Output ledger: ``spec/db/equiv-cells.yaml`` (generated header + one entry
  per ``SCR-*`` row).
* Deterministic: rows are sorted by SCR number, family order is fixed, and no
  timestamps or absolute paths are emitted. Re-running on unchanged inputs
  produces byte-identical output.
* State preservation: on regeneration, the hand-maintained fields
  ``status``, ``cells``, ``alive2``, ``saw`` and ``gap_note`` are copied from
  the existing ledger (matched by id). Computed fields (id, family, summary,
  core_ref, consensus) and the families section are regenerated. If the
  existing ledger cannot be parsed, the script aborts rather than silently
  discarding state.

Usage
-----
    python3 spec/equiv/results/scripts/build_equiv_cells.py
    python3 spec/equiv/results/scripts/build_equiv_cells.py --check
    python3 spec/equiv/results/scripts/build_equiv_cells.py --ledger /tmp/ledger.yaml

``--ledger`` is an optional testability hook: it redirects both the state
source and the output path. The default remains ``spec/db/equiv-cells.yaml``.

Exit codes: 0 success (or --check with no drift); 1 drift under --check;
2 missing dependency / malformed input. Requires PyYAML; if it is absent the
script reports the dependency explicitly and exits 2.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on a bare host
    sys.stderr.write(
        "build_equiv_cells.py: missing dependency PyYAML.\n"
        "Install it (e.g. `python3 -m pip install PyYAML`) and re-run.\n"
    )
    raise SystemExit(2)


STATUSES = [
    "planned",
    "alive2-green",
    "saw-green",
    "both-green",
    "unjudged-seam",
    "gap",
]
GREEN_STATUSES = {"alive2-green", "saw-green", "both-green"}
STATE_FIELDS = ("status", "cells", "alive2", "saw", "gap_note")

HERE = Path(__file__).resolve().parent
EQUIV_DIR = HERE.parent.parent
REPO_ROOT = EQUIV_DIR.parent.parent
RULES_PATH = REPO_ROOT / "spec" / "db" / "rules.yaml"
LEDGER_PATH = REPO_ROOT / "spec" / "db" / "equiv-cells.yaml"

# Fixed family order. Family ids are the directory names used under
# spec/equiv/cells/<family>/. `source` is the exact rules.yaml `source` string.
FAMILIES = [
    {
        "id": "exec-verify",
        "title": "Execution model & VerifyScript",
        "source": "06-script-interpreter.md:AppendixB §B.1 Execution model & VerifyScript",
    },
    {
        "id": "limits",
        "title": "Limits & accounting",
        "source": "06-script-interpreter.md:AppendixB §B.2 Limits & accounting",
    },
    {
        "id": "push-encoding",
        "title": "Push & encoding rules",
        "source": "06-script-interpreter.md:AppendixB §B.3 Push & encoding rules",
    },
    {
        "id": "control-flow",
        "title": "Control flow",
        "source": "06-script-interpreter.md:AppendixB §B.4 Control flow",
    },
    {
        "id": "stack-ops",
        "title": "Stack ops",
        "source": "06-script-interpreter.md:AppendixB §B.5 Stack ops",
    },
    {
        "id": "numeric",
        "title": "Numeric ops & ScriptNum",
        "source": "06-script-interpreter.md:AppendixB §B.6 Numeric ops & ScriptNum",
    },
    {
        "id": "hash-ops",
        "title": "Hash ops",
        "source": "06-script-interpreter.md:AppendixB §B.7 Hash ops",
    },
    {
        "id": "checksig",
        "title": "Checksig (pre-tapscript)",
        "source": "06-script-interpreter.md:AppendixB §B.8 Checksig (pre-tapscript)",
    },
    {
        "id": "checkmultisig",
        "title": "CHECKMULTISIG",
        "source": "06-script-interpreter.md:AppendixB §B.9 CHECKMULTISIG",
    },
    {
        "id": "locktime",
        "title": "Locktime",
        "source": "06-script-interpreter.md:AppendixB §B.10 Locktime",
    },
    {
        "id": "witness-v0",
        "title": "SegWit v0",
        "source": "06-script-interpreter.md:AppendixB §B.11 SegWit v0",
    },
    {
        "id": "tapscript",
        "title": "Taproot & Tapscript",
        "source": "06-script-interpreter.md:AppendixB §B.12 Taproot/Tapscript",
    },
    {
        "id": "disabled-opcodes",
        "title": "Disabled opcodes",
        "source": "06-script-interpreter.md:AppendixB §B.13 Disabled opcodes",
    },
    {
        "id": "tapscript-reimport",
        "title": "Tapscript re-import",
        "source": "w2-06-flags-activation.md:AppendixB §B.1 Tapscript re-import (consensus — new row)",
    },
    {
        "id": "policy-flags",
        "title": "Policy-only flags (non-consensus)",
        "source": "w2-06-flags-activation.md:AppendixB §B.12 Policy-only flag catalogue (NOT consensus — new rows)",
    },
]
SOURCE_TO_FAMILY = {f["source"]: f for f in FAMILIES}
FAMILY_ORDER = {f["id"]: i for i, f in enumerate(FAMILIES)}

CONTRACT = {
    "scope": (
        "Exactly one entry per SCR-* row in spec/db/rules.yaml "
        "(183 rows at the cce32b168 pin). A row is adjudicated when its "
        "status is green, unjudged-seam (with gap_note) or gap (with gap_note)."
    ),
    "source_of_truth": "spec/db/rules.yaml",
    "status_enum": STATUSES,
    "status_meaning": {
        "planned": "Initialized, no tool result recorded yet.",
        "alive2-green": "At least one Alive2 cell is green; SAW is inapplicable/filed.",
        "saw-green": "At least one SAW cell is green; Alive2 is inapplicable/filed.",
        "both-green": "Alive2 and SAW both have a green cell for this row.",
        "unjudged-seam": "Deliberately outside this claim (e.g. crypto/EC seam); gap_note required.",
        "gap": "Filed gap; gap_note must name the blocking IR feature or tool limit.",
    },
    "fields": {
        "id": "SCR rule id from rules.yaml; immutable.",
        "family": "Family id from the top-level families section.",
        "summary": "Verbatim rules.yaml summary (the spec statement).",
        "core_ref": "Verbatim rules.yaml core_ref (file:function:lines@commit).",
        "consensus": "Verbatim rules.yaml consensus flag.",
        "cells": "List of spec/equiv/cells/<family>/<cell> ids discharging this row.",
        "alive2": "null or a result record (result, cell, certificate, note).",
        "saw": "null or a result record (result, cell, certificate, note).",
        "status": "Aggregate status; one of status_enum.",
        "gap_note": "null or a non-empty filed reason; required for gap and unjudged-seam.",
    },
    "maintenance": (
        "Only status, cells, alive2, saw and gap_note are hand-maintained. "
        "All other fields are regenerated from rules.yaml. Rebuild with "
        "build_equiv_cells.py; check with coverage_report.py --strict."
    ),
}


def die(message: str) -> "NoReturn":
    sys.stderr.write(f"build_equiv_cells.py: {message}\n")
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


def scr_sort_key(rule_id: str):
    match = re.fullmatch(r"SCR-(\d+)", rule_id)
    if match:
        return (0, int(match.group(1)), rule_id)
    return (1, 0, rule_id)


def slug(text: str) -> str:
    text = re.sub(r"^\d+-", "", text)
    text = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return text or "unassigned"


def family_for(row: dict) -> tuple[str, str, str]:
    """Return (family_id, title, source) for a rules.yaml row."""
    source = row.get("source")
    if isinstance(source, str) and source in SOURCE_TO_FAMILY:
        family = SOURCE_TO_FAMILY[source]
        return family["id"], family["title"], source
    # Stable fallback for a new/edited source section: derive an id from
    # "<report stem>-<section>" and keep the source text on the family.
    if isinstance(source, str) and source:
        match = re.search(
            r"(?P<report>[^:]+):.*?§(?P<section>[A-Z]\.\d+)\s*(?P<title>.*)",
            source,
        )
        if match:
            report = Path(match.group("report")).stem
            section = match.group("section").lower().replace(".", "-")
            title = match.group("title").strip(" ()") or match.group("section")
            return f"{slug(report)}-{section}", title, source
    return "unassigned", "Unassigned (missing or unparseable source)", source or ""


def previous_state(path: Path) -> dict[str, dict]:
    """Load hand-maintained state keyed by id; abort on an unparseable ledger."""
    if not path.is_file():
        return {}
    data = load_yaml(path)
    rows = data.get("rows")
    if rows is None:
        return {}
    if not isinstance(rows, list):
        die(f"{path}: `rows` must be a list")
    state = {}
    for entry in rows:
        if not isinstance(entry, dict) or not entry.get("id"):
            continue
        state[str(entry["id"])] = {
            field: entry[field] for field in STATE_FIELDS if field in entry
        }
    return state


def build(ledger_path: Path | None = None) -> dict:
    data = load_yaml(RULES_PATH)
    rules = data.get("rules")
    if not isinstance(rules, list):
        die(f"{RULES_PATH}: `rules` must be a list")

    scr_rows = [
        row
        for row in rules
        if isinstance(row, dict) and str(row.get("id", "")).startswith("SCR-")
    ]
    if not scr_rows:
        die("no SCR-* rows found in rules.yaml")

    seen = set()
    for row in scr_rows:
        rule_id = str(row["id"])
        if rule_id in seen:
            die(f"duplicate SCR id in rules.yaml: {rule_id}")
        seen.add(rule_id)
        for required in ("summary", "core_ref", "consensus"):
            if required not in row:
                die(f"{rule_id}: missing required field `{required}` in rules.yaml")

    prior = previous_state(ledger_path or LEDGER_PATH)

    families = []
    counts = {}
    for family in FAMILIES:
        families.append(
            {
                "id": family["id"],
                "title": family["title"],
                "source": family["source"],
                "rows": 0,
                "consensus_rows": 0,
                "non_consensus_rows": 0,
            }
        )
        counts[family["id"]] = families[-1]

    entries = []
    for row in sorted(scr_rows, key=lambda item: scr_sort_key(str(item["id"]))):
        rule_id = str(row["id"])
        family_id, title, source = family_for(row)
        if family_id not in counts and source not in SOURCE_TO_FAMILY:
            sys.stderr.write(
                f"warning: {rule_id}: unrecognized source section; "
                f"derived fallback family {family_id!r}\n"
            )
        if family_id not in counts:
            counts[family_id] = {
                "id": family_id,
                "title": title,
                "source": source,
                "rows": 0,
                "consensus_rows": 0,
                "non_consensus_rows": 0,
            }
            families.append(counts[family_id])
        counts[family_id]["rows"] += 1
        if row["consensus"]:
            counts[family_id]["consensus_rows"] += 1
        else:
            counts[family_id]["non_consensus_rows"] += 1

        old = prior.get(rule_id, {})
        status = old.get("status", "planned")
        if status not in STATUSES:
            sys.stderr.write(
                f"warning: {rule_id}: preserving unknown status {status!r}; "
                "coverage_report.py will treat it as invalid\n"
            )
        cells = old.get("cells", [])
        if not isinstance(cells, list):
            sys.stderr.write(
                f"warning: {rule_id}: existing `cells` is not a list; resetting to []\n"
            )
            cells = []
        entries.append(
            {
                "id": rule_id,
                "family": family_id,
                "summary": row["summary"],
                "core_ref": row["core_ref"],
                "consensus": bool(row["consensus"]),
                "cells": cells,
                "alive2": old.get("alive2"),
                "saw": old.get("saw"),
                "status": status,
                "gap_note": old.get("gap_note"),
            }
        )

    # Preserve the canonical family order, then any fallback families by id.
    families.sort(key=lambda f: (FAMILY_ORDER.get(f["id"], len(FAMILY_ORDER)), f["id"]))

    return {
        "version": 1,
        "generated_by": "spec/equiv/results/scripts/build_equiv_cells.py",
        "source_of_truth": "spec/db/rules.yaml",
        "pin": "cce32b168",
        "contract": CONTRACT,
        "families": families,
        "rows": entries,
    }


HEADER = """\
# equiv-cells.yaml — SCR coverage ledger for spec/equiv (GENERATED FILE)
#
# Contract
# --------
# * Exactly one entry per SCR-* row in spec/db/rules.yaml (183 rows at the
#   cce32b168 pin). rules.yaml is the coverage oracle; do not edit it here.
# * Status enum: planned | alive2-green | saw-green | both-green |
#   unjudged-seam | gap.
# * Hand-maintained fields: status, cells, alive2, saw, gap_note. All other
#   fields and the families section are regenerated from rules.yaml.
# * Every gap/unjudged-seam entry must carry a non-empty gap_note naming the
#   blocking IR feature or seam. Every green entry must list >=1 cell.
# * Rebuild: python3 spec/equiv/results/scripts/build_equiv_cells.py
# * Derive:  python3 spec/equiv/results/scripts/update_ledger.py --from-cells
# * Drift:   python3 spec/equiv/results/scripts/update_ledger.py --check
# * Check:   python3 spec/equiv/results/scripts/coverage_report.py --strict
# * Matrix:  python3 spec/equiv/results/scripts/build_matrix.py
#
# The machine-readable contract is repeated under the top-level `contract:`
# key below. Do not hand-edit generated fields.
#
"""


def dump(ledger: dict) -> str:
    body = yaml.safe_dump(
        ledger,
        sort_keys=False,
        allow_unicode=True,
        default_flow_style=False,
        width=4096,
    )
    return HEADER + body


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 if the on-disk ledger differs from the regenerated text",
    )
    parser.add_argument(
        "--ledger",
        type=Path,
        default=LEDGER_PATH,
        help="ledger path (default: spec/db/equiv-cells.yaml; testability hook)",
    )
    args = parser.parse_args(argv)

    ledger_path: Path = args.ledger
    text = dump(build(ledger_path))
    if args.check:
        current = (
            ledger_path.read_text(encoding="utf-8") if ledger_path.is_file() else ""
        )
        if current != text:
            sys.stderr.write(
                f"{ledger_path} is stale; re-run build_equiv_cells.py\n"
            )
            return 1
        print(f"{ledger_path}: up to date")
        return 0

    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    ledger_path.write_text(text, encoding="utf-8")
    print(f"wrote {ledger_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
