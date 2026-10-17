#!/usr/bin/env python3
"""Cross-check the wallet traceability tags against the wallet census.

Invariants:

  1. every ``@[walletRule "ID"]`` in the wallet source trees names a row in
     ``spec/db/rules-wallet.yaml`` (no orphan tags);
  2. every wallet row whose ``lean_target`` is non-empty appears as a tag;
  3. a wallet tag ID is reported at most once (duplicate tag detector);
  4. no wallet tag or wallet row ID collides with an ID in the consensus
     database ``spec/db/rules.yaml``;
  5. no lowercase consensus attribute appears in wallet sources. The
     consensus scanner reads raw text and is case-sensitive
     (``spec/scripts/rule_crosscheck.py:22``), so a lowercase tag in a
     wallet file would be reported as a consensus orphan.

A declaration may carry several tags, e.g.
``@[walletRule "MS-001", walletRule "MS-002"]``; every tag in one attribute
block is collected. Tags are read from code, not prose: Lean comments are
stripped first so a docstring example is not counted as a real tag.

This gate checks traceability only. It does not check that a tagged
declaration proves the row, that the row statement is true, or that the
tagged declaration is in the wallet namespace.

Usage:
    python3 spec/scripts/wallet_crosscheck.py

Exit status is 1 on any violation, 0 otherwise.
"""
from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent.parent
WALLET_DB = REPO / "spec" / "db" / "rules-wallet.yaml"
CONSENSUS_DB = REPO / "spec" / "db" / "rules.yaml"
WALLET_TREES = (
    REPO / "spec" / "core" / "Bitcoin" / "Wallet",
    REPO / "spec" / "proofs" / "BitcoinProofs" / "Wallet",
)
WALLET_UMBRELLAS = (
    REPO / "spec" / "core" / "Bitcoin" / "Wallet.lean",
    REPO / "spec" / "proofs" / "BitcoinProofs" / "Wallet.lean",
)

# One @[ ... ] attribute block; the body may contain several walletRule tags.
ATTR_BLOCK_RE = re.compile(r"@\[([^\]]*)\]", re.S)
TAG_RE = re.compile(r'\bwalletRule\s+"([A-Za-z0-9]+-\d+)"')
# The consensus attribute matched case-sensitively, exactly as the consensus
# gate does. A capital walletRule does not match because "R" is not "r".
LOWERCASE_RULE_RE = re.compile(r'\brule\s+"([A-Za-z]{2,4}-\d{1,4})"')


def strip_comments(text: str) -> str:
    """Remove Lean line and block comments while preserving line count."""
    out: list[str] = []
    in_block = False
    for line in text.splitlines():
        kept: list[str] = []
        i = 0
        while i < len(line):
            if in_block:
                j = line.find("-/", i)
                if j == -1:
                    i = len(line)
                    break
                in_block = False
                i = j + 2
                continue
            if line.startswith("--", i):
                break
            if line.startswith("/-", i):
                in_block = True
                i += 2
                continue
            kept.append(line[i])
            i += 1
        out.append("".join(kept))
    return "\n".join(out)


def wallet_files() -> list[Path]:
    """Every Lean file in the wallet trees plus the wallet umbrella roots."""
    files: set[Path] = set()
    for tree in WALLET_TREES:
        if tree.is_dir():
            files.update(p for p in tree.rglob("*.lean") if ".lake" not in p.parts)
    for umbrella in WALLET_UMBRELLAS:
        if umbrella.is_file():
            files.add(umbrella)
    return sorted(files)


def load_rows(path: Path) -> dict[str, dict]:
    """Load a census and return its rows keyed by id, preserving order."""
    data = yaml.safe_load(path.read_text())
    rows = data.get("rules") if isinstance(data, dict) else None
    if not isinstance(rows, list):
        raise ValueError(f"{path}: top-level `rules:` list missing")
    return {
        row["id"]: row
        for row in rows
        if isinstance(row, dict) and isinstance(row.get("id"), str)
    }


def main() -> int:
    try:
        wallet_rows = load_rows(WALLET_DB)
        consensus_rows = load_rows(CONSENSUS_DB)
    except Exception as exc:  # noqa: BLE001 - report YAML errors verbatim
        print(f"wallet-crosscheck: FAIL {exc}", file=sys.stderr)
        return 1

    tag_sites: dict[str, list[str]] = {}
    lowercase_sites: list[str] = []

    for path in wallet_files():
        rel = path.relative_to(REPO).as_posix()
        raw = path.read_text()
        code = strip_comments(raw)
        for block in ATTR_BLOCK_RE.finditer(code):
            for match in TAG_RE.finditer(block.group(1)):
                tag_sites.setdefault(match.group(1), []).append(rel)
        for match in LOWERCASE_RULE_RE.finditer(raw):
            lowercase_sites.append(f"{rel}: {match.group(0)}")

    fail = 0

    # 1 + 3. orphan and duplicate tags
    for tag, sites in sorted(tag_sites.items()):
        if tag not in wallet_rows:
            print(
                f"ORPHAN WALLET TAG: @[walletRule \"{tag}\"] in "
                f"{sorted(set(sites))} - no rules-wallet.yaml row",
                file=sys.stderr,
            )
            fail = 1
        if len(sites) > 1:
            print(
                f"DUPLICATE WALLET TAG: \"{tag}\" tagged {len(sites)} times in "
                f"{sites}",
                file=sys.stderr,
            )
            fail = 1

    # 2. rows with a target must be tagged
    missing_tags = sorted(
        row_id
        for row_id, row in wallet_rows.items()
        if row.get("lean_target") not in (None, "", "null")
        and row_id not in tag_sites
    )
    if missing_tags:
        print(
            "WALLET ROWS WITH lean_target BUT NO @[walletRule] TAG: "
            f"{missing_tags}",
            file=sys.stderr,
        )
        fail = 1

    # 4. ID collision with the consensus census (tags and rows)
    for tag in sorted(set(tag_sites) & set(consensus_rows)):
        print(
            f"ID COLLISION: wallet tag \"{tag}\" also names a rules.yaml row",
            file=sys.stderr,
        )
        fail = 1
    for row_id in sorted(set(wallet_rows) & set(consensus_rows)):
        print(
            f"ID COLLISION: wallet row \"{row_id}\" also names a rules.yaml row",
            file=sys.stderr,
        )
        fail = 1

    # 5. lowercase consensus spelling in wallet sources
    for site in lowercase_sites:
        print(
            f"LOWERCASE CONSENSUS TAG IN WALLET SOURCE: {site} - "
            "the consensus scanner would treat this as a rules.yaml tag",
            file=sys.stderr,
        )
        fail = 1

    # Coverage report, useful when rows start acquiring lean_targets.
    namespaces = Counter(row_id.split("-", 1)[0] for row_id in wallet_rows)
    tagged_by_ns = Counter(tag.split("-", 1)[0] for tag in tag_sites)
    print(
        f"wallet-crosscheck: {len(wallet_rows)} wallet rows, "
        f"{len(consensus_rows)} consensus rows, "
        f"{sum(len(v) for v in tag_sites.values())} wallet tags "
        f"({len(tag_sites)} ids) across {len(wallet_files())} files"
    )
    for ns in sorted(namespaces):
        print(
            f"  {ns}: {namespaces[ns]} rows | tagged {tagged_by_ns.get(ns, 0)}"
        )
    targeted = sum(
        1 for row in wallet_rows.values()
        if row.get("lean_target") not in (None, "", "null")
    )
    print(f"  rows with lean_target: {targeted}")

    if fail:
        print("wallet-crosscheck: FAIL", file=sys.stderr)
        return 1
    print("wallet-crosscheck: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
