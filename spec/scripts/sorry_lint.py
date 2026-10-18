#!/usr/bin/env python3
"""sorry_lint.py — hygiene gate for the public Lean tree.

  * every code `sorry` or `admit` occurrence in `spec/core` and `spec/proofs`
    is rejected; a `SORRY[ID]` annotation never grants an exemption;
  * core `native_decide` is confined to test drivers (only under `Test/`
    paths or the root test harnesses);
  * `unsafe`/`partial`/`@[implemented_by]`/`@[extern]`/`unsafeIO` are
    inventoried (must stay zero in core).

The scanner is comment- and string-aware. A `sorry` in a docstring, line
comment, block comment, string literal, or character literal is not code and
does not count. Block comments nest, as in Lean.
Exit non-zero on any violation.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORE = ROOT / "core"
PROOFS = ROOT / "proofs"
TEST_ALLOW = re.compile(r"(^|/)(Test|tests)(/|$)|/Main\.lean$|lakefile")

SORRY_RE = re.compile(r"\bsorry\b")
ADMIT_RE = re.compile(r"\badmit\b")
TAG_RE = re.compile(r"SORRY\[[^\]]+\]")
HAZARDS = ["unsafe def", "unsafe let", "unsafe opaque", "unsafeIO",
           "partial def", "@[implemented_by", "@[extern]"]

fail = 0
n_sorry = n_tagged = n_admit = n_native_bad = n_hazard = 0


def code_lines(text: str) -> list[str]:
    """Return one line per input line, with comments/strings replaced by spaces.

    Newlines are preserved so line numbers and tag lookback stay aligned.
    This follows Lean's nesting rules for `/- ... -/`; it deliberately does
    not interpret Markdown code spans inside comments.
    """
    out: list[str] = [""]
    i = 0
    n = len(text)
    block = 0
    in_string = False
    in_char = False
    in_line_comment = False

    def emit(ch: str) -> None:
        out[-1] += ch

    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_line_comment:
            if c == "\n":
                out.append("")
                in_line_comment = False
            i += 1
            continue

        if block:
            if c == "\n":
                out.append("")
            elif c == "/" and nxt == "-":
                block += 1
                i += 2
                continue
            elif c == "-" and nxt == "/":
                block -= 1
                i += 2
                continue
            i += 1
            continue

        if in_string:
            if c == "\\" and i + 1 < n:
                i += 2
                continue
            if c == '"':
                in_string = False
                i += 1
                continue
            if c == "\n":
                out.append("")
            i += 1
            continue

        if in_char:
            if c == "\\" and i + 1 < n:
                i += 2
                continue
            if c == "'":
                in_char = False
                i += 1
                continue
            if c == "\n":
                out.append("")
            i += 1
            continue

        if c == "-" and nxt == "-":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "-":
            block = 1
            i += 2
            continue
        if c == '"':
            in_string = True
            i += 1
            continue
        if c == "'":
            # Lean identifiers can end in an apostrophe (foo'), so only enter
            # character mode when a closing quote exists in the next few chars.
            j = i + 1
            if j < n and text[j] == "\\":
                j += 2
            else:
                j += 1
            if j < n and text[j] == "'":
                in_char = True
                i += 1
                continue
            emit(c)
            i += 1
            continue

        if c == "\n":
            out.append("")
        else:
            emit(c)
        i += 1

    if not out:
        out.append("")
    return out


files = sorted(list(CORE.rglob("*.lean")) + list(PROOFS.rglob("*.lean")))
for f in files:
    rel = f.relative_to(ROOT)
    if ".lake" in rel.parts or f.name.startswith("lakefile"):
        continue
    is_core = CORE in f.parents
    raw_lines = f.read_text().splitlines()
    clean = code_lines(f.read_text())
    if len(clean) < len(raw_lines):
        # Defensive: preserve one entry per physical line for diagnostics.
        clean.extend([""] * (len(raw_lines) - len(clean)))
    recent: list[str] = []
    for ln, raw in enumerate(raw_lines, 1):
        code = clean[ln - 1]
        for regex, label, counter in (
            (SORRY_RE, "SORRY", "sorry"),
            (ADMIT_RE, "ADMIT", "admit"),
        ):
            if not regex.search(code):
                continue
            if counter == "sorry":
                n_sorry += 1
            else:
                n_admit += 1
            if any(TAG_RE.search(t) for t in recent + [raw]):
                if counter == "sorry":
                    n_tagged += 1
            print(f"FORBIDDEN {label}: {rel}:{ln}: {raw.strip()}")
            fail = 1
        if is_core and "native_decide" in code:
            if not TEST_ALLOW.search(str(rel)):
                print(f"NATIVE_DECIDE OUTSIDE TEST: {rel}:{ln}: {raw.strip()}")
                n_native_bad += 1
                fail = 1
        if is_core:
            for h in HAZARDS:
                if h in code:
                    print(f"HAZARD ({h}): {rel}:{ln}: {raw.strip()}")
                    n_hazard += 1
                    fail = 1
        recent.append(raw)
        recent = recent[-5:]

print(f"sorry-lint: {n_sorry} sorry occurrences, {n_tagged} tagged, "
      f"{n_sorry - n_tagged} untagged; {n_admit} admit occurrences")
print(f"sorry-lint: native_decide violations: {n_native_bad}; "
      f"unsafe/partial/FFI hazards: {n_hazard}")
print("sorry-lint: " + ("FAIL" if fail else "OK"))
sys.exit(1 if fail else 0)
