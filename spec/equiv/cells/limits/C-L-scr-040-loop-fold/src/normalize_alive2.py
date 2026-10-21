#!/usr/bin/env python3
"""Alive2 IR preparation for limits/C-L-scr-040-loop-fold.

Alive2 v20 refuses to translate functions whose pointer parameters carry the
caller-side ABI hint attributes clang derives at -O1:

    ERROR: Unsupported attribute: nocapture
    ERROR: Could not translate 'cell_witness_serialized_size' to Alive IR

This cell-local script removes exactly these codegen-only facts from an
extracted function's textual IR before `alive-tv` reads it:

  * caller-contract pointer attributes: nocapture, readonly, writeonly,
    memory(...);
  * the `nsw`/`nuw` overflow flags clang infers on `add`/`sub`/`mul`.

The attribute removal is conservative: those are promises the callee makes to
its caller, and dropping them only widens the callee's allowed behaviour, so
a proof that holds without them also holds with them.

The overflow flags are not part of the source semantics of this cell: clang
infers them from the value ranges (`uint32_t` lengths, at most 8 items, a
64-bit accumulator), so no overflow is possible on either leg.  Alive2 v20
handles the flagged 3+-item bitvector queries by case-splitting and times out,
while the same functions without the flags verify in well under a second.
Removing the flags compares the wrap-around semantics of the identical
arithmetic; because both legs receive the identical transform and the flags
are true on the cell's stated domain, the unflagged equality implies the
flagged equality there.  `-fwrapv` is already used when compiling, and SAW
checks the same arithmetic as total 64-bit bitvectors.

No instruction, operand, type, or control-flow edge is modified.  Both legs
receive the identical transform, and the prepared IR is what the Alive2
certificate hashes.

This is a new cell-local file; the shared `limits/_shared` harness is not
modified.  The same approach is used by the existing
limits/C-L-tapscript-weight cell.

Usage: normalize_alive2.py IN.ll OUT.ll
"""
import re
import sys

ATTRS = re.compile(r"\s+(?:nocapture|readonly|writeonly)\b")
MEMATTR = re.compile(r"\smemory\([^)]*\)")
OVF = re.compile(r"\s(?:nsw|nuw)\b")


def normalize(text: str) -> str:
    text = ATTRS.sub("", text)
    text = MEMATTR.sub("", text)
    text = OVF.sub("", text)
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
