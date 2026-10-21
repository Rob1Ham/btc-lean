#!/usr/bin/env python3
"""Build the published SCR equivalence matrix from the ledger.

Output: ``spec/equiv/results/matrix.md``.

The matrix is generated, never hand-edited. It contains:

  * per-family counts (SCR rows, green, unjudged seam, gap, planned);
  * the named trust base (source pins, tool versions, contract hash);
  * the claim form, including what the matrix does not establish;
  * links to every cell record named by the ledger;
  * a strict-gate footer.

It fails loudly (non-zero, no write) when:
  * a green row has no cell, a missing cell directory, a malformed record, or
    a cell whose recorded tool result is not a success;
  * the ledger status of a green row disagrees with the cell-derived state;
  * a cell named anywhere in the ledger does not exist;
  * a gap/unjudged-seam row lacks a non-empty gap_note;
  * the ledger does not cover exactly the SCR rows in rules.yaml;
  * any cell under cells/ is malformed or covers an unknown SCR row.

Usage:
    python3 spec/equiv/results/scripts/build_matrix.py
    python3 spec/equiv/results/scripts/build_matrix.py --check
    python3 spec/equiv/results/scripts/build_matrix.py --out /tmp/matrix.md

Exit codes: 0 success (or --check with no drift); 1 validation failure or
drift under --check; 2 missing dependency / unparseable input.
"""

from __future__ import annotations

import argparse
import configparser
import hashlib
import os
import sys
from collections import Counter, OrderedDict
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on a bare host
    sys.stderr.write(
        "build_matrix.py: missing dependency PyYAML.\n"
        "Install it (e.g. `python3 -m pip install PyYAML`) and re-run.\n"
    )
    raise SystemExit(2)

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import update_ledger as ledger_tool  # noqa: E402  (same directory)

EQUIV_DIR = HERE.parent.parent
REPO_ROOT = EQUIV_DIR.parent.parent
DEFAULT_LEDGER = REPO_ROOT / "spec" / "db" / "equiv-cells.yaml"
DEFAULT_RULES = REPO_ROOT / "spec" / "db" / "rules.yaml"
DEFAULT_CELLS = EQUIV_DIR / "cells"
DEFAULT_PINS = EQUIV_DIR / "PINS.lock"
DEFAULT_OUT = EQUIV_DIR / "results" / "matrix.md"

GREEN = ledger_tool.GREEN_STATUSES
STATUSES = ledger_tool.STATUSES


def die(message: str) -> "NoReturn":
    sys.stderr.write(f"build_matrix.py: {message}\n")
    raise SystemExit(2)


def load_yaml(path: Path) -> dict:
    if not path.is_file():
        die(f"missing input file: {path}")
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        die(f"cannot parse {path}: {exc}")
    if not isinstance(data, dict):
        die(f"{path} must contain a YAML mapping at the top level")
    return data


def load_pins(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, allow_no_value=True)
    parser.optionxform = str
    if not path.is_file():
        die(f"missing pins file: {path}")
    try:
        with path.open(encoding="utf-8") as handle:
            parser.read_file(handle)
    except (OSError, configparser.Error) as exc:
        die(f"cannot parse {path}: {exc}")
    return parser


def pin(parser: configparser.ConfigParser, section: str, key: str) -> str:
    value = parser.get(section, key, fallback="").strip()
    if not value:
        return "**MISSING**"
    if value.upper().startswith("TODO"):
        return f"**UNPINNED** ({value})"
    return value.replace("|", "\\|")


def md_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def resolve_cell(
    ref: str, row: dict, cells_dir: Path, by_rel: dict[str, ledger_tool.Cell]
) -> ledger_tool.Cell | None:
    ref = str(ref)
    candidate = Path(ref)
    if candidate.is_absolute():
        try:
            rel = candidate.resolve().relative_to(cells_dir.resolve()).as_posix()
        except ValueError:
            return None
        return by_rel.get(rel)
    rel = candidate.as_posix()
    if rel in by_rel:
        return by_rel[rel]
    family = str(row.get("family") or "")
    if family:
        fallback = f"{family}/{rel}"
        if fallback in by_rel:
            return by_rel[fallback]
    return None


def cell_link(cells_dir: Path, out: Path, rel: str, suffix: str = "") -> str:
    """Markdown link from the output file to a cell artifact."""
    target = cells_dir / rel / suffix
    return Path(os.path.relpath(target, out.parent)).as_posix()


def validate(
    ledger: dict,
    rules: dict,
    cells: list[ledger_tool.Cell],
    scan_issues: list[str],
    states: dict[str, ledger_tool.RowState],
    cells_dir: Path,
) -> list[str]:
    errors: list[str] = list(scan_issues)

    rows = ledger.get("rows")
    if not isinstance(rows, list):
        return errors + ["ledger `rows` must be a list"]
    rules_rows = rules.get("rules")
    if not isinstance(rules_rows, list):
        return errors + ["rules.yaml `rules` must be a list"]

    scr_ids = [
        str(row["id"])
        for row in rules_rows
        if isinstance(row, dict) and str(row.get("id", "")).startswith("SCR-")
    ]
    ledger_ids = [str(row.get("id")) for row in rows if isinstance(row, dict)]
    if len(scr_ids) != 183:
        errors.append(f"rules.yaml has {len(scr_ids)} SCR rows, expected 183")
    if len(ledger_ids) != len(set(ledger_ids)):
        errors.append("ledger has duplicate ids")
    missing = sorted(set(scr_ids) - set(ledger_ids))
    extra = sorted(set(ledger_ids) - set(scr_ids))
    if missing:
        errors.append(f"{len(missing)} SCR row(s) missing from ledger: {', '.join(missing[:8])}")
    if extra:
        errors.append(f"{len(extra)} ledger id(s) not in rules.yaml: {', '.join(extra[:8])}")

    by_rel = {cell.rel: cell for cell in cells}
    declared_families = {
        str(family.get("id")): family
        for family in (ledger.get("families") or [])
        if isinstance(family, dict) and family.get("id")
    }

    for cell in cells:
        if cell.issues:
            errors.append(f"{cell.rel}: malformed cell record: {cell.issues[0]}")
        for rule_id in cell.scr_rows:
            if rule_id not in set(scr_ids):
                errors.append(f"{cell.rel}: scr_rows entry {rule_id} is not in rules.yaml")

    referenced: set[str] = set()
    for row in rows:
        rule_id = str(row.get("id"))
        status = str(row.get("status"))
        cells_value = row.get("cells") or []
        if status not in STATUSES:
            errors.append(f"{rule_id}: invalid status {status!r}")
            continue
        if not isinstance(cells_value, list):
            errors.append(f"{rule_id}: cells must be a list")
            cells_value = []
        if status in GREEN | {"gap", "unjudged-seam"} and row.get("family") not in declared_families:
            errors.append(f"{rule_id}: family {row.get('family')!r} is not declared")
        if status in {"gap", "unjudged-seam"}:
            note = row.get("gap_note")
            if not isinstance(note, str) or not note.strip():
                errors.append(f"{rule_id}: {status} without a non-empty gap_note")
        if status in GREEN:
            if not cells_value:
                errors.append(
                    f"{rule_id}: {status} but cells is empty (a green row must "
                    "name at least one cell record)"
                )
                continue
            resolved = []
            for ref in cells_value:
                referenced.add(str(ref))
                cell = resolve_cell(str(ref), row, cells_dir, by_rel)
                if cell is None:
                    errors.append(
                        f"{rule_id}: {status} cites missing cell {ref!r}"
                    )
                    continue
                resolved.append(cell)
                if cell.issues:
                    errors.append(
                        f"{rule_id}: {status} cites malformed cell {cell.rel}: "
                        f"{cell.issues[0]}"
                    )
                elif rule_id not in cell.scr_rows:
                    errors.append(
                        f"{rule_id}: cell {cell.rel} does not list this row in scr_rows"
                    )
            if status in {"alive2-green", "both-green"} and not any(
                cell.alive2.state == "green" for cell in resolved if cell.valid
            ):
                errors.append(f"{rule_id}: {status} but no cited cell has an Alive2 success")
            if status in {"saw-green", "both-green"} and not any(
                cell.saw.state == "green" for cell in resolved if cell.valid
            ):
                errors.append(f"{rule_id}: {status} but no cited cell has a SAW success")
            computed = states.get(rule_id)
            if computed is None:
                errors.append(f"{rule_id}: {status} but the cell-derived state is absent")
            elif computed.blocked:
                errors.append(f"{rule_id}: {status} but a cited cell record is malformed")
            elif computed.status != status:
                errors.append(
                    f"{rule_id}: ledger says {status} but cells derive "
                    f"{computed.status}; run update_ledger.py --from-cells"
                )
        elif status == "planned" and cells_value:
            errors.append(f"{rule_id}: planned row lists cells; run update_ledger.py")

    for row in rows:
        if str(row.get("status")) in GREEN:
            continue
        refs = row.get("cells") or []
        if not isinstance(refs, list):
            continue
        for ref in refs:
            if str(ref) in referenced:
                continue
            referenced.add(str(ref))
            cell = resolve_cell(str(ref), row, cells_dir, by_rel)
            if cell is None:
                errors.append(f"{row.get('id')}: cites missing cell {ref!r}")

    # A row filed as an unjudged seam that names cells must cite at least one
    # cell that itself declares the seam and its DECISION/finding basis.
    for row in rows:
        if str(row.get("status")) != "unjudged-seam":
            continue
        refs = row.get("cells") or []
        if not isinstance(refs, list) or not refs:
            continue
        cited = [resolve_cell(str(ref), row, cells_dir, by_rel) for ref in refs]
        if not any(cell is not None and cell.seam_note for cell in cited):
            errors.append(
                f"{row.get('id')}: unjudged-seam cells do not include a cell "
                "declaring `unjudged_seam` (DECISION-lax-ecdsa.md + finding)"
            )

    for family_id, family in declared_families.items():
        declared = family.get("rows")
        actual = sum(1 for row in rows if str(row.get("family")) == family_id)
        if isinstance(declared, int) and declared != actual:
            errors.append(
                f"family {family_id}: declared rows={declared} but ledger has {actual}"
            )
    return errors


def build_markdown(
    ledger: dict,
    rules: dict,
    cells: list[ledger_tool.Cell],
    cells_dir: Path,
    out_path: Path,
    pins: configparser.ConfigParser,
    ledger_bytes: bytes,
) -> str:
    rows = ledger["rows"]
    families = [family for family in ledger.get("families") or [] if isinstance(family, dict)]

    buckets: "OrderedDict[str, Counter]" = OrderedDict()
    for family in families:
        buckets[str(family["id"])] = Counter()
    for row in rows:
        family_id = str(row.get("family"))
        buckets.setdefault(family_id, Counter())
        bucket = buckets[family_id]
        status = str(row.get("status"))
        bucket["rows"] += 1
        if status in GREEN:
            bucket["green"] += 1
            bucket["both" if status == "both-green" else "one"] += 1
        elif status == "planned":
            bucket["planned"] += 1
        elif status == "unjudged-seam":
            bucket["unjudged"] += 1
        elif status == "gap":
            bucket["gap"] += 1
        else:
            bucket["other"] += 1

    totals = Counter()
    for bucket in buckets.values():
        totals.update(bucket)

    ledger_hash = hashlib.sha256(ledger_bytes).hexdigest()
    contract_hash = pin(pins, "contract", "hash")
    pin_value = str(ledger.get("pin", "MISSING"))

    lines: list[str] = []
    lines.append("# LLVM IR equivalence matrix")
    lines.append("")
    lines.append(
        "Generated by `spec/equiv/results/scripts/build_matrix.py` from "
        "`spec/db/equiv-cells.yaml` "
        f"(sha256 `{ledger_hash}`). **Do not hand-edit.**"
    )
    lines.append("")
    lines.append(
        "Regenerate with `python3 spec/equiv/results/scripts/build_matrix.py`; "
        "check with `... --check`."
    )

    lines.append("")
    lines.append("## The claim form")
    lines.append("")
    lines.append(
        "> For all inputs in the harness domain, **if** the pinned front-ends, "
        "the LLVM IR semantics implemented by Alive2 and SAW/Crucible, the SMT "
        "solvers, the shims, the twin generator/transliteration, and the "
        "same-crypto premise are sound, **then** the Core slice and the "
        "Lean-derived twin agree on verdict and error kind.  All recorded "
        "cells are C/L; no R cell exists and the R lane is advisory/blocked."
    )
    lines.append("")
    lines.append(
        "This is a **conditional evidence statement**, not a Lean-kernel "
        "theorem, not a machine-backend/linker/OS result, and not a claim "
        "about libsecp256k1 internals. A row is covered only by a validated "
        "cell record with a recorded tool success, or by a filed gap/seam with "
        "a named blocker. `planned` is not coverage."
    )

    lines.append("")
    lines.append("## Trust base (named)")
    lines.append("")
    lines.append("### Source and front-end pins")
    lines.append("")
    lines.append("| Premise | Pinned value |")
    lines.append("|---|---|")
    lines.append(f"| Bitcoin Core | `{md_cell(pin(pins, 'core', 'commit'))}` ({md_cell(pin(pins, 'core', 'version'))}) |")
    lines.append(f"| Core build | {md_cell(pin(pins, 'core', 'build'))} |")
    lines.append(f"| Core patches | {md_cell(pin(pins, 'core', 'patches'))} |")
    lines.append(f"| rbitcoin | `{md_cell(pin(pins, 'rbitcoin', 'commit'))}` ({md_cell(pin(pins, 'rbitcoin', 'version'))}) |")
    lines.append(f"| rbitcoin toolchain | {md_cell(pin(pins, 'rbitcoin', 'toolchain'))} |")
    lines.append(f"| rbitcoin build | {md_cell(pin(pins, 'rbitcoin', 'build'))} |")
    lines.append(f"| Lean model | `{md_cell(pin(pins, 'lean', 'model_rev'))}`; lake {md_cell(pin(pins, 'lean', 'lake'))} |")
    lines.append(f"| Ledger pin | `{md_cell(pin_value)}` |")
    lines.append(f"| clang | {md_cell(pin(pins, 'llvm', 'clang'))} |")
    lines.append(f"| LLVM IR version | {md_cell(pin(pins, 'llvm', 'llvm_ir_version'))} |")
    lines.append(f"| IR flags | {md_cell(pin(pins, 'llvm', 'flags'))} |")
    lines.append(f"| Triple/datalayout | {md_cell(pin(pins, 'llvm', 'triple'))} |")
    lines.append("")
    lines.append("### Tool and solver pins")
    lines.append("")
    lines.append("| Tool | Pinned version |")
    lines.append("|---|---|")
    lines.append(f"| Alive2 | {md_cell(pin(pins, 'tools', 'alive2'))} |")
    lines.append(f"| SAW | {md_cell(pin(pins, 'tools', 'saw'))} |")
    lines.append(f"| Z3 | {md_cell(pin(pins, 'tools', 'z3'))} |")
    lines.append(f"| CVC5 | {md_cell(pin(pins, 'tools', 'cvc5'))} |")
    lines.append("")
    lines.append("### Contract")
    lines.append("")
    lines.append(f"- Contract hash: `{md_cell(contract_hash)}`")
    lines.append(f"- Recipe: `{md_cell(pin(pins, 'contract', 'recipe'))}`")
    lines.append(
        "- Any contract edit invalidates cell records and is a re-pin, not a "
        "reinterpretation."
    )
    if any(
        "UNPINNED" in pin(pins, section, key)
        for section, key in (
            ("core", "build"),
            ("rbitcoin", "build"),
        )
    ):
        lines.append(
            "- **Build entries with `TODO` are still unpinned** (shown above). "
            "Results against an unpinned build are not E6-complete."
        )

    lines.append("")
    lines.append("### IR artifact inventory and E5")
    lines.append("")
    lines.append(f"- IR manifest: `{md_cell(pin(pins, 'ir', 'manifest'))}` (sha256 `{md_cell(pin(pins, 'ir', 'manifest_sha256'))}`)")
    lines.append(f"- Core 15-TU closure (unpatched): `interpreter-O0` `{md_cell(pin(pins, 'ir', 'core_interpreter_O0_bc_sha256'))}`, `interpreter-O1` `{md_cell(pin(pins, 'ir', 'core_interpreter_O1_bc_sha256'))}`")
    lines.append(f"- Twin closure: `twin-O0` `{md_cell(pin(pins, 'ir', 'twin_O0_bc_sha256'))}`, `twin-O1` `{md_cell(pin(pins, 'ir', 'twin_O1_bc_sha256'))}`")
    lines.append(f"- rbitcoin closure: `consensus-O0` `{md_cell(pin(pins, 'ir', 'rust_consensus_O0_bc_sha256'))}`; pinned rustc 1.95/LLVM 22 is not Alive2-ingestible (F-TOOL-001); the non-pin 1.88/LLVM-20 lane is advisory only.")
    lines.append(f"- E5 residual: `{md_cell(pin(pins, 'ir', 'e5_residual'))}` — {md_cell(pin(pins, 'ir', 'e5_status'))}")
    lines.append("")
    lines.append("## Coverage by SCR family")
    lines.append("")
    lines.append(
        "| Family | SCR rows | Green | of which both-tool | Unjudged seam | Gap | Planned |"
    )
    lines.append("|---|---:|---:|---:|---:|---:|---:|")
    for family in families:
        family_id = str(family["id"])
        bucket = buckets[family_id]
        title = str(family.get("title", family_id))
        lines.append(
            f"| `{family_id}` — {md_cell(title)} | {bucket['rows']} | "
            f"{bucket['green']} | {bucket['both']} | {bucket['unjudged']} | "
            f"{bucket['gap']} | {bucket['planned']} |"
        )
    lines.append(
        f"| **Total** | **{totals['rows']}** | **{totals['green']}** | "
        f"**{totals['both']}** | **{totals['unjudged']}** | **{totals['gap']}** | "
        f"**{totals['planned']}** |"
    )
    lines.append("")
    lines.append(
        "Statuses: `both-green` | `alive2-green` | `saw-green` are green; "
        "`unjudged-seam` and `gap` require a non-empty `gap_note`; `planned` "
        "has no adjudication. A family is not complete until every row is "
        "green, unjudged-seam, or a filed gap."
    )
    if totals["other"]:
        lines.append(
            f"**{totals['other']} row(s) have an invalid status**; the matrix "
            "gate must fail."
        )

    lines.append("")
    lines.append("## Cell records")
    lines.append("")
    if not cells:
        lines.append(
            "**No cell records exist yet.** Zero rows are green; this is the "
            "honest bootstrap state, not a coverage claim."
        )
        lines.append("")
        lines.append(
            "When CELLS lands, each green row in the table above links to its "
            "`cells/<family>/<cell>/spec.md`, `alive2/result.txt`, and "
            "`saw/result.txt`. The ledger `cells` field is the authority."
        )
    else:
        rows_by_cell: dict[str, list[str]] = {}
        for row in rows:
            for ref in row.get("cells") or []:
                rows_by_cell.setdefault(str(ref), []).append(str(row.get("id")))
        by_rel = {cell.rel: cell for cell in cells}
        lines.append("| Cell | SCR rows | Alive2 | SAW | Records |")
        lines.append("|---|---|---|---|---|")
        for rel in sorted(rows_by_cell):
            cell = by_rel.get(rel)
            if cell is None:
                lines.append(f"| `{md_cell(rel)}` | missing | — | — | — |")
                continue
            links = [f"[spec]({cell_link(cells_dir, out_path, rel, 'spec.md')})"]
            if (cells_dir / rel / "alive2" / "result.txt").is_file():
                links.append(
                    f"[alive2]({cell_link(cells_dir, out_path, rel, 'alive2/result.txt')})"
                )
            if (cells_dir / rel / "saw" / "result.txt").is_file():
                links.append(
                    f"[saw]({cell_link(cells_dir, out_path, rel, 'saw/result.txt')})"
                )
            lines.append(
                f"| `{md_cell(rel)}` | {', '.join(sorted(set(rows_by_cell[rel])))} | "
                f"{cell.alive2.state} | {cell.saw.state} | {' · '.join(links)} |"
            )

    lines.append("")
    lines.append("## Coverage footer")
    lines.append("")
    strict_fail = totals["planned"] or totals["other"]
    scr_rows_count = sum(
        1
        for row in (rules.get("rules") or [])
        if isinstance(row, dict) and str(row.get("id", "")).startswith("SCR-")
    )
    lines.append("| Metric | Value |")
    lines.append("|---|---:|")
    lines.append(f"| SCR rows in `rules.yaml` | {scr_rows_count} |")
    lines.append(f"| Ledger entries | {len(rows)} |")
    lines.append(f"| Both-tool green | {totals['both']} |")
    lines.append(f"| One-tool green | {totals['one']} |")
    lines.append(f"| Unjudged seam | {totals['unjudged']} |")
    lines.append(f"| Filed gaps | {totals['gap']} |")
    lines.append(f"| Rows still planned | {totals['planned']} |")
    lines.append(f"| Malformed cell records | {sum(1 for cell in cells if cell.issues)} |")
    if strict_fail:
        reasons = []
        if totals["planned"]:
            reasons.append(f"{totals['planned']} row(s) still planned")
        if totals["other"]:
            reasons.append(f"{totals['other']} invalid status row(s)")
        lines.append(
            "| `coverage_report.py --strict` | **FAIL** — " + "; ".join(reasons) + " |"
        )
    else:
        lines.append(
            "| `coverage_report.py --strict` | **PASS** — all SCR rows adjudicated |"
        )
    lines.append("")
    lines.append(
        "Generated deterministically from the ledger and cell directories; "
        "no timestamps. A green row is rejected by the generator unless a cell "
        "record exists and its recorded tool result contains a success marker."
    )
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="no write; exit 1 on drift")
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--rules", type=Path, default=DEFAULT_RULES)
    parser.add_argument("--cells-dir", type=Path, default=DEFAULT_CELLS)
    parser.add_argument("--pins", type=Path, default=DEFAULT_PINS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv)

    ledger_bytes = args.ledger.read_bytes() if args.ledger.is_file() else b""
    ledger = load_yaml(args.ledger)
    rules = load_yaml(args.rules)
    pins = load_pins(args.pins)
    row_ids = {str(row.get("id")) for row in ledger.get("rows", [])}
    contract_pin = ledger_tool._load_contract_pin(args.pins)
    cells, scan_issues = ledger_tool.scan_cells(args.cells_dir, row_ids, contract_pin)
    states, _ = ledger_tool.compute_row_states(cells, row_ids)

    errors = validate(ledger, rules, cells, scan_issues, states, args.cells_dir)
    if errors:
        sys.stderr.write(f"build_matrix.py: FAIL ({len(errors)} issue(s))\n")
        for error in errors:
            sys.stderr.write(f"  - {error}\n")
        sys.stderr.write("matrix not written; fix the ledger/cells first\n")
        return 1

    text = build_markdown(ledger, rules, cells, args.cells_dir, args.out, pins, ledger_bytes)
    if args.check:
        current = args.out.read_text(encoding="utf-8") if args.out.is_file() else ""
        if current != text:
            sys.stderr.write(f"build_matrix.py: DRIFT  {args.out} is stale\n")
            return 1
        print(f"{args.out}: up to date")
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text, encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
