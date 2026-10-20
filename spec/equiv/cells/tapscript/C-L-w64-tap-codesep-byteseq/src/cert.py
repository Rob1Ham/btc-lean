#!/usr/bin/env python3
"""Write the cell certificate exactly as spec/equiv/tools/normalize_certificates.py
would: repo-relative SHA-256 over every tracked text input under the cell
(build/ and __pycache__/ excluded) plus the raw result transcripts.

Usage: cert.py alive2|saw
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

CELL = Path(__file__).resolve().parents[1]
ROOT = CELL.parents[4]
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


def main() -> int:
    leg = sys.argv[1]
    files = set()
    for p in CELL.rglob("*"):
        if p.is_file() and wanted(p) and p.stat().st_size <= 5 * 1024 * 1024:
            files.add(p.resolve())
    entries = [(p.relative_to(ROOT).as_posix(), digest(p)) for p in files]
    text = "".join(f"{d}  {rel}\n" for rel, d in sorted(entries))
    out = CELL / leg / "certificate.sha256"
    out.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
