#!/usr/bin/env bash
# build_core.sh -- emit LLVM IR for Bitcoin Core's script interpreter at -O0/-O1.
#
# Leg: C (Bitcoin Core v32.99 @ cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66).
# Producer: /usr/bin/clang++-20 (Ubuntu clang 20.1.2).
#
# What this does (no node build, no test stubs):
#   1. verifies the Core tree is clean and at the pin;
#   2. configures Core's own CMake (no compilation) to generate
#      bitcoin-build-config.h and compile_commands.json, so the include paths
#      and defines are Core's, not invented here;
#   3. compiles the script-layer translation units (interpreter.cpp plus the
#      Core TUs needed to resolve Core-internal calls) to LLVM bitcode;
#   4. llvm-link's them into one module, writes .bc + .ll;
#   5. computes sha256 of every output and of every TU source used, and writes
#      a provenance fragment.
#
# The only symbols left undefined are libc/libstdc++ and the libsecp256k1 C
# API (real library calls; no stubs are substituted). See README.md.
#
# Usage:
#   ./build_core.sh
# Environment (all optional):
#   BUILD_ROOT      scratch root                 (default /tmp/opencode/ir-pipeline)
#   CORE_SRC        clean Core clone at the pin  (default $BUILD_ROOT/bitcoin)
#   ARTIFACTS_DIR   output directory             (default $BUILD_ROOT/artifacts)
#   JOBS            parallel compile jobs        (default nproc)
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

CORE_PIN=cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
BUILD_ROOT=${BUILD_ROOT:-/tmp/opencode/ir-pipeline}
CORE_SRC=${CORE_SRC:-$BUILD_ROOT/bitcoin}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-$BUILD_ROOT/artifacts}
JOBS=${JOBS:-$(nproc)}
CLANGXX=${CLANGXX:-/usr/bin/clang++-20}
LLVM_BIN=${LLVM_BIN:-/usr/lib/llvm-20/bin}
BUILD_DIR=$CORE_SRC/build-ir

die() { echo "build_core: $*" >&2; exit 1; }

[ -d "$CORE_SRC/.git" ] || die "no git tree at $CORE_SRC"
[ -x "$CLANGXX" ] || die "clang++ not found at $CLANGXX"
for t in llvm-link llvm-dis llvm-nm; do
  [ -x "$LLVM_BIN/$t" ] || die "missing $LLVM_BIN/$t"
done

head=$(git -C "$CORE_SRC" rev-parse HEAD)
[ "$head" = "$CORE_PIN" ] || die "Core HEAD is $head, pin is $CORE_PIN"
if [ -n "$(git -C "$CORE_SRC" status --porcelain -- ':!build-ir' ':!build-*')" ]; then
  die "Core source tree is dirty (excluding build dirs); refusing to emit from it"
fi

clang_version=$("$CLANGXX" --version | head -1)
case "$clang_version" in
  *"clang version 20.1.2"*) : ;;
  *) die "clang is '$clang_version', pin requires 20.1.2" ;;
esac

mkdir -p "$ARTIFACTS_DIR" "$ARTIFACTS_DIR/logs"

# ---------------------------------------------------------------------------
# 1. Configure only (generates bitcoin-build-config.h + compile_commands.json).
#    No Core object is built by CMake; all compilation below is explicit.
# ---------------------------------------------------------------------------
if [ ! -f "$BUILD_DIR/compile_commands.json" ] || [ ! -f "$BUILD_DIR/src/bitcoin-build-config.h" ]; then
  cmake -S "$CORE_SRC" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF -DBUILD_FUZZ_BINARY=OFF \
    -DENABLE_WALLET=OFF -DBUILD_DAEMON=OFF -DBUILD_CLI=OFF \
    -DBUILD_BITCOIN_BIN=OFF -DBUILD_TX=OFF -DBUILD_UTIL=OFF -DENABLE_IPC=OFF \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_C_COMPILER=/usr/bin/clang-20 \
    -DCMAKE_CXX_COMPILER="$CLANGXX" \
    > "$ARTIFACTS_DIR/logs/core-cmake-configure.log" 2>&1 \
    || die "cmake configure failed (see logs/core-cmake-configure.log)"
fi

# ---------------------------------------------------------------------------
# 2. Translation units. Closure chosen by linking and inspecting undefined
#    symbols: everything Core-internal, plus the crypto primitives the script
#    layer calls. Nothing here is a test double.
# ---------------------------------------------------------------------------
TUS=(
  src/script/interpreter.cpp
  src/script/script.cpp
  src/script/script_error.cpp
  src/hash.cpp
  src/uint256.cpp
  src/arith_uint256.cpp
  src/pubkey.cpp
  src/crypto/sha1.cpp
  src/crypto/sha256.cpp
  src/crypto/sha256_sse4.cpp
  src/crypto/sha512.cpp
  src/crypto/ripemd160.cpp
  src/crypto/siphash.cpp
  src/crypto/hex_base.cpp
  src/util/strencodings.cpp
)

# Base flags come from Core's own compile_commands entry for interpreter.cpp,
# with output/optimisation/debug flags removed. -O0 or -O1 and -g0 are added
# explicitly per variant. This is the exact command set recorded in the
# manifest.
mapfile -t BASE_FLAGS < <(python3 - "$BUILD_DIR/compile_commands.json" <<'PY'
import json, os, shlex, sys
db = json.load(open(sys.argv[1]))
ent = next(e for e in db if e["file"].endswith("/src/script/interpreter.cpp"))
args = shlex.split(ent["command"])
if args and "clang" in os.path.basename(args[0]):
    args = args[1:]          # drop the compiler executable itself
out, drop_next = [], False
for a in args:
    if drop_next:
        drop_next = False
        continue
    if a in ("-o", "-c"):
        drop_next = a == "-o"
        continue
    if a.startswith(("-O", "-g")) or a == ent["file"]:
        continue
    out.append(a)
print("\n".join(out))
PY
)
[ "${#BASE_FLAGS[@]}" -gt 0 ] || die "could not derive flags from compile_commands.json"
printf '%s\n' "${BASE_FLAGS[@]}" > "$ARTIFACTS_DIR/core-base-flags.txt"

TU_DIR=$ARTIFACTS_DIR/tu
rm -rf "$TU_DIR"; mkdir -p "$TU_DIR"

for opt in 0 1; do
  for rel in "${TUS[@]}"; do
    name=${rel#src/}; name=${name//\//-}
    ( cd "$CORE_SRC" && "$CLANGXX" "${BASE_FLAGS[@]}" -O"$opt" -g0 -emit-llvm -c "$rel" \
        -o "$TU_DIR/$name-O$opt.bc" ) \
        > "$ARTIFACTS_DIR/logs/cc-${name}-O$opt.log" 2>&1 &
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
  done
  wait
done

# Every TU must have produced non-empty bitcode for both variants.
for opt in 0 1; do
  for rel in "${TUS[@]}"; do
    name=${rel#src/}; name=${name//\//-}
    [ -s "$TU_DIR/$name-O$opt.bc" ] || die "missing bitcode for $rel -O$opt"
  done
done

# ---------------------------------------------------------------------------
# 3. Link + disassemble. llvm-link normalises source_filename, so the module
#    has no absolute build paths and is byte-stable for a fixed toolchain.
# ---------------------------------------------------------------------------
for opt in 0 1; do
  inputs=()
  for rel in "${TUS[@]}"; do
    name=${rel#src/}; name=${name//\//-}
    inputs+=("$TU_DIR/$name-O$opt.bc")
  done
  "$LLVM_BIN/llvm-link" "${inputs[@]}" -o "$ARTIFACTS_DIR/core-interpreter-O$opt.bc"
  "$LLVM_BIN/llvm-dis" "$ARTIFACTS_DIR/core-interpreter-O$opt.bc" \
      -o "$ARTIFACTS_DIR/core-interpreter-O$opt.ll"
done

# ---------------------------------------------------------------------------
# 4. Provenance fragment (hashes are computed only after files exist).
# ---------------------------------------------------------------------------
python3 - "$ARTIFACTS_DIR" "$CORE_SRC" "$BUILD_DIR" "$head" "$clang_version" "${TUS[@]}" <<'PY'
import hashlib, json, os, re, subprocess, sys

art, src, build, head, clang_version, *tus = sys.argv[1:]
LLVM = "/usr/lib/llvm-20/bin"

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def syms(bc, defined):
    flag = "--defined-only" if defined else "--undefined-only"
    out = subprocess.run([f"{LLVM}/llvm-nm", flag, bc], capture_output=True, text=True, check=True).stdout
    return sorted({line.split()[-1] for line in out.splitlines() if line.split()})

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
    bc = os.path.join(art, f"core-interpreter-O{opt}.bc")
    ll = os.path.join(art, f"core-interpreter-O{opt}.ll")
    triple, dl = ir_header(ll)
    defined = syms(bc, True)
    arts.append({
        "id": f"core-interpreter-O{opt}",
        "leg": "C",
        "opt": f"-O{opt}",
        "bc_path": bc, "bc_sha256": sha(bc), "bc_bytes": os.path.getsize(bc),
        "ll_path": ll, "ll_sha256": sha(ll), "ll_bytes": os.path.getsize(ll),
        "triple": triple, "datalayout": dl,
        "defined_symbols": defined,
        "defined_symbol_count": len(defined),
        "undefined_symbols": syms(bc, False),
    })

frag = {
    "leg": "C",
    "commands": {
        "configure": (
            "cmake -S <core_src> -B <core_src>/build-ir "
            "-DCMAKE_BUILD_TYPE=RelWithDebInfo "
            "-DBUILD_TESTS=OFF -DBUILD_BENCH=OFF -DBUILD_FUZZ_BINARY=OFF "
            "-DENABLE_WALLET=OFF -DBUILD_DAEMON=OFF -DBUILD_CLI=OFF "
            "-DBUILD_BITCOIN_BIN=OFF -DBUILD_TX=OFF -DBUILD_UTIL=OFF -DENABLE_IPC=OFF "
            "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON "
            "-DCMAKE_C_COMPILER=/usr/bin/clang-20 "
            "-DCMAKE_CXX_COMPILER=/usr/bin/clang++-20"
        ),
        "base_flags": [l.rstrip("\n") for l in open(os.path.join(art, "core-base-flags.txt"))],
        "compile_per_tu": (
            "cd <core_src> && /usr/bin/clang++-20 <base_flags> -O{0|1} -g0 "
            "-emit-llvm -c <tu> -o <artifacts>/tu/<tu-name>-O{0|1}.bc"
        ),
        "link": (
            "/usr/lib/llvm-20/bin/llvm-link <artifacts>/tu/*-O{0|1}.bc "
            "-o <artifacts>/core-interpreter-O{0|1}.bc"
        ),
        "disassemble": (
            "/usr/lib/llvm-20/bin/llvm-dis <artifacts>/core-interpreter-O{0|1}.bc "
            "-o <artifacts>/core-interpreter-O{0|1}.ll"
        ),
    },
    "source": {
        "repo": "bitcoin/bitcoin",
        "head": head,
        "version": "v32.99",
        "tree_clean_at_build_start": True,
        "patches": "none",
        "cmake_build_dir": build,
        "build_config_header": os.path.join(build, "src", "bitcoin-build-config.h"),
        "build_config_header_sha256": sha(os.path.join(build, "src", "bitcoin-build-config.h")),
        "compile_commands_sha256": sha(os.path.join(build, "compile_commands.json")),
    },
    "producer": {"tool": "clang++", "version_line": clang_version,
                 "binary": "/usr/bin/clang++-20", "llvm": "20.1.2"},
    "translation_units": [
        {"path": t, "sha256": sha(os.path.join(src, t))} for t in tus
    ],
    "artifacts": arts,
    "notes": [
        "Core source tree at the pin; no patches; no test stubs.",
        "C++ flags are Core's CMake flags for interpreter.cpp minus -O/-g; "
        "-O0/-O1 and -g0 are set by this script.",
        "libsecp256k1 C API, libc and libstdc++ remain as external declarations; "
        "the calls are real, no replacement bodies were linked.",
        "No full node build was performed; only the listed TUs were compiled.",
    ],
}
os.makedirs(os.path.join(art, "fragments"), exist_ok=True)
with open(os.path.join(art, "fragments", "core.json"), "w") as f:
    json.dump(frag, f, indent=2, sort_keys=True)
    f.write("\n")
print("wrote", os.path.join(art, "fragments", "core.json"))
for a in arts:
    print(a["id"], "bc", a["bc_sha256"][:16], "ll", a["ll_sha256"][:16], "defs", a["defined_symbol_count"])
PY
