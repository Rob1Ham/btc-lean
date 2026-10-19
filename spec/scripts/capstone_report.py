#!/usr/bin/env python3
"""capstone_report.py — turn the capstone runner's stdout into the
public capstone report.

Input: the stdout of `lake exe capstone` (Test.Capstone.Run), either on
stdin or as the first argument, e.g.

    cd spec/core && lake exe capstone > /tmp/capstone.out
    python3 scripts/capstone_report.py /tmp/capstone.out > db/capstone.md

Line grammar (emitted by Run.lean):

    ANCHOR <height> replayOk=<b> accepted=<b> isPartial=<b> \
      reason=<r> txs=<n> scriptOk=<n> scriptUnjudged=<n> \
      scriptAdjudication=<complete|incomplete> foldAgrees=<b> ms=<n> hash=<hex>
    PROBE <height>: <per-tx probe text>        (failure forensics only)
    SUMMARY blocks=<n> missing=<n> allReplayOk=<b> allAccepted=<b> totalMs=<n>

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
    r"ANCHOR (\d+) replayOk=(\w+) accepted=(\w+) isPartial=(\w+) "
    r"reason=(\S+) txs=(\d+) scriptOk=(\d+) scriptUnjudged=(\d+) "
    r"scriptAdjudication=(complete|incomplete) foldAgrees=(\w+) ms=(\d+) hash=([0-9a-f]*)")
PROBE_RE = re.compile(r"PROBE (\d+): (.*)")
SUMMARY_RE = re.compile(
    r"SUMMARY blocks=(\d+) missing=(\d+) allReplayOk=(\w+) "
    r"allAccepted=(\w+) totalMs=(\d+)")


def parse(text: str):
    anchors, probes, summary = {}, {}, None
    for line in text.splitlines():
        m = ANCHOR_RE.match(line)
        if m:
            h = int(m.group(1))
            anchors[h] = dict(
                replayOk=m.group(2).lower() == "true",
                accepted=m.group(3).lower() == "true",
                isPartial=m.group(4).lower() == "true",
                reason=m.group(5), txs=int(m.group(6)),
                scriptOk=int(m.group(7)), scriptUnjudged=int(m.group(8)),
                scriptAdjudication=m.group(9),
                foldAgrees=m.group(10).lower() == "true", ms=int(m.group(11)),
                hash=m.group(12))
            continue
        m = PROBE_RE.match(line)
        if m:
            probes[int(m.group(1))] = m.group(2)
            continue
        m = SUMMARY_RE.match(line)
        if m:
            summary = dict(blocks=int(m.group(1)), missing=int(m.group(2)),
                           allReplayOk=m.group(3).lower() == "true",
                           allAccepted=m.group(4).lower() == "true",
                           totalMs=int(m.group(5)))
    return anchors, probes, summary


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "/dev/stdin"
    text = open(src).read()
    anchors, probes, summary = parse(text)
    if not anchors:
        print("capstone-report: no ANCHOR lines found in input", file=sys.stderr)
        return 1

    print("# Capstone replay: real mainnet anchor blocks")
    print()
    print("## Scope and method")
    print()
    print("This page records one offline replay of historical, serialized mainnet")
    print("blocks through the compiled Lean `replayBlockPartial` diagnostic adapter.")
    print("The input block data are the checksum-pinned anchor sets from the data")
    print("release (see `docs/DATA.md`). The replay does not contact a live network")
    print("and does not run or compare against `bitcoind`.")
    print()
    print("`replayBlockPartial` is a **diagnostic** adapter: it supplies the")
    print("serialized block, the release UTXO view, and the parent hash, but no")
    print("ancestor/clock context. It therefore reports `accepted=false` and")
    print("`isPartial=true` even when every available check agrees. `replayOk`")
    print("means the checks that could be run agreed; it is not an acceptance")
    print("claim. `scriptAdjudication=complete` with `scriptUnjudged=0` means the")
    print("runner produced a verdict for every input; otherwise the unjudged")
    print("inputs are reported and are not counted as validated.")
    print()
    replay_n = sum(1 for a in anchors.values() if a["replayOk"])
    accepted_n = sum(1 for a in anchors.values() if a["accepted"])
    hash_n = sum(1 for h, a in anchors.items()
                 if a["hash"] == CANONICAL.get(h))
    total_ms = sum(a["ms"] for a in anchors.values())
    print(f"**Blocks: {len(anchors)} — replayOk {replay_n}, accepted {accepted_n}, "
          f"hash==canonical {hash_n}** · script-unjudged total "
          f"{sum(a['scriptUnjudged'] for a in anchors.values())} · "
          f"fold cross-check "
          f"{'OK' if all(a['foldAgrees'] for a in anchors.values()) else 'MISMATCH'}"
          f" · sum of per-block ms {total_ms/1000:.1f}s (blocks run concurrently).")
    print()
    print("**Limits.** This is an offline model replay of a finite historical")
    print("block set. It is not live-network validation, peer synchronization,")
    print("chain-tip following, or a claim of `bitcoind` equivalence. A")
    print("`replayOk` record is a run record, not a kernel theorem.")
    print()
    print("## Results")
    print()
    header = ("| height | replayOk | accepted | isPartial | reason | txs | inputs adjudicated "
              "| script unjudged | adjudication | fold agrees | ms | hash==canonical |")
    rule = "|---|---|---|---|---|---|---|---|---|---|---|---|"

    def row(h: int) -> str:
        a = anchors[h]
        return (f"| {h} | {a['replayOk']} | {a['accepted']} | {a['isPartial']} "
                f"| {a['reason'] or '—'} | {a['txs']} | {a['scriptOk']} "
                f"| {a['scriptUnjudged']} | {a['scriptAdjudication']} "
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
    failed = (
        any(not a["replayOk"] or not a["foldAgrees"] or
            a["scriptUnjudged"] != 0 or
            a["scriptAdjudication"] != "complete" for a in anchors.values()) or
        any(a["accepted"] for a in anchors.values()))
    if (summary and (not summary["allReplayOk"] or summary["missing"] != 0 or
                     summary["blocks"] != len(anchors))):
        failed = True
    if failed:
        print()
        print("**capstone-report: RUN FAILED — see probes above.**")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
