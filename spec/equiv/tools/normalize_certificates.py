#!/usr/bin/env python3
"""Normalize cell certificates to repo-relative, tracked inputs.

The cell runners historically hashed ignored ``build/`` artifacts (including a
``build.txt`` containing the absolute checkout path).  Those certificates
cannot be replayed from a fresh checkout.  This tool rewrites each certificate
over the cell's tracked inputs plus its raw ``result.txt`` transcript only.
It never invents a result or changes a success marker.

Run from anywhere:

    python3 spec/equiv/tools/normalize_certificates.py [--check]
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EQ = ROOT / "spec" / "equiv"
CELLS = EQ / "cells"
SKIP_PARTS = {"build", "__pycache__", ".git"}
TEXT_SUFFIXES = {
    ".md", ".sh", ".cpp", ".c", ".h", ".hpp", ".cry", ".saw", ".ll",
    ".bc", ".json", ".yaml", ".yml", ".txt", ".out", ".hex", ".py",
    ".lean", ".toml", ".cfg", ".ini", ".spec", ".log",
}


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def wanted(path: Path) -> bool:
    if any(part in SKIP_PARTS for part in path.parts):
        return False
    if path.name == "certificate.sha256":
        return False
    if path.name == "buildspec":
        return True
    return path.suffix in TEXT_SUFFIXES or path.suffix == ""


def old_paths(cert: Path) -> set[Path]:
    """Keep file references from the old certificate if they are tracked.

    This preserves shared inputs such as contract/error_kind.h and cell-local
    _tools headers, while dropping build/ and absolute entries.
    """
    kept: set[Path] = set()
    try:
        lines = cert.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return kept
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        rel = parts[1].strip()
        if rel.startswith("/") or not rel:
            continue
        p = ROOT / rel
        if not p.is_file() or any(part in SKIP_PARTS for part in Path(rel).parts):
            continue
        if p.stat().st_size > 5 * 1024 * 1024:
            continue
        kept.add(p.resolve())
    return kept


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    changed = 0
    missing = 0
    for cert in sorted(CELLS.glob("*/*/*/certificate.sha256")):
        cell = cert.parent.parent
        leg = cert.parent.name
        files: set[Path] = set(old_paths(cert))
        for p in cell.rglob("*"):
            if p.is_file() and wanted(p) and p.stat().st_size <= 5 * 1024 * 1024:
                files.add(p.resolve())
        result = cert.parent / "result.txt"
        if result.is_file():
            files.add(result.resolve())
        # A certificate must at least contain the cell record and its result.
        for required in (cell / "spec.md", result):
            if required.is_file():
                files.add(required.resolve())
        entries = []
        for p in files:
            try:
                rel = p.relative_to(ROOT).as_posix()
            except ValueError:
                continue
            entries.append((rel, digest(p)))
        if not entries:
            missing += 1
            continue
        text = "".join(f"{d}  {rel}\n" for rel, d in sorted(entries))
        if cert.read_text(encoding="utf-8", errors="replace") != text:
            changed += 1
            if not args.check:
                cert.write_text(text, encoding="utf-8")
        if result.is_file() and not any(rel == result.relative_to(ROOT).as_posix() for rel, _ in entries):
            print(f"MISSING-RESULT {cert.relative_to(ROOT)}")
            missing += 1
        _ = leg
    print(f"certificates normalized: changed={changed}, missing={missing}")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
