#!/usr/bin/env python3
"""twin/gen.py -- Lean-model -> imperative IR -> C++ twin generator.

STATUS: E1 base-script surface.  Emits a contract-compatible C++17 twin for
the opcode subset in `ops_ir.py`, with TX_WITH_WITNESS decoding, scriptSig +
scriptPubKey evaluation in `verifyScriptFull` order, P2SH wrapping, the
policy bits that the subset actually reads, and the Core ScriptError ordinal
mapping at the ABI boundary.

Pipeline (see twin/generator.md):
    Lean Defs.lean --hand-transcribed, line-cited--> IR (ops_ir.OPS)
    IR + runtime.inc --deterministic substitution--> C++17 twin

`runtime.inc` holds the structural code (stack primitives, GetOp, EvalScript,
TX decode, VerifyScript ordering); handler bodies live in `ops_ir.py` and are
copied verbatim.  Every handler has a `Lean:` anchor.

Exit codes: 0 ok, 1 drift under --check, 2 bad usage.  Never runs a compiler.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List

from ops_ir import OPS

GENERATOR = "twin/gen.py"
VERSION = "0.2.0"
IR_VERSION = 2
HERE = Path(__file__).resolve().parent
CONTRACT = HERE.parent / "contract" / "error_kind.h"

# ---------------------------------------------------------------------------
# TwinErr: stable IDs = 1 + Lean ExecError constructor index (Defs.lean:119-177),
# TWIN_OK = 0, plus two twin-only sentinels.  `core` names a Core ScriptError
# (EQUIV_ERR_<core> in contract/error_kind.h); None means UNKNOWN_ERROR at the
# boundary (never a consensus verdict for the sentinels).
# ---------------------------------------------------------------------------
ERRORS: List[Dict[str, object]] = [
    {"name": "TWIN_OK", "id": 0, "core": "OK", "lean": "ok"},
    {"name": "TWIN_BAD_OPCODE", "id": 1, "core": "BAD_OPCODE", "lean": "badOpcode"},
    {"name": "TWIN_PUSH_SIZE", "id": 2, "core": "PUSH_SIZE", "lean": "pushSize"},
    {"name": "TWIN_OP_COUNT", "id": 3, "core": "OP_COUNT", "lean": "opCount"},
    {"name": "TWIN_STACK_SIZE", "id": 4, "core": "STACK_SIZE", "lean": "stackSize"},
    {"name": "TWIN_SCRIPT_SIZE", "id": 5, "core": "SCRIPT_SIZE", "lean": "scriptSize"},
    {"name": "TWIN_INVALID_STACK_OPERATION", "id": 6, "core": "INVALID_STACK_OPERATION", "lean": "stackUnderflow"},
    {"name": "TWIN_VERIFY", "id": 7, "core": "VERIFY", "lean": "verifyFailed"},
    {"name": "TWIN_EQUALVERIFY", "id": 8, "core": "EQUALVERIFY", "lean": "equalVerifyFailed"},
    {"name": "TWIN_DISABLED_OPCODE", "id": 9, "core": "DISABLED_OPCODE", "lean": "disabledOpcode"},
    {"name": "TWIN_UNBALANCED_CONDITIONAL", "id": 10, "core": "UNBALANCED_CONDITIONAL", "lean": "unbalancedConditional"},
    {"name": "TWIN_MINIMALIF", "id": 11, "core": "MINIMALIF", "lean": "minimalIf"},
    {"name": "TWIN_CLEANSTACK", "id": 12, "core": "CLEANSTACK", "lean": "cleanstack"},
    {"name": "TWIN_UNKNOWN_ERROR", "id": 13, "core": "UNKNOWN_ERROR", "lean": "unknownError"},
    {"name": "TWIN_EVAL_FALSE", "id": 14, "core": "EVAL_FALSE", "lean": "evalFalse"},
    {"name": "TWIN_SCRIPTNUM", "id": 15, "core": "SCRIPTNUM", "lean": "scriptNum"},
    {"name": "TWIN_NUMEQUALVERIFY", "id": 16, "core": "NUMEQUALVERIFY", "lean": "numEqualVerifyFailed"},
    {"name": "TWIN_CHECKSIGVERIFY", "id": 17, "core": "CHECKSIGVERIFY", "lean": "checkSigVerify"},
    {"name": "TWIN_CHECKMULTISIGVERIFY", "id": 18, "core": "CHECKMULTISIGVERIFY", "lean": "checkMultiSigVerify"},
    {"name": "TWIN_INVALID_ALTSTACK_OPERATION", "id": 19, "core": "INVALID_ALTSTACK_OPERATION", "lean": "invalidAltstackOperation"},
    {"name": "TWIN_OP_RETURN", "id": 20, "core": "OP_RETURN", "lean": "opReturn"},
    {"name": "TWIN_SIG_OP_CODESEPARATOR", "id": 21, "core": "OP_CODESEPARATOR", "lean": "opCodeSeparator"},
    {"name": "TWIN_SIG_FINDANDDELETE", "id": 22, "core": "SIG_FINDANDDELETE", "lean": "sigFindAndDelete"},
    {"name": "TWIN_SIG_DER", "id": 23, "core": "SIG_DER", "lean": "sigDer"},
    {"name": "TWIN_SIG_HIGH_S", "id": 24, "core": "SIG_HIGH_S", "lean": "sigHighS"},
    {"name": "TWIN_SIG_HASHTYPE", "id": 25, "core": "SIG_HASHTYPE", "lean": "sigHashType"},
    {"name": "TWIN_SIG_NULLDUMMY", "id": 26, "core": "SIG_NULLDUMMY", "lean": "sigNullDummy"},
    {"name": "TWIN_SIG_NULLFAIL", "id": 27, "core": "SIG_NULLFAIL", "lean": "sigNullFail"},
    {"name": "TWIN_SIG_PUSHONLY", "id": 28, "core": "SIG_PUSHONLY", "lean": "sigPushOnly"},
    {"name": "TWIN_PUBKEYTYPE", "id": 29, "core": "PUBKEYTYPE", "lean": "pubKeyType"},
    {"name": "TWIN_PUBKEY_COUNT", "id": 30, "core": "PUBKEY_COUNT", "lean": "pubKeyCount"},
    {"name": "TWIN_SIG_COUNT", "id": 31, "core": "SIG_COUNT", "lean": "sigCount"},
    {"name": "TWIN_NEGATIVE_LOCKTIME", "id": 32, "core": "NEGATIVE_LOCKTIME", "lean": "negativeLocktime"},
    {"name": "TWIN_UNSATISFIED_LOCKTIME", "id": 33, "core": "UNSATISFIED_LOCKTIME", "lean": "unsatisfiedLocktime"},
    {"name": "TWIN_SCHNORR_SIG", "id": 34, "core": "SCHNORR_SIG", "lean": "schnorrSig"},
    {"name": "TWIN_SCHNORR_SIG_SIZE", "id": 35, "core": "SCHNORR_SIG_SIZE", "lean": "schnorrSigSize"},
    {"name": "TWIN_SCHNORR_SIG_HASHTYPE", "id": 36, "core": "SCHNORR_SIG_HASHTYPE", "lean": "schnorrSigHashtype"},
    {"name": "TWIN_TAPROOT_DATA_UNAVAILABLE", "id": 37, "core": None, "lean": "taprootDataUnavailable"},
    {"name": "TWIN_WITNESS_PROGRAM_WRONG_LENGTH", "id": 38, "core": "WITNESS_PROGRAM_WRONG_LENGTH", "lean": "witnessProgramWrongLength"},
    {"name": "TWIN_WITNESS_PROGRAM_WITNESS_EMPTY", "id": 39, "core": "WITNESS_PROGRAM_WITNESS_EMPTY", "lean": "witnessProgramWitnessEmpty"},
    {"name": "TWIN_WITNESS_PROGRAM_MISMATCH", "id": 40, "core": "WITNESS_PROGRAM_MISMATCH", "lean": "witnessProgramMismatch"},
    {"name": "TWIN_WITNESS_MALLEATED", "id": 41, "core": "WITNESS_MALLEATED", "lean": "witnessMalleated"},
    {"name": "TWIN_WITNESS_MALLEATED_P2SH", "id": 42, "core": "WITNESS_MALLEATED_P2SH", "lean": "witnessMalleatedP2SH"},
    {"name": "TWIN_WITNESS_UNEXPECTED", "id": 43, "core": "WITNESS_UNEXPECTED", "lean": "witnessUnexpected"},
    {"name": "TWIN_WITNESS_PUBKEYTYPE", "id": 44, "core": "WITNESS_PUBKEYTYPE", "lean": "witnessPubkeyType"},
    {"name": "TWIN_DISCOURAGE_UPGRADABLE_NOPS", "id": 45, "core": "DISCOURAGE_UPGRADABLE_NOPS", "lean": "discourageUpgradableNops"},
    {"name": "TWIN_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM", "id": 46, "core": "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM", "lean": "discourageUpgradableWitnessProgram"},
    {"name": "TWIN_DISCOURAGE_UPGRADABLE_PUBKEYTYPE", "id": 47, "core": "DISCOURAGE_UPGRADABLE_PUBKEYTYPE", "lean": "discourageUpgradablePubkeyType"},
    {"name": "TWIN_DISCOURAGE_OP_SUCCESS", "id": 48, "core": "DISCOURAGE_OP_SUCCESS", "lean": "discourageOpSuccess"},
    {"name": "TWIN_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION", "id": 49, "core": "DISCOURAGE_UPGRADABLE_TAPROOT_VERSION", "lean": "discourageUpgradableTaprootVersion"},
    {"name": "TWIN_TAPROOT_WRONG_CONTROL_SIZE", "id": 50, "core": "TAPROOT_WRONG_CONTROL_SIZE", "lean": "taprootWrongControlSize"},
    {"name": "TWIN_TAPSCRIPT_VALIDATION_WEIGHT", "id": 51, "core": "TAPSCRIPT_VALIDATION_WEIGHT", "lean": "tapscriptValidationWeight"},
    {"name": "TWIN_TAPSCRIPT_CHECKMULTISIG", "id": 52, "core": "TAPSCRIPT_CHECKMULTISIG", "lean": "tapscriptCheckMultiSig"},
    {"name": "TWIN_TAPSCRIPT_EMPTY_PUBKEY", "id": 53, "core": "TAPSCRIPT_EMPTY_PUBKEY", "lean": "tapscriptEmptyPubkey"},
    {"name": "TWIN_TAPSCRIPT_MINIMALIF", "id": 54, "core": "TAPSCRIPT_MINIMALIF", "lean": "tapscriptMinimalIf"},
    {"name": "TWIN_MINIMALDATA", "id": 55, "core": "MINIMALDATA", "lean": "minimalData"},
    {"name": "TWIN_INVALID_UNSUPPORTED", "id": 56, "core": None, "lean": "-"},
    {"name": "TWIN_BAD_INPUT", "id": 57, "core": None, "lean": "-"},
]

SUBSET = ("base-script E1: pushes + stack/altstack/flow + EQUAL/SIZE + "
          "numeric unary/binary + RIPEMD160/SHA256/HASH160/HASH256 + "
          "P2SH wrapper; flags accepted")


def load_core_values() -> Dict[str, int]:
    text = CONTRACT.read_text(encoding="utf-8")
    vals = {m.group(1): int(m.group(2))
            for m in re.finditer(r"EQUIV_ERR_([A-Z0-9_]+)\s*=\s*(\d+)", text)}
    if not vals:
        raise SystemExit(f"gen.py: no EQUIV_ERR_* values in {CONTRACT}")
    return vals


def checked_core_values() -> Dict[str, int]:
    vals = load_core_values()
    for e in ERRORS:
        core = e["core"]
        if core is None:
            continue
        if core not in vals:
            raise SystemExit(f"gen.py: {e['name']} maps to missing EQUIV_ERR_{core}")
    return vals


def cxx_error_enum() -> str:
    lines = []
    for e in ERRORS:
        core = "UNKNOWN_ERROR" if e["core"] is None else str(e["core"])
        lines.append(f"  {e['name']} = {e['id']},  // EQUIV_ERR_{core}  [Lean: {e['lean']}]")
    return "\n".join(lines)


def cxx_core_map(vals: Dict[str, int]) -> str:
    lines = []
    for e in ERRORS:
        core = "UNKNOWN_ERROR" if e["core"] is None else str(e["core"])
        lines.append(f"  static_cast<int32_t>(EQUIV_ERR_{core}),  // {e['name']}")
    return "\n".join(lines)


def cxx_ops() -> str:
    out = []
    seen = set()
    for op in OPS:
        wires = [int(w) for w in op["wires"]]
        for w in wires:
            if w in seen:
                raise SystemExit(f"gen.py: duplicate wire 0x{w:02x}")
            seen.add(w)
        anchor = "Defs.lean:" + ", ".join(str(op["lean"]).replace("Defs.lean:", "").split(", "))
        out.append(f"// {op['name']} (wire {' '.join(f'0x{w:02x}' for w in wires)}) -- Lean: {anchor}")
        out.append(f"static TwinErr op_{op['name']}(State& st, const Ctx& ctx, const Decoded& d) {{")
        for line in op["body"]:
            out.append("  " + line)
        out.append("}")
        out.append("")
    return "\n".join(out)


def cxx_cases() -> str:
    lines = []
    for op in OPS:
        for w in op["wires"]:
            lines.append(f"    case 0x{int(w):02x}: return op_{op['name']}(st, ctx, d);")
    return "\n".join(lines)


def render() -> str:
    vals = checked_core_values()
    src = (HERE / "runtime.inc").read_text(encoding="utf-8")
    src = src.replace("__GENERATOR__", GENERATOR)
    src = src.replace("__VERSION__", VERSION)
    src = src.replace("__IR_VERSION__", str(IR_VERSION))
    src = src.replace("__SUBSET__", SUBSET)
    src = src.replace("__ERROR_ENUM__", cxx_error_enum())
    src = src.replace("__ERR_COUNT__", str(len(ERRORS)))
    src = src.replace("__CORE_MAP__", cxx_core_map(vals))
    src = src.replace("__OPS__", cxx_ops())
    src = src.replace("__DISPATCH_CASES__", cxx_cases())
    return src


def ir_dump(vals: Dict[str, int]) -> Dict[str, object]:
    return {
        "generator": {"name": GENERATOR, "version": VERSION, "ir_version": IR_VERSION},
        "subset": SUBSET,
        "semantics_source": "spec/core/Bitcoin/Interpreter/Defs.lean",
        "abi": "contract/ABI.md v2; error_kind.h",
        "stack": {
            "lean": "Stack = List ByteArray, head = top (Defs.lean:59-63)",
            "cxx": "Stack { n, len[1000], e[1000][520] }, index 0 = bottom, n-1 = top",
        },
        "errors": [
            {"name": e["name"], "id": e["id"], "core": e["core"], "lean_ctor": e["lean"],
             "core_value": vals.get(str(e["core"])) if e["core"] is not None else vals["UNKNOWN_ERROR"]}
            for e in ERRORS
        ],
        "opcodes_supported": [
            {"wires": [int(w) for w in o["wires"]], "name": o["name"], "lean": o["lean"],
             "body": o["body"]} for o in OPS
        ],
        "flags": {
            "accepted_mask": "0x1fffff",
            "implemented": ["P2SH", "SIGPUSHONLY", "MINIMALDATA", "DISCOURAGE_UPGRADABLE_NOPS",
                            "CLEANSTACK", "WITNESS (malleated/unexpected tails only)",
                            "CONST_SCRIPTCODE (OP_CODESEPARATOR)"],
            "inert_with_justification": [
                "STRICTENC/LOW_S/DERSIG/NULLDUMMY/NULLFAIL/WITNESS_PUBKEYTYPE: read only by "
                "CHECKSIG/CHECKMULTISIG, which dispatch to result 3",
                "MINIMALIF: read only on witnessV0/tapscript, which dispatch to result 3",
                "CLTV/CSV: no-op with the activation flag off; result 3 with it on",
                "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM/TAPROOT/OP_SUCCESS/PUBKEYTYPE: "
                "witness/tapscript paths dispatch to result 3",
            ],
        },
        "unsupported": {
            "policy": "TWIN_INVALID_UNSUPPORTED, result 3 (outside cell domain)",
            "opcodes": ["CHECKSIG", "CHECKSIGVERIFY", "CHECKMULTISIG",
                        "CHECKMULTISIGVERIFY", "SHA1"],
            "conditional": {
                "CHECKLOCKTIMEVERIFY": "result 3 when SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY is set; otherwise no-op",
                "CHECKSEQUENCEVERIFY": "result 3 when SCRIPT_VERIFY_CHECKSEQUENCEVERIFY is set; otherwise no-op",
                "CHECKSIGADD": "BAD_OPCODE under base/witnessV0; tapscript path is E4",
            },
            "paths": ["witness v0/v1/taproot script execution (E4)"],
        },
    }


def validate_wire_table() -> None:
    """Every wire 0x00..0xff is covered exactly once.

    Structural handling covers direct pushes (0x00..0x4e), OP_1NEGATE
    (0x4f), OP_1..OP_16 (0x51..0x60), and the 15 disabled wires.  OPS must
    cover 0x50 and the remaining 0x61..0xff wires with no duplicates.  An
    incomplete table would otherwise fall through to the dispatch safety net;
    make that a generator error, not a runtime surprise.
    """
    covered: Dict[int, str] = {}
    for w in range(0x00, 0x50):
        covered[w] = "structural-push"
    for w in range(0x51, 0x61):
        covered[w] = "structural-pushnum"
    for w in (0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
              0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99):
        covered[w] = "structural-disabled"
    names = set()
    for op in OPS:
        name = op["name"]
        if not str(op.get("lean", "")).startswith("Defs.lean:"):
            raise ValueError(f"{name}: missing Defs.lean anchor")
        if name in names:
            raise ValueError(f"handler name repeated: {name}")
        names.add(name)
        for w in op["wires"]:
            if w in covered:
                raise ValueError(f"wire {w:#04x} handled twice: {covered[w]} and {name}")
            covered[w] = name
    missing = [w for w in range(0x100) if w not in covered]
    if missing:
        raise ValueError("unhandled wires: " + ", ".join(f"{w:#04x}" for w in missing))


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="-", help="output C++ path ('-' = stdout)")
    ap.add_argument("--dump-ir", metavar="PATH", help="write the imperative IR as JSON")
    ap.add_argument("--check", metavar="PATH", help="drift gate against PATH")
    ap.add_argument("--version", action="version", version=f"{GENERATOR} {VERSION}")
    args = ap.parse_args(argv)

    try:
        validate_wire_table()
    except ValueError as exc:
        print(f"IR ERROR: {exc}", file=sys.stderr)
        return 2

    src = render()
    if args.check:
        try:
            old = Path(args.check).read_text(encoding="utf-8")
        except FileNotFoundError:
            print(f"DRIFT: {args.check} does not exist", file=sys.stderr)
            return 1
        if old != src:
            print(f"DRIFT: {args.check} is not reproducible from {GENERATOR}", file=sys.stderr)
            return 1
        print(f"OK: {args.check} matches generator output", file=sys.stderr)
        if args.out == "-":
            args.out = None

    if args.out == "-":
        sys.stdout.write(src)
    elif args.out is not None:
        path = Path(args.out)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(src, encoding="utf-8", newline="\n")
        print(f"wrote {args.out} ({len(src.encode('utf-8'))} bytes)", file=sys.stderr)

    if args.dump_ir:
        vals = checked_core_values()
        path = Path(args.dump_ir)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(ir_dump(vals), indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"wrote {args.dump_ir}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
