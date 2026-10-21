#!/usr/bin/env bash
# Build the wave65/28 E5 cell-local proof modules.
#
# Nothing here edits Core or the repo's pinned artifacts.  Inputs are the
# PINS.lock carriers and a clean source tree at the pin; outputs go to $OUT.
#
# Inputs (verify hashes before use):
#   single-TU carrier  ir20/interpreter-O0.bc          f5718af7...
#   canonical closure  ir-pipeline/.../core-interpreter-O0.bc  204cf671...
#   Core source tree   cce32b168... (for script.cpp; single-TU lane only)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-/tmp/opencode/wave65/28-e5-heap-scratch}"
CORE_SRC="${CORE_SRC:-/tmp/opencode/equiv-work/bitcoin}"
SINGLE_TU="${SINGLE_TU:-/tmp/opencode/equiv-work/ir20/interpreter-O0.bc}"
CLOSURE="${CLOSURE:-/tmp/opencode/ir-pipeline/artifacts/core-interpreter-O0.bc}"
CXX=/usr/bin/clang++-20
L=/usr/lib/llvm-20/bin

mkdir -p "$OUT"
cd "$OUT"

check() { # file expected_sha label
  local got
  got=$(sha256sum "$1" | cut -d' ' -f1)
  if [ "$got" != "$2" ]; then
    echo "HASH MISMATCH $3: $1" >&2
    echo "  expected $2" >&2
    echo "  got      $got" >&2
    exit 1
  fi
  echo "ok $3 $got"
}

check "$SINGLE_TU" f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c "PINS [core.ir] O0_bc"
check "$CLOSURE"   204cf6711ca56738eccd9d8034fe40e39b01e6f070e286f0882d3fd5956c0975 "PINS [ir] core-interpreter-O0"
[ "$(git -C "$CORE_SRC" rev-parse HEAD)" = "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66" ] \
  || { echo "CORE_SRC is not at the pin" >&2; exit 1; }

# --- script.cpp at the pin, same flags as the interpreter TU (B1 closure) ----
(
  cd "$CORE_SRC"
  "$CXX" -std=c++20 -O0 -g0 -emit-llvm -c \
    -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
    src/script/script.cpp -o "$OUT/script-O0.bc"
)
check "$OUT/script-O0.bc" 657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c "script.cpp O0"

# --- ABI stubs ---------------------------------------------------------------
"$L/llvm-as" "$HERE/abi-stub-singletu.ll" -o abi-stub-singletu.bc
"$L/llvm-as" "$HERE/abi-stub-closure.ll"  -o abi-stub-closure.bc

# --- heap + guard model, one module per CAP ---------------------------------
for CAP in 128 66 65; do
  sed "s/@CAP@/$CAP/g" "$HERE/../models/cell-model.ll.tmpl" > "model-$CAP.ll"
  "$L/llvm-as" "model-$CAP.ll" -o "model-$CAP.bc"
done

# --- single-TU carrier + linked script.cpp ----------------------------------
"$L/llvm-link" "$SINGLE_TU" script-O0.bc abi-stub-singletu.bc -o singletu-link.bc
"$L/llvm-dis" singletu-link.bc -o singletu-link.ll
for CAP in 128 66 65; do
  "$L/llvm-link" singletu-link.bc "model-$CAP.bc" -o "singletu-model-$CAP.bc"
  "$L/llvm-dis" "singletu-model-$CAP.bc" -o "singletu-model-$CAP.ll"
done

# --- canonical closure ------------------------------------------------------
"$L/llvm-link" "$CLOSURE" abi-stub-closure.bc "model-128.bc" -o closure-model-128.bc
"$L/llvm-dis" closure-model-128.bc -o closure-model-128.ll
for CAP in 66 65; do
  "$L/llvm-link" "$CLOSURE" abi-stub-closure.bc "model-$CAP.bc" -o "closure-model-$CAP.bc"
done

# --- pinned-guard control modules (the wave16b/64 shortcut) -----------------
# Guards become `constant i64 1` (initialization assumed complete) and the
# static objects become constants holding zeroinitializer, which is literally
# what the old probe left in memory.  This is used only as a negative control.
python3 - "$OUT" <<'PY'
import re, sys, os
out = sys.argv[1]
for src, dst in [("singletu-model-128.ll", "singletu-pinned.ll"),
                 ("closure-model-128.ll", "closure-pinned.ll")]:
    s = open(os.path.join(out, src)).read()
    s, n1 = re.subn(r'(@_ZGV[^ ]+) = internal global i64 0, align 8',
                    r'\1 = internal constant i64 1, align 8', s)
    s, n2 = re.subn(r'(@_ZZ10EvalScript[^ ]+) = internal global ',
                    r'\1 = internal constant ', s)
    assert n1 == 4, (src, n1)
    open(os.path.join(out, dst), "w").write(s)
    print("pinned-guard control", dst, "guards", n1, "objects", n2)
PY
"$L/llvm-as" singletu-pinned.ll -o singletu-pinned.bc
"$L/llvm-as" closure-pinned.ll  -o closure-pinned.bc

# --- hashes -----------------------------------------------------------------
{
  echo "# wave65/28 build hashes ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
  sha256sum script-O0.bc singletu-link.bc singletu-model-128.bc \
            singletu-model-66.bc singletu-model-65.bc singletu-pinned.bc \
            closure-model-128.bc closure-model-66.bc closure-model-65.bc \
            closure-pinned.bc model-128.bc model-66.bc model-65.bc
} | tee build-hashes.txt
