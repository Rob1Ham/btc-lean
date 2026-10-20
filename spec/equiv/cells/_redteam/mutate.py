#!/usr/bin/env python3
"""Apply one named textual mutation to an explicit source file.

This is the ONLY supported way to apply a mutation from
`cells/_redteam/MUTATIONS.md`. It:

  * refuses to run without an explicit --target and --mutation;
  * refuses symlinks, non-files, `.git/` targets, and `patches/` targets;
  * requires an exact, unique anchor and checks the expected occurrence count;
  * writes a unified diff and a mutant record JSON under
    `cells/_redteam/mutants/` with before/after sha256;
  * supports --dry-run (no write, no record) and --revert RECORD;
  * refuses to apply an uncalibrated entry.

Most catalogue entries are intentionally uncalibrated: the first gate cells
are not yet green, and remaining twin/Core anchors must be calibrated against
the actual `twin/build/twin.cpp` and a patched Core copy. The `M-E1-001` and
`M-E1-002` twin anchors are calibrated against `twin/ops_ir.py`. Fill
`find`/`replace` for a variant after the source lands, then run `--dry-run`
before applying. Do not hand-edit a source to "calibrate" a mutation.

Exit codes:
  0  success (or --list)
  2  usage error
  3  refusal / validation failure
  4  mutation not calibrated / variant not applicable
  5  record already exists / output collision

Examples:
  python3 cells/_redteam/mutate.py --list
  python3 cells/_redteam/mutate.py --target /path/to/twin.cpp \
      --mutation M-E1-001 --target-kind twin --dry-run
  python3 cells/_redteam/mutate.py --target /path/to/twin.cpp \
      --mutation M-E1-001 --target-kind twin
  python3 cells/_redteam/mutate.py --revert cells/_redteam/mutants/<record>.json
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA = "redteam-mutant-v1"
CATALOGUE_VERSION = "0.2-wave64"
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_OUT_DIR = SCRIPT_DIR / "mutants"
PINS_PATH = SCRIPT_DIR.parents[1] / "PINS.lock"  # spec/equiv/PINS.lock
REPO_ROOT = SCRIPT_DIR.parents[3]                # btc-lean-public


# --------------------------------------------------------------------------
# Catalogue
# --------------------------------------------------------------------------

def _variant(anchor_hint: str) -> dict[str, Any]:
    """An uncalibrated variant. `find`/`replace` are filled at E1."""
    return {
        "find": None,
        "replace": None,
        "expect_count": 1,
        "anchor_hint": anchor_hint,
        "status": "uncalibrated",
    }


def _m(
    mutant_id: str,
    family: str,
    description: str,
    expected_cells: list[str],
    catchers: list[str],
    *,
    twin_anchor: str,
    core_anchor: str,
    twin: bool = True,
    core: bool = True,
    e4_anchor: str | None = None,
    e3_anchor: str | None = None,
) -> dict[str, Any]:
    variants: dict[str, Any] = {}
    if twin:
        variants["twin"] = _variant(twin_anchor)
    if core:
        variants["core-copy"] = _variant(core_anchor)
    if e4_anchor:
        variants["e4-cell"] = _variant(e4_anchor)
    if e3_anchor:
        variants["e3-cell"] = _variant(e3_anchor)
    return {
        "id": mutant_id,
        "family": family,
        "description": description,
        "expected_failing_cells": expected_cells,
        "catchers": catchers,
        "variants": variants,
    }


CATALOGUE: list[dict[str, Any]] = [
    # ---- E1: stack ops + push surface -----------------------------------
    _m(
        "M-E1-001", "e1-stack",
        "OP_SWAP becomes a no-op (top two not exchanged)",
        ["cells/e1-stack/swap-order"], ["alive2", "saw"],
        twin_anchor="twin OP_SWAP / swap top two",
        core_anchor="interpreter.cpp: case OP_SWAP",
    ),
    _m(
        "M-E1-002", "e1-stack",
        "OP_DUP duplicates the second-from-top item, not top",
        ["cells/e1-stack/dup-order"], ["alive2", "saw"],
        twin_anchor="twin OP_DUP",
        core_anchor="interpreter.cpp: case OP_DUP",
    ),
    _m(
        "M-E1-003", "e1-stack",
        "OP_ROT rotates in the opposite direction",
        ["cells/e1-stack/rot-direction"], ["alive2", "saw"],
        twin_anchor="twin OP_ROT / rotate three",
        core_anchor="interpreter.cpp: case OP_ROT",
    ),
    _m(
        "M-E1-004", "e1-stack",
        "TOALTSTACK/FROMALTSTACK swapped (or TOALT acts on the main stack)",
        ["cells/e1-altstack/roundtrip"], ["alive2", "saw"],
        twin_anchor="twin altstack transfer",
        core_anchor="interpreter.cpp: OP_TOALTSTACK / OP_FROMALTSTACK",
    ),
    _m(
        "M-E1-005", "e1-push",
        "MAX_SCRIPT_ELEMENT_SIZE 520 -> 521 (or 520 rejected)",
        ["cells/e1-push/size-boundary"], ["alive2", "saw", "differential"],
        twin_anchor="twin push-size limit",
        core_anchor="interpreter.cpp: MAX_SCRIPT_ELEMENT_SIZE / GetScriptOp",
    ),
    _m(
        "M-E1-006", "e1-stack",
        "OP_DEPTH returns depth - 1",
        ["cells/e1-stack/depth-count"], ["alive2", "saw"],
        twin_anchor="twin OP_DEPTH",
        core_anchor="interpreter.cpp: case OP_DEPTH",
    ),
    _m(
        "M-E1-007", "e1-stack",
        "OP_PICK/OP_ROLL index off by one (selects neighbor)",
        ["cells/e1-stack/pick-depth"], ["alive2", "saw"],
        twin_anchor="twin OP_PICK / OP_ROLL depth",
        core_anchor="interpreter.cpp: OP_PICK / OP_ROLL",
    ),
    _m(
        "M-E1-008", "e1-stack",
        "OP_2DROP arity guard dropped (accepts depth < 2)",
        ["cells/stack-ops/C-L-arity"], ["alive2", "saw"],
        twin_anchor="twin OP_2DROP",
        core_anchor="interpreter.cpp:888-895 OP_2DROP guard",
    ),

    # ---- E2: flow, numeric, hash ----------------------------------------
    _m(
        "M-E2-001", "e2-flow",
        "CastToBool treats negative zero (0x80) as true",
        ["cells/e2-flow/negzero-if"], ["alive2", "saw", "differential"],
        twin_anchor="twin CastToBool / castToBool",
        core_anchor="interpreter.cpp: CastToBool",
    ),
    _m(
        "M-E2-002", "e2-numeric",
        "CScriptNum operand bound 4 -> 5 bytes",
        ["cells/e2-numeric/num-4byte-boundary"], ["alive2", "saw"],
        twin_anchor="twin CScriptNum decode / nMaxNumSize",
        core_anchor="interpreter.cpp: CScriptNum nMaxNumSize",
    ),
    _m(
        "M-E2-003", "e2-numeric",
        "CScriptNum result truncated/wrapped to 4 bytes instead of emitting the 5-byte sum",
        ["cells/e2-numeric/result-5byte"], ["alive2", "saw", "differential"],
        twin_anchor="twin CScriptNum result encoding / setVch",
        core_anchor="interpreter.cpp: CScriptNum result encoding",
    ),
    _m(
        "M-E2-004", "e2-numeric",
        "OP_WITHIN max boundary is inclusive (<=) instead of exclusive (<)",
        ["cells/e2-numeric/within-boundary"], ["alive2", "saw"],
        twin_anchor="twin OP_WITHIN comparison",
        core_anchor="interpreter.cpp: case OP_WITHIN",
    ),
    _m(
        "M-E2-005", "e2-flow",
        "OP_COUNT threshold 201 -> 200 (off-by-one at the budget)",
        ["cells/e2-flow/opcount-201"], ["alive2", "saw"],
        twin_anchor="twin MAX_OPS_PER_SCRIPT / opCount check",
        core_anchor="interpreter.cpp: MAX_OPS_PER_SCRIPT check",
    ),
    _m(
        "M-E2-006", "e2-flow",
        "OP_ENDIF without OP_IF is accepted (unbalanced conditional)",
        ["cells/e2-flow/unbalanced-endif"], ["saw", "error-enum", "differential"],
        twin_anchor="twin conditional balance check / OP_ENDIF",
        core_anchor="interpreter.cpp: unbalanced conditional path",
    ),
    _m(
        "M-E2-007", "e2-hash",
        "HASH160 composition swapped or hash opcode dispatch swapped",
        ["cells/e2-hash/hash160-vector"], ["saw", "differential"],
        twin_anchor="twin HASH160 / hash dispatch",
        core_anchor="interpreter.cpp: HASH160 / hash opcode",
    ),
    _m(
        "M-E2-008", "e2-flow",
        "CheckLockTime comparison off by one at equality (or skips type check)",
        ["cells/e2-flow/cltv-equal"], ["alive2", "saw"],
        twin_anchor="twin CheckLockTime comparison",
        core_anchor="interpreter.cpp: CheckLockTime",
    ),
    _m(
        "M-E2-009", "e2-flow",
        "stack-size limit 1000 -> 1001 (or wrong check placement)",
        ["cells/e2-flow/stacksize-1000"], ["alive2", "saw"],
        twin_anchor="twin MAX_STACK_SIZE / stack size check",
        core_anchor="interpreter.cpp: MAX_STACK_SIZE check",
    ),
    _m(
        "M-E2-010", "e2-flow",
        "OP_RETURN succeeds instead of returning OP_RETURN error",
        ["cells/control-flow/C-L-nop-return"], ["alive2", "saw"],
        twin_anchor="twin OP_RETURN",
        core_anchor="interpreter.cpp: case OP_RETURN",
    ),

    # ---- E3: checksig, CMS, encoding, error kind ------------------------
    _m(
        "M-E3-001", "e3-cms",
        "CMS loop advances/selects the wrong index (sig/key order swapped)",
        ["cells/e3-cms/sig-key-order"], ["saw", "differential"],
        twin_anchor="twin cmsLoop isig/ikey",
        core_anchor="interpreter.cpp: CHECKMULTISIG loop",
    ),
    _m(
        "M-E3-002", "e3-cms",
        "NULLDUMMY check dropped",
        # wave64: the planned e3-cms/nulldummy cell was materialized as the
        # function cell_cms_nulldummy inside C-L-cms-1of1.
        ["cells/e3-cms/C-L-cms-1of1"], ["alive2", "saw", "error-enum"],
        twin_anchor="twin NULLDUMMY gate",
        core_anchor="interpreter.cpp: NULLDUMMY",
        e3_anchor="E3 reviewed l_cms NULLDUMMY gate",
    ),
    _m(
        "M-E3-003", "e3-cms",
        "NULLFAIL cleanup check dropped",
        ["cells/e3-cms/nullfail"], ["saw", "error-enum"],
        twin_anchor="twin cmsCleanup NULLFAIL",
        core_anchor="interpreter.cpp: NULLFAIL cleanup",
    ),
    _m(
        "M-E3-004", "e3-checksig",
        "HIGH_S / low-S gate skipped",
        ["cells/e3-checksig/high-s"], ["saw", "differential"],
        twin_anchor="twin HIGH_S encoding check",
        core_anchor="interpreter.cpp: HIGH_S check",
    ),
    _m(
        "M-E3-005", "e3-cms",
        "CMS count bounds relaxed (nSigs > nKeys or nKeys > 20 accepted)",
        ["cells/e3-cms/count-bounds"], ["alive2", "saw"],
        twin_anchor="twin CMS nKeys/nSigs bounds",
        core_anchor="interpreter.cpp: MAX_PUBKEYS_PER_MULTISIG bounds",
    ),
    _m(
        "M-E3-006", "e3-checksig",
        "FindAndDelete applied in witness v0 (must be base-only)",
        ["cells/e3-checksig/findanddelete-v0"], ["saw", "differential"],
        twin_anchor="twin FindAndDelete / SigVersion gate",
        core_anchor="interpreter.cpp: FindAndDelete SigVersion",
    ),
    _m(
        "M-E3-007", "e3-checksig",
        "OP_CODESEPARATOR offset off by one (scriptCode start)",
        ["cells/e3-checksig/codesep"], ["saw", "differential"],
        twin_anchor="twin codeSep extraction",
        core_anchor="interpreter.cpp: OP_CODESEPARATOR",
    ),
    _m(
        "M-E3-008", "e3-cms",
        "CHECKMULTISIGVERIFY failure maps to EVAL_FALSE",
        ["cells/e3-cms/C-L-cms-1of1"], ["alive2", "saw", "error-enum"],
        twin_anchor="twin CHECKMULTISIGVERIFY error",
        core_anchor="interpreter.cpp: CHECKMULTISIGVERIFY error",
        e3_anchor="E3 reviewed l_cms CHECKMULTISIGVERIFY return",
    ),

    # ---- E4: witness v0 and taproot -------------------------------------
    _m(
        "M-E4-001", "e4-p2sh",
        "P2SH redeem script taken from the wrong source",
        ["cells/e4-p2sh/redeem-source"], ["saw", "differential"],
        twin_anchor="twin P2SH redeem-script selection",
        core_anchor="interpreter.cpp: P2SH redeem script",
    ),
    _m(
        "M-E4-002", "e4-witness",
        "witness stack order reversed for v0 execution",
        ["cells/e4-witness/stack-order"], ["saw", "differential"],
        twin_anchor="twin witness stack construction",
        core_anchor="interpreter.cpp: ExecuteWitnessScript stack",
    ),
    _m(
        "M-E4-003", "e4-taproot",
        "taproot leaf version accepted/compared with the wrong value or mask",
        # wave64: the planned e4-taproot/leaf-version cell was materialized as
        # cell_leaf_version inside tapscript/C-L-taproot-scriptpath-dispatch.
        ["cells/tapscript/C-L-taproot-scriptpath-dispatch"],
        ["alive2", "saw"],
        twin_anchor="twin taproot leaf version",
        core_anchor="interpreter.cpp: TAPROOT_LEAF_VERSION",
        e4_anchor="E4 tapscript l_leg leaf-version mask",
    ),
    _m(
        "M-E4-004", "e4-witness",
        "v0 witness program length check accepts a bad length",
        ["cells/e4-witness/C-L-witness-v0-dispatch"], ["alive2", "saw"],
        twin_anchor="twin v0 witness program length",
        core_anchor="interpreter.cpp: WITNESS_PROGRAM_WRONG_LENGTH",
        e4_anchor="E4 l_cell v0 20-byte arm witness_n check",
    ),
    _m(
        "M-E4-005", "e4-witness",
        "P2WSH script hash uses HASH160 instead of SHA256",
        ["cells/e4-witness/p2wsh-hash"], ["saw", "differential"],
        twin_anchor="twin P2WSH hash",
        core_anchor="interpreter.cpp: P2WSH SHA256 check",
    ),
    _m(
        "M-E4-006", "e4-taproot",
        "taproot annex treated as a stack element instead of stripped",
        ["cells/e4-taproot/annex"], ["saw", "differential"],
        twin_anchor="twin taproot annex detection",
        core_anchor="interpreter.cpp: annex detection",
    ),
    _m(
        "M-E4-007", "e4-taproot",
        "OP_SUCCESSx treated as BAD_OPCODE (or not immediate success)",
        # wave64: the planned e4-taproot/opsuccess cell was materialized as
        # cell_is_op_success inside tapscript/C-L-tapscript-isopsuccess.
        ["cells/tapscript/C-L-tapscript-isopsuccess"], ["alive2", "saw"],
        twin_anchor="twin OP_SUCCESSx handling",
        core_anchor="interpreter.cpp: OP_SUCCESSx",
        e4_anchor="E4 tapscript l_leg IsOpSuccess byte set",
    ),
    _m(
        "M-E4-008", "e4-taproot",
        "control-block size bounds off by one",
        ["cells/e4-taproot/control-size"], ["saw", "error-enum"],
        twin_anchor="twin control-block size",
        core_anchor="interpreter.cpp: TAPROOT_WRONG_CONTROL_SIZE",
    ),
]


def variant_status(variant: dict[str, Any]) -> str:
    find, replace = variant.get("find"), variant.get("replace")
    if find is None or replace is None:
        return "uncalibrated"
    if not isinstance(find, str) or not isinstance(replace, str):
        return "invalid"
    if find == replace or find == "":
        return "invalid"
    return "calibrated"


def _calibrate(
    mutant_id: str,
    target_kind: str,
    find: str,
    replace: str,
    expect_count: int = 1,
) -> None:
    """Fill a catalogue anchor after the real source has been inspected.

    Calibration is deliberate: the anchor must be unique in the target and the
    before/after text must differ. This function is called only for the two
    first gate mutants against `twin/ops_ir.py`; the rest stay uncalibrated
    until their gate cells exist.
    """
    for entry in CATALOGUE:
        if entry["id"] == mutant_id:
            variant = entry["variants"][target_kind]
            variant.update(
                {
                    "find": find,
                    "replace": replace,
                    "expect_count": expect_count,
                    "status": "calibrated",
                }
            )
            return
    raise RuntimeError(f"cannot calibrate unknown mutation {mutant_id}")


# First gate batch (cells/README.md): generator-site anchors are exact and
# unique in twin/ops_ir.py as of the E0/E1 skeleton. Re-verify with --dry-run
# after any twin change; a missing anchor is a hard refusal, not a silent edit.
_calibrate(
    "M-E1-001",
    "twin",
    '''"if (st.stack.n < 2) return TWIN_INVALID_STACK_OPERATION;",
            "uint32_t a = st.stack.n - 1, b = st.stack.n - 2;",
            "uint8_t tmp[MAX_SCRIPT_ELEMENT_SIZE];",
            "uint32_t tl = st.stack.len[a];",
            "std::memcpy(tmp, st.stack.e[a], tl);",
            "std::memcpy(st.stack.e[a], st.stack.e[b], st.stack.len[b]);",
            "st.stack.len[a] = st.stack.len[b];",
            "std::memcpy(st.stack.e[b], tmp, tl);",
            "st.stack.len[b] = tl;",
            "return TWIN_OK;",''',
    '''"if (st.stack.n < 2) return TWIN_INVALID_STACK_OPERATION;",
            "return TWIN_OK; // M-E1-001 mutant: OP_SWAP no-op",''',
)
_calibrate(
    "M-E1-002",
    "twin",
    '''"(void)ctx; (void)d;",
            "return st_push_copy(st.stack, 1);",''',
    '''"(void)ctx; (void)d;",
            "return st_push_copy(st.stack, 2); // M-E1-002 mutant: second-from-top",''',
)
_calibrate(
    "M-E1-006",
    "twin",
    '''"(void)ctx; (void)d;",
            "return st_push_num(st.stack, static_cast<int64_t>(st.stack.n));",''',
    '''"(void)ctx; (void)d;",
            "return st_push_num(st.stack, static_cast<int64_t>(st.stack.n) - 1); // M-E1-006 mutant: depth-1",''',
)
# Core-slice anchor: the C leaf used by the E1 cells is the line-cited exact
# slice of Core's interpreter.cpp (cells/_tools/gate/c_leaf.cpp), compiled by
# the pinned clang.  This mutation exercises that C artifact.  It is labelled
# core-slice, not a mutation of the whole Core translation unit; the residual
# for a full-Core rebuild is E1-CORE-RESIDUAL.
_calibrate(
    "M-E1-001",
    "core-copy",
    '''  const uint32_t a = s.n - 2, b = s.n - 1;
  const uint32_t la=s.len[a], va=s.val[a];
  s.len[a]=s.len[b]; s.val[a]=s.val[b];
  s.len[b]=la; s.val[b]=va;''',
    '''  return 0; // M-E1-001 core-slice mutant: OP_SWAP no-op''',
)
_calibrate(
    "M-E2-010",
    "twin",
    '''"body": ["(void)st; (void)ctx; (void)d;", "return TWIN_OP_RETURN;"],''',
    '''"body": ["(void)st; (void)ctx; (void)d;", "return TWIN_OK; // M-E2-010 mutant: OP_RETURN succeeds"],''',
)
_calibrate(
    "M-E1-008",
    "twin",
    '''"body": [
            "(void)ctx; (void)d;",
            "if (st.stack.n < 2) return TWIN_INVALID_STACK_OPERATION;",
            "st.stack.n -= 2;",
            "return TWIN_OK;",
        ],''',
    '''"body": [
            "(void)ctx; (void)d;",
            "return TWIN_OK; // M-E1-008 mutant: OP_2DROP arity guard dropped",
        ],''',
)
_calibrate(
    "M-E4-004",
    "e4-cell",
    '''        if (witness_n != 2) return {L_FAIL, 40};''',
    '''        if (witness_n < 2) return {L_FAIL, 40}; // M-E4-004 mutant''',
)
_calibrate(
    "M-E3-008",
    "e3-cell",
    '''    return TWIN_CHECKMULTISIGVERIFY;''',
    '''    return (TwinErr)2; // M-E3-008 mutant: CHECKMULTISIGVERIFY -> EVAL_FALSE''',
)
_calibrate(
    "M-E3-002",
    "e3-cell",
    '''  if (null_dummy && st.stack.len[st.stack.n - 1] != 0) return TWIN_SIG_NULLDUMMY;
''',
    '''  // M-E3-002 mutant: NULLDUMMY gate dropped
''',
)
_calibrate(
    "M-E4-003",
    "e4-cell",
    '''  const uint64_t leaf = (control0 & 0xffu) & TAP_LEAF_MASK;  // leafVersionOf''',
    '''  const uint64_t leaf = (control0 & 0xffu) & 0xffu;  // M-E4-003 mutant: wrong leaf mask''',
)
_calibrate(
    "M-E4-007",
    "e4-cell",
    '''  const bool r = w == 80u || w == 98u || (126u <= w && w <= 129u) ||''',
    '''  const bool r = (126u <= w && w <= 129u) ||  // M-E4-007 mutant: drop OP_SUCCESS 80/98''',
)



def get_mutation(mutant_id: str) -> dict[str, Any]:
    for entry in CATALOGUE:
        if entry["id"] == mutant_id:
            return entry
    raise Refusal("UNKNOWN_MUTATION", f"no mutation with id {mutant_id!r}")


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

class Refusal(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_text_preserve(path: Path) -> str:
    # newline="" preserves CRLF/LF exactly on read.
    with path.open("r", encoding="utf-8", newline="") as f:
        return f.read()


def write_text_atomic(path: Path, text: str) -> None:
    fd, tmp_name = tempfile.mkstemp(
        prefix=path.name + ".", suffix=".mut", dir=str(path.parent)
    )
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, stat.S_IMODE(path.stat().st_mode))
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def write_json_new(path: Path, obj: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise Refusal("RECORD_EXISTS", f"refusing to overwrite existing record {path}")
    data = json.dumps(obj, indent=2, sort_keys=True) + "\n"
    fd, tmp_name = tempfile.mkstemp(
        prefix=path.name + ".", suffix=".tmp", dir=str(path.parent)
    )
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        if path.exists():
            raise Refusal("RECORD_EXISTS", f"refusing to overwrite existing record {path}")
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def validate_target(raw: str) -> Path:
    if not raw:
        raise Refusal("NO_TARGET", "--target is required and must be an explicit file")
    raw_path = Path(raw)
    if raw_path.is_symlink():
        raise Refusal("SYMLINK_TARGET", f"refusing to mutate symlink {raw_path}")
    path = raw_path.resolve()
    if not path.exists():
        raise Refusal("TARGET_NOT_FOUND", f"target does not exist: {path}")
    if not path.is_file():
        raise Refusal("TARGET_NOT_FILE", f"target is not a regular file: {path}")
    parts = set(path.parts)
    if ".git" in parts:
        raise Refusal("PROTECTED_TARGET", f"refusing to mutate inside .git: {path}")
    if "patches" in parts:
        raise Refusal(
            "PROTECTED_TARGET",
            f"refusing to mutate a patches/ path (mutants are not patches): {path}",
        )
    return path


def unified_diff(old: str, new: str, path: Path) -> str:
    rel = str(path)
    try:
        rel = str(path.relative_to(REPO_ROOT))
    except ValueError:
        rel = str(path).lstrip("/")
    return "".join(
        difflib.unified_diff(
            old.splitlines(keepends=True),
            new.splitlines(keepends=True),
            fromfile=f"a/{rel}",
            tofile=f"b/{rel}",
        )
    )


def git_head() -> str | None:
    try:
        out = subprocess.check_output(
            ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return out.strip() or None
    except Exception:
        return None


def pins_sha256() -> str | None:
    try:
        return sha256_file(PINS_PATH)
    except OSError:
        return None


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

def cmd_list() -> int:
    print(f"# Mutation catalogue v{CATALOGUE_VERSION} (schema {SCHEMA})")
    print("# Status is per target variant; apply requires a calibrated variant.")
    print()
    for entry in CATALOGUE:
        print(f"{entry['id']}  [{entry['family']}]  {entry['description']}")
        variants = ", ".join(
            f"{name}={variant_status(v)}" for name, v in entry["variants"].items()
        )
        print(f"  variants: {variants}")
        print(f"  expected: {', '.join(entry['expected_failing_cells'])}")
        print(f"  catchers: {', '.join(entry['catchers'])}")
        for name, v in entry["variants"].items():
            print(f"  anchor[{name}]: {v['anchor_hint']}")
        print()
    print(f"# {len(CATALOGUE)} mutations; apply only variants reported as calibrated.")
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    if not args.target:
        raise Refusal("NO_TARGET", "--target is required to apply a mutation")
    if not args.mutation:
        raise Refusal("NO_MUTATION", "--mutation is required to apply a mutation")
    if not args.target_kind:
        raise Refusal("NO_TARGET_KIND", "--target-kind is required to apply a mutation")

    target = validate_target(args.target)
    entry = get_mutation(args.mutation)
    variant = entry["variants"].get(args.target_kind)
    if variant is None:
        raise Refusal(
            "VARIANT_NOT_APPLICABLE",
            f"{args.mutation} has no {args.target_kind!r} variant "
            f"(available: {', '.join(entry['variants'])})",
        )
    status = variant_status(variant)
    if status != "calibrated":
        raise Refusal(
            "MUTATION_NOT_CALIBRATED",
            f"{args.mutation}/{args.target_kind} is {status}; fill find/replace "
            f"anchors in mutate.py after the target source lands "
            f"(hint: {variant['anchor_hint']})",
        )

    find = variant["find"]
    replace = variant["replace"]
    expect = int(variant.get("expect_count", 1))
    if expect < 1:
        raise Refusal("BAD_EXPECT_COUNT", "expect_count must be >= 1")
    if not isinstance(find, str) or not isinstance(replace, str):
        raise Refusal("MUTATION_NOT_CALIBRATED", "find/replace must be strings")
    if find == replace or find == "":
        raise Refusal("NO_OP_MUTATION", "find and replace must differ and be non-empty")

    old_bytes = target.read_bytes()
    try:
        old_text = old_bytes.decode("utf-8")
    except UnicodeDecodeError as e:
        raise Refusal("NON_UTF8_TARGET", f"target is not valid UTF-8: {e}")
    before = sha256_bytes(old_bytes)

    count = old_text.count(find)
    if count == 0:
        if old_text.count(replace) > 0:
            raise Refusal(
                "ALREADY_APPLIED",
                f"{args.mutation}/{args.target_kind} target already contains the "
                f"replacement text; revert or use a clean copy",
            )
        raise Refusal(
            "ANCHOR_NOT_FOUND",
            f"anchor for {args.mutation}/{args.target_kind} not found in {target}; "
            f"hint: {variant['anchor_hint']}",
        )
    if count != expect:
        raise Refusal(
            "ANCHOR_COUNT_MISMATCH",
            f"anchor occurs {count} times, expected {expect}; expand the anchor "
            f"context; never use replace_all for a semantic mutation",
        )

    new_text = old_text.replace(find, replace, expect)
    new_bytes = new_text.encode("utf-8")
    after = sha256_bytes(new_bytes)
    if after == before:
        raise Refusal("NO_OP_MUTATION", "mutation produced identical bytes")

    diff = unified_diff(old_text, new_text, target)

    if args.dry_run:
        print("DRY RUN — no write, no record")
        print(f"mutation:    {entry['id']} ({entry['family']})")
        print(f"target:      {target}")
        print(f"target kind: {args.target_kind}")
        print(f"sha256 before: {before}")
        print(f"sha256 after:  {after}")
        print(f"expected failing cells: {', '.join(entry['expected_failing_cells'])}")
        print(f"catchers: {', '.join(entry['catchers'])}")
        print()
        print(diff)
        return 0

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    record_path = out_dir / f"{entry['id']}-{args.target_kind}-{stamp}-{before[:8]}.json"
    if record_path.exists():
        raise Refusal("RECORD_EXISTS", f"refusing to overwrite existing record {record_path}")
    # Preflight the record directory before touching the source.
    probe_fd, probe_name = tempfile.mkstemp(prefix=".preflight.", dir=str(out_dir))
    os.close(probe_fd)
    os.unlink(probe_name)

    write_text_atomic(target, new_text)
    written = sha256_file(target)
    if written != after:
        raise Refusal(
            "WRITE_HASH_MISMATCH",
            f"post-write hash {written} != expected {after}; do not continue",
        )

    try:
        rel_target = str(target.relative_to(REPO_ROOT))
    except ValueError:
        rel_target = None

    record = {
        "schema": SCHEMA,
        "mutant_id": entry["id"],
        "family": entry["family"],
        "description": entry["description"],
        "target_kind": args.target_kind,
        "target": {
            "path": str(target),
            "path_relative_to_repo": rel_target,
            "sha256_before": before,
            "sha256_after": after,
        },
        "find": find,
        "replace": replace,
        "expect_count": expect,
        "diff": diff,
        "expected_failing_cells": entry["expected_failing_cells"],
        "catchers": entry["catchers"],
        "catalogue_version": CATALOGUE_VERSION,
        "pins_sha256": pins_sha256(),
        "git_head": git_head(),
        "applied_at_utc": utc_now(),
        "status": "applied",
        "outcome": "pending",
        "classification": None,
        "observed": None,
        "witness": None,
        "log_hashes": [],
        "operator": None,
        "reverted_at_utc": None,
    }
    try:
        write_json_new(record_path, record)
    except Exception:
        # The record is the audit trail; without it, restore the source.
        try:
            write_text_atomic(target, old_text)
        except Exception:
            pass
        raise

    print(f"APPLIED {entry['id']} ({args.target_kind})")
    print(f"target:       {target}")
    print(f"sha256 before: {before}")
    print(f"sha256 after:  {after}")
    print(f"record:        {record_path}")
    print("Next: rebuild from this source, run the expected cells, then revert.")
    return 0


def cmd_revert(record_name: str) -> int:
    record_path = Path(record_name).resolve()
    if not record_path.is_file():
        raise Refusal("RECORD_NOT_FOUND", f"record not found: {record_path}")
    try:
        record = json.loads(record_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise Refusal("BAD_RECORD", f"record is not valid JSON: {e}")
    if record.get("schema") != SCHEMA:
        raise Refusal("BAD_RECORD", f"record schema is not {SCHEMA}")
    if record.get("status") not in ("applied", "reverted"):
        raise Refusal("BAD_RECORD", f"record status is {record.get('status')!r}")

    target_info = record.get("target") or {}
    target = Path(target_info.get("path", ""))
    if not target.is_file():
        raise Refusal("TARGET_NOT_FOUND", f"target from record not found: {target}")

    before = target_info.get("sha256_before")
    after = target_info.get("sha256_after")
    current = sha256_file(target)

    if current == before:
        print(f"ALREADY REVERTED: {target} already matches sha256_before {before}")
        return 0

    if current != after:
        raise Refusal(
            "TARGET_HASH_MISMATCH",
            f"current hash {current} matches neither before {before} nor after {after}; "
            f"refusing to revert a contaminated target",
        )

    find = record.get("replace")
    replace = record.get("find")
    expect = int(record.get("expect_count", 1))
    if not isinstance(find, str) or not isinstance(replace, str):
        raise Refusal("BAD_RECORD", "record find/replace are not usable")

    text = read_text_preserve(target)
    count = text.count(find)
    if count != expect:
        raise Refusal(
            "REVERSE_ANCHOR_COUNT_MISMATCH",
            f"replacement anchor occurs {count} times, expected {expect}; "
            f"refusing a partial revert",
        )

    restored = text.replace(find, replace, expect)
    restored_bytes = restored.encode("utf-8")
    if sha256_bytes(restored_bytes) != before:
        raise Refusal(
            "REVERT_HASH_MISMATCH",
            "reverse replacement does not reproduce sha256_before; refusing to write",
        )

    write_text_atomic(target, restored)
    current_after = sha256_file(target)
    if current_after != before:
        raise Refusal(
            "REVERT_WRITE_MISMATCH",
            f"post-revert hash {current_after} != sha256_before {before}",
        )

    receipt = {
        "schema": SCHEMA + "-revert",
        "reverts_record": str(record_path),
        "mutant_id": record.get("mutant_id"),
        "target_kind": record.get("target_kind"),
        "target": str(target),
        "sha256_before": before,
        "sha256_after_application": after,
        "sha256_at_revert": current,
        "sha256_after_revert": current_after,
        "reverted_at_utc": utc_now(),
        "status": "reverted",
    }
    receipt_path = record_path.with_suffix(record_path.suffix + ".revert.json")
    write_json_new(receipt_path, receipt)

    print(f"REVERTED {record.get('mutant_id')} ({record.get('target_kind')})")
    print(f"target:      {target}")
    print(f"sha256 now:  {current_after}")
    print(f"receipt:     {receipt_path}")
    print("Next: rebuild and confirm the baseline cell is green again.")
    return 0


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Apply one named textual mutation and record before/after hashes.",
        epilog=(
            "Refuses to apply without --target, --mutation, and --target-kind; "
            "refuses uncalibrated catalogue entries."
        ),
    )
    p.add_argument("--list", dest="list_mode", action="store_true",
                   help="print the mutation catalogue and exit")
    p.add_argument("--target", help="explicit target source file (required to apply)")
    p.add_argument("--mutation", help="mutation id from MUTATIONS.md (required to apply)")
    p.add_argument("--target-kind", choices=["twin", "core-copy", "rust-copy", "e4-cell", "e3-cell"],
                   help="which variant to apply (required to apply)")
    p.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR),
                   help=f"mutant record directory (default: {DEFAULT_OUT_DIR})")
    p.add_argument("--dry-run", action="store_true",
                   help="validate and print the diff; do not write or record")
    p.add_argument("--revert", metavar="RECORD",
                   help="revert a previously applied mutant from its JSON record")
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.list_mode:
            if args.revert or args.target or args.mutation:
                parser.error("--list does not take --target/--mutation/--revert")
            return cmd_list()
        if args.revert:
            if args.target or args.mutation or args.target_kind or args.dry_run:
                parser.error("--revert takes only the record path")
            return cmd_revert(args.revert)
        return cmd_apply(args)
    except Refusal as e:
        print(f"REFUSED [{e.code}]: {e.message}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # e.g. `mutate.py --list | head`; not an error worth a traceback.
        try:
            sys.stdout.close()
        except Exception:
            pass
        sys.exit(0)
