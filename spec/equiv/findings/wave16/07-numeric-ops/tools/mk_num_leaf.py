#!/usr/bin/env python3
"""Emit a *wide-domain* bounded leaf of the twin's imperative IR.

Why this exists
---------------
`cells/_tools/mk_leaf.py` is the shared generator; its bounded runtime
primitives are specialised to a 2-byte element (`decode_num` has a hard
`len > 2` guard, `encode_num` has a 4-byte `tmp`, `cast_to_bool` only knows
lengths 0..2).  The numeric opcodes need the real 4-byte CScriptNum operand
domain and can push 5-byte results (e.g. OP_ADD of two 4-byte operands), so a
2-byte leaf cannot express them.

This helper *reuses* mk_leaf for everything that carries roughly half the
proof weight:
  * the handler table and the emitted `op_<NAME>` bodies (byte-identical),
  * the `TwinErr` enum and the mechanical `core_ord` map,
  * the stack/state structs and `st_push` / `st_push_copy` / `st_top`.

It then replaces six *bounded runtime primitives* with the twin's own
`twin/runtime.inc` implementations, unrolled to a fixed 8-byte element width
so the emitted leaf is loop-free (`bounded_memcpy`, `bounded_memcmp`,
`encode_num`, `st_push_num`, `decode_num`, `cast_to_bool`).  Each replacement
is asserted to apply exactly once, and every handler body is asserted
byte-identical to mk_leaf's output before the header is written.

The opcode semantics therefore still come from `twin/ops_ir.py`; only the
*representation constants* of the bounded leaf move (element 2 -> 8 bytes,
depth 4), exactly like the E2 hash cell re-bound the element width for a
20-byte digest.

Usage:
  python3 mk_num_leaf.py --ops OP_ADD,OP_SUB --out HEADER --meta META
  python3 mk_num_leaf.py --ops ... --check HEADER
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent


def _find_equiv() -> Path:
    for p in (HERE, *HERE.parents):
        if (p / "contract" / "error_kind.h").is_file():
            return p
    raise SystemExit(f"cannot locate spec/equiv from {HERE}")


EQUIV = _find_equiv()
CELLS = EQUIV / "cells"
MK_LEAF = CELLS / "_tools" / "mk_leaf.py"
TWIN = EQUIV / "twin"

MAX_ELEM = 8   # element bytes: 4-byte operand + 5-byte OP_ADD result + 2 spare
MAX_DEPTH = 4  # stack depth: WITHIN needs 3


def load_mk_leaf():
    spec = importlib.util.spec_from_file_location("mk_leaf_ro", MK_LEAF)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# --------------------------------------------------------------------------
# Loop-free replacements for the bounded runtime primitives.
#
# Each body below is the twin/runtime.inc implementation with its data loops
# unrolled to MAX_ELEM bytes / MAX_ELEM+2 sign bytes.  Offsets are constant so
# neither Alive2 nor SAW has to reason about symbolic loop bounds.
# --------------------------------------------------------------------------
REPLACEMENTS: dict[str, str] = {}

REPLACEMENTS["bounded_memcpy"] = """
static inline __attribute__((always_inline)) void bounded_memcpy(uint8_t* d, const uint8_t* s, uint32_t len) {
  // runtime.inc st_push's `std::memmove(s.e[..], data, len)` unrolled to the
  // 8-byte cell element.  Constant offsets; guarded by the symbolic length.
  if (len >= 1) d[0] = s[0];
  if (len >= 2) d[1] = s[1];
  if (len >= 3) d[2] = s[2];
  if (len >= 4) d[3] = s[3];
  if (len >= 5) d[4] = s[4];
  if (len >= 6) d[5] = s[5];
  if (len >= 7) d[6] = s[6];
  if (len >= 8) d[7] = s[7];
}
""".strip()

REPLACEMENTS["bounded_memcmp"] = """
static inline __attribute__((always_inline)) int bounded_memcmp(const uint8_t* a, const uint8_t* b, uint32_t len) {
  // std::memcmp unrolled to the 8-byte cell element (first differing byte wins).
  if (len >= 1 && a[0] != b[0]) return (int)a[0] - (int)b[0];
  if (len >= 2 && a[1] != b[1]) return (int)a[1] - (int)b[1];
  if (len >= 3 && a[2] != b[2]) return (int)a[2] - (int)b[2];
  if (len >= 4 && a[3] != b[3]) return (int)a[3] - (int)b[3];
  if (len >= 5 && a[4] != b[4]) return (int)a[4] - (int)b[4];
  if (len >= 6 && a[5] != b[5]) return (int)a[5] - (int)b[5];
  if (len >= 7 && a[6] != b[6]) return (int)a[6] - (int)b[6];
  if (len >= 8 && a[7] != b[7]) return (int)a[7] - (int)b[7];
  return 0;
}
""".strip()

REPLACEMENTS["encode_num"] = """
static inline __attribute__((always_inline)) uint32_t encode_num(int64_t v, uint64_t& packed) {
  // twin/runtime.inc encode_num (interpreter.cpp:415-427 serialize), while
  // loop unrolled to 8 magnitude bytes; |v| < 2^33 in these cells so at most
  // 5 bytes are produced.  The original writes/reads `tmp[n-1]` through a
  // symbolic index, which no SROA can remove and which makes Alive2's UB
  // query quantified; the same bytes are assembled here in a LE uint64 so
  // every access is constant-indexed.
  packed = 0;
  if (v == 0) return 0;
  const bool neg = v < 0;
  uint64_t a = neg ? (static_cast<uint64_t>(-(v + 1)) + 1u) : static_cast<uint64_t>(v);
  uint8_t b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0, b7 = 0;
  uint32_t n = 0;
  if (a != 0) { b0 = static_cast<uint8_t>(a & 0xffu); n = 1; a >>= 8; }
  if (a != 0) { b1 = static_cast<uint8_t>(a & 0xffu); n = 2; a >>= 8; }
  if (a != 0) { b2 = static_cast<uint8_t>(a & 0xffu); n = 3; a >>= 8; }
  if (a != 0) { b3 = static_cast<uint8_t>(a & 0xffu); n = 4; a >>= 8; }
  if (a != 0) { b4 = static_cast<uint8_t>(a & 0xffu); n = 5; a >>= 8; }
  if (a != 0) { b5 = static_cast<uint8_t>(a & 0xffu); n = 6; a >>= 8; }
  if (a != 0) { b6 = static_cast<uint8_t>(a & 0xffu); n = 7; a >>= 8; }
  if (a != 0) { b7 = static_cast<uint8_t>(a & 0xffu); n = 8; a >>= 8; }
  const uint8_t last = (n == 1) ? b0 : (n == 2) ? b1 : (n == 3) ? b2 :
                       (n == 4) ? b3 : (n == 5) ? b4 : (n == 6) ? b5 :
                       (n == 7) ? b6 : b7;
  if ((last & 0x80u) != 0) {
    const uint8_t sgn = neg ? 0x80u : 0x00u;
    if (n == 1) b1 = sgn;
    else if (n == 2) b2 = sgn;
    else if (n == 3) b3 = sgn;
    else if (n == 4) b4 = sgn;
    else if (n == 5) b5 = sgn;
    else if (n == 6) b6 = sgn;
    else b7 = sgn;
    n += 1;
  } else if (neg) {
    if (n == 1) b0 = static_cast<uint8_t>(b0 | 0x80u);
    else if (n == 2) b1 = static_cast<uint8_t>(b1 | 0x80u);
    else if (n == 3) b2 = static_cast<uint8_t>(b2 | 0x80u);
    else if (n == 4) b3 = static_cast<uint8_t>(b3 | 0x80u);
    else if (n == 5) b4 = static_cast<uint8_t>(b4 | 0x80u);
    else if (n == 6) b5 = static_cast<uint8_t>(b5 | 0x80u);
    else if (n == 7) b6 = static_cast<uint8_t>(b6 | 0x80u);
    else b7 = static_cast<uint8_t>(b7 | 0x80u);
  }
  packed = static_cast<uint64_t>(b0)
         | (static_cast<uint64_t>(b1) << 8)  | (static_cast<uint64_t>(b2) << 16)
         | (static_cast<uint64_t>(b3) << 24) | (static_cast<uint64_t>(b4) << 32)
         | (static_cast<uint64_t>(b5) << 40) | (static_cast<uint64_t>(b6) << 48)
         | (static_cast<uint64_t>(b7) << 56);
  return n;
}
""".strip()

REPLACEMENTS["st_push_num"] = """
static inline __attribute__((always_inline)) TwinErr st_push_num(Stack& s, int64_t v) {
  // runtime.inc serialises into tmp[10] then st_push()s it; here the bytes
  // stay packed in a word and are stored with constant indices (see above).
  uint64_t packed = 0;
  const uint32_t n = encode_num(v, packed);
  if (n > MAX_SCRIPT_ELEMENT_SIZE) return TWIN_PUSH_SIZE;
  if (s.n >= MAX_STACK_SIZE) return TWIN_STACK_SIZE;
  s.len[s.n] = n;
  if (n >= 1) s.e[s.n][0] = static_cast<uint8_t>(packed);
  if (n >= 2) s.e[s.n][1] = static_cast<uint8_t>(packed >> 8);
  if (n >= 3) s.e[s.n][2] = static_cast<uint8_t>(packed >> 16);
  if (n >= 4) s.e[s.n][3] = static_cast<uint8_t>(packed >> 24);
  if (n >= 5) s.e[s.n][4] = static_cast<uint8_t>(packed >> 32);
  if (n >= 6) s.e[s.n][5] = static_cast<uint8_t>(packed >> 40);
  if (n >= 7) s.e[s.n][6] = static_cast<uint8_t>(packed >> 48);
  if (n >= 8) s.e[s.n][7] = static_cast<uint8_t>(packed >> 56);
  s.n += 1;
  return TWIN_OK;
}
""".strip()

REPLACEMENTS["decode_num"] = """
static inline __attribute__((always_inline)) TwinErr decode_num(const uint8_t* d, uint32_t len, bool minimal,
                                  uint32_t maxlen, int64_t& out) {
  // twin/runtime.inc decode_num (interpreter.cpp:429-451), unrolled to the
  // 8-byte cell element.  `len > maxlen` is the CScriptNum width guard
  // (script.h:247-249); the minimality guard (script.h:252-268) is folded off
  // by the cells (minimalData = false) but kept textually.
  if (len > maxlen) return TWIN_SCRIPTNUM;
  if (minimal && len > 0) {
    const uint32_t top = (len == 1) ? d[0] : (len == 2) ? d[1] : (len == 3) ? d[2] :
                         (len == 4) ? d[3] : (len == 5) ? d[4] : (len == 6) ? d[5] :
                         (len == 7) ? d[6] : d[7];
    const uint32_t second = (len == 2) ? d[0] : (len == 3) ? d[1] : (len == 4) ? d[2] :
                            (len == 5) ? d[3] : (len == 6) ? d[4] : (len == 7) ? d[5] : d[6];
    if ((top & 0x7fu) == 0 && (len <= 1 || (second & 0x80u) == 0)) return TWIN_SCRIPTNUM;
  }
  if (len == 0) { out = 0; return TWIN_OK; }
  uint64_t v = 0;
  if (len >= 1) v |= static_cast<uint64_t>(d[0]);
  if (len >= 2) v |= static_cast<uint64_t>(d[1]) << 8;
  if (len >= 3) v |= static_cast<uint64_t>(d[2]) << 16;
  if (len >= 4) v |= static_cast<uint64_t>(d[3]) << 24;
  if (len >= 5) v |= static_cast<uint64_t>(d[4]) << 32;
  if (len >= 6) v |= static_cast<uint64_t>(d[5]) << 40;
  if (len >= 7) v |= static_cast<uint64_t>(d[6]) << 48;
  if (len >= 8) v |= static_cast<uint64_t>(d[7]) << 56;
  const uint32_t last = (len == 1) ? d[0] : (len == 2) ? d[1] : (len == 3) ? d[2] :
                        (len == 4) ? d[3] : (len == 5) ? d[4] : (len == 6) ? d[5] :
                        (len == 7) ? d[6] : d[7];
  // ~(0x80 << (8*(len-1))) as a constant select chain (no symbolic shift).
  const uint64_t signmask = (len == 1) ? 0xffffffffffffff7fULL
                          : (len == 2) ? 0xffffffffffff7fffULL
                          : (len == 3) ? 0xffffffffff7fffffULL
                          : (len == 4) ? 0xffffffff7fffffffULL
                          : (len == 5) ? 0xffffff7fffffffffULL
                          : (len == 6) ? 0xffff7fffffffffffULL
                          : (len == 7) ? 0xff7fffffffffffffULL
                                       : 0x7fffffffffffffffULL;
  v &= signmask;
  const bool neg = (last & 0x80u) != 0;
  out = neg ? -static_cast<int64_t>(v) : static_cast<int64_t>(v);
  return TWIN_OK;
}
""".strip()

REPLACEMENTS["cast_to_bool"] = """
static inline __attribute__((always_inline)) bool cast_to_bool(const uint8_t* d, uint32_t len) {
  // interpreter.cpp:46-59 / runtime.inc CastToBool, unrolled to 8 bytes:
  // TRUE iff some byte is nonzero, except when the *first* nonzero byte is the
  // last byte and equals 0x80 (negative zero).
  if (len >= 1 && d[0] != 0) return !(len == 1 && d[0] == 0x80);
  if (len >= 2 && d[1] != 0) return !(len == 2 && d[1] == 0x80);
  if (len >= 3 && d[2] != 0) return !(len == 3 && d[2] == 0x80);
  if (len >= 4 && d[3] != 0) return !(len == 4 && d[3] == 0x80);
  if (len >= 5 && d[4] != 0) return !(len == 5 && d[4] == 0x80);
  if (len >= 6 && d[5] != 0) return !(len == 6 && d[5] == 0x80);
  if (len >= 7 && d[6] != 0) return !(len == 7 && d[6] == 0x80);
  if (len >= 8 && d[7] != 0) return !(len == 8 && d[7] == 0x80);
  return false;
}
""".strip()

FN_RE = r"static inline __attribute__\(\(always_inline\)\)\s+[A-Za-z0-9_<>:&\* ]+?\b{name}\s*\("


def replace_fn(text: str, name: str, body: str) -> str:
    """Replace one whole `static inline ... name(...) { ... }` definition."""
    m = re.search(FN_RE.format(name=name), text)
    if m is None:
        raise SystemExit(f"mk_num_leaf: primitive {name} not found in mk_leaf output")
    start = m.start()
    i = text.index("{", m.end() - 1)
    depth = 0
    j = i
    while True:
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    out = text[:start] + body + text[j + 1:]
    return out


# `disabled_wire` is engine code (twin/runtime.inc), not a bounded runtime
# primitive: it is copied byte-identically, like the op_* handler bodies, so the
# numeric/C-L-2div-disabled cell can compare the twin's wire table directly.
WIRE_GATE_RE = re.compile(
    r"^// disabledWire \(Defs\.lean:455-462\): fails even in unexecuted branches\.\n"
    r"static bool disabled_wire\(uint32_t w\) \{.*?\n\}\n",
    re.S | re.M,
)


def emit_wire_gate(text: str) -> tuple[str, str]:
    src = (TWIN / "runtime.inc").read_text()
    m = WIRE_GATE_RE.search(src)
    if m is None:
        raise SystemExit("mk_num_leaf: disabled_wire not found in twin/runtime.inc")
    block = m.group(0)
    anchor = "}  // namespace twinleaf"
    if text.count(anchor) != 1:
        raise SystemExit("mk_num_leaf: twinleaf namespace anchor not unique")
    return text.replace(anchor, block + anchor), block


def handler_blocks(text: str) -> dict[str, str]:
    return {
        m.group(1): m.group(0)
        for m in re.finditer(
            r"static inline __attribute__\(\(always_inline\)\) TwinErr (op_[A-Z0-9_]+)\(State& st, const Ctx& ctx, const Decoded& d\) \{.*?\n\}",
            text,
            re.S,
        )
    }


def render(selected) -> tuple[str, dict]:
    mk = load_mk_leaf()
    base = mk.render(selected, MAX_DEPTH, MAX_ELEM)
    base_blocks = handler_blocks(base)
    text = base
    applied = []
    for name, body in REPLACEMENTS.items():
        text = replace_fn(text, name, body)
        applied.append(name)
    text, wire_gate = emit_wire_gate(text)
    # The stack/state structs and st_push/st_push_copy/st_top are inherited
    # from mk_leaf unchanged; only the six primitives above are re-bound.
    new_blocks = handler_blocks(text)
    if set(base_blocks) != set(new_blocks):
        raise SystemExit("mk_num_leaf: handler set changed during primitive rebind")
    for k in base_blocks:
        if base_blocks[k] != new_blocks[k]:
            raise SystemExit(f"mk_num_leaf: handler body for {k} changed during rebind")
    provenance = {
        "generator": "findings/wave16/07-numeric-ops/tools/mk_num_leaf.py",
        "base_generator": "cells/_tools/mk_leaf.py",
        "base_generator_sha256": hashlib.sha256(MK_LEAF.read_bytes()).hexdigest(),
        "ops_ir_sha256": hashlib.sha256((TWIN / "ops_ir.py").read_bytes()).hexdigest(),
        "gen_py_sha256": hashlib.sha256((TWIN / "gen.py").read_bytes()).hexdigest(),
        "runtime_inc_sha256": hashlib.sha256((TWIN / "runtime.inc").read_bytes()).hexdigest(),
        "max_depth": MAX_DEPTH,
        "max_elem": MAX_ELEM,
        "ops": sorted(selected),
        "handlers_verbatim": sorted(base_blocks),
        "primitives_rebound": applied,
        "wire_gate_verbatim": ["disabled_wire"],
        "note": "handler bodies are byte-identical to cells/_tools/mk_leaf.py output; "
                "the six bounded runtime primitives are the twin/runtime.inc bodies "
                "unrolled to an 8-byte element; disabled_wire is copied verbatim "
                "from twin/runtime.inc.",
    }
    return text, provenance


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ops", required=True)
    ap.add_argument("--out")
    ap.add_argument("--meta")
    ap.add_argument("--check")
    a = ap.parse_args()
    selected = {s for s in a.ops.split(",") if s}
    src, prov = render(selected)
    if a.check:
        try:
            old = Path(a.check).read_text()
        except FileNotFoundError:
            print(f"DRIFT: {a.check} missing", file=sys.stderr)
            return 1
        if old != src:
            print(f"DRIFT: {a.check} is not reproducible", file=sys.stderr)
            return 1
        print(f"OK: {a.check} matches mk_num_leaf output", file=sys.stderr)
    if a.out:
        Path(a.out).parent.mkdir(parents=True, exist_ok=True)
        Path(a.out).write_text(src)
        print(f"wrote {a.out} ({len(src)} bytes)", file=sys.stderr)
    if a.meta:
        prov = dict(prov)
        prov["leaf_sha256"] = hashlib.sha256(src.encode()).hexdigest()
        Path(a.meta).write_text(json.dumps(prov, indent=2, sort_keys=True) + "\n")
        print(f"wrote {a.meta}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
