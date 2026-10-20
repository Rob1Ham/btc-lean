#!/usr/bin/env python3
"""Check PINS.lock completeness, and optionally verify installed tool versions.

This is deliberately conservative: a value that starts with "TODO" is
unfilled, and strict mode exits non-zero if anything is unfilled. E0 is
expected to fail strict mode until CORE-IR/TWIN-IR/RUST-IR finish their pins.

Usage:
  python3 tools/check_pins.py                 # strict: exit 1 if any TODO
  python3 tools/check_pins.py --allow-todo    # report but exit 0
  python3 tools/check_pins.py --no-verify     # skip running tool binaries
"""
from __future__ import annotations

import argparse
import configparser
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "PINS.lock"

REQUIRED = {
    "core": ["commit", "version", "source", "build", "patches"],
    "rbitcoin": ["commit", "version", "source", "toolchain", "crypto", "build"],
    "lean": ["repo", "lake", "model_rev"],
    "llvm": ["clang", "llvm_ir_version", "flags", "triple"],
    "tools": ["alive2", "saw", "z3", "cvc5", "kani", "miri", "python", "cmake"],
}

# command -> (version token that must appear in stdout, human label)
VERSION_CHECKS = {
    "alive-tv": (None, "LLVM version line (Alive2 tag is the git pin)"),
    "saw": ("1.6", "SAW"),
    "z3": ("4.8.12", "Z3"),
    "cvc5": ("1.3.1", "cvc5"),
}


def load_pins(path: Path) -> configparser.ConfigParser:
    cp = configparser.ConfigParser(interpolation=None, allow_no_value=True)
    cp.optionxform = str
    with path.open() as f:
        cp.read_file(f)
    return cp


def unfilled(value: str | None) -> bool:
    if value is None:
        return True
    v = value.strip()
    return not v or v.upper().startswith("TODO")


def run_version(cmd: str) -> tuple[bool, str]:
    exe = shutil.which(cmd)
    if not exe:
        return False, f"{cmd}: NOT FOUND on PATH"
    try:
        p = subprocess.run(
            [exe, "--version"], capture_output=True, text=True, timeout=60
        )
    except Exception as e:  # noqa: BLE001 - report, never crash the gate
        return False, f"{cmd}: error running --version: {e}"
    out = (p.stdout + p.stderr).strip().splitlines()
    first = " | ".join(out[:2]) if out else "(no output)"
    return p.returncode == 0, f"{cmd}: {first}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--allow-todo", action="store_true", help="do not fail on TODO")
    ap.add_argument("--no-verify", action="store_true", help="do not run tools")
    args = ap.parse_args()

    if not PINS.exists():
        print(f"FAIL: missing {PINS}")
        return 1
    cp = load_pins(PINS)

    missing_sections = [s for s in REQUIRED if s not in cp]
    missing_keys: list[str] = []
    todo: list[str] = []
    for section, keys in REQUIRED.items():
        if section not in cp:
            continue
        for key in keys:
            if key not in cp[section]:
                missing_keys.append(f"{section}.{key} (absent)")
            elif unfilled(cp[section][key]):
                todo.append(f"{section}.{key}")

    print(f"PINS.lock: {PINS}")
    for section, keys in REQUIRED.items():
        if section not in cp:
            print(f"  [{section}] MISSING SECTION")
            continue
        for key in keys:
            val = cp[section].get(key)
            state = "TODO" if key in [t.split(".", 1)[1] for t in todo if t.startswith(section + ".")] else "set"
            if val is None or key not in cp[section]:
                state = "MISSING"
                val = ""
            print(f"  [{section}] {key} = {state}: {val.strip()}")

    print()
    if missing_sections:
        print("FAIL missing sections: " + ", ".join(missing_sections))
    if missing_keys:
        print("FAIL missing keys:")
        for m in missing_keys:
            print("  - " + m)
    print(f"Unfilled TODO keys: {len(todo)}")
    for t in todo:
        print("  - " + t)

    verify_fail = False
    if not args.no_verify:
        print("\nInstalled tool probes:")
        for cmd, (token, label) in VERSION_CHECKS.items():
            ok, line = run_version(cmd)
            status = "OK" if ok else "FAIL"
            if ok and token is not None and token not in line:
                status = "VERSION-MISMATCH"
                verify_fail = True
            if not ok:
                verify_fail = True
            print(f"  {status:16s} {line}  [{label}]")
            if cmd == "alive-tv" and ok and "LLVM" not in line:
                print("    note: Alive2 --version reports LLVM, not the Alive2 tag")

    incomplete = bool(missing_sections or missing_keys or todo)
    if incomplete and not args.allow_todo:
        print("\nRESULT: FAIL (incomplete pins; pass --allow-todo to report only)")
        return 1
    if verify_fail:
        print("\nRESULT: FAIL (installed tool probe failed/mismatched)")
        return 1
    if incomplete:
        print(f"\nRESULT: OK (pins incomplete: {len(todo)} TODO; --allow-todo)")
        return 0
    print("\nRESULT: OK (pins complete and tool probes passed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
