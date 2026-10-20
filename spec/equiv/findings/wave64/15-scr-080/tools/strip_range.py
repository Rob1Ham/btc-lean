#!/usr/bin/env python3
"""Strip the derived return-value range attribute from an extracted leaf.

Both legs are normalised identically.  clang attaches
`range(<lo>, <hi>)` to a leaf's definition when it can bound the return value;
the bounds are *derived*, not part of the source semantics, and Alive2 treats
the attribute as a source of poison.  The C and L legs can derive different
lower bounds (the C leaf's reject arm and the twin's reject arm reach the same
bit pattern through different expressions), and Alive2 then reports
"Source and target don't have the same return domain" for an equivalent pair.

Removing the attribute weakens the source (a smaller UB set), which is sound
for a refinement check: if the weaker program refines the target, so does the
original.  Usage:

    python3 strip_range.py FILE.ll
"""
from __future__ import annotations

import re
import sys

DEFINE_RANGE = re.compile(r"(define\b[^(\n]*)range\([^)]*\)\s*")


def main(path: str) -> int:
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    out = []
    changed = 0
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith("define "):
            new, n = DEFINE_RANGE.subn(r"\1", line, count=1)
            changed += n
            line = new
        out.append(line)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("".join(out))
    return 0 if changed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
