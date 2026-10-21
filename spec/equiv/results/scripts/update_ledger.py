#!/usr/bin/env python3
"""Deterministically derive SCR ledger status from cell records.

The ledger (``spec/db/equiv-cells.yaml``) is the coverage oracle for E6. A row
may only become green when a real cell record says so. This script is the only
supported way to move rows off ``planned``:

    python3 spec/equiv/results/scripts/update_ledger.py            # update
    python3 spec/equiv/results/scripts/update_ledger.py --check    # no write
    python3 spec/equiv/results/scripts/update_ledger.py --from-cells

It reads every ``cells/<family>/<cell>/`` directory and validates it against
``cells/README.md``:

  spec.md                 YAML front matter with the required keys
  alive2/result.txt       raw Alive2 output (success marker required)
  saw/result.txt          raw SAW output (success marker required)
  alive2|certificate.sha256   optional but validated when present
  notes.md                required only for a filed inapplicability (F-TOOL-nnn)

Status derivation
-----------------
  both legs green                         -> both-green
  one leg green, other filed inapplicable  -> alive2-green / saw-green
  any red/ambiguous leg, or neither green  -> gap (auto gap_note)
  malformed cell                           -> affected rows stay planned
  no cell                                  -> no status change (planned)

Green is never inferred from the ledger itself, a status file, or a record
field written by hand. It requires a non-empty ``cells`` list plus a parsed
tool result containing the tool's success marker. A malformed cell is reported
with its exact path and the expected schema; it is never repaired silently.

Exit codes: 0 clean; 1 drift under --check, malformed cell, or write with
malformed cells; 2 missing dependency / unparseable ledger. Requires PyYAML.
"""

from __future__ import annotations

import argparse
import configparser
import hashlib
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on a bare host
    sys.stderr.write(
        "update_ledger.py: missing dependency PyYAML.\n"
        "Install it (e.g. `python3 -m pip install PyYAML`) and re-run.\n"
    )
    raise SystemExit(2)

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_equiv_cells as builder  # noqa: E402  (same directory)

EQUIV_DIR = HERE.parent.parent
REPO_ROOT = EQUIV_DIR.parent.parent
DEFAULT_CELLS_DIR = EQUIV_DIR / "cells"
DEFAULT_LEDGER = REPO_ROOT / "spec" / "db" / "equiv-cells.yaml"
DEFAULT_RULES = REPO_ROOT / "spec" / "db" / "rules.yaml"
DEFAULT_PINS = EQUIV_DIR / "PINS.lock"

STATUSES = set(builder.STATUSES)
GREEN_STATUSES = {"alive2-green", "saw-green", "both-green"}
FILED_STATUSES = {"gap", "unjudged-seam"}

REQUIRED_SPEC_FIELDS = (
    "contract",
    "legs",
    "precondition",
    "postcondition",
    "direction",
    "scr_rows",
    "patches",
    "trust_note",
)
SCR_RE = re.compile(r"^SCR-\d{3}$")
TOOL_FINDING_RE = re.compile(r"\bF-TOOL-\d+\b")
HEX64_RE = re.compile(r"\b[0-9a-fA-F]{64}\b")
CELL_ID_RE = re.compile(r"^(?:C-L|C-R|L-R)-[A-Za-z0-9][A-Za-z0-9._-]*$")

# Family directory names documented in cells/README.md, plus the ledger family
# ids (tolerated so CELLS may use either spelling without a false failure).
README_FAMILIES = {
    "stack",
    "flow",
    "numeric",
    "hash",
    "checksig",
    "cms",
    "locktime",
    "segwit0",
    "taproot",
    "disabled",
    "limits",
    "whole",
}
LEDGER_FAMILIES = {family["id"] for family in builder.FAMILIES} | {
    "exec-verify",
    "push-encoding",
    "stack-ops",
    "control-flow",
    "hash-ops",
    "checkmultisig",
    "witness-v0",
    "disabled-opcodes",
    "tapscript-reimport",
    "policy-flags",
}


@dataclass
class Leg:
    """One tool's recorded outcome."""

    name: str
    state: str  # green | inapplicable | red
    detail: str = ""
    certificate: str | None = None
    result_path: Path | None = None


@dataclass
class Cell:
    """A validated-or-malformed cell directory."""

    rel: str
    path: Path
    spec: dict[str, Any] = field(default_factory=dict)
    scr_rows: list[str] = field(default_factory=list)
    legs: list[str] = field(default_factory=list)
    alive2: Leg = field(default_factory=lambda: Leg("alive2", "red"))
    saw: Leg = field(default_factory=lambda: Leg("saw", "red"))
    seam_note: str | None = None
    issues: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.issues


@dataclass
class RowState:
    """Computed ledger state for one SCR row."""

    status: str
    cells: list[str]
    alive2: dict | None
    saw: dict | None
    gap_note: str | None
    blocked: bool = False


# ---------------------------------------------------------------------------
# small parsing helpers
# ---------------------------------------------------------------------------


def _as_text(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


def _as_list(value: Any, *, split_words: bool = False) -> list[str] | None:
    """Return a clean list of strings, or None when the shape is wrong."""
    if isinstance(value, str):
        if not value.strip():
            return []
        if split_words:
            return [part for part in re.split(r"[^A-Za-z0-9]+", value) if part]
        return [part.strip() for part in re.split(r"[,;]", value) if part.strip()]
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    return None


def _front_matter(spec_path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        text = spec_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return None, f"cannot read spec.md: {exc}"
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, "spec.md: missing YAML front matter delimited by '---'"
    end = None
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            end = index
            break
    if end is None:
        return None, "spec.md: YAML front matter has no closing '---'"
    try:
        doc = yaml.safe_load("\n".join(lines[1:end]))
    except yaml.YAMLError as exc:
        return None, f"spec.md: front matter is not valid YAML: {exc}"
    if not isinstance(doc, dict):
        return None, "spec.md: front matter must be a YAML mapping"
    return doc, None


def _contract_hash(value: Any) -> str | None:
    if isinstance(value, str):
        match = HEX64_RE.search(value)
        if match:
            return match.group(0).lower()
    return None


def _load_contract_pin(pins_path: Path) -> str | None:
    if not pins_path.is_file():
        return None
    parser = configparser.ConfigParser(interpolation=None, allow_no_value=True)
    parser.optionxform = str
    try:
        with pins_path.open(encoding="utf-8") as handle:
            parser.read_file(handle)
        value = parser.get("contract", "hash", fallback="").strip()
    except (OSError, configparser.Error):
        return None
    match = HEX64_RE.search(value)
    return match.group(0).lower() if match else None


def _first_line(text: str, needle: re.Pattern[str]) -> str:
    for line in text.splitlines():
        if needle.search(line):
            return line.strip()[:200]
    return ""


# ---------------------------------------------------------------------------
# tool result parsing
# ---------------------------------------------------------------------------

ALIVE2_SUCCESS = "Transformation seems to be correct"
ALIVE2_ZERO_BAD = "0 incorrect transformations"
ALIVE2_FAILURE_RE = re.compile(
    r"(Transformation doesn't verify|Counterexample|Failed to translate|"
    r"ERROR:|\b[1-9]\d* incorrect transformations|"
    r"\b[1-9]\d* Alive2 errors)",
    re.IGNORECASE,
)
SAW_SUCCESS = "Proof succeeded"
SAW_FAILURE_RE = re.compile(
    r"Proof failed|saw: error|Failed to verify|Could not find definition|"
    r"Stack trace|Symbolic execution failed|Error during|Aborted|panic",
    re.IGNORECASE,
)
INAPPLICABLE_RE = re.compile(
    r"(\b(inapplicable|not applicable)\b|\bunsupported\b|\bnot supported\b|"
    r"\bcannot (handle|express|ingest|translate)\b|\btool[- ]gap\b)",
    re.IGNORECASE,
)


def _parse_leg(
    cell_dir: Path,
    name: str,
    notes: str,
    issues: list[str],
    warnings: list[str],
    rel: str,
) -> Leg:
    leg_dir = cell_dir / name
    leg_rel = f"{rel}/{name}"
    if not leg_dir.is_dir():
        issues.append(
            f"{leg_rel}/: directory missing (cells/README.md requires an alive2/ "
            "and saw/ attempt, or a recorded inapplicability)"
        )
        return Leg(name, "red", "directory missing")

    result_path = leg_dir / "result.txt"
    if not result_path.is_file():
        issues.append(f"{leg_rel}/result.txt: missing required raw tool output")
        return Leg(name, "red", "result.txt missing", result_path=result_path)
    try:
        raw = result_path.read_bytes()
        text = raw.decode("utf-8", errors="replace")
    except OSError as exc:
        issues.append(f"{leg_rel}/result.txt: cannot read: {exc}")
        return Leg(name, "red", "result.txt unreadable", result_path=result_path)
    if not text.strip():
        issues.append(f"{leg_rel}/result.txt: empty; a success marker is required")
        return Leg(name, "red", "result.txt empty", result_path=result_path)

    certificate = None
    cert_path = leg_dir / "certificate.sha256"
    if cert_path.is_file():
        try:
            cert_text = cert_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            issues.append(f"{leg_rel}/certificate.sha256: cannot read: {exc}")
            cert_text = ""
        digests = [m.group(0).lower() for m in HEX64_RE.finditer(cert_text)]
        actual = hashlib.sha256(raw).hexdigest()
        if not digests:
            issues.append(
                f"{leg_rel}/certificate.sha256: no 64-hex sha256 digest found "
                "(expected the sha256 of result.txt)"
            )
        elif actual not in digests:
            issues.append(
                f"{leg_rel}/certificate.sha256: digest does not match result.txt "
                f"(expected {actual}, found {', '.join(digests[:2])})"
            )
        else:
            certificate = actual
    else:
        warnings.append(
            f"{leg_rel}/certificate.sha256: missing (cells/README.md evidence "
            "standard expects a content-addressed output hash)"
        )

    if not (leg_dir / "run.sh").is_file():
        warnings.append(f"{leg_rel}/run.sh: missing (exact command not recorded)")

    # Cell runners prepend annotation lines beginning with "#".  A comment such
    # as "# expected: ... no 'Proof failed'" must not be mistaken for a tool
    # failure.  Classify only the tool output proper.
    tool_text = "\n".join(
        ln for ln in text.splitlines() if not ln.lstrip().startswith("#")
    )
    if name == "alive2":
        success = ALIVE2_SUCCESS in tool_text and ALIVE2_ZERO_BAD in tool_text
        success_detail = _first_line(tool_text, re.compile(re.escape(ALIVE2_SUCCESS)))
    else:
        success = SAW_SUCCESS in tool_text and not SAW_FAILURE_RE.search(tool_text)
        success_detail = _first_line(tool_text, re.compile(re.escape(SAW_SUCCESS)))
    failure = bool(ALIVE2_FAILURE_RE.search(tool_text) if name == "alive2" else SAW_FAILURE_RE.search(tool_text))
    inapplicable = INAPPLICABLE_RE.search(tool_text)
    inapp_detail = _first_line(tool_text, INAPPLICABLE_RE)

    if success and (failure or inapplicable):
        issues.append(
            f"{leg_rel}/result.txt: ambiguous result (success marker present "
            "together with a failure/inapplicability marker)"
        )
        return Leg(name, "red", "ambiguous result", None, result_path)

    if success:
        return Leg(
            name,
            "green",
            success_detail or "success marker recorded",
            certificate,
            result_path,
        )

    if inapplicable:
        if not notes.strip():
            issues.append(
                f"{leg_rel}/result.txt: inapplicable but notes.md is missing; the "
                "blocking IR feature and a TOOL finding id are required"
            )
            return Leg(name, "red", inapp_detail or "inapplicable", None, result_path)
        if not TOOL_FINDING_RE.search(notes):
            issues.append(
                f"{leg_rel}/result.txt: inapplicable but notes.md has no TOOL "
                "finding id (expected F-TOOL-nnn naming the blocking feature)"
            )
            return Leg(name, "red", inapp_detail or "inapplicable", None, result_path)
        if not inapp_detail:
            issues.append(
                f"{leg_rel}/result.txt: inapplicable marker has no feature text"
            )
            return Leg(name, "red", "inapplicable", None, result_path)
        return Leg(name, "inapplicable", inapp_detail, certificate, result_path)

    if failure:
        detail = _first_line(
            text,
            re.compile(
                "Transformation doesn't verify|Counterexample|Proof failed|ERROR:",
                re.IGNORECASE,
            ),
        )
        return Leg(name, "red", detail or "failure marker recorded", certificate, result_path)

    # Non-empty output that contains neither marker: this is a red cell, not a
    # green one. Keep the first non-empty line as the recorded reason.
    detail = next((line.strip()[:200] for line in text.splitlines() if line.strip()), "")
    return Leg(name, "red", detail or "no success marker", certificate, result_path)


# ---------------------------------------------------------------------------
# cell validation
# ---------------------------------------------------------------------------


def _validate_spec(
    cell_dir: Path,
    rel: str,
    contract_pin: str | None,
    known_rows: set[str],
    issues: list[str],
    warnings: list[str],
) -> tuple[dict[str, Any], list[str], list[str]]:
    spec_path = cell_dir / "spec.md"
    if not spec_path.is_file():
        issues.append(
            f"{rel}/spec.md: missing (expected YAML front matter with "
            + ", ".join(REQUIRED_SPEC_FIELDS)
            + ")"
        )
        return {}, [], []

    spec, error = _front_matter(spec_path)
    if error or spec is None:
        issues.append(f"{rel}/: {error}")
        return {}, [], []

    missing = [name for name in REQUIRED_SPEC_FIELDS if name not in spec]
    if missing:
        issues.append(
            f"{rel}/spec.md: missing required front-matter field(s): "
            f"{', '.join(missing)} (expected {', '.join(REQUIRED_SPEC_FIELDS)})"
        )

    for name in ("precondition", "postcondition", "trust_note"):
        value = spec.get(name)
        if name in spec and (not isinstance(value, str) or not value.strip()):
            issues.append(f"{rel}/spec.md: `{name}` must be a non-empty string")

    direction = spec.get("direction")
    if "direction" in spec:
        directions = _as_list(direction)
        if not directions:
            issues.append(
                f"{rel}/spec.md: `direction` must be one of L ⊑ C, C ⊑ L, "
                "R ⊑ C, C ⊑ R (or a non-empty list of them)"
            )

    patches = spec.get("patches")
    if "patches" in spec:
        if not isinstance(patches, (str, list)) or (
            isinstance(patches, str) and not patches.strip()
        ) or (isinstance(patches, list) and not patches):
            issues.append(
                f"{rel}/spec.md: `patches` must list patch ids or the string `none`"
            )

    contract = spec.get("contract")
    cell_hash = _contract_hash(contract)
    if "contract" in spec:
        if cell_hash is None:
            issues.append(
                f"{rel}/spec.md: `contract` must contain the pinned 64-hex "
                "sha256 from PINS.lock [contract] hash"
            )
        elif contract_pin and cell_hash != contract_pin:
            issues.append(
                f"{rel}/spec.md: contract hash {cell_hash} does not match "
                f"PINS.lock [contract] hash {contract_pin}; re-pin makes a "
                "new result"
            )

    legs_raw = _as_list(spec.get("legs"), split_words=True)
    if "legs" in spec:
        if not legs_raw:
            issues.append(
                f"{rel}/spec.md: `legs` must name the compared legs (subset of C, L, R)"
            )
            legs_raw = []
        else:
            bad = [leg for leg in legs_raw if leg not in {"C", "L", "R"}]
            if bad:
                issues.append(
                    f"{rel}/spec.md: `legs` contains unknown leg(s): {', '.join(bad)}"
                )
            if len(set(legs_raw)) < 2:
                issues.append(
                    f"{rel}/spec.md: `legs` must name at least two of C, L, R"
                )
    else:
        legs_raw = []

    rows_raw = spec.get("scr_rows")
    rows = _as_list(rows_raw)
    if "scr_rows" in spec:
        if rows is None:
            issues.append(
                f"{rel}/spec.md: `scr_rows` must be a list of SCR ids"
            )
            rows = []
        elif not rows:
            warnings.append(f"{rel}/spec.md: `scr_rows` is empty; no ledger row is covered")
        else:
            for rule_id in rows:
                if not SCR_RE.match(rule_id):
                    issues.append(
                        f"{rel}/spec.md: malformed scr_rows entry {rule_id!r} "
                        "(expected SCR-nnn)"
                    )
                elif rule_id not in known_rows:
                    issues.append(
                        f"{rel}/spec.md: scr_rows entry {rule_id} is not in "
                        "spec/db/rules.yaml"
                    )
    else:
        rows = []

    if cell_dir.name and not CELL_ID_RE.match(cell_dir.name):
        warnings.append(
            f"{rel}/: cell id does not match the documented "
            "C-L-* / C-R-* / L-R-* naming pattern"
        )
    if cell_dir.parent.name not in (README_FAMILIES | LEDGER_FAMILIES):
        warnings.append(
            f"{rel}/: family directory {cell_dir.parent.name!r} is not in "
            "cells/README.md or the ledger family list"
        )

    return spec, rows, legs_raw


def load_cell(
    cell_dir: Path,
    cells_dir: Path,
    known_rows: set[str],
    contract_pin: str | None,
) -> Cell:
    rel = cell_dir.relative_to(cells_dir).as_posix()
    cell = Cell(rel=rel, path=cell_dir)
    spec, rows, legs = _validate_spec(
        cell_dir,
        rel,
        contract_pin,
        known_rows,
        cell.issues,
        cell.warnings,
    )
    cell.spec = spec
    cell.scr_rows = rows
    cell.legs = legs

    notes = ""
    notes_path = cell_dir / "notes.md"
    if notes_path.is_file():
        try:
            notes = notes_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            notes = ""

    cell.alive2 = _parse_leg(cell_dir, "alive2", notes, cell.issues, cell.warnings, rel)
    cell.saw = _parse_leg(cell_dir, "saw", notes, cell.issues, cell.warnings, rel)

    seam = spec.get("unjudged_seam")
    if seam is not None:
        if not isinstance(seam, str) or not seam.strip():
            cell.issues.append(
                f"{rel}/spec.md: `unjudged_seam` must be a non-empty reason string"
            )
        else:
            if cell.alive2.state != "inapplicable" or cell.saw.state != "inapplicable":
                cell.issues.append(
                    f"{rel}/spec.md: `unjudged_seam` declared but both tool legs "
                    "are not filed inapplicable (a seam cell cannot claim a "
                    "green or red tool result)"
                )
            if (
                "DECISION-lax-ecdsa.md" not in notes
                and "DECISION-lax-ecdsa.md" not in seam
                and not re.search(r"\bF-[A-Z]+-\d+\b", notes + "\n" + seam)
            ):
                cell.issues.append(
                    f"{rel}/notes.md: unjudged-seam cell must cite "
                    "docs/DECISION-lax-ecdsa.md or a named finding id "
                    "(e.g. F-DIV-001, E4:F-TOOL-001)"
                )
            if not re.search(r"\bF-[A-Z]+-\d+\b", notes):
                cell.issues.append(
                    f"{rel}/notes.md: unjudged-seam cell must cite a finding id "
                    "(expected F-TOOL-nnn or F-<AREA>-nnn)"
                )
            cell.seam_note = seam.strip()
    return cell


def scan_cells(
    cells_dir: Path,
    known_rows: set[str] | None = None,
    contract_pin: str | None = None,
) -> tuple[list[Cell], list[str]]:
    """Scan cells/<family>/<cell>/ deterministically; return (cells, issues)."""
    cells: list[Cell] = []
    issues: list[str] = []
    if known_rows is None:
        known_rows = set()
    if contract_pin is None:
        contract_pin = _load_contract_pin(DEFAULT_PINS)
    if not cells_dir.is_dir():
        return cells, [f"{cells_dir}: cells directory missing"]

    for family_dir in sorted(p for p in cells_dir.iterdir() if p.is_dir()):
        if family_dir.name.startswith((".", "_")):
            continue
        for cell_dir in sorted(p for p in family_dir.iterdir() if p.is_dir()):
            if cell_dir.name.startswith((".", "_")):
                continue
            if cell_dir.name in {"alive2", "saw", "build", "logs", "witnesses", "behavior"}:
                continue
            cell = load_cell(cell_dir, cells_dir, known_rows, contract_pin)
            cells.append(cell)
            issues.extend(cell.issues)
    return cells, issues


# ---------------------------------------------------------------------------
# status derivation
# ---------------------------------------------------------------------------


def _leg_text(leg: Leg) -> str:
    if leg.state == "green":
        return "green"
    detail = leg.detail.strip()[:140]
    return f"{leg.state}" + (f" ({detail})" if detail else "")


def _partial_coverage(cell: Cell, rule_id: str) -> bool:
    """A cell that says it covers only part of an SCR row cannot green it.

    Coverage may be a per-row bullet list.  In that case only the named row's
    bullet is consulted; a partial bullet for one row must not demote the
    other rows the same cell fully covers.
    """
    cov = cell.spec.get("scr_row_coverage")
    if not isinstance(cov, str):
        return False
    text = cov.strip()
    if text.lower().startswith("partial"):
        return True
    for match in re.finditer(
        r"(?ms)^\s*-\s*(SCR-\d+)\b(.*?)(?=^\s*-\s*SCR-\d+\b|\Z)", text
    ):
        if match.group(1) == rule_id and "partial" in match.group(2).lower():
            return True
    return False


def _row_coverage_text(cell: Cell, rule_id: str) -> str:
    """Return the coverage bullet for one row, not sibling-row bullets."""
    cov = cell.spec.get("scr_row_coverage")
    if not isinstance(cov, str):
        return ""
    text = cov.strip()
    for match in re.finditer(
        r"(?ms)^\s*-\s*(SCR-\d+)\b(.*?)(?=^\s*-\s*SCR-\d+\b|\Z)", text
    ):
        if match.group(1) == rule_id:
            return match.group(0).strip()
    # No per-row bullet: keep the first paragraph, not a wall of sibling data.
    out = re.split(r"\n\s*\n", text, maxsplit=1)[0].strip()
    if len(out) < 80:
        notes = cell.path / "notes.md"
        if notes.is_file():
            m = re.search(
                r"(?ms)^##\s+Why partial\s*(.*?)(?=^##\s|\Z)",
                notes.read_text(errors="replace"),
            )
            if m:
                return re.sub(r"\s+", " ", m.group(1)).strip()
    return out


def _green_record(cell: Cell, leg: Leg) -> dict[str, Any]:
    return {
        "result": "green",
        "cell": cell.rel,
        "certificate": leg.certificate,
        "note": leg.detail or f"{leg.name} success marker recorded",
    }


def compute_row_states(
    cells: list[Cell], row_ids: set[str]
) -> tuple[dict[str, RowState], dict[str, list[str]]]:
    """Derive row states from cell records. Never promotes without green legs."""
    by_row: dict[str, list[Cell]] = {}
    blocked: dict[str, list[str]] = {}
    for cell in cells:
        for rule_id in cell.scr_rows:
            if rule_id not in row_ids:
                continue
            if cell.issues:
                blocked.setdefault(rule_id, []).append(cell.rel)
            else:
                by_row.setdefault(rule_id, []).append(cell)

    states: dict[str, RowState] = {}
    for rule_id in sorted(row_ids):
        row_cells = sorted(by_row.get(rule_id, []), key=lambda item: item.rel)
        blocked_cells = sorted(blocked.get(rule_id, []))
        if blocked_cells:
            # A malformed record is never repaired or guessed around. Leave the
            # row planned until CELLS fixes the record.
            states[rule_id] = RowState(
                status="planned",
                cells=[],
                alive2=None,
                saw=None,
                gap_note=None,
                blocked=True,
            )
            continue
        if not row_cells:
            continue

        red = any(
            cell.alive2.state == "red" or cell.saw.state == "red"
            for cell in row_cells
        )
        # Cells that declare partial row coverage may contribute evidence but
        # never discharge the whole SCR row.
        alive2_green = [
            cell
            for cell in row_cells
            if cell.alive2.state == "green" and not _partial_coverage(cell, rule_id)
        ]
        saw_green = [
            cell
            for cell in row_cells
            if cell.saw.state == "green" and not _partial_coverage(cell, rule_id)
        ]
        partial_green = [
            cell
            for cell in row_cells
            if (cell.alive2.state == "green" or cell.saw.state == "green")
            and _partial_coverage(cell, rule_id)
        ]
        seam_cells = [cell for cell in row_cells if cell.seam_note]

        if red:
            status = "gap"
        elif seam_cells and not alive2_green and not saw_green:
            status = "unjudged-seam"
        elif alive2_green and saw_green:
            status = "both-green"
        elif alive2_green:
            status = "alive2-green"
        elif saw_green:
            status = "saw-green"
        else:
            status = "gap"

        if status == "gap" and partial_green and not red:
            notes = []
            for cell in partial_green:
                cov = _row_coverage_text(cell, rule_id)
                notes.append(f"{cell.rel}: {cov}")
            note = "auto(cells): partial row coverage; " + "; ".join(notes)
            states[rule_id] = RowState(
                status="gap",
                cells=[cell.rel for cell in partial_green],
                alive2=None,
                saw=None,
                gap_note=note[:1200],
            )
            continue

        if status == "unjudged-seam":
            details = []
            for cell in seam_cells:
                details.append(f"{cell.rel}: {cell.seam_note}")
            note = (
                "auto(cells): unjudged seam: "
                + "; ".join(details)
            )
            states[rule_id] = RowState(
                status=status,
                cells=[cell.rel for cell in seam_cells],
                alive2=None,
                saw=None,
                gap_note=note[:1200],
            )
            continue

        if status in GREEN_STATUSES:
            if status == "both-green":
                both = [
                    cell
                    for cell in row_cells
                    if cell.alive2.state == "green"
                    and cell.saw.state == "green"
                    and not _partial_coverage(cell, rule_id)
                ]
                alive2_cell = both[0] if both else alive2_green[0]
                saw_cell = both[0] if both else saw_green[0]
                green_cells = [
                    cell.rel
                    for cell in row_cells
                    if cell.alive2.state == "green" or cell.saw.state == "green"
                ]
            elif status == "alive2-green":
                alive2_cell = alive2_green[0]
                saw_cell = None
                green_cells = [cell.rel for cell in alive2_green]
            else:
                alive2_cell = None
                saw_cell = saw_green[0]
                green_cells = [cell.rel for cell in saw_green]
            states[rule_id] = RowState(
                status=status,
                cells=sorted(green_cells),
                alive2=_green_record(alive2_cell, alive2_cell.alive2)
                if alive2_cell
                else None,
                saw=_green_record(saw_cell, saw_cell.saw) if saw_cell else None,
                gap_note=None,
            )
            continue

        details = []
        for cell in row_cells:
            details.append(
                f"{cell.rel}: alive2={_leg_text(cell.alive2)}; "
                f"saw={_leg_text(cell.saw)}"
            )
        note = "auto(cells): " + "; ".join(details) + "; no cell discharges this row"
        states[rule_id] = RowState(
            status="gap",
            cells=[cell.rel for cell in row_cells],
            alive2=None,
            saw=None,
            gap_note=note[:1200],
        )
    return states, blocked


# ---------------------------------------------------------------------------
# ledger application
# ---------------------------------------------------------------------------


def _set_fields(row: dict, state: RowState) -> None:
    row["status"] = state.status
    row["cells"] = list(state.cells)
    row["alive2"] = state.alive2
    row["saw"] = state.saw
    row["gap_note"] = state.gap_note


def _clear_to_planned(row: dict) -> None:
    row["status"] = "planned"
    row["cells"] = []
    row["alive2"] = None
    row["saw"] = None
    row["gap_note"] = None


def apply_states(
    ledger: dict[str, Any],
    states: dict[str, RowState],
    from_cells: bool,
) -> tuple[list[str], list[str]]:
    """Apply computed states to ledger rows. Returns (changes, warnings)."""
    changes: list[str] = []
    warnings: list[str] = []
    for row in ledger.get("rows", []):
        rule_id = str(row.get("id"))
        current = str(row.get("status"))
        state = states.get(rule_id)

        if state is not None:
            if state.blocked:
                if current != "planned" or row.get("cells"):
                    _clear_to_planned(row)
                    changes.append(
                        f"{rule_id}: {current} -> planned (malformed cell record)"
                    )
                else:
                    row["status"] = "planned"
                    row["cells"] = []
                    row["alive2"] = None
                    row["saw"] = None
                    row["gap_note"] = None
                continue
            before = {name: row.get(name) for name in builder.STATE_FIELDS}
            _set_fields(row, state)
            if before != {name: row.get(name) for name in builder.STATE_FIELDS}:
                changes.append(
                    f"{rule_id}: {current} -> {state.status} "
                    f"({len(state.cells)} cell(s))"
                )
            continue

        # No valid cell covers this row.
        if current in FILED_STATUSES:
            note = row.get("gap_note")
            if isinstance(note, str) and note.strip():
                continue
            _clear_to_planned(row)
            changes.append(
                f"{rule_id}: {current} -> planned (filed status has no note)"
            )
            warnings.append(
                f"{rule_id}: {current} had no gap_note; filed statuses require one"
            )
            continue

        if current in GREEN_STATUSES:
            _clear_to_planned(row)
            changes.append(
                f"{rule_id}: {current} -> planned (no valid cell supports green)"
            )
            warnings.append(
                f"{rule_id}: demoted unsupported green; a green row requires "
                "a validated cell with a recorded success marker"
            )
            continue

        if from_cells:
            if current != "planned":
                warnings.append(
                    f"{rule_id}: unknown status {current!r} left for coverage_report"
                )
            if current == "planned" and row.get("cells"):
                row["cells"] = []
                row["alive2"] = None
                row["saw"] = None
                changes.append(f"{rule_id}: cleared stale cell list on planned row")
    return changes, warnings


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _row_diff(old_text: str, new_ledger: dict[str, Any]) -> list[str]:
    try:
        old = yaml.safe_load(old_text) or {}
    except yaml.YAMLError:
        return ["ledger is unparseable; full rewrite required"]
    old_rows = {str(row.get("id")): row for row in old.get("rows", []) if isinstance(row, dict)}
    new_rows = {str(row.get("id")): row for row in new_ledger.get("rows", [])}
    diffs = []
    for rule_id in sorted(set(old_rows) | set(new_rows)):
        before = old_rows.get(rule_id, {})
        after = new_rows.get(rule_id, {})
        fields = []
        for name in builder.STATE_FIELDS:
            if before.get(name) != after.get(name):
                fields.append(f"{name}={after.get(name)!r}")
        if fields:
            diffs.append(f"{rule_id}: " + ", ".join(fields))
    return diffs


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Derive SCR ledger status from validated cell records"
    )
    parser.add_argument(
        "--from-cells",
        action="store_true",
        help=(
            "authoritative reconciliation: also demote green rows with no valid "
            "cell, clear stale cell lists on planned rows, and drop filed "
            "statuses without notes"
        ),
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="no writes; exit 1 if the on-disk ledger differs from the derived text",
    )
    parser.add_argument(
        "--cells-dir",
        type=Path,
        default=DEFAULT_CELLS_DIR,
        help="cells root (default: spec/equiv/cells)",
    )
    parser.add_argument(
        "--ledger",
        type=Path,
        default=DEFAULT_LEDGER,
        help="ledger path (default: spec/db/equiv-cells.yaml)",
    )
    parser.add_argument(
        "--pins",
        type=Path,
        default=DEFAULT_PINS,
        help="PINS.lock path (default: spec/equiv/PINS.lock)",
    )
    args = parser.parse_args(argv)

    ledger = builder.build(ledger_path=args.ledger)
    row_ids = {str(row.get("id")) for row in ledger.get("rows", [])}
    contract_pin = _load_contract_pin(args.pins)
    cells, scan_issues = scan_cells(args.cells_dir, row_ids, contract_pin)
    states, blocked = compute_row_states(cells, row_ids)

    for cell in cells:
        for warning in cell.warnings:
            sys.stderr.write(f"update_ledger.py: WARN  {warning}\n")

    changes, apply_warnings = apply_states(ledger, states, args.from_cells)
    for warning in apply_warnings:
        sys.stderr.write(f"update_ledger.py: WARN  {warning}\n")

    text = builder.dump(ledger)
    malformed = [cell for cell in cells if cell.issues]
    status_counts: dict[str, int] = {}
    for row in ledger.get("rows", []):
        status = str(row.get("status"))
        status_counts[status] = status_counts.get(status, 0) + 1
    green = sum(status_counts.get(status, 0) for status in GREEN_STATUSES)

    print("ledger derivation")
    print("=================")
    print(f"ledger:  {args.ledger}")
    print(f"cells:   {args.cells_dir}")
    print(f"cells scanned: {len(cells)} (valid {len(cells) - len(malformed)}, malformed {len(malformed)})")
    print(f"rows:    {len(row_ids)}")
    print(
        "statuses: "
        + ", ".join(f"{name}={status_counts.get(name, 0)}" for name in builder.STATUSES)
    )
    print(f"green rows: {green}; blocked rows: {len(blocked)}")
    if changes:
        print(f"changes: {len(changes)}")
        for change in changes[:40]:
            print(f"  - {change}")
        if len(changes) > 40:
            print(f"  ... (+{len(changes) - 40} more)")
    else:
        print("changes: 0")

    if scan_issues:
        print(f"malformed cell record(s): {len(scan_issues)}", file=sys.stderr)
        for issue in scan_issues:
            print(f"  - {issue}", file=sys.stderr)
        print(
            "expected schema: spec.md front matter with "
            + ", ".join(REQUIRED_SPEC_FIELDS)
            + "; alive2/result.txt and saw/result.txt with a raw success "
            "marker; inapplicable legs require notes.md with F-TOOL-nnn. "
            "Affected rows were left planned.",
            file=sys.stderr,
        )

    if args.check:
        current = (
            args.ledger.read_text(encoding="utf-8") if args.ledger.is_file() else ""
        )
        if current != text:
            sys.stderr.write(
                f"update_ledger.py: DRIFT  {args.ledger} differs from the "
                "cell-derived ledger\n"
            )
            for diff in _row_diff(current, ledger)[:40]:
                sys.stderr.write(f"  - {diff}\n")
            return 1
        print(f"check: {args.ledger} is up to date")
        return 1 if scan_issues else 0

    args.ledger.parent.mkdir(parents=True, exist_ok=True)
    args.ledger.write_text(text, encoding="utf-8")
    print(f"wrote: {args.ledger}")
    return 1 if scan_issues else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
