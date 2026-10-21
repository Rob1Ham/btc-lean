#!/usr/bin/env python3
"""Extract the pinned Core source fragments used by the SCR-040 loop->fold cell.

The cell's Lean proof is stated about *this* text.  To make the connection
source-anchored rather than a claim, the Lean file embeds each fragment as a
string literal in a generated region, and this script either re-emits that
region (`--print`) or fails if the embedded literals differ from a fresh
extraction of the pinned Core tree (`--check`, the default).

Checks performed by `--check`:
  1. the Core tree is at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66;
  2. the three source files match their recorded sha256;
  3. every embedded literal equals the exact line range listed in EXCERPTS.

The Lean proof then reduces `tokenize <literal>` in the kernel and proves the
token stream is the recognised fragment text before applying the semantics
theorem.  Nothing here is consulted at proof time; it is a provenance check.

Usage:
  extract_pinned.py --print          # emit the generated Lean region
  extract_pinned.py --check [FILE]   # default FILE = src/lean/LoopToFold.lean
"""
from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

PIN = "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
CORE_SRC = Path(
    __import__("os").environ.get("CORE_SRC", "/tmp/opencode/equiv-work/bitcoin")
)
HERE = Path(__file__).resolve().parent
LEAN_FILE = HERE / "lean" / "LoopToFold.lean"

# file -> sha256 at the pin
FILES = {
    "src/serialize.h": "9acb4bab2fe63ef351429b19d6ed75a9e719705060999c4e5dba78ce7c08db6f",
    "src/script/script.h": "43e4eb10ee85ac31996e257d0c5dc45cbe3b29b2d61d1a72d101453ba64ded01",
    "src/script/interpreter.cpp": "57a6f328c7e6202f499e48366a86eb26e09c8ebb78e92eef7e839207230be333",
}

# name -> (file, first_line, last_line, citation)
EXCERPTS = {
    "exSizeComputerWrite": (
        "src/serialize.h", 1123, 1123, "serialize.h:1121-1124 SizeComputer::write"
    ),
    "exSizeComputerSeek": (
        "src/serialize.h", 1129, 1129, "serialize.h:1127-1130 SizeComputer::seek"
    ),
    "exWriteCompactSize": (
        "src/serialize.h", 1153, 1153, "serialize.h:1151-1154 WriteCompactSize(SizeComputer&, n)"
    ),
    "exVectorFormatterSer": (
        "src/serialize.h", 671, 675, "serialize.h:666-676 VectorFormatter::Ser (the element loop)"
    ),
    "exBasicByteSerialize": (
        "src/serialize.h", 901, 902, "serialize.h:900-902 Serialize(SizeComputer&, vector<u8>) BasicByte arm"
    ),
    "exGetSerializeSize": (
        "src/serialize.h", 1159, 1159, "serialize.h:1156-1160 GetSerializeSize"
    ),
    "exValidationWeightOffset": (
        "src/script/script.h", 65, 65, "script.h:62-65 VALIDATION_WEIGHT_OFFSET"
    ),
    "exValidationWeightSeed": (
        "src/script/interpreter.cpp", 1991, 1991,
        "interpreter.cpp:1991-1992 tapscript validation-weight seed",
    ),
}

BEGIN = "-- BEGIN GENERATED EXCERPTS (src/extract_pinned.py)"
END = "-- END GENERATED EXCERPTS"


def lean_string(text: str) -> str:
    out = text.replace("\\", "\\\\").replace('"', '\\"')
    out = out.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return '"' + out + '"'


def lean_unescape(lit: str) -> str:
    # only the escapes lean_string emits
    body = lit[1:-1]
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\":
            n = body[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}[n])
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def check_pin() -> None:
    if not (CORE_SRC / "src/serialize.h").is_file():
        sys.exit(f"error: no Core tree at {CORE_SRC} (set CORE_SRC)")
    try:
        head = subprocess.run(
            ["git", "-C", str(CORE_SRC), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"error: cannot read Core pin: {exc}")
    if head != PIN:
        sys.exit(f"error: Core tree pin is {head}, expected {PIN}")
    for rel, want in FILES.items():
        got = hashlib.sha256((CORE_SRC / rel).read_bytes()).hexdigest()
        if got != want:
            sys.exit(f"error: {rel} sha256 {got} != pinned {want}")
        print(f"PIN_FILE {rel} {got}")


def extract() -> dict[str, str]:
    texts: dict[str, list[str]] = {}
    out: dict[str, str] = {}
    for name, (rel, lo, hi, _cite) in EXCERPTS.items():
        if rel not in texts:
            texts[rel] = (CORE_SRC / rel).read_text(encoding="utf-8").splitlines()
        lines = texts[rel]
        if not (1 <= lo <= hi <= len(lines)):
            sys.exit(f"error: bad range for {name}: {rel}:{lo}-{hi}")
        out[name] = "\n".join(lines[lo - 1:hi])
    return out


def render(values: dict[str, str]) -> str:
    lines = [BEGIN]
    for name, (_rel, lo, hi, cite) in EXCERPTS.items():
        lines.append(f"-- {cite}  ({_rel}:{lo}-{hi})")
        lines.append(f"def {name} : String := {lean_string(values[name])}")
        lines.append("")
    lines.append(END)
    return "\n".join(lines)


def check_file(path: Path, values: dict[str, str]) -> int:
    text = path.read_text(encoding="utf-8")
    m = re.search(re.escape(BEGIN) + r"(.*?)" + re.escape(END), text, re.S)
    if not m:
        sys.exit(f"error: no generated region in {path}")
    region = m.group(1)
    found = dict(re.findall(r'def (\w+) : String := ("(?:[^"\\]|\\.)*")', region))
    bad = 0
    for name, want in values.items():
        if name not in found:
            print(f"MISSING {name}")
            bad += 1
            continue
        got = lean_unescape(found[name])
        if got != want:
            print(f"MISMATCH {name}")
            print("  embedded:", repr(got))
            print("  pinned:  ", repr(want))
            bad += 1
    extra = set(found) - set(values)
    if extra:
        print(f"UNEXPECTED {sorted(extra)}")
        bad += 1
    for name, (_rel, lo, hi, cite) in EXCERPTS.items():
        print(f"OK {name} {cite} ({_rel}:{lo}-{hi})")
    return bad


def main() -> int:
    args = sys.argv[1:]
    check_pin()
    values = extract()
    if "--print" in args:
        print(render(values))
        return 0
    path = LEAN_FILE
    if len(args) >= 1 and args[0] not in ("--check", "--print"):
        path = Path(args[0])
    bad = check_file(path, values)
    if bad:
        print(f"RESULT=excerpts-not-pinned ({bad} mismatches)")
        return 1
    print(f"RESULT=excerpts-pinned core={PIN} file={path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
