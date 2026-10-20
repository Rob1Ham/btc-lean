#!/usr/bin/env python3
"""Extract Core's ScriptError taxonomy from a bitcoin/bitcoin checkout.

The pin for spec/equiv is Bitcoin Core v32.99 @ cce32b168.  Core's
`ScriptError` enum is the reference taxonomy for the three-leg harness; this
script turns it into (a) a reviewable Markdown mapping table, (b) a JSON
record, or (c) the C header `contract/error_kind.h` used by the shims.

Why two files?
  * `src/script/script_error.h` defines the enum *and its order/values*.
  * `src/script/script_error.cpp` defines the human-readable strings.
The .cpp alone does not carry numeric values, so ordinals are taken from the
header and cross-checked against the .cpp case labels.

Usage:
    python3 contract/extract_error_enum.py --core-src /path/to/bitcoin
    CORE_SRC=/path/to/bitcoin python3 contract/extract_error_enum.py --format h
    python3 contract/extract_error_enum.py --core-src ... --format json

Exit codes: 0 success, 2 CORE_SRC absent/incomplete, 1 parse/consistency error.
No network access, no Core build, no import of Core code.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

EXPECTED_PIN = "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
SHARED_PREFIX = "EQUIV_ERR_"
CORE_PREFIX = "SCRIPT_ERR_"

HEADER_REL = Path("src/script/script_error.h")
CPP_REL = Path("src/script/script_error.cpp")


@dataclass
class Entry:
    core_name: str
    value: int
    group: str
    message: str = ""
    shared_name: str = field(init=False)

    def __post_init__(self) -> None:
        suffix = self.core_name.removeprefix(CORE_PREFIX)
        # The sentinel is spelled EQUIV_ERR_COUNT, not EQUIV_ERR_ERROR_COUNT.
        if suffix == "ERROR_COUNT":
            suffix = "COUNT"
        self.shared_name = SHARED_PREFIX + suffix


def die(msg: str, code: int = 1) -> "NoReturn":  # type: ignore[name-defined]
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def find_core_src(cli_value: str | None) -> Path:
    raw = cli_value or os.environ.get("CORE_SRC")
    if not raw:
        die(
            "CORE_SRC is not set. Pass --core-src /path/to/bitcoin or set the "
            "CORE_SRC environment variable to a bitcoin/bitcoin checkout at the "
            f"pin ({EXPECTED_PIN}).\n"
            "This script does not need a Core build, only the source tree.",
            code=2,
        )
    root = Path(raw).expanduser()
    missing = [str(p) for p in (root / HEADER_REL, root / CPP_REL) if not p.is_file()]
    if missing:
        die(
            f"CORE_SRC is absent or incomplete: {root}\n"
            "missing: " + ", ".join(missing) + "\n"
            "Expected a bitcoin/bitcoin checkout at the pin "
            f"({EXPECTED_PIN}); no build is required.",
            code=2,
        )
    return root


def git_head(root: Path) -> str | None:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return out.stdout.strip() or None


def parse_header(path: Path) -> list[Entry]:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"typedef\s+enum\s+ScriptError_t\s*\{(.*?)\}\s*ScriptError\s*;", text, re.S)
    if not m:
        die(f"could not find 'typedef enum ScriptError_t {{...}} ScriptError;' in {path}")
    body = m.group(1)

    # Preserve group comments as sentinels so they survive splitting by comma.
    def group_repl(match: re.Match[str]) -> str:
        group = re.sub(r"\s+", " ", match.group(1)).strip()
        return f"@@GROUP:{group}@@"

    body = re.sub(r"/\*(.*?)\*/", group_repl, body, flags=re.S)
    body = re.sub(r"//[^\n]*", "", body)

    entries: list[Entry] = []
    group = "ungrouped"
    next_value = 0
    for chunk in body.split(","):
        gm = re.search(r"@@GROUP:(.*?)@@", chunk)
        if gm:
            group = gm.group(1)
            chunk = chunk.replace(gm.group(0), "")
        chunk = chunk.strip()
        if not chunk:
            continue
        em = re.fullmatch(r"(SCRIPT_ERR_[A-Z0-9_]+)\s*(?:=\s*(-?\d+))?", chunk)
        if not em:
            die(f"unparsed header entry {chunk!r} in {path}")
        name = em.group(1)
        value = int(em.group(2)) if em.group(2) is not None else next_value
        if name == "SCRIPT_ERR_ERROR_COUNT":
            group = "sentinel"
        entries.append(Entry(core_name=name, value=value, group=group))
        next_value = value + 1

    if not entries:
        die(f"no SCRIPT_ERR_* entries parsed from {path}")
    return entries


def parse_messages(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    messages: dict[str, str] = {}
    pattern = re.compile(
        r"case\s+(SCRIPT_ERR_[A-Z0-9_]+)\s*:\s*return\s+\"((?:[^\"\\]|\\.)*)\"\s*;",
        re.S,
    )
    for name, msg in pattern.findall(text):
        messages[name] = bytes(msg, "utf-8").decode("unicode_escape")
    return messages


def load(root: Path) -> tuple[list[Entry], str | None]:
    entries = parse_header(root / HEADER_REL)
    messages = parse_messages(root / CPP_REL)

    header_names = {e.core_name for e in entries}
    unknown_cpp = sorted(set(messages) - header_names)
    if unknown_cpp:
        die(f"{CPP_REL} mentions names absent from the header: {unknown_cpp}")

    for entry in entries:
        entry.message = messages.get(entry.core_name, "")
        if not entry.message and entry.core_name not in {
            "SCRIPT_ERR_UNKNOWN_ERROR",
            "SCRIPT_ERR_ERROR_COUNT",
        }:
            print(
                f"warning: no ScriptErrorString() message for {entry.core_name}",
                file=sys.stderr,
            )

    # Ordinals must be dense and zero-based: the shared enum mirrors them.
    actual = [e.value for e in entries]
    if actual != list(range(len(entries))):
        die(f"ScriptError ordinals are not dense from 0: {actual}")
    if entries[-1].core_name != "SCRIPT_ERR_ERROR_COUNT":
        die("last ScriptError entry is not SCRIPT_ERR_ERROR_COUNT")

    return entries, git_head(root)


def emit_md(entries: list[Entry], head: str | None) -> str:
    lines = [
        "# Core ScriptError -> shared enum (generated)",
        "",
        "Generated by `contract/extract_error_enum.py` from "
        "`src/script/script_error.h` + `src/script/script_error.cpp`.",
        f"Core commit: `{head or 'unknown (not a git checkout)'}`",
        f"Shared values mirror Core ordinals exactly; `COUNT` = {len(entries)}.",
        "",
        "| Core value | Core name | Shared name | Group | `ScriptErrorString` |",
        "|---:|---|---|---|---|",
    ]
    for e in entries:
        msg = e.message.replace("|", "\\|") if e.message else "_falls through to \"unknown error\"_"
        lines.append(
            f"| {e.value} | `{e.core_name}` | `{e.shared_name}` = {e.value} "
            f"| {e.group} | {msg} |"
        )
    lines.append("")
    return "\n".join(lines)


def emit_json(entries: list[Entry], head: str | None) -> str:
    doc = {
        "pin": head,
        "expected_pin": EXPECTED_PIN,
        "source": {
            "header": str(HEADER_REL),
            "strings": str(CPP_REL),
        },
        "values_mirror_core_ordinals": True,
        "count": len(entries),
        "entries": [
            {
                "value": e.value,
                "core_name": e.core_name,
                "shared_name": e.shared_name,
                "group": e.group,
                "message": e.message or None,
            }
            for e in entries
        ],
    }
    return json.dumps(doc, indent=2) + "\n"


def emit_header(entries: list[Entry], head: str | None) -> str:
    guard = "SPEC_EQUIV_ERROR_KIND_H"
    lines = [
        "/* Generated by contract/extract_error_enum.py -- do not hand-edit.",
        " *",
        " * Shared script-error taxonomy for the three-leg equivalence harness.",
        f" * Source: Bitcoin Core {head or 'unknown commit'}",
        f" *         ({HEADER_REL} + {CPP_REL})",
        " *",
        " * Values mirror Core's ScriptError ordinals at the pin, so the Core shim",
        " * can pass ScriptError through without a translation table.  The twin and",
        " * rbitcoin legs MUST map onto these values; a divergence is a finding.",
        " *",
        " * EQUIV_ERR_OK        : script passed (VerifyScript set SCRIPT_ERR_OK).",
        " * EQUIV_ERR_UNKNOWN_ERROR : result 2/3, or Core's catch-all.",
        " * EQUIV_ERR_COUNT     : sentinel, never a result.",
        " */",
        f"#ifndef {guard}",
        f"#define {guard}",
        "",
        "/* Normative ABI version; bump with ABI.md and re-pin. */",
        "#define EQUIV_ABI_VERSION 2",
        "",
        "#include <stdint.h>",
        "",
        "typedef enum equiv_error_kind {",
    ]
    width = max(len(e.shared_name) for e in entries) + 1
    last_group = None
    for e in entries:
        if e.group != last_group:
            if last_group is not None:
                lines.append("")
            lines.append(f"    /* {e.group} */")
            last_group = e.group
        lines.append(f"    {e.shared_name.ljust(width)}= {e.value},")
    lines += [
        "} equiv_error_kind;",
        "",
        "/* The Rust shim receives this out-parameter as *mut i32; keep it 32-bit. */",
        "#if defined(__cplusplus)",
        "static_assert(sizeof(equiv_error_kind) == sizeof(int32_t),",
        '              "equiv_error_kind must be 32-bit for the C ABI");',
        "#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L",
        "_Static_assert(sizeof(equiv_error_kind) == sizeof(int32_t),",
        '                "equiv_error_kind must be 32-bit for the C ABI");',
        "#endif",
        "",
        f"/* Number of real error kinds excluding OK and the COUNT sentinel: "
        f"{len(entries) - 2}. */",
        "",
        f"#endif /* {guard} */",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--core-src", help="bitcoin/bitcoin checkout (or set CORE_SRC)")
    ap.add_argument("--format", choices=("md", "json", "h"), default="md")
    ap.add_argument("--out", help="write to this path instead of stdout")
    ap.add_argument(
        "--strict-pin",
        action="store_true",
        help=f"fail if CORE_SRC HEAD is not {EXPECTED_PIN}",
    )
    args = ap.parse_args()

    root = find_core_src(args.core_src)
    entries, head = load(root)

    if args.strict_pin and head != EXPECTED_PIN:
        die(f"CORE_SRC HEAD is {head or 'unknown'}, expected {EXPECTED_PIN}")

    if head and head != EXPECTED_PIN:
        print(
            f"warning: CORE_SRC HEAD {head} differs from spec/equiv pin "
            f"{EXPECTED_PIN}; values below describe the checkout, not the pin",
            file=sys.stderr,
        )

    emit = {"md": emit_md, "json": emit_json, "h": emit_header}[args.format]
    text = emit(entries, head)
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
        print(
            f"wrote {args.out} ({len(entries)} entries, format={args.format})",
            file=sys.stderr,
        )
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
