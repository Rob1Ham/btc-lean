#!/usr/bin/env python3
"""Enumerate the CScriptNum constructions in pinned Core's EvalScript.

SCR-080's claim is about the *default* size argument, so the interesting set is
every CScriptNum construction that decodes a stack operand without naming a
size.  This script reads one file (default: `src/script/interpreter.cpp` from a
Core checkout at cce32b168) and classifies each construction:

  int-ctor          constructed from an integer/size, no operand decode
  decode-default4   decoded from a stack operand, size argument omitted
  decode-explicit5  decoded from a stack operand with an explicit 5 (SCR-081)
  static-int        namespace-scope `static const CScriptNum bnZero(0)`

Usage:
    python3 enumerate_sites.py /path/to/bitcoin/src/script/interpreter.cpp
    python3 enumerate_sites.py FILE > call-sites.tsv

The output is a TSV with header:
    line  class  CScriptNum-expression  case-labels

`case-labels` is the nearest OP_* case label group above the line (comma
separated) plus its line number, as a reading aid; it is not a parser.
"""
from __future__ import annotations

import re
import sys

CSN = re.compile(r"\bCScriptNum\b")
CASE = re.compile(r"\bcase\s+(OP_[A-Z0-9_]+)\s*:")


def is_comment(line: str) -> bool:
    return line.strip().startswith("//")


def classify(expr: str) -> str:
    if "static const CScriptNum" in expr:
        return "static-int"
    if re.search(r"stacktop\([^)]*\)\.size\(\)", expr):
        return "int-ctor"
    if "stacktop(" in expr:
        if re.search(r",\s*5\s*\)", expr):
            return "decode-explicit5"
        return "decode-default4"
    return "int-ctor"


def case_group(lines: list[str], idx: int) -> tuple[int, list[str]]:
    """Nearest `case OP_*:` group above 0-based idx: (1-based line, labels)."""
    j = idx - 1
    while j >= 0 and (is_comment(lines[j]) or not lines[j].strip()):
        j -= 1
    # Walk up to the nearest case label, then collect the contiguous group.
    while j >= 0 and not CASE.search(lines[j]):
        j -= 1
    if j < 0:
        return 0, []
    start = j
    labels: list[str] = []
    while j >= 0:
        s = lines[j].strip()
        m = CASE.search(s)
        if m:
            labels.insert(0, m.group(1))
            start = j
            j -= 1
            continue
        if is_comment(s) or not s:
            j -= 1
            continue
        break
    return start + 1, labels


def eval_scope(lines: list[str]) -> tuple[int, int]:
    """0-based [start, end) of the EvalScript body, or the whole file."""
    start = None
    for i, line in enumerate(lines):
        if re.search(r"\bbool\s+EvalScript\s*\(", line):
            start = i
            break
    if start is None:
        return 0, len(lines)
    depth = 0
    seen = False
    for j in range(start, len(lines)):
        depth += lines[j].count("{") - lines[j].count("}")
        if "{" in lines[j]:
            seen = True
        if seen and depth <= 0:
            return start, j + 1
    return start, len(lines)


def main(path: str) -> int:
    with open(path, "r", encoding="utf-8") as fh:
        lines = fh.readlines()
    lo, hi = eval_scope(lines)
    print("line\tclass\tCScriptNum-expression\tcase-labels")
    for i in range(lo, hi):
        line = lines[i].rstrip("\n")
        if is_comment(line) or not CSN.search(line):
            continue
        at, labels = case_group(lines, i)
        tag = f"{','.join(labels)}@L{at}" if labels else "-"
        print(f"{i + 1}\t{classify(line.strip())}\t{line.strip()}\t{tag}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1
                  else "src/script/interpreter.cpp"))
