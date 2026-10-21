#!/usr/bin/env bash
# build_twin.sh -- generate the Lean-derived C++ twin (L leg) and emit IR.
#
# Leg: L. Source of record: spec/core/Bitcoin/Interpreter/Defs.lean at the repo
# pin, lowered by twin/gen.py (hand-transcribed IR, deterministic emitter).
# Producer: /usr/bin/clang++-20 (clang 20.1.2), the same front-end as the C leg.
#
# The twin/ directory is used read-only: this script runs the generator's own
# drift gate, emits a fresh copy into the scratch area, re-checks it, then
# compiles that copy. It never edits twin/.
#
# Usage:  ./build_twin.sh
# Env:    BUILD_ROOT, ARTIFACTS_DIR (as in build_core.sh)
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
EQUIV=$(cd "$HERE/.." && pwd)
REPO=$(cd "$EQUIV/../.." && pwd)

BUILD_ROOT=${BUILD_ROOT:-/tmp/opencode/ir-pipeline}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-$BUILD_ROOT/artifacts}
CLANGXX=${CLANGXX:-/usr/bin/clang++-20}
LLVM_BIN=${LLVM_BIN:-/usr/lib/llvm-20/bin}
OUT=$BUILD_ROOT/out/twin

die() { echo "build_twin: $*" >&2; exit 1; }
[ -f "$EQUIV/twin/gen.py" ] || die "missing twin/gen.py"
[ -x "$CLANGXX" ] || die "missing $CLANGXX"

clang_version=$("$CLANGXX" --version | head -1)
case "$clang_version" in
  *"clang version 20.1.2"*) : ;;
  *) die "clang is '$clang_version', pin requires 20.1.2" ;;
esac

mkdir -p "$ARTIFACTS_DIR/logs" "$OUT"

# twin/ is owned by another role and may be edited concurrently. Snapshot the
# generator inputs and refuse to publish if they move while we are building.
before=$(sha256sum "$EQUIV/twin/gen.py" "$EQUIV/twin/ops_ir.py" \
  "$EQUIV/twin/runtime.inc" "$EQUIV/contract/error_kind.h" \
  | sha256sum | cut -d' ' -f1)

# 1. Drift gate on the checked-in artifact.
( cd "$EQUIV" && python3 twin/gen.py --check twin/build/twin.cpp ) \
  > "$ARTIFACTS_DIR/logs/twin-check-repo.log" 2>&1 \
  || die "twin drift gate failed on twin/build/twin.cpp"

# 2. Fresh generation into scratch, then re-check the generated file.
( cd "$EQUIV" && python3 twin/gen.py --out "$OUT/twin.cpp" --dump-ir "$OUT/twin.ir.json" ) \
  > "$ARTIFACTS_DIR/logs/twin-gen.log" 2>&1 \
  || die "twin generation failed"
( cd "$EQUIV" && python3 twin/gen.py --check "$OUT/twin.cpp" ) \
  > "$ARTIFACTS_DIR/logs/twin-check-generated.log" 2>&1 \
  || die "generated twin fails its own drift gate"

# 3. Compile and emit IR at both optimisation levels. Compile from the
#    generated file's directory with a relative path so the IR's
#    source_filename (and therefore the artifact hash) does not depend on
#    BUILD_ROOT.
for opt in 0 1; do
  ( cd "$OUT" && "$CLANGXX" -std=c++17 -O"$opt" -fno-strict-aliasing -g0 \
      -I "$EQUIV/contract" -emit-llvm -c twin.cpp \
      -o "$ARTIFACTS_DIR/twin-O$opt.bc" ) \
      > "$ARTIFACTS_DIR/logs/twin-cc-O$opt.log" 2>&1 \
      || die "twin compile failed at -O$opt"
  "$LLVM_BIN/llvm-dis" "$ARTIFACTS_DIR/twin-O$opt.bc" \
      -o "$ARTIFACTS_DIR/twin-O$opt.ll"
done

after=$(sha256sum "$EQUIV/twin/gen.py" "$EQUIV/twin/ops_ir.py" \
  "$EQUIV/twin/runtime.inc" "$EQUIV/contract/error_kind.h" \
  | sha256sum | cut -d' ' -f1)
[ "$before" = "$after" ] || die "twin/ generator inputs changed during the build; rerun"

# Preserve the exact generator inputs next to the artifact: twin/ has no VCS
# pin in PINS.lock and may be edited by its owning role.
mkdir -p "$ARTIFACTS_DIR/twin-src"
cp "$EQUIV/twin/gen.py" "$ARTIFACTS_DIR/twin-src/gen.py"
cp "$EQUIV/twin/ops_ir.py" "$ARTIFACTS_DIR/twin-src/ops_ir.py"
cp "$EQUIV/twin/runtime.inc" "$ARTIFACTS_DIR/twin-src/runtime.inc"
cp "$OUT/twin.cpp" "$ARTIFACTS_DIR/twin-src/twin.cpp"
cp "$OUT/twin.ir.json" "$ARTIFACTS_DIR/twin-src/twin.ir.json"

# 4. Provenance fragment.
python3 - "$ARTIFACTS_DIR" "$OUT" "$REPO" "$EQUIV" "$clang_version" <<'PY'
import hashlib, json, os, subprocess, sys

art, out, repo, equiv, clang_version = sys.argv[1:]
LLVM = "/usr/lib/llvm-20/bin"

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def syms(bc, defined):
    flag = "--defined-only" if defined else "--undefined-only"
    r = subprocess.run([f"{LLVM}/llvm-nm", flag, bc], capture_output=True, text=True, check=True)
    return sorted({l.split()[-1] for l in r.stdout.splitlines() if l.split()})

def ir_header(ll):
    triple = datalayout = None
    for line in open(ll, errors="replace"):
        if line.startswith("target datalayout"):
            datalayout = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("target triple"):
            triple = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("define "):
            break
    return triple, datalayout

arts = []
for opt in (0, 1):
    bc = os.path.join(art, f"twin-O{opt}.bc")
    ll = os.path.join(art, f"twin-O{opt}.ll")
    triple, dl = ir_header(ll)
    defined = syms(bc, True)
    arts.append({
        "id": f"twin-O{opt}", "leg": "L", "opt": f"-O{opt}",
        "bc_path": bc, "bc_sha256": sha(bc), "bc_bytes": os.path.getsize(bc),
        "ll_path": ll, "ll_sha256": sha(ll), "ll_bytes": os.path.getsize(ll),
        "triple": triple, "datalayout": dl,
        "defined_symbols": defined, "defined_symbol_count": len(defined),
        "undefined_symbols": syms(bc, False),
    })

frag = {
    "leg": "L",
    "commands": {
        "drift_gate": "cd <equiv> && python3 twin/gen.py --check twin/build/twin.cpp",
        "generate": ("cd <equiv> && python3 twin/gen.py --out <build_root>/out/twin/twin.cpp "
                     "--dump-ir <build_root>/out/twin/twin.ir.json"),
        "drift_gate_generated": "cd <equiv> && python3 twin/gen.py --check <build_root>/out/twin/twin.cpp",
        "compile": ("cd <build_root>/out/twin && /usr/bin/clang++-20 -std=c++17 -O{0|1} "
                    "-fno-strict-aliasing -g0 -I <equiv>/contract -emit-llvm -c twin.cpp "
                    "-o <artifacts>/twin-O{0|1}.bc"),
        "disassemble": "/usr/lib/llvm-20/bin/llvm-dis <artifacts>/twin-O{0|1}.bc -o <artifacts>/twin-O{0|1}.ll",
    },
    "source": {
        "generator": os.path.join(equiv, "twin", "gen.py"),
        "generator_sha256": sha(os.path.join(equiv, "twin", "gen.py")),
        "ops_ir": os.path.join(equiv, "twin", "ops_ir.py"),
        "ops_ir_sha256": sha(os.path.join(equiv, "twin", "ops_ir.py")),
        "runtime_template": os.path.join(equiv, "twin", "runtime.inc"),
        "runtime_template_sha256": sha(os.path.join(equiv, "twin", "runtime.inc")),
        "contract_error_header": os.path.join(equiv, "contract", "error_kind.h"),
        "contract_error_header_sha256": sha(os.path.join(equiv, "contract", "error_kind.h")),
        "generator_doc": os.path.join(equiv, "twin", "generator.md"),
        "generator_doc_sha256": sha(os.path.join(equiv, "twin", "generator.md")),
        "lean_source_of_record": os.path.join(repo, "spec", "core", "Bitcoin", "Interpreter", "Defs.lean"),
        "lean_source_sha256": sha(os.path.join(repo, "spec", "core", "Bitcoin", "Interpreter", "Defs.lean")),
        "checked_in_twin": os.path.join(equiv, "twin", "build", "twin.cpp"),
        "checked_in_twin_sha256": sha(os.path.join(equiv, "twin", "build", "twin.cpp")),
        "generated_twin": os.path.join(out, "twin.cpp"),
        "generated_twin_sha256": sha(os.path.join(out, "twin.cpp")),
        "generated_ir_json": os.path.join(out, "twin.ir.json"),
        "generated_ir_json_sha256": sha(os.path.join(out, "twin.ir.json")),
        "drift_gate": "python3 twin/gen.py --check (checked-in and generated copy): PASS",
    },
    "producer": {"tool": "clang++", "version_line": clang_version,
                 "binary": "/usr/bin/clang++-20", "llvm": "20.1.2"},
    "artifacts": arts,
    "notes": [
        "Twin is the E0/E1 skeleton: base-script stack subset only; witness/taproot, "
        "numerics, hashing and signature checking return 3 (outside subset).",
        "Generated, not hand-edited: drift gate passes before and after generation.",
        "The module exports 'entry', 'equiv_entry', and 'twin_entry'.",
    ],
}
os.makedirs(os.path.join(art, "fragments"), exist_ok=True)
with open(os.path.join(art, "fragments", "twin.json"), "w") as f:
    json.dump(frag, f, indent=2, sort_keys=True)
    f.write("\n")
print("wrote", os.path.join(art, "fragments", "twin.json"))
for a in arts:
    print(a["id"], "bc", a["bc_sha256"][:16], "ll", a["ll_sha256"][:16], "defs", a["defined_symbol_count"])
PY
