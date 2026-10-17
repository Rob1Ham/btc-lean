#!/usr/bin/env python3
"""backfill_overrides.py — (re)generate rules_overrides_sync.py.

Contributor OVRBACK, 2026-10-17 (GATES F-G4-01/F-G4-02; the 04:35 rules.yaml
clobber). See the REGEN SAFETY contract in extract_rules.py's docstring.

What happened at 04:35: an in-repo regen ran with report tables + the
hand OVERRIDES table as the only inputs. But the committed rules.yaml had
accumulated 475+ rows of hand curation that neither input carried
(status/lean_target/notes drift, 54 implemented_by, 26+11 non-empty
test_vector_ids, 124 hand lean_note, ...), and 11 hand-added rows
(SGN-101..111, no report source) existed nowhere but the yaml. The regen
therefore rewrote 477+ rows (census at OVRBACK time: 478)
(to stale values) and dropped 11 rows outright,
while their @[rule] attributes stayed in the tree.

This script closes the loop the other way: it takes the committed
rules.yaml as the curation record (the truth — this is what the
promotion lanes maintain as block-local flips), computes the per-row
delta against the PRE-OVRBACK generator state

    BASE row  =  report row (parse_source) | HAND_ROWS literal
                 + hand OVERRIDES (build_base_row, NO sync layer)

and writes that delta as spec/scripts/rules_overrides_sync.py:
OVERRIDES_SYNC[id] = {field: yaml_value} for EVERY field where the yaml
row differs from the BASE row. Merge precedence in the generator
(build_row): sync WINS over the hand table. With the sync layer in
place, a regen is a fixed point: `extract_rules.py --check` exits 0.

CURATION FLOW (post-OVRBACK):
    1. edit the rules.yaml row (the supported path);
    2. re-run this script (python3 spec/scripts/backfill_overrides.py);
    3. verify with spec/scripts/extract_rules.py --check (exit 0).

CI mode: `python3 spec/scripts/backfill_overrides.py --check` builds the
same generated text in memory and diffs it against the committed sync
layer WITHOUT writing. Exit 0 = mirror is fresh, exit 1 = drift (run the
script without --check to regenerate). This is gate 6 of `make gates`.
A regen that is NOT a fixed point is the 04:35 clobber; extract_rules.py
refuses to run without the sync layer unless --force.

Safety properties of THIS script:
  * writes ONE file: spec/scripts/rules_overrides_sync.py. It never
    touches rules.yaml or anything else.
  * NO-BASE check (loud, exit 1): yaml rows with neither a report row
    nor a HAND_ROWS entry are rows a regen would silently DROP — the
    SGN-101..111 failure class. They cannot be mirrored into the sync
    layer (there is no source row to overlay); they need a report table
    or a HAND_ROWS entry. Nothing is dropped silently, ever.
  * no-yaml check (loud, exit 1): report/HAND rows missing from the yaml
    are rows a regen would silently ADD back.
  * stale-hand conflict report: hand OVERRIDES entries whose
    status/lean_target/notes disagree with the yaml (the hand table is
    historical/advisory since OVRBACK; the sync layer shadows them).
    Expected at generation time: INV-003/INV-040/SCR-145/TXV-003/
    TXV-041/TXV-042 (X09-era promotions) — hand table was never updated.
  * fixed-point proof at generation time: for every row it re-applies
    the delta to the BASE row and asserts the result equals the yaml row
    dict exactly (so a regen of the mirrored state is the identity).
  * deterministic: no timestamps; the source yaml sha256 is recorded in
    the generated header (an out-of-date sync layer is detectable).
"""

from __future__ import annotations
import hashlib
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # .../btc-lean/spec/scripts
sys.path.insert(0, str(HERE))

import extract_rules as er                      # noqa: E402  (module import:
# NO regen runs here; extract_rules.py is only ever read)

SYNC_OUT = HERE / "rules_overrides_sync.py"
CURATION_FIELDS = ("status", "lean_target", "notes", "implemented_by",
                   "test_vector_ids")


def main() -> int:
    import yaml

    check_only = "--check" in sys.argv[1:]
    unknown = [a for a in sys.argv[1:] if a not in ("--check",)]
    if unknown:
        print(f"usage: {Path(sys.argv[0]).name} [--check]", file=sys.stderr)
        return 2

    # ---- inputs ---------------------------------------------------------
    # The yaml as currently committed/worktree = the curation record.
    ytext = er.OUT.read_text()
    ysha = hashlib.sha256(ytext.encode()).hexdigest()
    yrows = yaml.safe_load(ytext)["rules"]

    # ---- BASE rows (the pre-OVRBACK generator state) ---------------------
    report_rows: list[dict] = []
    for src in er.SOURCES:
        report_rows.extend(er.parse_source(src))
    base_rows: list[dict] = [er.build_base_row(r) for r in report_rows]
    base_rows += [er.build_base_row(r) for r in er.HAND_ROWS]
    base_map = {r["id"]: r for r in base_rows}

    # ---- no-base / no-yaml checks (the loud drop/add detectors) ---------
    yids = [r["id"] for r in yrows]
    no_base = [i for i in yids if i not in base_map]
    no_yaml = [i for i in base_map if i not in {r["id"] for r in yrows}]
    rc = 0
    if no_base:
        rc = 1
        print("FATAL: yaml rows with NO source (a regen would DROP them; give\n"
              "       them a report table row or a HAND_ROWS entry — they can\n"
              "       NOT ride the sync layer):", file=sys.stderr)
        for i in no_base:
            print(f"  {i}", file=sys.stderr)
    if no_yaml:
        rc = 1
        print("FATAL: report/HAND rows missing from the yaml (a regen would\n"
              "       ADD them back):", file=sys.stderr)
        for i in no_yaml:
            print(f"  {i}", file=sys.stderr)

    # ---- the delta = the sync layer --------------------------------------
    sync: dict[str, dict] = {}
    field_census: dict[str, int] = {}
    conflict_fields = ("status", "lean_target", "notes")
    stale_hand: list[tuple[str, str]] = []
    n_hand_rows = 0
    for yrow in yrows:
        rid = yrow["id"]
        base = base_map.get(rid)
        if base is None:
            continue                       # already FATALed above
        delta = {}
        for k, v in yrow.items():          # yaml row field order
            if k == "id":
                continue
            if base.get(k) != v:
                delta[k] = v
        for k in base:                     # base fields the yaml lost
            if k != "id" and k not in yrow and base[k] is not None:
                delta[k] = None
        if not delta:
            continue
        sync[rid] = delta
        for k in delta:
            field_census[k] = field_census.get(k, 0) + 1
        hand = er.OVERRIDES.get(rid)
        if hand:
            n_hand_rows += 1
            for k in conflict_fields:
                if k in delta and k in hand and hand[k] != delta[k]:
                    stale_hand.append((rid, k))

        # fixed-point proof at generation time: BASE + delta == yaml row.
        # (None-valued keys are dropped by the generator's emit_row, so
        # they compare equal to absent keys: normalize both sides.)
        merged = {k: v for k, v in {**base, **delta}.items() if v is not None}
        yrow_n = {k: v for k, v in yrow.items() if v is not None}
        if merged != yrow_n:
            rc = 1
            print(f"FATAL: fixed-point check failed for {rid} — "
                  "delta application is not the identity; NOT writing",
                  file=sys.stderr)
            return rc

    # ---- duplicate literal keys in the hand OVERRIDES table --------------
    # (runtime dict silently keeps the later literal — later-literal-wins;
    # e.g. PDW5's in-flight v2 added a second "BLK-072" next to W06's.)
    src_text = Path(er.__file__).read_text()
    ovr_block = src_text.split("OVERRIDES = {", 1)[1].split("\nHAND_ROWS", 1)[0]
    lit_keys = re.findall(r"['\"]([A-Z]{2,4}-\d{1,4})['\"]\s*:", ovr_block)
    seen: dict[str, int] = {}
    for k in lit_keys:
        seen[k] = seen.get(k, 0) + 1
    dup_lit = {k: n for k, n in seen.items() if n > 1}

    # ---- report -----------------------------------------------------------
    print(f"source yaml : {er.OUT}  ({len(yrows)} rows)")
    print(f"              sha256 {ysha}")
    print(f"BASE rows   : {len(base_rows)} ({len(report_rows)} report "
          f"+ {len(er.HAND_ROWS)} HAND_ROWS)")
    print(f"hand OVERRIDES keys: {len(er.OVERRIDES)} "
          f"(delta rows also in the hand table: {n_hand_rows})")
    print(f"SYNC entries: {len(sync)} rows, field census: {field_census}")
    print(f"3-field census (status/lean_target/notes): "
          f"{sum(1 for d in sync.values() if any(k in d for k in conflict_fields))} rows")
    print(f"beyond-3-field rows (implemented_by/test_vector_ids/lean_note/"
          f"core_ref/...): "
          f"{sum(1 for d in sync.values() if any(k not in conflict_fields for k in d))}")
    if stale_hand:
        print(f"STALE hand-table entries shadowed by the sync layer "
              f"({len(stale_hand)}, yaml WINS):")
        if check_only:
            print("  (details omitted in --check; run without --check to list)")
        else:
            for rid, k in stale_hand:
                print(f"  {rid}.{k}: hand={er.OVERRIDES[rid].get(k)!r} "
                      f"-> yaml={sync[rid][k]!r}")
    if dup_lit:
        print(f"duplicate literal keys in the hand OVERRIDES source "
              f"(later-literal-wins): {dup_lit}")
    orphan_hand = sorted(k for k in er.OVERRIDES
                         if k not in base_map and k not in sync)
    if orphan_hand:
        print(f"hand-table keys with no source row at all (dead, no effect "
              f"on a regen): {orphan_hand}")

    # ---- write the sync layer --------------------------------------------
    out = [f'''# rules_overrides_sync.py — GENERATED by spec/scripts/backfill_overrides.py
# (contributor OVRBACK, 2026-10-17; GATES F-G4-01/F-G4-02 regen-safety layer).
#
# Per-row overlay of EVERY field where the committed rules.yaml differs
# from the pre-OVRBACK generator state (report row | HAND_ROWS literal
# + the hand OVERRIDES table). Merge precedence in extract_rules.py's
# build_row(): this layer WINS over the hand table — it mirrors the
# committed yaml = the curation record. {len(sync)} entries over
# {len(yrows)} rows; field census {dict(sorted(field_census.items()))}.
#
# Source yaml: {er.OUT.relative_to(er.REPO)}
#   {len(yrows)} rows, sha256 {ysha}
#
# DO NOT hand-edit this file. Curation flow:
#   1. edit the rules.yaml row;
#   2. python3 spec/scripts/backfill_overrides.py   (re-mirror);
#   3. python3 spec/scripts/extract_rules.py --check  (must exit 0).
# A regen without this layer is the 04:35 clobber: extract_rules.py
# refuses (see its docstring) unless --force.
#
# At generation time: {len(stale_hand)} stale hand-table entries shadowed
# ({", ".join(f"{r}.{k}" for r, k in stale_hand) or "none"});
# hand table is historical/advisory since OVRBACK.
''']
    out.append("OVERRIDES_SYNC = {")
    for yrow in yrows:                      # yaml row order
        rid = yrow["id"]
        delta = sync.get(rid)
        if not delta:
            continue
        out.append(f"    {rid!r}: {{")
        for k, v in delta.items():          # yaml field order
            out.append(f"        {k!r}: {v!r},")
        out.append("    },")
    out.append("}")
    out.append("")
    text = "\n".join(out)

    # ---- --check: diff in memory, never write ----------------------------
    if check_only:
        current = SYNC_OUT.read_text() if SYNC_OUT.exists() else ""
        if current == text:
            print(f"\nbackfill-overrides: OK ({SYNC_OUT.name} is current, "
                  f"{len(sync)} entries)")
        else:
            print(f"\nbackfill-overrides: DRIFT — {SYNC_OUT} is stale "
                  f"({len(sync)} entries expected). Run:\n"
                  f"  python3 spec/scripts/backfill_overrides.py\n"
                  f"then re-run extract_rules.py --check.", file=sys.stderr)
            rc = 1
        return rc

    SYNC_OUT.write_text(text)
    print(f"\nwrote {SYNC_OUT} ({len(sync)} entries)")
    return rc


if __name__ == "__main__":
    sys.exit(main())
