#!/usr/bin/env python3
"""Lint the wallet source trees for unfinished or compiler-trusting proofs.

Scope is exactly the two additive wallet trees:

  * ``spec/core/Bitcoin/Wallet/**/*.lean``
  * ``spec/proofs/BitcoinProofs/Wallet/**/*.lean``
  * the two wallet umbrella roots when present (``Wallet.lean``)

``sorry`` and ``admit`` are rejected everywhere in those trees.
``native_decide`` is rejected except in files below a ``Test/Wallet``
directory, where test-only evaluation is permitted. The scan is
comment-aware, so prose in a docstring does not trigger a finding.

This gate deliberately does not inspect consensus sources; the existing
``sorry_lint.py`` covers those. It also does not prove that a wallet
declaration is true, only that it contains no unfinished proof term and no
compiler-trusting decision procedure.

Usage:
    python3 spec/scripts/wallet_sorry_lint.py

Exit status is 1 when any finding is reported, 0 otherwise.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
WALLET_TREES = (
    REPO / "spec" / "core" / "Bitcoin" / "Wallet",
    REPO / "spec" / "proofs" / "BitcoinProofs" / "Wallet",
)
WALLET_UMBRELLAS = (
    REPO / "spec" / "core" / "Bitcoin" / "Wallet.lean",
    REPO / "spec" / "proofs" / "BitcoinProofs" / "Wallet.lean",
)

SORRY_RE = re.compile(r"\bsorry\b")
ADMIT_RE = re.compile(r"\badmit\b")
NATIVE_RE = re.compile(r"\bnative_decide\b")
TEST_WALLET_RE = re.compile(r"(^|/)Test/Wallet(/|$)")


def strip_comments(line: str, in_block: bool) -> tuple[str, bool]:
    """Return the code part of *line* and the block-comment state after it."""
    out: list[str] = []
    i = 0
    while i < len(line):
        if in_block:
            j = line.find("-/", i)
            if j == -1:
                return "", True
            in_block = False
            i = j + 2
            continue
        if line.startswith("--", i):
            break
        if line.startswith("/-", i):
            in_block = True
            i += 2
            continue
        out.append(line[i])
        i += 1
    return "".join(out), in_block


def wallet_files() -> list[Path]:
    """Every Lean file in the wallet trees, de-duplicated and sorted."""
    files: set[Path] = set()
    for tree in WALLET_TREES:
        if tree.is_dir():
            files.update(p for p in tree.rglob("*.lean") if ".lake" not in p.parts)
    for umbrella in WALLET_UMBRELLAS:
        if umbrella.is_file():
            files.add(umbrella)
    return sorted(files)


def main() -> int:
    files = wallet_files()
    findings: list[str] = []
    n_sorry = n_admit = n_native = 0

    for path in files:
        rel = path.relative_to(REPO)
        is_test = bool(TEST_WALLET_RE.search(rel.as_posix()))
        in_block = False
        for lineno, raw in enumerate(path.read_text().splitlines(), 1):
            code, in_block = strip_comments(raw, in_block)
            if SORRY_RE.search(code):
                n_sorry += 1
                findings.append(f"{rel}:{lineno}: sorry: {raw.strip()}")
            if ADMIT_RE.search(code):
                n_admit += 1
                findings.append(f"{rel}:{lineno}: admit: {raw.strip()}")
            if NATIVE_RE.search(code) and not is_test:
                n_native += 1
                findings.append(
                    f"{rel}:{lineno}: native_decide outside Test/Wallet: {raw.strip()}"
                )

    for finding in findings:
        print(f"wallet-sorry: FAIL {finding}", file=sys.stderr)

    print(
        f"wallet-sorry: {len(files)} files scanned; "
        f"sorry={n_sorry}, admit={n_admit}, "
        f"native_decide outside Test/Wallet={n_native}"
    )
    if findings:
        print(f"wallet-sorry: FAIL ({len(findings)} finding(s))", file=sys.stderr)
        return 1
    print("wallet-sorry: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
