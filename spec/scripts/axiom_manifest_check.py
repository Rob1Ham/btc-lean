#!/usr/bin/env python3
"""Validate a consensus axiom footprint file in static and dynamic modes."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


ALLOWED = frozenset({"propext", "Classical.choice", "Quot.sound"})
ENTRY = re.compile(
    r"^'[^']+' (?:does not depend on any axioms|depends on axioms: \[([^\]]*)\])$"
)


def check(path: Path) -> tuple[int, list[str]]:
    entries: list[tuple[int, str]] = []
    current: list[str] = []
    start = 0
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        if line.startswith("'"):
            if current:
                entries.append((start, " ".join(current)))
            current, start = [line.strip()], lineno
        elif current:
            current.append(line.strip())
        else:
            entries.append((lineno, line.strip()))
    if current:
        entries.append((start, " ".join(current)))

    errors = []
    if not entries:
        errors.append(f"{path}: no axiom entries")
    for lineno, entry in entries:
        match = ENTRY.fullmatch(entry)
        if match is None:
            errors.append(f"{path}:{lineno}: malformed axiom entry: {entry[:120]}")
            continue
        footprint = match.group(1)
        if footprint is None or not footprint.strip():
            continue
        axioms = [name.strip() for name in footprint.split(",")]
        if any(not name for name in axioms):
            errors.append(f"{path}:{lineno}: empty axiom name")
        unexpected = sorted(set(axioms) - ALLOWED - {""})
        if unexpected:
            errors.append(f"{path}:{lineno}: unapproved axiom(s): {', '.join(unexpected)}")
    return len(entries), errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        count, errors = check(args.manifest)
    except (OSError, UnicodeError) as error:
        print(f"axiom-manifest: cannot read {args.manifest}: {error}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(f"axiom-manifest: {error}", file=sys.stderr)
        return 1
    print(f"axiom-manifest[validate]: OK ({count} entries; only {', '.join(sorted(ALLOWED))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
