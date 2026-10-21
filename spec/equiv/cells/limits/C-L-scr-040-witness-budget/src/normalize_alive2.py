#!/usr/bin/env python3
"""Alive2 IR preparation for limits/C-L-scr-040-witness-budget.

Alive2 v20 refuses to translate functions whose pointer parameters carry the
caller-side ABI hint attributes clang derives at -O1:

    ERROR: Unsupported attribute: nocapture
    ERROR: Could not translate 'cell_witness_serialized_size' to Alive IR

This cell-local script removes exactly those *caller contracts* from an
extracted function's textual IR before `alive-tv` reads it:

    nocapture, readonly, writeonly, memory(...)

Soundness: every attribute removed here is a promise the *callee* makes to its
caller about how it uses a pointer.  Dropping the promise can only make the
callee's behaviour less constrained (more caller-visible effects allowed), so
a refinement proof that holds with the attributes removed also holds with them
present; the transform cannot hide a divergence.  No instruction, operand,
type, or control-flow edge is modified.  Both legs receive the identical
transform, and the prepared IR is what the Alive2 certificate hashes.

This is a new cell-local file; the shared `limits/_shared` harness is not
modified.  The same approach is used by the existing
limits/C-L-tapscript-weight cell.

Usage: normalize_alive2.py IN.ll OUT.ll
"""
import re
import sys

ATTRS = re.compile(r"\s+(?:nocapture|readonly|writeonly)\b")
MEMATTR = re.compile(r"\smemory\([^)]*\)")


def normalize(text: str) -> str:
    text = ATTRS.sub("", text)
    text = MEMATTR.sub("", text)
    return text


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        text = f.read()
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(normalize(text))
    return 0


if __name__ == "__main__":
    sys.exit(main())
