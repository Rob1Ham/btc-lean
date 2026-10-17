#!/usr/bin/env python3
"""Validate the wallet census in ``spec/db/rules-wallet.yaml``.

The wallet census is a second, independent database. It is never merged into
``spec/db/rules.yaml``. This script checks the mechanical parts of its
contract:

* the file parses and has a ``rules`` list of 100 through 140 rows;
* IDs are unique and use one of the five census namespaces;
* every row has the required fields, ``status: planned``, a permitted
  difficulty (``s``, ``m``, ``l``, ``xl``) and ``consensus: false``;
* every ``core_ref`` is a relative ``path:line`` anchor whose file exists in
  the pinned Bitcoin Core source tree and whose cited line is non-empty;
* every ``statement`` is a single sentence ending in a period.

The script prints per-namespace, per-status and per-Core-file counts. It
returns 0 when all checks pass and 1 when any check fails. A missing Core
source tree is reported separately and returns 2.

The Core source root is taken from ``--core-src``, then ``$CORE_SRC``, then a
few conventional sibling directories. It may be either the repository root or
the directory containing ``script/`` and ``psbt.h``; the nested ``src/``
layout is detected automatically.

Usage:
    python3 spec/scripts/wallet_census.py [spec/db/rules-wallet.yaml] \
        [--core-src /path/to/bitcoin/src]
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from collections import Counter
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent.parent
DEFAULT_DB = REPO / "spec" / "db" / "rules-wallet.yaml"
MIN_ROWS = 100
MAX_ROWS = 140
NAMESPACES = ("DESC", "MS", "PSBT", "WSP", "SGN2")
ALLOWED_STATUSES = {"planned", "stubbed", "implemented", "proven", "obsolete"}
ALLOWED_DIFFICULTIES = {"s", "m", "l", "xl"}
REQUIRED_FIELDS = (
    "id",
    "summary",
    "statement",
    "check",
    "core_ref",
    "bip_cve",
    "lean_target",
    "test_vector_ids",
    "status",
    "difficulty",
    "consensus",
    "notes",
    "source",
)
REF_RE = re.compile(r"^(?P<path>[A-Za-z0-9_./-]+):(?P<line>[1-9][0-9]*)$")
ID_RE = re.compile(r"^(?P<ns>[A-Z0-9]+)-(?P<num>[0-9]{3,})$")
# A period followed by whitespace usually starts a second sentence. Decimal
# points are not followed by whitespace, so they do not trigger this test.
SENTENCE_BREAK_RE = re.compile(r"\.\s")


def is_core_root(path: Path) -> bool:
    """Return whether *path* looks like a Bitcoin Core source root."""
    return (path / "script" / "descriptor.cpp").is_file() and (path / "psbt.h").is_file()


def core_root_from(path: Path) -> Path | None:
    """Resolve a Core directory, accepting either a repo root or its src/."""
    for candidate in (path, path / "src"):
        if is_core_root(candidate):
            return candidate.resolve()
    return None


def resolve_core_src(explicit: str | None) -> Path | None:
    """Find the pinned Core source tree from CLI, environment or siblings."""
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("CORE_SRC"):
        candidates.append(Path(os.environ["CORE_SRC"]))
    candidates.extend(
        [
            REPO.parent / "core",
            REPO.parent / "bitcoin",
            REPO.parent / "bitcoin-core",
            REPO.parent / "core-build" / "src",
            REPO.parent / "core-build" / "src" / "src",
        ]
    )
    for candidate in candidates:
        resolved = core_root_from(candidate)
        if resolved is not None:
            return resolved
    return None


def load_rows(db: Path) -> list[dict] | None:
    """Load and return the rows list, or None after printing a parse error."""
    try:
        data = yaml.safe_load(db.read_text())
    except Exception as exc:  # noqa: BLE001 - report the parser error verbatim
        print(f"wallet-census: yaml.safe_load FAILED: {exc}", file=sys.stderr)
        return None
    rows = data.get("rules") if isinstance(data, dict) else None
    if not isinstance(rows, list):
        print("wallet-census: top-level `rules:` list missing", file=sys.stderr)
        return None
    return rows


def check_row_shape(row: object, index: int, errors: list[str]) -> dict | None:
    """Check one row's fields and scalar values, recording every error."""
    if not isinstance(row, dict):
        errors.append(f"row {index}: not a mapping")
        return None

    row_id = row.get("id")
    label = row_id if isinstance(row_id, str) and row_id else f"row {index}"
    for field in REQUIRED_FIELDS:
        if field not in row:
            errors.append(f"{label}: missing field {field!r}")

    if not isinstance(row_id, str) or not ID_RE.fullmatch(row_id):
        errors.append(f"{label}: id must match NAMESPACE-NNN")
    elif row_id.split("-", 1)[0] not in NAMESPACES:
        errors.append(f"{label}: unknown namespace")

    for field in ("summary", "statement", "check", "core_ref", "bip_cve", "notes", "source"):
        value = row.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{label}: field {field!r} must be a non-empty string")

    statement = row.get("statement")
    if isinstance(statement, str):
        if not statement.endswith(".") or SENTENCE_BREAK_RE.search(statement):
            errors.append(f"{label}: statement must be exactly one sentence")

    status = row.get("status")
    if status not in ALLOWED_STATUSES:
        errors.append(f"{label}: status {status!r} is not allowed")
    elif status != "planned":
        errors.append(f"{label}: census rows must remain planned, got {status!r}")

    difficulty = row.get("difficulty")
    if difficulty not in ALLOWED_DIFFICULTIES:
        errors.append(f"{label}: difficulty {difficulty!r} is not one of s/m/l/xl")

    if row.get("consensus") is not False:
        errors.append(f"{label}: consensus must be false")

    if "lean_target" not in row:
        errors.append(f"{label}: missing field 'lean_target'")
    vectors = row.get("test_vector_ids")
    if not isinstance(vectors, list):
        errors.append(f"{label}: test_vector_ids must be a list")

    return row


def check_anchor(
    row: dict, core_src: Path, errors: list[str], file_counts: Counter[str]
) -> None:
    """Check that one core_ref resolves to a non-empty line in the pinned tree."""
    label = row.get("id", "<missing-id>")
    ref = row.get("core_ref")
    match = REF_RE.fullmatch(ref) if isinstance(ref, str) else None
    if match is None:
        errors.append(f"{label}: core_ref must be a relative path:line anchor, got {ref!r}")
        return

    rel_path = match.group("path")
    line_no = int(match.group("line"))
    if rel_path.startswith("/") or ".." in Path(rel_path).parts:
        errors.append(f"{label}: core_ref must stay inside the Core tree")
        return

    path = core_src / rel_path
    if not path.is_file():
        errors.append(f"{label}: anchor file does not exist: {rel_path}")
        return

    lines = path.read_text(errors="replace").splitlines()
    if line_no > len(lines):
        errors.append(
            f"{label}: anchor {rel_path}:{line_no} is beyond end of file "
            f"({len(lines)} lines)"
        )
        return
    if not lines[line_no - 1].strip():
        errors.append(f"{label}: anchor {rel_path}:{line_no} cites an empty line")
        return

    file_counts[rel_path] += 1


def main() -> int:
    """Run every check and print the census summary."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "db",
        nargs="?",
        default=str(DEFAULT_DB),
        help="wallet census YAML (default: spec/db/rules-wallet.yaml)",
    )
    parser.add_argument(
        "--core-src",
        default=None,
        help="Bitcoin Core source root (or repository root); defaults to $CORE_SRC",
    )
    parser.add_argument(
        "--lock",
        action="store_true",
        help="after validation, write spec/db/rules-wallet.lock with "
        "per-namespace counts and the SHA-256 of the census file",
    )
    args = parser.parse_args()
    db = Path(args.db)

    rows = load_rows(db)
    if rows is None:
        return 1

    core_src = resolve_core_src(args.core_src)
    if core_src is None:
        print(
            "wallet-census: cannot locate the Bitcoin Core source tree; "
            "pass --core-src or set CORE_SRC to the directory containing "
            "script/ and psbt.h",
            file=sys.stderr,
        )
        return 2

    errors: list[str] = []
    if not MIN_ROWS <= len(rows) <= MAX_ROWS:
        errors.append(f"row count {len(rows)} is outside {MIN_ROWS}..{MAX_ROWS}")

    checked: list[dict] = []
    seen_ids: set[str] = set()
    for index, raw in enumerate(rows, start=1):
        row = check_row_shape(raw, index, errors)
        if row is None:
            continue
        row_id = row.get("id")
        if isinstance(row_id, str):
            if row_id in seen_ids:
                errors.append(f"{row_id}: duplicate id")
            seen_ids.add(row_id)
        checked.append(row)

    file_counts: Counter[str] = Counter()
    for row in checked:
        check_anchor(row, core_src, errors, file_counts)

    namespaces = Counter(
        row["id"].split("-", 1)[0]
        for row in checked
        if isinstance(row.get("id"), str) and ID_RE.fullmatch(row["id"])
    )
    statuses = Counter(row.get("status") for row in checked)

    print(
        f"wallet-census: {db} — {len(rows)} rows "
        f"(allowed {MIN_ROWS}..{MAX_ROWS}), {len(seen_ids)} unique ids"
    )
    print(f"  core source: {core_src}")
    print(
        "  namespaces: "
        + ", ".join(f"{ns}={namespaces.get(ns, 0)}" for ns in NAMESPACES)
    )
    print(
        "  status: " + ", ".join(f"{k}={v}" for k, v in sorted(statuses.items()))
    )
    anchor_problems = sum(
        1 for error in errors if "anchor" in error or "core_ref" in error
    )
    print(
        f"  anchors: {sum(file_counts.values())} checked, "
        f"{anchor_problems} problem(s)"
    )

    if errors:
        for error in errors:
            print(f"wallet-census: FAIL {error}", file=sys.stderr)
        print(
            f"wallet-census: FAILED with {len(errors)} error(s)",
            file=sys.stderr,
        )
        return 1

    if args.lock:
        digest = hashlib.sha256(db.read_bytes()).hexdigest()
        lock_path = REPO / "spec" / "db" / "rules-wallet.lock"
        namespace_line = " ".join(
            f"{ns}={namespaces.get(ns, 0)}" for ns in NAMESPACES
        )
        lock_path.write_text(
            "# rules-wallet.lock - frozen wallet census summary.\n"
            "# Generated by: python3 spec/scripts/wallet_census.py --lock\n"
            f"rows: {len(rows)}\n"
            f"namespaces: {namespace_line}\n"
            f"sha256: {digest}\n",
            encoding="utf-8",
        )
        print(
            f"wallet-census: wrote {lock_path.relative_to(REPO)} "
            f"(sha256 {digest})"
        )

    print(
        f"wallet-census: OK ({len(rows)} rows, "
        f"{len(namespaces)} namespaces, {sum(file_counts.values())} anchors)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
