#!/usr/bin/env python3
"""Fail unless every rule row is anchored at the single pinned Core commit.

The DB contract is one pin: Bitcoin Core v32.99 at `cce32b168`. The short
form `cce32b168` names the same commit; `cce32b168` is a later commit that
differs from the pin only in non-consensus `src/policy/packages.cpp`. Either
way, every `core_ref` must carry the canonical `@cce32b168` suffix.

Static gate: no Bitcoin Core checkout is required.
"""
import re
import sys

import yaml

PIN = "cce32b168"
TAG = re.compile(r"@([0-9a-f]{7,40})\b")


def main(path: str = "spec/db/rules.yaml") -> int:
    rows = yaml.safe_load(open(path))["rules"]
    bad = []
    for r in rows:
        ref = (r.get("core_ref") or "").strip()
        if not ref:
            bad.append((r["id"], "empty core_ref"))
            continue
        tags = TAG.findall(ref)
        if not tags or any(t != PIN for t in tags):
            bad.append((r["id"], f"tags={tags or 'none'}"))
    if bad:
        print(f"anchor-pin-check: FAIL ({len(bad)}/{len(rows)} rows off-pin)")
        for rid, why in bad[:40]:
            print(f"  {rid}: {why}")
        if len(bad) > 40:
            print(f"  ... and {len(bad) - 40} more")
        return 1
    print(f"anchor-pin-check: OK ({len(rows)} rows @ {PIN})")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
