#!/usr/bin/env python3
"""Rewrite one cell certificate over the cell's tracked inputs + raw result.

Same contract as spec/equiv/tools/normalize_certificates.py (repo-relative
paths, ignored build/ products excluded, raw result.txt included), scoped to a
single cell so a cell runner never rewrites another cell's certificate.

Usage: python3 normalize_cert.py CELL_DIR CERT_PATH
"""
from __future__ import annotations
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
SKIP_PARTS = {"build", "__pycache__", ".git"}

# Shared tracked inputs that determine the result (family harness, generator,
# twin sources, contract ordinals).
SHARED = [
    "spec/equiv/cells/stack-ops/_harness/build.sh",
    "spec/equiv/cells/stack-ops/_harness/extract_extras.py",
    "spec/equiv/cells/stack-ops/_harness/leaf_common.h",
    "spec/equiv/cells/stack-ops/_harness/run_alive2.sh",
    "spec/equiv/cells/stack-ops/_harness/run_saw.sh",
    "spec/equiv/cells/_tools/mk_leaf.py",
    "spec/equiv/twin/ops_ir.py",
    "spec/equiv/twin/gen.py",
    "spec/equiv/twin/runtime.inc",
    "spec/equiv/contract/error_kind.h",
]


def digest(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    cell = Path(sys.argv[1]).resolve()
    cert = Path(sys.argv[2]).resolve()
    result = cert.parent / "result.txt"
    files = set()
    for p in cell.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(cell)
        if any(part in SKIP_PARTS for part in rel.parts):
            continue
        if p.name == "certificate.sha256":
            continue
        # Each leg certifies its own raw transcript; the other legs' result.txt
        # files would make the certificate depend on run order.
        if p.name == "result.txt" and p.parent != cert.parent:
            continue
        if p.stat().st_size > 5 * 1024 * 1024:
            continue
        files.add(p.resolve())
    if result.is_file():
        files.add(result.resolve())
    for rel in SHARED:
        p = ROOT / rel
        if p.is_file():
            files.add(p.resolve())
    entries = []
    for p in files:
        try:
            rel = p.relative_to(ROOT).as_posix()
        except ValueError:
            continue
        entries.append((rel, digest(p)))
    cert.write_text("".join(f"{d}  {rel}\n" for rel, d in sorted(entries)),
                    encoding="utf-8")
    print(f"certificate: {len(entries)} tracked inputs + result -> {cert.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
