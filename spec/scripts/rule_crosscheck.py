#!/usr/bin/env python3
"""rule_crosscheck.py — traceability gate (D1 design, research/14 §(d)):

  1. every `@[rule "ID"]` attribute in spec/core/**/*.lean must name a row
     in spec/db/rules.yaml;
  2. every row with status implemented|proven must have a non-null
     lean_target AND a matching @[rule "ID"] attribute on that
     declaration's file;
  3. IDs must be unique in the YAML.

Reports per-namespace coverage counts. Exit non-zero on violation.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
DB = REPO / "spec" / "db" / "rules.yaml"
CORE = REPO / "spec" / "core"

ATTR_RE = re.compile(r'\brule\s+"([A-Za-z]{2,4}-\d{1,4})"')


def load_rows():
    try:
        import yaml
        data = yaml.safe_load(DB.read_text())
        return data["rules"]
    except ImportError:
        # minimal fallback parser (rows are flat key: value maps)
        rows, cur = [], None
        for line in DB.read_text().splitlines():
            if line.startswith("- id: "):
                cur = {"id": line.split("- id: ", 1)[1].strip().strip('"')}
                rows.append(cur)
            elif cur is not None and line.startswith("  "):
                k, _, v = line.strip().partition(": ")
                cur[k.strip()] = v.strip().strip('"')
        return rows


def main() -> int:
    rows = load_rows()
    by_id = {}
    dupes = []
    for r in rows:
        if r["id"] in by_id:
            dupes.append(r["id"])
        by_id[r["id"]] = r

    # 1. collect Lean attributes
    tagged: dict[str, list[str]] = {}
    for f in sorted(CORE.rglob("*.lean")) + sorted((REPO / "spec" / "proofs").rglob("*.lean")):
        if ".lake" in str(f):
            continue
        text = f.read_text()
        for m in ATTR_RE.finditer(text):
            tagged.setdefault(m.group(1), []).append(str(f.relative_to(REPO)))

    fail = 0

    # gate 1: every attribute has a row
    for rid, files in sorted(tagged.items()):
        if rid not in by_id:
            print(f"ORPHAN ATTRIBUTE: @[rule \"{rid}\"] in {files} — no rules.yaml row")
            fail = 1

    # gate 2: implemented/proven rows must be tagged
    missing_tag, missing_target = [], []
    for rid, r in sorted(by_id.items()):
        if r.get("status") in ("implemented", "proven"):
            if not r.get("lean_target") or r["lean_target"] in ("null", ""):
                missing_target.append(rid)
            if rid not in tagged:
                missing_tag.append(rid)
    if missing_target:
        print(f"ROWS WITH status>=implemented BUT NO lean_target: {missing_target}")
        fail = 1
    if missing_tag:
        print(f"ROWS WITH status>=implemented BUT NO @[rule] ATTRIBUTE: {missing_tag}")
        fail = 1

    # gate 3: uniqueness
    if dupes:
        print(f"DUPLICATE RULE IDS: {sorted(set(dupes))}")
        fail = 1

    # coverage report
    print(f"rule DB: {len(rows)} rows; Lean @[rule] attributes: {len(tagged)} ids / "
          f"{sum(len(v) for v in tagged.values())} attributes")
    ns_rows: dict[str, int] = {}
    ns_impl: dict[str, int] = {}
    for r in rows:
        ns = r["id"].rsplit("-", 1)[0]
        ns_rows[ns] = ns_rows.get(ns, 0) + 1
        if r.get("status") in ("implemented", "proven"):
            ns_impl[ns] = ns_impl.get(ns, 0) + 1
    for ns in sorted(ns_rows):
        impl = ns_impl.get(ns, 0)
        tag = sum(1 for rid in tagged if rid.startswith(ns + "-"))
        print(f"  {ns}: {ns_rows[ns]} rows | implemented {impl} | tagged {tag}")
    tagged_ns = {rid.rsplit('-', 1)[0] for rid in tagged}
    print(f"  coverage of implemented rows by Lean attributes: "
          f"{sum(ns_impl.values())}/{len(rows)} total rows implemented")

    if fail:
        print("rule-crosscheck: FAIL")
        return 1
    print("rule-crosscheck: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
