#!/usr/bin/env python3
"""Independent differential audit for SCR-015 / SCR-016 flag-derivation cells.

This script does NOT trust the cell's transcribed constants.  It re-derives the
expected answer from the *pinned Core tree* and compares three independent
artefacts:

  * C leg  -- spec/equiv/cells/_tools/w32/c_flags.cpp (compiled)
  * L leg  -- spec/equiv/cells/_tools/w32/l_flags.cpp (compiled)
  * model  -- this file's Python implementation, whose constants are parsed
              from the pinned Core sources at run time:
                src/kernel/chainparams.cpp   (exception hashes + heights)
                src/validation.cpp           (base set / REPLACE / OR order)
                src/script/interpreter.h     (flag ordinals -> 1 << ordinal)

It also runs negative controls: a deliberately mutated C leg and a mutated L
leg must be caught by the same harness, so a green result is not vacuous.

Usage:
  python3 check_flags_diff.py [--core-src /path/to/bitcoin] [--json out.json]

Exit code 0 iff every comparison agrees and both mutation controls are caught.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import random
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]          # repo root
CELLS = ROOT / "spec" / "equiv" / "cells" / "_tools" / "w32"
C_SRC = CELLS / "c_flags.cpp"
L_SRC = CELLS / "l_flags.cpp"
COMMON = CELLS / "w32_common.h"

CLANG = "/usr/bin/clang++-20"


# --------------------------------------------------------------------------- #
# Core-source model
# --------------------------------------------------------------------------- #
def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="replace")


def parse_flag_ordinals(interpreter_h: Path) -> dict[str, int]:
    """Parse `enum class script_verify_flag_name : uint8_t { ... }`.

    Core defines the numeric value of a flag as
        1 << static_cast<uint8_t>(name)
    (src/script/verify_flags.h), so the ordinal is the declaration order.
    """
    text = _read(interpreter_h)
    m = re.search(
        r"enum\s+class\s+script_verify_flag_name\s*:\s*uint8_t\s*\{(.*?)\};",
        text,
        re.S,
    )
    if not m:
        raise SystemExit(f"could not find script_verify_flag_name in {interpreter_h}")
    body = re.sub(r"//[^\n]*", "", m.group(1))
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.S)
    names = [n.strip() for n in body.split(",") if n.strip()]
    return {name: i for i, name in enumerate(names)}


def parse_core(core_src: Path) -> dict:
    chainparams_full = _read(core_src / "src" / "kernel" / "chainparams.cpp")
    # Only CMainParams: the other chains also populate script_flag_exceptions.
    m_main = re.search(
        r"class CMainParams\s*:\s*public CChainParams\s*\{(.*?)\n\};",
        chainparams_full,
        re.S,
    )
    if not m_main:
        raise SystemExit("could not isolate CMainParams in chainparams.cpp")
    chainparams = m_main.group(1)
    validation = _read(core_src / "src" / "validation.cpp")
    interpreter = core_src / "src" / "script" / "interpreter.h"
    ordinals = parse_flag_ordinals(interpreter)

    def bit(name: str) -> int:
        return 1 << ordinals[name]

    # --- exception map: mainnet emplace() calls, in source order -----------
    # consensus.script_flag_exceptions.emplace( // comment
    #     uint256{"<hash>"}, SCRIPT_VERIFY_NONE);
    # consensus.script_flag_exceptions.emplace( // comment
    #     uint256{"<hash>"}, SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS);
    exc = re.findall(
        r"script_flag_exceptions\.emplace\((.*?)\);", chainparams, re.S
    )
    exceptions: list[tuple[int, int]] = []
    for block in exc:
        hm = re.search(r'uint256\{"([0-9a-fA-F]{64})"\}', block)
        if not hm:
            continue
        hash_int = int(hm.group(1), 16)
        flags = 0
        for name in re.findall(r"SCRIPT_VERIFY_[A-Z0-9_]+", block):
            if name == "SCRIPT_VERIFY_NONE":
                continue
            flags |= bit(name)
        exceptions.append((hash_int, flags))
    if len(exceptions) != 2:
        raise SystemExit(
            f"expected 2 mainnet script_flag_exceptions, parsed {len(exceptions)}"
        )

    # --- buried heights ----------------------------------------------------
    heights = {}
    for key in ("BIP66Height", "BIP65Height", "CSVHeight", "SegwitHeight"):
        m = re.search(rf"consensus\.{key}\s*=\s*(\d+);", chainparams)
        if not m:
            raise SystemExit(f"could not parse consensus.{key}")
        heights[key] = int(m.group(1))

    # --- function body / order sanity --------------------------------------
    fn = re.search(
        r"script_verify_flags GetBlockScriptFlags\(.*?\n\}", validation, re.S
    )
    if not fn:
        raise SystemExit("could not find GetBlockScriptFlags in validation.cpp")
    body = fn.group(0)
    checks = {
        "base": bool(
            re.search(
                r"script_verify_flags flags\{SCRIPT_VERIFY_P2SH \| "
                r"SCRIPT_VERIFY_WITNESS \| SCRIPT_VERIFY_TAPROOT\};",
                body,
            )
        ),
        "replace": "flags = it->second;" in body,
        "dersig": bool(
            re.search(
                r"DEPLOYMENT_DERSIG.*?flags \|= SCRIPT_VERIFY_DERSIG;", body, re.S
            )
        ),
        "cltv": bool(
            re.search(
                r"DEPLOYMENT_CLTV.*?flags \|= SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY;",
                body,
                re.S,
            )
        ),
        "csv": bool(
            re.search(
                r"DEPLOYMENT_CSV.*?flags \|= SCRIPT_VERIFY_CHECKSEQUENCEVERIFY;",
                body,
                re.S,
            )
        ),
        "nulldummy": bool(
            re.search(
                r"DEPLOYMENT_SEGWIT.*?flags \|= SCRIPT_VERIFY_NULLDUMMY;", body, re.S
            )
        ),
    }
    if not all(checks.values()):
        raise SystemExit(f"GetBlockScriptFlags shape checks failed: {checks}")

    # Order matters: the replacement precedes the ORs.
    if body.index("flags = it->second;") > body.index("DEPLOYMENT_DERSIG"):
        raise SystemExit("exception replacement does not precede the buried ORs")

    # --- BIP34 activation hash (used by the L2-ACT oracle) ----------------
    m34 = re.search(r'consensus\.BIP34Hash\s*=\s*uint256\{"([0-9a-fA-F]{64})"\}', chainparams)
    bip34_hash = int(m34.group(1), 16) if m34 else None

    return {
        "source": str(core_src),
        "source_sha256": {
            "src/kernel/chainparams.cpp": hashlib.sha256(
                (core_src / "src/kernel/chainparams.cpp").read_bytes()
            ).hexdigest(),
            "src/validation.cpp": hashlib.sha256(
                (core_src / "src/validation.cpp").read_bytes()
            ).hexdigest(),
            "src/script/interpreter.h": hashlib.sha256(interpreter.read_bytes()).hexdigest(),
        },
        "exceptions": exceptions,
        "bip34_hash": bip34_hash,
        "heights": heights,
        "base": bit("SCRIPT_VERIFY_P2SH") | bit("SCRIPT_VERIFY_WITNESS") | bit("SCRIPT_VERIFY_TAPROOT"),
        "bits": {
            "P2SH": bit("SCRIPT_VERIFY_P2SH"),
            "WITNESS": bit("SCRIPT_VERIFY_WITNESS"),
            "TAPROOT": bit("SCRIPT_VERIFY_TAPROOT"),
            "DERSIG": bit("SCRIPT_VERIFY_DERSIG"),
            "CLTV": bit("SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY"),
            "CSV": bit("SCRIPT_VERIFY_CHECKSEQUENCEVERIFY"),
            "NULLDUMMY": bit("SCRIPT_VERIFY_NULLDUMMY"),
        },
        "shape_checks": checks,
    }


def model_flags(model: dict, hash_int: int, height: int) -> int:
    flags = model["base"]
    for h, f in model["exceptions"]:
        if hash_int == h:
            flags = f  # REPLACE
            break
    hts = model["heights"]
    if height >= hts["BIP66Height"]:
        flags |= model["bits"]["DERSIG"]
    if height >= hts["BIP65Height"]:
        flags |= model["bits"]["CLTV"]
    if height >= hts["CSVHeight"]:
        flags |= model["bits"]["CSV"]
    if height >= hts["SegwitHeight"]:
        flags |= model["bits"]["NULLDUMMY"]
    return flags


def model_exc_select(model: dict, hash_int: int) -> int:
    for idx, (h, _f) in enumerate(model["exceptions"], start=1):
        if hash_int == h:
            return idx
    return 0


def split_limbs(value: int) -> tuple[int, int, int, int]:
    return tuple((value >> s) & 0xFFFFFFFFFFFFFFFF for s in (192, 128, 64, 0))


def abi_domain_ok(flags: int) -> bool:
    """Contract tape/ABI domain for the `flags` argument (tape.md section 5).

    bits 0..20 only; WITNESS => P2SH; CLEANSTACK => P2SH and WITNESS.
    """
    if flags & ~0x1FFFFF:
        return False
    p2sh = bool(flags & 0x1)
    witness = bool(flags & 0x800)
    cleanstack = bool(flags & 0x100)
    if witness and not p2sh:
        return False
    if cleanstack and not (p2sh and witness):
        return False
    return True


# --------------------------------------------------------------------------- #
# Build the legs
# --------------------------------------------------------------------------- #
def build(src: Path, out: Path, extra: list[str] | None = None) -> None:
    cmd = [
        CLANG,
        "-std=c++17",
        "-O1",
        "-fno-strict-aliasing",
        "-fPIC",
        "-shared",
        "-I",
        str(CELLS),
        str(src),
        "-o",
        str(out),
    ] + (extra or [])
    subprocess.run(cmd, check=True)


class Leg:
    def __init__(self, so: Path):
        lib = ctypes.CDLL(str(so))
        u64 = ctypes.c_uint64
        u32 = ctypes.c_uint32
        self.block_flags = lib.cell_block_flags
        self.block_flags.argtypes = [u64, u64, u64, u64, u32]
        self.block_flags.restype = u64
        self.exc_select = lib.cell_exc_select
        self.exc_select.argtypes = [u64, u64, u64, u64]
        self.exc_select.restype = u64
        self.bip16_at = lib.cell_flags_bip16_at
        self.bip16_at.argtypes = [u32]
        self.bip16_at.restype = u64
        self.taproot_at = lib.cell_flags_taproot_at
        self.taproot_at.argtypes = [u32]
        self.taproot_at.restype = u64
        self.bip16_named = lib.cell_flags_bip16_named
        self.bip16_named.argtypes = []
        self.bip16_named.restype = u64
        self.taproot_named = lib.cell_flags_taproot_named
        self.taproot_named.argtypes = []
        self.taproot_named.restype = u64

    def flags(self, h: int, height: int) -> int:
        return int(self.block_flags(*split_limbs(h), height))

    def select(self, h: int) -> int:
        return int(self.exc_select(*split_limbs(h)))


# --------------------------------------------------------------------------- #
# Test vectors
# --------------------------------------------------------------------------- #
def make_hashes(model: dict, rng: random.Random) -> list[tuple[str, int]]:
    out: list[tuple[str, int]] = []
    exc_hashes = [h for h, _ in model["exceptions"]]
    for name, h in zip(("bip16", "taproot"), exc_hashes):
        out.append((f"exception/{name}", h))
        # every single-bit flip: 256 per hash
        for bit in range(256):
            out.append((f"exception/{name}/flip-bit-{bit}", h ^ (1 << bit)))
        # each limb all-ones / all-zero patterns
        for limb in range(4):
            for pat in (0, 0xFFFFFFFFFFFFFFFF):
                v = list(split_limbs(h))
                v[limb] = pat
                n = 0
                for x in v:
                    n = (n << 64) | x
                out.append((f"exception/{name}/limb-{limb}-{pat:#x}", n))
    for i in range(4000):
        out.append((f"random/{i}", rng.getrandbits(256)))
    for name, v in (
        ("zero", 0),
        ("max", (1 << 256) - 1),
        ("one", 1),
        ("2^255", 1 << 255),
    ):
        out.append((name, v))
    return out


def make_heights(model: dict) -> list[tuple[str, int]]:
    hs = sorted(model["heights"].values())
    out: list[tuple[str, int]] = [
        ("0", 0),
        ("1", 1),
        ("2^31", 1 << 31),
        ("2^32-2", (1 << 32) - 2),
        ("2^32-1", (1 << 32) - 1),
    ]
    for h in hs:
        out += [(f"{h}-1", h - 1), (f"{h}", h), (f"{h}+1", h + 1)]
    rng = random.Random(20261020)
    out += [(f"random/{i}", rng.randrange(1 << 32)) for i in range(500)]
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--core-src",
        default="/tmp/opencode/core-pin",
        help="pinned Bitcoin Core checkout (default: /tmp/opencode/core-pin)",
    )
    ap.add_argument("--json", default=None, help="write the summary as JSON")
    args = ap.parse_args()

    core_src = Path(args.core_src)
    if not (core_src / "src" / "validation.cpp").is_file():
        raise SystemExit(
            f"pinned Core tree not found at {core_src}; pass --core-src"
        )
    model = parse_core(core_src)

    with tempfile.TemporaryDirectory(prefix="w32-flags-audit-") as td:
        td = Path(td)
        c_so, l_so = td / "c.so", td / "l.so"
        build(C_SRC, c_so)
        build(L_SRC, l_so)
        c, l = Leg(c_so), Leg(l_so)

        hashes = make_hashes(model, random.Random(20261020))
        heights = make_heights(model)

        mismatches: list[dict] = []
        checks = 0
        abi_domain_violations = 0

        def record(want: int) -> None:
            nonlocal abi_domain_violations
            if not abi_domain_ok(want):
                abi_domain_violations += 1

        # full hash x full height would be 2^256; instead: every hash against a
        # boundary/random height sample, and every boundary height against a
        # hash sample.  This covers both axes independently.
        h_sample = hashes[:: max(1, len(hashes) // 400)]
        for name, hv in hashes:
            for hname, height in heights[:: max(1, len(heights) // 12)]:
                want = model_flags(model, hv, height)
                record(want)
                got_c = c.flags(hv, height)
                got_l = l.flags(hv, height)
                checks += 1
                if not (want == got_c == got_l):
                    mismatches.append(
                        {
                            "fn": "cell_block_flags",
                            "hash": name,
                            "height": hname,
                            "model": want,
                            "c": got_c,
                            "l": got_l,
                        }
                    )
        for name, hv in h_sample:
            for hname, height in heights:
                want = model_flags(model, hv, height)
                record(want)
                got_c = c.flags(hv, height)
                got_l = l.flags(hv, height)
                checks += 1
                if not (want == got_c == got_l):
                    mismatches.append(
                        {
                            "fn": "cell_block_flags",
                            "hash": name,
                            "height": hname,
                            "model": want,
                            "c": got_c,
                            "l": got_l,
                        }
                    )

        for name, hv in hashes:
            want = model_exc_select(model, hv)
            got_c, got_l = c.select(hv), l.select(hv)
            checks += 1
            if not (want == got_c == got_l):
                mismatches.append(
                    {
                        "fn": "cell_exc_select",
                        "hash": name,
                        "model": want,
                        "c": got_c,
                        "l": got_l,
                    }
                )

        # at() wrappers and the two named blocks
        for name, (h, base) in zip(("bip16", "taproot"), model["exceptions"]):
            for hname, height in heights:
                want = model_flags(model, h, height)
                record(want)
                got_c = int(c.bip16_at(height) if name == "bip16" else c.taproot_at(height))
                got_l = int(l.bip16_at(height) if name == "bip16" else l.taproot_at(height))
                checks += 1
                if not (want == got_c == got_l):
                    mismatches.append(
                        {
                            "fn": f"cell_flags_{name}_at",
                            "height": hname,
                            "model": want,
                            "c": got_c,
                            "l": got_l,
                        }
                    )

        named = {
            "bip16": (model["exceptions"][0][0], 170060),
            "taproot": (model["exceptions"][1][0], 692261),
        }
        # Named heights are documentation data, not Core constants.  If the
        # Lean module records different pairs, fail loudly instead of silently
        # blessing the cell.
        lean = _read(ROOT / "spec" / "core" / "Bitcoin" / "Activation" / "Flags.lean")
        for name, (h, height) in named.items():
            want = model_flags(model, h, height)
            record(want)
            got_c = int(c.bip16_named() if name == "bip16" else c.taproot_named())
            got_l = int(l.bip16_named() if name == "bip16" else l.taproot_named())
            checks += 1
            if not (want == got_c == got_l):
                mismatches.append(
                    {
                        "fn": f"cell_flags_{name}_named",
                        "model": want,
                        "c": got_c,
                        "l": got_l,
                    }
                )
            if not re.search(
                rf"{name}(?:_| )?[^\n]*{height}", lean, re.I
            ) and height not in lean:
                mismatches.append(
                    {
                        "fn": "named-height-provenance",
                        "detail": f"{name} height {height} absent from Flags.lean",
                    }
                )

        # ---- in-repo L2-ACT oracle (class E, hash-keyed) ------------------
        # A different workstream's Core transliteration (L2ActMirror.py) plus
        # its checked-in vectors.  Class E supplies the hash selector, so it
        # is directly comparable to the hash-keyed cell.
        l2_path = ROOT / "spec" / "data" / "l2" / "act" / "cases.jsonl"
        l2_checked = l2_agree = 0
        l2_mismatches: list[dict] = []
        if l2_path.is_file():
            bit_order = ["P2SH", "DERSIG", "CLTV", "CSV", "NULLDUMMY", "WITNESS", "TAPROOT"]
            bit_values = [model["bits"][k] for k in bit_order]
            unused_hash = int.from_bytes(b"\xde\xad" * 16, "big")
            for line in l2_path.read_text().splitlines():
                parts = line.split("|")
                if len(parts) < 6 or parts[1] != "E":
                    continue
                cid, height_s, sel_s, bits = parts[0], parts[2], parts[3], parts[5]
                if len(bits) != 7 or set(bits) - {"0", "1"}:
                    continue
                height = int(height_s)
                sel = int(sel_s)
                if sel == 1:
                    hv = model["exceptions"][0][0]
                elif sel == 2:
                    hv = model["exceptions"][1][0]
                elif sel == 3 and model["bip34_hash"] is not None:
                    hv = model["bip34_hash"]
                else:
                    hv = unused_hash
                want = 0
                for b, v in zip(bits, bit_values):
                    if b == "1":
                        want |= v
                got_c, got_l = c.flags(hv, height), l.flags(hv, height)
                got_m = model_flags(model, hv, height)
                l2_checked += 1
                if want == got_c == got_l == got_m:
                    l2_agree += 1
                else:
                    l2_mismatches.append(
                        {
                            "case": cid,
                            "height": height,
                            "selector": sel,
                            "want": f"0x{want:x}",
                            "model": f"0x{got_m:x}",
                            "c": f"0x{got_c:x}",
                            "l": f"0x{got_l:x}",
                        }
                    )
                    mismatches.append({"fn": "l2-act", **l2_mismatches[-1]})

        # ---- negative controls ------------------------------------------
        # 1. mutated C leg: BIP66 height off by one must be caught.
        hdr = COMMON.read_text()
        mut_dir = td / "mut_c"
        mut_dir.mkdir()
        (mut_dir / "w32_common.h").write_text(
            hdr.replace("BIP66_HEIGHT = 363725", "BIP66_HEIGHT = 363726")
        )
        # Copy the source too: a quoted include resolves next to the .cpp
        # before -I paths, so compiling the shared source would silently use
        # the original header.
        mut_c_src = mut_dir / "c_flags.cpp"
        mut_c_src.write_text(C_SRC.read_text())
        mut_so = td / "c_mut.so"
        subprocess.run(
            [
                CLANG, "-std=c++17", "-O1", "-fno-strict-aliasing", "-fPIC",
                "-shared", "-I", str(mut_dir), str(mut_c_src), "-o", str(mut_so),
            ],
            check=True,
        )
        mut = Leg(mut_so)
        probe_h = next(h for h in make_heights(model) if h[0] == "363725")
        # use a non-exception hash
        normal_h = named["bip16"][0] ^ 1
        mutation_caught = (
            mut.flags(normal_h, probe_h[1]) != model_flags(model, normal_h, probe_h[1])
        )

        # 2. mutated L leg: one limb of the BIP16 exception hash off by one.
        # l_flags includes w32_common.h, so mutate that copy (and the copied
        # source, for the same quoted-include reason).
        mut_l_dir = td / "mut_l"
        mut_l_dir.mkdir()
        (mut_l_dir / "w32_common.h").write_text(
            hdr.replace(
                "BIP16_H3 = 0x94b1ba88ac4f9c22ull",
                "BIP16_H3 = 0x94b1ba88ac4f9c23ull",
            )
        )
        mut_l_src = mut_l_dir / "l_flags.cpp"
        mut_l_src.write_text(L_SRC.read_text())
        l_mut_so = td / "l_mut.so"
        subprocess.run(
            [
                CLANG, "-std=c++17", "-O1", "-fno-strict-aliasing", "-fPIC",
                "-shared", "-I", str(mut_l_dir), str(mut_l_src), "-o", str(l_mut_so),
            ],
            check=True,
        )
        lmut = Leg(l_mut_so)
        mutation_l_caught = (
            lmut.select(named["bip16"][0]) != 1
        )

        # ---- SAW / Alive2 artefacts: markers, not re-run here -------------
        artefact_status = {}
        for cell in ("C-L-w32-block-flags", "C-L-w32-flag-exceptions"):
            base = ROOT / "spec" / "equiv" / "cells" / "exec-verify" / cell
            artefact_status[cell] = {
                "alive2_result": (base / "alive2" / "result.txt").read_text().strip().splitlines()[-1],
                "saw_result": (base / "saw" / "result.txt").read_text().strip().splitlines()[-1],
                "alive2_sha256": hashlib.sha256((base / "alive2" / "result.txt").read_bytes()).hexdigest(),
                "saw_sha256": hashlib.sha256((base / "saw" / "result.txt").read_bytes()).hexdigest(),
            }

        summary = {
            "model_source": model["source"],
            "source_sha256": model["source_sha256"],
            "parsed": {
                "exceptions": [
                    {"hash": f"{h:064x}", "flags": f"0x{f:x}"}
                    for h, f in model["exceptions"]
                ],
                "heights": model["heights"],
                "base": f"0x{model['base']:x}",
                "bits": {k: f"0x{v:x}" for k, v in model["bits"].items()},
                "shape_checks": model["shape_checks"],
            },
            "comparisons": checks,
            "mismatches": mismatches,
            "abi_domain_violations": abi_domain_violations,
            "l2_act": {
                "path": "spec/data/l2/act/cases.jsonl",
                "class_E_cases": l2_checked,
                "agree": l2_agree,
                "mismatches": l2_mismatches,
            },
            "negative_controls": {
                "c_bip66_height_plus_one_caught": mutation_caught,
                "l_bip16_hash_limb_flip_caught": mutation_l_caught,
            },
            "named": {
                "bip16@170060": f"0x{model_flags(model, named['bip16'][0], 170060):x}",
                "taproot@692261": f"0x{model_flags(model, named['taproot'][0], 692261):x}",
            },
            "artefacts": artefact_status,
        }

        ok = (
            not mismatches
            and abi_domain_violations == 0
            and (l2_checked == 0 or l2_agree == l2_checked)
            and mutation_caught
            and mutation_l_caught
            and all(
                v["alive2_result"] == "STATUS=alive2-green"
                and v["saw_result"] == "STATUS=saw-green"
                for v in artefact_status.values()
            )
        )
        summary["verdict"] = "PASS" if ok else "FAIL"
        print(json.dumps(summary, indent=2))
        if args.json:
            Path(args.json).write_text(json.dumps(summary, indent=2) + "\n")
        return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
