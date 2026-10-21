#!/usr/bin/env python3
"""Regenerate the corpus inventory hashes/counts. Read-only."""
import hashlib
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))

FILES = [
    "spec/data/core/script_tests.json",
    "spec/data/core/tx_valid.json",
    "spec/data/core/tx_invalid.json",
    "spec/data/core/sighash.json",
]


def case_like(entry):
    if not isinstance(entry, list) or len(entry) < 3:
        return False
    if len(entry) == 1 and isinstance(entry[0], str):
        return False
    return True


def main():
    for rel in FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print(f"{rel}|MISSING")
            continue
        raw = open(path, "rb").read()
        try:
            data = json.loads(raw)
            total = len(data)
            cases = sum(1 for e in data if case_like(e))
        except Exception as exc:  # noqa: BLE001
            total = cases = f"parse-error:{exc}"
        print(f"{rel}|{len(raw)}|{hashlib.sha256(raw).hexdigest()}|{total}|{cases}")

    for rel in (
        "spec/data/l2/scr/cases/seam.l2c",
        "spec/data/l2/scr/results/tierC.l2r",
        "spec/data/l2/scr/results/tierG.l2r",
        "spec/data/l2/scr/results/seam.l2r",
    ):
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print(f"{rel}|MISSING")
            continue
        raw = open(path, "rb").read()
        lines = sum(1 for _ in open(path, encoding="utf-8", errors="replace"))
        print(f"{rel}|{len(raw)}|{hashlib.sha256(raw).hexdigest()}|lines={lines}")


if __name__ == "__main__":
    main()
