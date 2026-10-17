#!/usr/bin/env python3
"""capstone_report.py — turn the capstone runner's stdout into the
public capstone report.

Input: the stdout of `lake exe capstone` (Test.Capstone.Run), either on
stdin or as the first argument, e.g.

    cd spec/core && lake exe capstone > /tmp/capstone.out
    python3 scripts/capstone_report.py /tmp/capstone.out > db/capstone.md

Line grammar (emitted by Run.lean):

    ANCHOR <height> ok=<b> reason=<r> txs=<n> scriptOk=<n> \
      scriptUnjudged=<n> foldAgrees=<b> ms=<n> hash=<hex>
    PROBE <height>: <per-tx probe text>        (failure forensics only)
    SUMMARY blocks=<n> allOk=<b> totalMs=<n>

The script cross-checks each reported block hash against the pinned
canonical mainnet hash (independent of the runner: these constants were
taken from public block explorers at fetch time and verified by
scripts/fetch_anchors.sh via header double-SHA256), and emits the
per-block table used by the `spec/db/capstone.md` replay record.
"""
from __future__ import annotations
import re
import sys

# Canonical mainnet block hashes (display order) — pinned, verified by
# fetch_anchors.sh (header double-SHA256) and cross-checked here so a
# runner-side hash-computation bug cannot pass silently.
CANONICAL = {
    0: "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
    74638: "000000000069e1affe7161ab4bcbeacebb4ddf155b50e807f42de971b688a09b",
    91842: "00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec",
    91880: "00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721",
    481824: "0000000000000000001c8018d9cb3b742ef25114f27563e3fc4a1902167f9893",
    709632: "0000000000000000000687bca986194dc2c1f949318629b44bb54ec0a94d8244",
    # Extended anchor set — verified by fetch_anchors2.sh header double-SHA256
    # and independently re-checked against spec/vectors/anchors2/<H>.raw.
    170: "00000000d1145790a8694403d4063f323d499e655c83426834d4ce2f8dd4a2ee",
    170060: "00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22",
    170061: "0000000000000abd377cb70a3131adefe82fbefb9f3adfc0ea1a4252be3896de",
    481827: "000000000000000000509863d58a52dbe2ec811d91619f164dab3fe9177874b4",
    481828: "000000000000000000bc331eb461d522cb3673b3881217dc30c6a5cf91710f23",
    499195: "0000000000000000000c239e79582620a8f586387a3e6990eba9d7f2328315bc",
    709635: "00000000000000000001f9ee4f69cbc75ce61db5178175c2ad021fe1df5bad8f",
}

# Corpus membership (Run.lean `anchors` / `anchors2`) for per-corpus sections.
SET1 = {0, 74638, 91842, 91880, 481824, 709632}

ANCHOR_RE = re.compile(
    r"ANCHOR (\d+) ok=(\w+) reason=(\S*) txs=(\d+) scriptOk=(\d+) "
    r"scriptUnjudged=(\d+) foldAgrees=(\w+) ms=(\d+) hash=([0-9a-f]*)")
PROBE_RE = re.compile(r"PROBE (\d+): (.*)")
SUMMARY_RE = re.compile(r"SUMMARY blocks=(\d+) allOk=(\w+) totalMs=(\d+)")


def parse(text: str):
    anchors, probes, summary = {}, {}, None
    for line in text.splitlines():
        m = ANCHOR_RE.match(line)
        if m:
            h = int(m.group(1))
            anchors[h] = dict(
                ok=m.group(2).lower() == "true", reason=m.group(3), txs=int(m.group(4)),
                scriptOk=int(m.group(5)), scriptUnjudged=int(m.group(6)),
                foldAgrees=m.group(7).lower() == "true", ms=int(m.group(8)),
                hash=m.group(9))
            continue
        m = PROBE_RE.match(line)
        if m:
            probes[int(m.group(1))] = m.group(2)
            continue
        m = SUMMARY_RE.match(line)
        if m:
            summary = dict(blocks=int(m.group(1)), allOk=m.group(2).lower() == "true",
                           totalMs=int(m.group(3)))
    return anchors, probes, summary


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "/dev/stdin"
    text = open(src).read()
    anchors, probes, summary = parse(text)
    if not anchors:
        print("capstone-report: no ANCHOR lines found in input", file=sys.stderr)
        return 1

    print("## Capstone run: real mainnet anchor blocks "
          f"({len(anchors)} across both corpora)")
    print()
    print("End-to-end `validateBlock` (decode → block structure → PoW and")
    print("chain link → merkle/witness commitment → per-tx input and script")
    print("checks with ECDSA → ledger fold keyed by txid), compiled Lean runner.")
    print()
    ok_n = sum(1 for a in anchors.values() if a["ok"])
    hash_n = sum(1 for h, a in anchors.items()
                 if a["hash"] == CANONICAL.get(h))
    print(f"**Blocks: {len(anchors)} — validated {ok_n}, "
          f"hash==canonical {hash_n}** · fold cross-check "
          f"{'OK' if all(a['foldAgrees'] for a in anchors.values()) else 'MISMATCH'}"
          f" · wall-clock {(summary or {}).get('totalMs', 0)/1000:.1f}s")
    print()
    header = ("| height | verdict | reason | txs | inputs adjudicated "
              "| taproot unjudged | fold agrees | ms | hash==canonical |")
    rule = "|---|---|---|---|---|---|---|---|---|"

    def row(h: int) -> str:
        a = anchors[h]
        return (f"| {h} | {'PASS' if a['ok'] else 'FAIL'} | {a['reason'] or '—'} "
                f"| {a['txs']} | {a['scriptOk']} | {a['scriptUnjudged']} "
                f"| {a['foldAgrees']} | {a['ms']} "
                f"| {a['hash'] == CANONICAL.get(h)} |")

    set1 = [h for h in sorted(anchors) if h in SET1]
    set2 = [h for h in sorted(anchors) if h not in SET1]
    if set1 and set2:  # combined run: per-corpus sections
        print("### Corpus 1 — historical anchor blocks")
        print()
        print(header); print(rule)
        for h in set1: print(row(h))
        print()
        print("### Corpus 2 — extended anchor blocks")
        print()
        print(header); print(rule)
        for h in set2: print(row(h))
    else:
        print(header); print(rule)
        for h in sorted(anchors): print(row(h))
    if probes:
        print()
        print("### Failure probes")
        print()
        for h in sorted(probes):
            print(f"- **{h}**: {probes[h]}")
    if summary and not summary["allOk"]:
        print()
        print("**capstone-report: RUN FAILED — see probes above.**")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
