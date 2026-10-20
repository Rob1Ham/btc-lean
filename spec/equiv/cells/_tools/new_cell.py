#!/usr/bin/env python3
"""Create a deterministic E1 cell skeleton.

The tool writes only under `spec/equiv/cells/<id>/` and refuses `_redteam`.
It creates the required evidence directories and thin wrappers that call the
shared bounded-leaf runners in `cells/_tools/gate/`.  It does not run either
tool and does not invent proof results.

Example:

  python3 cells/_tools/new_cell.py \
    --id e1-stack/example \
    --fn cell_example \
    --spk 51527c5187 \
    --expected 0x0000000000a04a01 \
    --script "OP_1 OP_2 OP_SWAP OP_1 OP_EQUAL" \
    --mutant "OP_SWAP becomes a no-op"

Exit codes: 0 created, 2 usage/refused existing file, 3 bad id.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # spec/equiv/cells/_tools
CELLS = HERE.parent                              # spec/equiv/cells
EQ = CELLS.parent                                # spec/equiv
ROOT = EQ.parents[1]                             # repository root

CONTRACT_FILES = [
    EQ / "contract" / "ABI.md",
    EQ / "contract" / "tape.md",
    EQ / "contract" / "error_kind.h",
    EQ / "contract" / "corpus_schema.md",
]


def contract_hash() -> str:
    h = hashlib.sha256()
    for f in CONTRACT_FILES:
        h.update(f.read_bytes())
    return h.hexdigest()


def repo_head() -> str:
    # Keep this deterministic and local; do not shell out to git.
    git = ROOT / ".git"
    if not git.is_dir():
        return "unknown"
    try:
        head = (git / "HEAD").read_text().strip()
        if head.startswith("ref: "):
            ref = git / head[5:]
            if ref.is_file():
                return ref.read_text().strip()
        return head
    except OSError:
        return "unknown"


def validate_id(cell_id: str) -> Path:
    if not cell_id or cell_id.startswith("/") or ".." in Path(cell_id).parts:
        raise ValueError("--id must be a relative path under cells/")
    parts = Path(cell_id).parts
    if not parts or parts == (".",):
        raise ValueError("--id must name a directory under cells/")
    if parts[0] in {"_redteam", "_tools"}:
        raise ValueError("--id may not target _redteam or _tools")
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", cell_id):
        raise ValueError("--id contains unsupported characters")
    dest = (CELLS / cell_id).resolve()
    if CELLS.resolve() not in dest.parents and dest != CELLS.resolve():
        raise ValueError("--id escapes cells/")
    return dest


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True, help="e.g. e1-stack/example")
    ap.add_argument("--fn", help="C symbol, default cell_<sanitised id>")
    ap.add_argument("--spk", required=True, help="scriptPubKey hex, no spaces")
    ap.add_argument("--expected", default="0x0",
                    help="packed observable constant (TODO if omitted)")
    ap.add_argument("--script", default="TODO",
                    help="human-readable opcode sequence")
    ap.add_argument("--mutant", default="TODO", help="expected mutation")
    ap.add_argument("--force", action="store_true",
                    help="overwrite an existing scaffold")
    a = ap.parse_args()

    try:
        dest = validate_id(a.id)
    except ValueError as e:
        print(f"new_cell: {e}", file=sys.stderr)
        return 3

    spk = a.spk.replace(" ", "").lower()
    if len(spk) % 2 or not re.fullmatch(r"[0-9a-f]*", spk):
        print("new_cell: --spk must be even-length hex", file=sys.stderr)
        return 3

    fn = a.fn or ("cell_" + re.sub(r"[^A-Za-z0-9]+", "_", a.id).strip("_"))
    expected = a.expected if a.expected.startswith("0x") else "0x" + a.expected
    if not re.fullmatch(r"0x[0-9a-fA-F]+", expected):
        print("new_cell: --expected must be a hex constant", file=sys.stderr)
        return 3

    targets = [
        dest / "spec.md",
        dest / "notes.md",
        dest / "alive2" / "run.sh",
        dest / "saw" / "run.sh",
        dest / "behavior" / "run.sh",
    ]
    if not a.force:
        existing = [p for p in targets if p.exists()]
        if existing:
            print("new_cell: refusing to overwrite:", file=sys.stderr)
            for p in existing:
                print(f"  {p.relative_to(ROOT)}", file=sys.stderr)
            print("use --force to replace the scaffold", file=sys.stderr)
            return 2

    for p in targets:
        p.parent.mkdir(parents=True, exist_ok=True)

    contract = contract_hash()
    head = repo_head()
    (dest / "spec.md").write_text(f"""# Cell {a.id}

contract: {contract}
repo_head: {head}
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: {a.id}
witness_spk: `{spk}`
script: `{a.script}`
precondition: TODO — exact tape subset, flags, scriptSig, bounds.
postcondition: TODO — verdict/error_kind and observable relation.
direction: L ⊑ C
direction: C ⊑ L
tool_status: unbuilt (scaffold only; no green claim)
scr_rows: TODO
scr_row_coverage: TODO — never claim a whole SCR row from a success-only witness.
patches: none
trust_note: TODO — bounded leaf, source provenance, tool limits, open findings.
evidence: alive2/, saw/, behavior/
mutant: {a.mutant}
mutant_site: TODO — twin/ops_ir.py preferred; generated twin.cpp alone may not be observed.
""")

    (dest / "notes.md").write_text(f"""# Notes — {a.id}

Status: `unbuilt` scaffold.  No tool has been run and no green claim is made.

Witness: `{spk}` (`{a.script}`).

Next action: fill `spec.md`, run `alive2/run.sh`, `saw/run.sh`, and
`behavior/run.sh`, then replace this note with the raw results, exact tool
versions, blockers, and certificate hashes.  A behavioral match alone is not
proof evidence.
""")

    (dest / "alive2" / "run.sh").write_text(f"""#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_alive2.sh" "$CELL_DIR" "{fn}" "{a.id}"
""")
    (dest / "saw" / "run.sh").write_text(f"""#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_saw.sh" "$CELL_DIR" "{fn}" "{a.id}" "{expected}"
""")
    (dest / "behavior" / "run.sh").write_text(f"""#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_behavior.sh" "$CELL_DIR" "{a.id}" "{spk}"
""")
    for p in (dest / "alive2" / "run.sh", dest / "saw" / "run.sh",
              dest / "behavior" / "run.sh"):
        os.chmod(p, 0o755)

    print(f"created cells/{a.id}/")
    for p in targets:
        print(f"  {p.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
