#!/usr/bin/env python3
"""F-HARNESS-002 token-census audit.

Scans the pinned rbitcoin script layer for every literal that reaches
`ConsensusError::Script(...)`, then checks that the F-HARNESS-002 classifier
accounts for it: either an exact mapped token, an exact documented-unmapped
token, or one of the dynamic opcode patterns. Any token in neither table is a
hard error - the map must not silently ignore a new engine token.

This is an audit of the *string vocabulary*, not evidence that the strings
are stable across rbitcoin commits. That instability is the finding.

Usage:
  python3 tools/census.py [--rbtc DIR] [--witness build/witness]
"""
from __future__ import annotations

import argparse
import collections
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
PIN = "ae47aa98174e04d0d8c493f13041daf65e4ac1d3"

# Literal string argument of ConsensusError::Script("...") or
# ConsensusError::Script(format!("...")).
LITERAL = re.compile(
    r'ConsensusError::Script\(\s*(?:format!\(\s*)?"((?:[^"\\]|\\.)*)"',
    re.DOTALL,
)


def strip_annotation(s: str) -> str:
    return s.split(" txid=")[0]


def table(path: Path):
    out = subprocess.run(
        [str(path), "--dump-table"], capture_output=True, text=True, check=True
    ).stdout
    exact, unmapped, dynamic = {}, set(), []
    for line in out.splitlines():
        kind, token, ordinal = line.split("\t")
        if kind == "mapped":
            exact[token] = int(ordinal)
        elif kind == "unmapped":
            unmapped.add(token)
        elif kind == "dynamic":
            dynamic.append(token)
    return exact, unmapped, dynamic


def matches_dynamic(token: str, dynamic) -> bool:
    # `*` matches one opcode spelling (two hex digits in practice).
    import fnmatch

    return any(fnmatch.fnmatchcase(token, pat) for pat in dynamic)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rbtc", default="/tmp/opencode/equiv-work/rbitcoin-clean")
    ap.add_argument("--witness", default=str(HERE / "build" / "witness"))
    ap.add_argument("--out", default=str(HERE / "logs" / "token-census.tsv"))
    args = ap.parse_args()

    rbtc = Path(args.rbtc)
    head = subprocess.run(
        ["git", "-C", str(rbtc), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    if head != PIN:
        print(f"census: rbitcoin HEAD {head} != pin {PIN}", file=sys.stderr)
        return 2

    exact, unmapped, dynamic = table(Path(args.witness))
    src = rbtc / "crates" / "rbitcoin-consensus" / "src"
    seen = collections.Counter()
    where = collections.defaultdict(set)
    for path in sorted(src.rglob("*.rs")):
        text = path.read_text()
        for m in LITERAL.finditer(text):
            raw = m.group(1)
            # The annotation wrapper is not an engine token.
            if "txid=" in raw or raw.startswith("{msg}"):
                continue
            seen[raw] += 1
            where[raw].add(str(path.relative_to(rbtc)))

    rows = []
    unaccounted = []
    for token in sorted(seen):
        normalized = token.replace("{code:02x}", "*")
        base = strip_annotation(token)
        if base in exact:
            disposition = f"mapped:{exact[base]}"
        elif base in unmapped:
            disposition = "unmapped"
        elif matches_dynamic(normalized, dynamic):
            disposition = "dynamic"
        else:
            disposition = "UNACCOUNTED"
            unaccounted.append(token)
        rows.append((token, seen[token], disposition, ",".join(sorted(where[token]))))

    lines = ["token\tcount\tdisposition\tsource"]
    for token, count, disposition, source in rows:
        lines.append(f"{token}\t{count}\t{disposition}\t{source}")
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text("\n".join(lines) + "\n")

    by_disp = collections.Counter(r[2] for r in rows)
    for token, count, disposition, source in rows:
        print(f"{disposition:12s} {count:2d}  {token}")
    print()
    print(f"distinct source tokens: {len(rows)}")
    print(
        "  mapped: {mapped}  unmapped: {unmapped}  dynamic: {dynamic}".format(
            mapped=sum(1 for r in rows if r[2].startswith("mapped")),
            unmapped=by_disp["unmapped"],
            dynamic=by_disp["dynamic"],
        )
    )
    print(f"wrote {args.out}")
    if unaccounted:
        print(
            "CENSUS_UNACCOUNTED: " + ", ".join(unaccounted), file=sys.stderr
        )
        return 1
    print("CENSUS_ACCOUNTED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
