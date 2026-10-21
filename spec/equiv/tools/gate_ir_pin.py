#!/usr/bin/env python3
"""gate-ir-pin: pins + cell records + SCR coverage + no unfiled gaps.

Exit status is non-zero on any FAIL. E0 is expected to fail until the leg
owners finish PINS.lock and CELLS produce records; use --allow-todo to make
pin TODO entries warnings (coverage failures still fail).

Checks implemented:
  1. PINS.lock has every required section/key and no TODO values.
  2. Cell records exist under cells/<family>/<cell>/ (record.yaml/json/...).
  3. If spec/db/equiv-cells.yaml exists: exactly one row per SCR-* in
     spec/db/rules.yaml, valid status, green rows have cells, gap rows have
     a non-empty gap_note, and every named cell directory has a record.

Known TODOs (not implemented): certificate hash verification, cross-checking
record leg fingerprints against PINS.lock, and per-cell Alive2/SAW result
parsing. Those belong to LEDGER/CELLS once the record schema lands.
"""
from __future__ import annotations

import argparse
import configparser
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
PINS = ROOT / "PINS.lock"
CELLS = ROOT / "cells"
RULES = ROOT.parent / "db" / "rules.yaml"
EQUIV = ROOT.parent / "db" / "equiv-cells.yaml"

REQUIRED = {
    "core": ["commit", "version", "source", "build", "patches"],
    "rbitcoin": ["commit", "version", "source", "toolchain", "crypto", "build"],
    "lean": ["repo", "lake", "model_rev"],
    "llvm": ["clang", "llvm_ir_version", "flags", "triple"],
    "tools": ["alive2", "saw", "z3", "cvc5", "kani", "miri", "python", "cmake"],
}

GREEN = {"alive2-green", "saw-green", "both-green"}
GAP = {"gap", "unjudged-seam"}
RECORD_NAMES = (
    "spec.md",
    "record.yaml",
    "record.json",
    "cell.yaml",
    "cell.json",
    "meta.yaml",
    "meta.json",
)

fails: list[str] = []
warns: list[str] = []


def fail(msg: str) -> None:
    fails.append(msg)
    print(f"FAIL  {msg}")


def warn(msg: str) -> None:
    warns.append(msg)
    print(f"WARN  {msg}")


def ok(msg: str) -> None:
    print(f"OK    {msg}")


def unfilled(v: str | None) -> bool:
    return v is None or not v.strip() or v.strip().upper().startswith("TODO")


def check_pins(allow_todo: bool) -> None:
    print("== 1. PINS.lock ==")
    if not PINS.exists():
        fail(f"missing {PINS}")
        return
    cp = configparser.ConfigParser(interpolation=None, allow_no_value=True)
    cp.optionxform = str
    with PINS.open() as f:
        cp.read_file(f)
    missing: list[str] = []
    todo: list[str] = []
    for section, keys in REQUIRED.items():
        if section not in cp:
            missing.append(f"[{section}]")
            continue
        for key in keys:
            if key not in cp[section]:
                missing.append(f"[{section}] {key}")
            elif unfilled(cp[section][key]):
                todo.append(f"[{section}] {key}")
    if missing:
        fail("missing pin keys: " + ", ".join(missing))
    if todo:
        msg = f"{len(todo)} TODO pin(s): " + ", ".join(todo)
        if allow_todo:
            warn(msg)
        else:
            fail(msg)
    if not missing and not todo:
        ok("all required pins are filled")


def find_record(cell_dir: Path) -> Path | None:
    for name in RECORD_NAMES:
        p = cell_dir / name
        if p.is_file():
            if name == "spec.md":
                # The cell schema is a Markdown record; require the coverage
                # field so a stray README is not counted as a cell record.
                if "scr_rows:" not in p.read_text(errors="replace"):
                    continue
            return p
    return None


def check_cell_records() -> int:
    print("\n== 2. cell records ==")
    if not CELLS.is_dir():
        fail(f"missing {CELLS}")
        return 0
    cell_dirs = sorted(
        p
        for p in CELLS.glob("*/*")
        if p.is_dir()
        and not any(part.startswith("_") for part in p.relative_to(CELLS).parts)
        and p.name not in {"logs", "saw", "alive2", "build", "witnesses", "behavior"}
    )
    with_record = [p for p in cell_dirs if find_record(p)]
    print(f"  cell directories: {len(cell_dirs)}; with a record file: {len(with_record)}")
    if not cell_dirs:
        warn("no cells yet (E0: expected; CELLS role has not landed any)")
    for p in cell_dirs:
        if not find_record(p):
            warn(f"cell without record: {p.relative_to(ROOT)}")
    return len(with_record)


def resolve_cell(row: dict, ref: str) -> Path:
    ref = str(ref)
    p = Path(ref)
    if p.is_absolute():
        return p
    if p.parts and (CELLS / p).is_dir():
        return CELLS / p
    fam = row.get("family")
    if fam and (CELLS / str(fam) / p).is_dir():
        return CELLS / str(fam) / p
    return CELLS / p


def load_yaml(path: Path):
    try:
        import yaml  # type: ignore
    except ImportError:
        warn("PyYAML is not installed; coverage check skipped")
        return None
    with path.open() as f:
        return yaml.safe_load(f)


def check_coverage() -> None:
    print("\n== 3. SCR coverage ==")
    if not RULES.exists():
        warn(f"{RULES} absent; coverage check skipped")
        return
    if not EQUIV.exists():
        warn(f"{EQUIV} absent; coverage check skipped (LEDGER has not landed it)")
        return
    rules_doc = load_yaml(RULES)
    equiv_doc = load_yaml(EQUIV)
    if rules_doc is None or equiv_doc is None:
        return

    scr_ids = [
        str(r.get("id"))
        for r in (rules_doc.get("rules") or [])
        if str(r.get("id", "")).startswith("SCR-")
    ]
    rows = equiv_doc.get("rows") or []
    by_id: dict[str, dict] = {}
    dupes = []
    for r in rows:
        rid = str(r.get("id"))
        if rid in by_id:
            dupes.append(rid)
        by_id[rid] = r
    print(f"  SCR rows in rules.yaml: {len(scr_ids)}")
    print(f"  rows in equiv-cells.yaml: {len(rows)}")

    if dupes:
        fail("duplicate coverage rows: " + ", ".join(sorted(set(dupes))))
    missing = sorted(set(scr_ids) - set(by_id))
    extra = sorted(set(by_id) - set(scr_ids))
    if missing:
        fail(f"{len(missing)} SCR row(s) missing from equiv-cells.yaml: " + ", ".join(missing[:8]))
    if extra:
        fail(f"{len(extra)} row(s) not in rules.yaml: " + ", ".join(extra[:8]))

    status_enum = set(
        ((equiv_doc.get("contract") or {}).get("status_enum") or [])
    ) or (GREEN | GAP | {"planned"})
    counts: dict[str, int] = {}
    pending = 0
    for rid in scr_ids:
        row = by_id.get(rid)
        if not row:
            continue
        status = str(row.get("status", ""))
        counts[status] = counts.get(status, 0) + 1
        if status not in status_enum:
            fail(f"{rid}: invalid status {status!r}")
            continue
        if status == "planned":
            pending += 1
            continue
        if status in GREEN:
            cells = row.get("cells") or []
            if not cells:
                fail(f"{rid}: {status} but no cells listed")
            for ref in cells:
                cdir = resolve_cell(row, ref)
                if not cdir.is_dir():
                    fail(f"{rid}: cell path does not exist: {ref}")
                elif not find_record(cdir):
                    fail(f"{rid}: cell has no record file: {ref}")
            if status == "both-green":
                for leg in ("alive2", "saw"):
                    if not row.get(leg):
                        fail(f"{rid}: both-green but {leg} result missing")
            elif status in ("alive2-green", "saw-green"):
                leg = "alive2" if status.startswith("alive2") else "saw"
                if not row.get(leg):
                    fail(f"{rid}: {status} but {leg} result missing")
        elif status in GAP:
            note = row.get("gap_note")
            if not note or not str(note).strip():
                fail(f"{rid}: {status} requires a non-empty gap_note")

    print("  status counts: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    if pending:
        warn(f"{pending} SCR row(s) still 'planned' (not adjudicated)")
    adjudicated = len(scr_ids) - pending
    if scr_ids and adjudicated < len(scr_ids):
        fail(f"coverage incomplete: {adjudicated}/{len(scr_ids)} SCR rows adjudicated")
    elif scr_ids:
        ok(f"all {len(scr_ids)} SCR rows adjudicated")


def check_certificates() -> None:
    """Replay every cell certificate against the current tree.

    A certificate is a list of ``sha256  repo-relative-path`` lines.  Build
    artifacts are not listed: they are ignored and path-dependent.  For the
    Alive2 and SAW legs the raw result.txt must also be covered.
    """
    print("\n== 4. certificates ==")
    certs = sorted(
        p for p in CELLS.rglob("certificate.sha256")
        if "build" not in p.parts and "__pycache__" not in p.parts
    )
    if not certs:
        warn("no cell certificates found")
        return
    bad = 0
    for cert in certs:
        rel_cert = cert.relative_to(REPO)
        digests: set[str] = set()
        for line in cert.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 1)
            if len(parts) != 2 or len(parts[0]) != 64:
                fail(f"{rel_cert}: malformed line {line[:80]!r}")
                bad += 1
                continue
            expected, rel = parts
            digests.add(expected.lower())
            p = REPO / rel
            if not p.is_file():
                fail(f"{rel_cert}: missing {rel}")
                bad += 1
                continue
            actual = hashlib.sha256(p.read_bytes()).hexdigest()
            if actual != expected.lower():
                fail(f"{rel_cert}: digest mismatch for {rel}")
                bad += 1
        result = cert.parent / "result.txt"
        if result.is_file():
            actual = hashlib.sha256(result.read_bytes()).hexdigest()
            if actual not in digests:
                fail(f"{rel_cert}: result.txt digest not recorded")
                bad += 1
        elif cert.parent.name in ("alive2", "saw"):
            fail(f"{rel_cert}: result.txt missing")
            bad += 1
    if bad:
        fail(f"{bad} certificate issue(s)")
    else:
        ok(f"all {len(certs)} certificates replay cleanly")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--allow-todo", action="store_true", help="TODO pins are warnings")
    args = ap.parse_args()

    print(f"gate-ir-pin root: {ROOT}")
    check_pins(args.allow_todo)
    n = check_cell_records()
    check_coverage()
    check_certificates()

    print("\n== summary ==")
    print(f"  cell records: {n}")
    print(f"  failures: {len(fails)}; warnings: {len(warns)}")
    if fails:
        print("RESULT: FAIL")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
