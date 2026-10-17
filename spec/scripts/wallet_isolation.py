#!/usr/bin/env python3
"""Prove that the additive wallet tree has not leaked into consensus.

Three isolation invariants:

  1. the consensus census is still exactly 726 rows: 676 proven, 50
     obsolete, 0 implemented, 0 planned. The existing gate is invoked as a
     subprocess, so this check reuses its parser and constants instead of
     duplicating them;
  2. the two consensus umbrella roots (``Bitcoin.lean`` and
     ``BitcoinProofs.lean``) import no wallet module;
  3. no Lean source outside the wallet trees mentions ``Bitcoin.Wallet`` or
     the ``walletRule`` attribute. The scan covers the published core and
     proofs source trees; a wallet consumer placed there would make the
     consensus build depend on wallet material.

Nothing in this gate compiles Lean. It asserts dependency direction from
the source text and from the existing census gate, not from a fresh build.

Usage:
    python3 spec/scripts/wallet_isolation.py

Exit status is 1 on any violation, 0 otherwise.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
GATE_CENSUS = REPO / "spec" / "scripts" / "gate_census.py"
ROOTS = (
    REPO / "spec" / "core" / "Bitcoin.lean",
    REPO / "spec" / "proofs" / "BitcoinProofs.lean",
)
SOURCE_TREES = (
    REPO / "spec" / "core",
    REPO / "spec" / "proofs",
)

EXPECTED_ROWS = 726
EXPECTED_STATUS = {"proven": 676, "obsolete": 50, "implemented": 0, "planned": 0}
WALLET_IMPORT_RE = re.compile(
    r"^\s*import\s+(Bitcoin\.Wallet(?:\.[A-Za-z0-9_.]+)?|"
    r"BitcoinProofs\.Wallet(?:\.[A-Za-z0-9_.]+)?)\s*$"
)


def is_wallet_path(path: Path) -> bool:
    """A path belongs to wallet code iff it has a Wallet/ directory or a
    Wallet.lean umbrella root."""
    rel = path.relative_to(REPO)
    return "Wallet" in rel.parts or path.stem == "Wallet"


def check_census() -> int:
    """Invoke gate_census.py and require its exact published contract."""
    proc = subprocess.run(
        [sys.executable, str(GATE_CENSUS)],
        cwd=str(REPO),
        text=True,
        capture_output=True,
    )
    output = proc.stdout + proc.stderr
    print("wallet-isolation: gate_census output:")
    for line in output.splitlines():
        print(f"  {line}")

    if proc.returncode != 0:
        print(
            "wallet-isolation: FAIL consensus census gate returned "
            f"{proc.returncode}",
            file=sys.stderr,
        )
        return 1

    row_match = re.search(r"(\d+)\s+rows,\s+(\d+)\s+unique ids", output)
    status_matches = {
        key: re.search(rf"\b{key}=(\d+)", output) for key in EXPECTED_STATUS
    }
    problems: list[str] = []
    if row_match is None:
        problems.append("could not read row count from gate_census output")
    elif int(row_match.group(1)) != EXPECTED_ROWS:
        problems.append(
            f"consensus rows={row_match.group(1)}, expected {EXPECTED_ROWS}"
        )
    for key, expected in EXPECTED_STATUS.items():
        match = status_matches[key]
        if match is None:
            problems.append(f"could not read {key} count from gate_census output")
        elif int(match.group(1)) != expected:
            problems.append(
                f"consensus {key}={match.group(1)}, expected {expected}"
            )
    if problems:
        for problem in problems:
            print(f"wallet-isolation: FAIL {problem}", file=sys.stderr)
        return 1
    print(
        "wallet-isolation: consensus census unchanged "
        f"({EXPECTED_ROWS} rows; 676 proven / 50 obsolete / "
        "0 implemented / 0 planned)"
    )
    return 0


def check_umbrellas() -> int:
    """Require both consensus umbrella roots to exist and import no wallet."""
    fail = 0
    for root in ROOTS:
        rel = root.relative_to(REPO)
        if not root.is_file():
            print(f"wallet-isolation: FAIL missing umbrella root {rel}",
                  file=sys.stderr)
            fail = 1
            continue
        wallet_lines = [
            f"{rel}:{lineno}: {line.strip()}"
            for lineno, line in enumerate(root.read_text().splitlines(), 1)
            if WALLET_IMPORT_RE.match(line)
        ]
        if wallet_lines:
            for hit in wallet_lines:
                print(f"wallet-isolation: FAIL wallet import in umbrella: {hit}",
                      file=sys.stderr)
            fail = 1
        else:
            print(f"wallet-isolation: {rel}: no wallet import")
    return fail


def check_non_wallet_sources() -> int:
    """Reject wallet namespace or attribute references outside Wallet/."""
    fail = 0
    scanned = 0
    for tree in SOURCE_TREES:
        if not tree.is_dir():
            continue
        for path in sorted(tree.rglob("*.lean")):
            if ".lake" in path.parts or is_wallet_path(path):
                continue
            scanned += 1
            rel = path.relative_to(REPO)
            for lineno, line in enumerate(path.read_text().splitlines(), 1):
                if "Bitcoin.Wallet" in line or "walletRule" in line:
                    print(
                        f"wallet-isolation: FAIL non-wallet source mentions "
                        f"wallet material: {rel}:{lineno}: {line.strip()}",
                        file=sys.stderr,
                    )
                    fail = 1
    print(
        f"wallet-isolation: {scanned} non-wallet Lean sources scanned for "
        "'Bitcoin.Wallet'/'walletRule'"
    )
    return fail


def main() -> int:
    fail = check_census()
    fail |= check_umbrellas()
    fail |= check_non_wallet_sources()
    if fail:
        print("wallet-isolation: FAIL", file=sys.stderr)
        return 1
    print("wallet-isolation: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
