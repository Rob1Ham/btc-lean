#!/usr/bin/env python3
"""Check the public reproducibility surface.

The test runners and generated Lean modules cite a small set of independent
reference implementations.  This check makes the dependency explicit: every
required script must be present, and tracked shell/Python files must not
contain absolute build paths.

It is intentionally limited to the reproducibility surface.  Data-integrity
checks and the Lean build remain separate.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "spec"

REQUIRED = [
    "spec/Test/Crypto/gen_ecdsa_vectors.py",
    "spec/Test/Crypto/gen_schnorr_vectors.py",
    "spec/Test/Crypto/gen_schnorr_random.py",
    "spec/Test/Crypto/taproot_sighash_crosscheck.py",
    "spec/Test/Crypto/taproot_verify_crosscheck.py",
    "spec/Test/Sighash/crosscheck.py",
    "spec/Test/Sighash/mirror.py",
    "spec/core/Test/Script/Parser/ref.py",
    "spec/proofs/BitcoinProofs/Conservation/reference.py",
    "spec/proofs/BitcoinProofs/EcdsaDeep/emit_cor.py",
    "spec/proofs/BitcoinProofs/EcdsaDeep/emit_crownlink.py",
    "spec/proofs/BitcoinProofs/EcdsaDeep/emit_crownschnorr.py",
    "spec/proofs/BitcoinProofs/EcdsaDeep/gen_der_battery.py",
    "spec/proofs/BitcoinProofs/EcdsaDeep/gen_pubkeycor_vecs.py",
    "spec/proofs/BitcoinProofs/SmallCurve/curve.py",
    "spec/proofs/BitcoinProofs/SmallCurve/probe_lits.py",
    "spec/proofs/BitcoinProofs/Bip/B14/budget_e2e.py",
    "spec/proofs/BitcoinProofs/Bip/B14/ref342_xcheck.py",
    "spec/proofs/BitcoinProofs/Property/Y11/powbits_reference.py",
    "spec/data/core/script_tests.json",
    "spec/data/core/sighash.json",
    "spec/data/bips/bip-0340_test-vectors.csv",
    "spec/data/bips/bip-0341_wallet-test-vectors.json",
]

# Catch the failure mode this check exists for: a test command or generator
# that points at a local checkout.  It is not a general content policy scanner.
FORBIDDEN = ("/home/",)

SCAN_SUFFIXES = {".py", ".sh"}


def main() -> int:
    missing = [rel for rel in REQUIRED if not (ROOT / rel).is_file()]
    leaks: list[str] = []
    scanned = 0
    self_path = Path(__file__).resolve()
    for path in SPEC.rglob("*"):
        if not path.is_file() or path.suffix not in SCAN_SUFFIXES:
            continue
        if path.resolve() == self_path:
            continue
        if any(part in {".git", ".lake", "build"} for part in path.parts):
            continue
        scanned += 1
        text = path.read_text(errors="replace")
        for marker in FORBIDDEN:
            if marker in text:
                leaks.append(f"{path.relative_to(ROOT)}: {marker}")

    if missing:
        print("missing reproducibility inputs:", file=sys.stderr)
        for rel in missing:
            print(f"  {rel}", file=sys.stderr)
    if leaks:
        print("absolute checkout paths in public scripts:", file=sys.stderr)
        for item in leaks:
            print(f"  {item}", file=sys.stderr)

    if missing or leaks:
        return 1
    print(f"reproducibility: {len(REQUIRED)} inputs present; "
          f"{scanned} shell/Python files clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
