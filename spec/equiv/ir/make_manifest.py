#!/usr/bin/env python3
"""make_manifest.py -- assemble spec/equiv/ir/manifest.json.

Reads the provenance fragments emitted by build_core.sh / build_twin.sh /
build_rust.sh, the raw smoke output (smoke.sh), and the pins; re-hashes every
artifact file; and writes one manifest. It exits non-zero if a recorded hash
does not match a file on disk, or if a producer/triple/datalayout differs from
the pin. No timestamp is embedded, so the manifest is reproducible.
"""
from __future__ import annotations

import configparser
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EQUIV = os.path.dirname(HERE)

EXPECTED_DATALAYOUT = (
    "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-"
    "f80:128-n8:16:32:64-S128"
)
EXPECTED = {
    "C": {"producer_contains": "clang version 20.1.2",
          "triple": "x86_64-pc-linux-gnu"},
    "L": {"producer_contains": "clang version 20.1.2",
          "triple": "x86_64-pc-linux-gnu"},
    "R": {"producer_contains": "rustc 1.95.0 (59807616e 2026-04-14)",
          "triple": "x86_64-unknown-linux-gnu"},
}

KEY_PATTERNS = {
    "C": ("VerifyScript", "EvalScript", "CastToBool", "CheckSignatureEncoding",
          "FindAndDelete", "SigHashCache", "ComputeTapleafHash",
          "ComputeTaprootMerkleRoot", "CheckMinimalPush"),
    "L": ("entry", "eval_script", "cast_to_bool", "validate_script", "dispatch"),
    "R": ("verify_input", "verify_job_all_inputs", "verify_tx_scripts_with_flags",
          "is_op_success", "verify_bare", "script_pool"),
}


def key_functions(leg: str, defined: list[str]) -> list[str]:
    return [s for s in defined if any(p in s for p in KEY_PATTERNS[leg])]


def demangle(names: list[str]) -> list[str]:
    try:
        r = subprocess.run(["c++filt"], input="\n".join(names), capture_output=True,
                           text=True, check=True)
        return r.stdout.splitlines()
    except Exception:
        return names


def sha(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def read_pins() -> dict:
    cp = configparser.ConfigParser(delimiters=("=",), comment_prefixes=("#",))
    cp.read(os.path.join(EQUIV, "PINS.lock"))
    return {s: dict(cp.items(s)) for s in cp.sections()}


def text_functions(ll_path: str, limit: int | None = None) -> list[str]:
    """Defined function names, for artifacts LLVM-20 nm cannot read."""
    names = []
    pat = re.compile(r'^define\s[^@]*@("?)([^"(\s]+)\1')
    with open(ll_path, errors="replace") as f:
        for line in f:
            m = pat.match(line)
            if m:
                names.append(m.group(2))
    return sorted(set(names))


def main() -> int:
    art_root = sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/ir-pipeline/artifacts"
    frag_dir = os.path.join(art_root, "fragments")
    frags = {}
    for leg in ("core", "twin", "rust"):
        p = os.path.join(frag_dir, f"{leg}.json")
        if not os.path.isfile(p):
            print(f"make_manifest: missing fragment {p}", file=sys.stderr)
            return 2
        with open(p) as f:
            frags[leg] = json.load(f)

    pins = read_pins()
    problems, mismatches = [], []

    artifacts = []
    for leg, frag in frags.items():
        p = frag["producer"]
        if "version_line" in p:
            producer = p["version_line"]
        else:
            producer = "\n".join(p.get("version_vv", [])) + "\nLLVM " + p.get("llvm", "")
        want = EXPECTED[frag["leg"]]
        producer_ok = want["producer_contains"] in producer
        if not producer_ok:
            mismatches.append({"leg": frag["leg"], "field": "producer",
                               "expected": want["producer_contains"], "actual": producer})
        leg_entry = {
            "leg": frag["leg"],
            "role": {"C": "Bitcoin Core script interpreter (unmodified at pin)",
                     "L": "Lean-derived C++ twin (generated)",
                     "R": "rbitcoin consensus crate (unmodified at pin)"}[frag["leg"]],
            "producer": fragment_producer(frag),
            "source": frag.get("source", {}),
            "artifacts": [],
        }
        # Preserve the reproducible commands and scope notes from the build
        # fragments; these are part of the manifest contract.
        for extra in ("commands", "translation_units", "notes"):
            if extra in frag:
                leg_entry[extra] = frag[extra]
        artifacts.append(leg_entry)
        for a in frag["artifacts"]:
            if not os.path.isfile(a["bc_path"]) or not os.path.isfile(a["ll_path"]):
                problems.append(f"missing file for {a['id']}")
                continue
            bc_sha, ll_sha = sha(a["bc_path"]), sha(a["ll_path"])
            if bc_sha != a["bc_sha256"]:
                problems.append(f"{a['id']} .bc hash changed ({a['bc_sha256']} -> {bc_sha})")
            if ll_sha != a["ll_sha256"]:
                problems.append(f"{a['id']} .ll hash changed ({a['ll_sha256']} -> {ll_sha})")
            if a.get("triple") != want["triple"]:
                mismatches.append({"leg": frag["leg"], "artifact": a["id"],
                                   "field": "triple", "expected": want["triple"],
                                   "actual": a.get("triple")})
            if a.get("datalayout") != EXPECTED_DATALAYOUT:
                mismatches.append({"leg": frag["leg"], "artifact": a["id"],
                                   "field": "datalayout", "expected": EXPECTED_DATALAYOUT,
                                   "actual": a.get("datalayout")})
            entry = dict(a)
            entry["bc_sha256_recomputed"] = bc_sha
            entry["ll_sha256_recomputed"] = ll_sha
            entry["bc_sha256_verified"] = bc_sha == a["bc_sha256"]
            entry["ll_sha256_verified"] = ll_sha == a["ll_sha256"]
            if entry.get("defined_symbols") is None:
                entry["defined_functions_from_text"] = text_functions(a["ll_path"])
                entry["defined_function_count_from_text"] = len(entry["defined_functions_from_text"])            # Keep the manifest readable: full symbol lists go to
            # ir/symbols/<artifact>.{defined,undefined}.txt.
            sym_dir = os.path.join(HERE, "symbols")
            os.makedirs(sym_dir, exist_ok=True)
            defined = entry.pop("defined_symbols", None)
            if defined is None:
                defined = entry["defined_functions_from_text"]
                entry.pop("defined_functions_from_text", None)
            undef = entry.pop("undefined_symbols", None)
            dp = os.path.join(sym_dir, f"{a['id']}.defined.txt")
            with open(dp, "w") as f:
                f.write("\n".join(defined) + ("\n" if defined else ""))
            entry["defined_symbol_count"] = len(defined)
            entry["defined_symbols_file"] = os.path.relpath(dp, HERE)
            entry["defined_symbols_file_sha256"] = sha(dp)
            if undef is None:
                entry["undefined_symbol_count"] = None
                entry["undefined_symbols_file"] = None
                entry["undefined_symbols_note"] = (
                    "llvm-nm-20 cannot read this rustc/LLVM-22 bitcode; "
                    "undefined symbols are not enumerated for the raw artifact")
            else:
                up = os.path.join(sym_dir, f"{a['id']}.undefined.txt")
                with open(up, "w") as f:
                    f.write("\n".join(undef) + ("\n" if undef else ""))
                entry["undefined_symbol_count"] = len(undef)
                entry["undefined_symbols_file"] = os.path.relpath(up, HERE)
                entry["undefined_symbols_file_sha256"] = sha(up)
            entry["key_functions"] = key_functions(frag["leg"], defined)
            entry["key_functions_demangled"] = demangle(entry["key_functions"])
            artifacts[-1]["artifacts"].append(entry)

    smoke_path = os.path.join(art_root, "smoke", "smoke.json")
    smoke = None
    if os.path.isfile(smoke_path):
        with open(smoke_path) as f:
            smoke = json.load(f)

    manifest = {
        "schema": "equiv-ir-manifest/1",
        "purpose": "Canonical LLVM IR artifacts for the three-leg equivalence "
                   "workstream. Hashes identify artifacts; regeneration commands "
                   "are in build_core.sh / build_twin.sh / build_rust.sh.",
        "pins": {
            "core": {"repo": pins.get("core", {}).get("source"),
                     "version": pins.get("core", {}).get("version"),
                     "commit": pins.get("core", {}).get("commit"),
                     "patches": pins.get("core", {}).get("patches")},
            "rbitcoin": {"repo": pins.get("rbitcoin", {}).get("source"),
                         "version": pins.get("rbitcoin", {}).get("version"),
                         "commit": pins.get("rbitcoin", {}).get("commit"),
                         "toolchain": pins.get("rbitcoin", {}).get("toolchain")},
            "lean": {"repo": pins.get("lean", {}).get("repo"),
                     "lake": pins.get("lean", {}).get("lake"),
                     "model_rev": pins.get("lean", {}).get("model_rev")},
            "llvm": {"clang": pins.get("llvm", {}).get("clang"),
                     "ir_version": pins.get("llvm", {}).get("llvm_ir_version"),
                     "flags": pins.get("llvm", {}).get("flags"),
                     "triple": pins.get("llvm", {}).get("triple"),
                     "datalayout": pins.get("llvm", {}).get("datalayout")},
            "tools": {"alive2": pins.get("tools", {}).get("alive2"),
                      "saw": pins.get("tools", {}).get("saw"),
                      "z3": pins.get("tools", {}).get("z3")},
        },
        "expected": EXPECTED,
        "expected_datalayout": EXPECTED_DATALAYOUT,
        "legs": artifacts,
        "smoke": smoke,
        "integrity": {
            "all_recorded_hashes_match": not problems,
            "problems": problems,
            "producer_triple_datalayout_mismatches": mismatches,
        },
        "trust_assumptions": [
            "The Core leg is the unmodified source tree at the pin; only the listed "
            "TUs are compiled, no test stubs are linked.",
            "The L leg is the twin generator's deterministic output; the generator "
            "input hashes are recorded because twin/ has no VCS pin in PINS.lock.",
            "The R leg is a clean clone at the pin with no FFI patch and without the "
            "equiv-ffi feature.",
            "The R LLVM-20-normalised derivative differs from the raw rustc IR only "
            "by removal of the LLVM-22-only 'nocreateundeforpoison' attribute "
            "(checked with llvm-diff). It is not the pin artifact.",
            "LLVM IR hashes are byte hashes for a fixed producer and fixed paths; "
            "they are not semantic identifiers.",
        ],
    }

    out_path = os.path.join(HERE, "manifest.json")
    with open(out_path, "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")

    n = sum(len(l["artifacts"]) for l in artifacts)
    print(f"wrote {out_path}: {len(artifacts)} legs, {n} artifacts")
    if mismatches:
        print("PRODUCER/TRIPLE/DATALAYOUT MISMATCHES:", file=sys.stderr)
        for m in mismatches:
            print(" ", m, file=sys.stderr)
    if problems:
        print("HASH PROBLEMS:", file=sys.stderr)
        for p in problems:
            print(" ", p, file=sys.stderr)
    return 0 if not (problems or mismatches) else 1


def fragment_producer(frag: dict) -> dict:
    p = dict(frag["producer"])
    p["leg"] = frag["leg"]
    return p


if __name__ == "__main__":
    sys.exit(main())
