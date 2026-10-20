#!/usr/bin/env python3
"""Expand `llvm.abs` / min-max intrinsics into plain IR (Alive2 v20 fix).

    expand_abs.py FILE.ll [...]

Alive2 v20 does not model `llvm.abs.iN`: two semantically identical modules
that both contain it are reported as "1 incorrect transformations", and
modules that differ only in how the intrinsic was formed can time out.  The
same is true for `llvm.{smin,smax,umin,umax}` when they survive the pipeline.
The expansions below are the intrinsics' own definitions:

    abs(x)        -> %neg = icmp slt x, 0
                     %n   = sub nsw 0, x        ; poison when x == INT_MIN
                     %r   = select %neg, %n, x
    smin(a,b)     -> %c = icmp slt a, b ; select %c, a, b
    smax(a,b)     -> %c = icmp sgt a, b ; select %c, a, b
    umin(a,b)     -> %c = icmp ult a, b ; select %c, a, b
    umax(a,b)     -> %c = icmp ugt a, b ; select %c, a, b

`sub nsw` overflows exactly for INT_MIN, so the poison behaviour of
`llvm.abs(x, /*is_int_min_poison=*/true)` is preserved.  This is a
tool-ingestion normalisation applied identically to both legs; it does not
weaken the compared functions.
"""
import re
import sys

BIN = {
    "smin": "slt",
    "smax": "sgt",
    "umin": "ult",
    "umax": "ugt",
}
TY = r"i\d+"
# The callee may carry parameter attributes between `call` and the return type
# (`noundef`, `range(i32 0, 16)`, `immarg`, ...); the pattern stops at the
# first `@` so those are skipped.  Operands may be SSA values or constants.
CALL_ABS = re.compile(
    r"^(?P<indent>\s*)(?P<lhs>%[\w.$-]+) = (?:tail )?call [^@]*"
    r"@llvm\.abs\.(?P<ty>i\d+)\((?P=ty) (?P<x>[%\w.$-]+), i1 (?:true|false)\)\s*$"
)
CALL_BIN = re.compile(
    r"^(?P<indent>\s*)(?P<lhs>%[\w.$-]+) = (?:tail )?call [^@]*"
    r"@llvm\.(?P<op>smin|smax|umin|umax)\.(?P<ty>i\d+)"
    r"\((?P=ty) (?P<a>[%\w.$-]+), (?P=ty) (?P<b>[%\w.$-]+)\)\s*$"
)
DECL = re.compile(
    r"^declare i\d+ @llvm\.(abs\.i\d+\(i\d+, i1 immarg\)|"
    r"(?:smin|smax|umin|umax)\.i\d+\(i\d+, i\d+\))"
)


def expand(path: str) -> int:
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    out: list[str] = []
    n = 0
    for line in lines:
        m = CALL_ABS.match(line)
        if m:
            n += 1
            ind, lhs, ty, x = m["indent"], m["lhs"], m["ty"], m["x"]
            tag = f".absexp{n}"
            out.append(f"{ind}{lhs}{tag}.neg = icmp slt {ty} {x}, 0\n")
            out.append(f"{ind}{lhs}{tag}.val = sub nsw {ty} 0, {x}\n")
            out.append(
                f"{ind}{lhs} = select i1 {lhs}{tag}.neg, {ty} {lhs}{tag}.val, "
                f"{ty} {x}\n"
            )
            continue
        m = CALL_BIN.match(line)
        if m:
            n += 1
            ind, lhs, ty = m["indent"], m["lhs"], m["ty"]
            a, b = m["a"], m["b"]
            tag = f".mmexp{n}"
            out.append(f"{ind}{lhs}{tag}.cmp = icmp {BIN[m['op']]} {ty} {a}, {b}\n")
            out.append(
                f"{ind}{lhs} = select i1 {lhs}{tag}.cmp, {ty} {a}, {ty} {b}\n"
            )
            continue
        if DECL.match(line):
            continue
        out.append(line)
    text = "".join(out)
    if "llvm.abs" in text or re.search(r"llvm\.(smin|smax|umin|umax)", text):
        raise SystemExit(f"{path}: min/max intrinsic survived expansion")
    with open(path, "w", encoding="utf-8") as fh:
        fh.writelines(out)
    return n


if __name__ == "__main__":
    total = sum(expand(p) for p in sys.argv[1:])
    print(f"expand_abs: expanded {total} intrinsic call(s)", file=sys.stderr)
