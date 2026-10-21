#!/usr/bin/env python3
"""Deterministic textual-IR transform used ONLY to enumerate Alive2 blockers.

Each class is opt-in via --strip. Nothing here is a proof step: removing a
soundness-relevant attribute/metadata from the *source* changes the source
contract and is NOT admissible for a refinement claim.

Classes:
  attrs   : drop `noalias`, `captures(...)`, `sret(...)`, `dead_on_return`
            from function parameter lists (declarations and definitions).
  nomd    : drop `!noalias` and `!alias.scope` instruction attachments.
  scopedecl: drop `call void @llvm.experimental.noalias.scope.decl(metadata !N)`.
  volatile: drop `load volatile i8, ptr @__rust_no_alloc_shim_is_unstable`.
  atomic  : drop `atomic` from load/store/atomicrmw/cmpxchg (LAST RESORT).
"""
import re
import sys

PARAM_ATTR_RE = re.compile(
    r"\b(?:noalias|captures\([^()]*\)|sret\([^()]*\)|dead_on_return(?:\([^()]*\))?)\s*"
)
MD_ATTR_RE = re.compile(r",\s*!(?:noalias|alias\.scope)\s*!\d+")
SCOPEDECL_RE = re.compile(
    r"^.*@llvm\.experimental\.noalias\.scope\.decl\(metadata !\d+\).*\n", re.M
)
VOLATILE_RE = re.compile(
    r"^.*load volatile i8, ptr @__rust_no_alloc_shim_is_unstable.*\n", re.M
)


def split_sig(line):
    """Return (prefix, params, suffix) for a define/declare line."""
    i = line.find("(")
    if i < 0:
        return None
    depth = 0
    for j in range(i, len(line)):
        if line[j] == "(":
            depth += 1
        elif line[j] == ")":
            depth -= 1
            if depth == 0:
                return line[: i + 1], line[i + 1 : j], line[j:]
    return None


def main():
    src, dst = sys.argv[1], sys.argv[2]
    classes = set(sys.argv[3:])
    text = open(src).read()
    if "param_noalias" in classes:
        out = []
        for line in text.splitlines(keepends=True):
            if line.startswith(("define ", "declare ")):
                parts = split_sig(line)
                if parts:
                    pre, params, post = parts
                    params = re.sub(r"\bnoalias\s+", "", params)
                    line = pre + params + post
            out.append(line)
        text = "".join(out)
    if "attrs" in classes:
        out = []
        for line in text.splitlines(keepends=True):
            if line.startswith(("define ", "declare ")):
                parts = split_sig(line)
                if parts:
                    pre, params, post = parts
                    params = PARAM_ATTR_RE.sub("", params)
                    params = re.sub(r"\s{2,}", " ", params)
                    line = pre + params + post
            out.append(line)
        text = "".join(out)
    if "nomd" in classes:
        text = MD_ATTR_RE.sub("", text)
    if "scopedecl" in classes:
        text = SCOPEDECL_RE.sub("", text)
    if "volatile" in classes:
        text = VOLATILE_RE.sub("", text)
    if "atomic" in classes:
        text = re.sub(r"\b(load|store)\s+atomic\b", r"\1", text)
        text = re.sub(r"\b(atomicrmw|cmpxchg)\b", r"\1_unsupported_kept", text)
    open(dst, "w").write(text)


if __name__ == "__main__":
    main()
