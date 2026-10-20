#!/usr/bin/env python3
"""Reviewer check (not proof evidence): the two transcriptions must agree.

Alive2 and SAW are the evidence; this script is a fast human-readable diff so
a table divergence is easy to locate.  It exits non-zero on any difference.
"""
import sys
from pathlib import Path


def read(path: Path) -> dict[int, str]:
    out = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        w, name = line.split(None, 1)
        out[int(w, 16)] = name.strip()
    return out


def main(here: Path) -> int:
    core = read(here / "core_names.txt")
    lean = read(here / "lean_names.txt")
    bad = 0
    for w in range(0x100):
        c = core.get(w, "OP_UNKNOWN")
        l = lean.get(w, "OP_UNKNOWN")
        if c != l:
            print(f"MISMATCH 0x{w:02x}: core={c} lean={l}")
            bad += 1
    named = sum(1 for w in range(0x100) if core.get(w, "OP_UNKNOWN") != "OP_UNKNOWN")
    unknown = 256 - named
    print(f"named={named} unknown={unknown} mismatches={bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(Path(__file__).resolve().parent))
