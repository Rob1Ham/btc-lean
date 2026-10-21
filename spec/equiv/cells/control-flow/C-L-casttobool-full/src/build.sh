#!/usr/bin/env bash
# Build the arbitrary-length C/L CastToBool leaves.
#
# The C loop is the verbatim interpreter.cpp:46-59 slice with a symbolic
# length.  The L loop is extracted verbatim from twin/runtime.inc.  Both are
# compiled at -O1; the loop is deliberately kept as a loop (no per-length
# specialisation), so the tools must reason about the scan for a symbolic
# length.
#
# All compiler outputs use paths relative to the cell directory so the IR and
# its certificate hashes are checkout-root independent.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$CELL_DIR/src"
CELLS="$(cd "$CELL_DIR/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
FN=cell_cast_arb
mkdir -p "$CELL_DIR/build"
cd "$CELL_DIR"

python3 "$HERE/extract_twin.py"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I src -I build -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" src/c_leaf.cpp -o build/c_leaf.ll
"${CXX[@]}" src/l_leaf.cpp -o build/l_leaf.ll

# Alive2 v20 rejects the `nocapture` / `readonly` parameter attributes that
# clang emits for pointer arguments.  Removing attributes only drops caller
# guarantees, so the comparison is conservative.
for leg in c l; do
  sed -E 's/ nocapture//g; s/ readonly//g' \
    "build/${leg}_leaf.ll" > "build/${leg}_leaf.clean.ll"
  /usr/lib/llvm-20/bin/llvm-as "build/${leg}_leaf.clean.ll" \
    -o "build/${leg}_leaf.bc"
  /usr/lib/llvm-20/bin/llvm-extract --func="$FN" --recursive \
    "build/${leg}_leaf.bc" -o "build/${leg}_${FN}.bc"
  /usr/lib/llvm-20/bin/llvm-dis "build/${leg}_${FN}.bc" \
    -o "build/${leg}_${FN}.ll"
done

{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "$FN"
  printf 'domain=len<=520 (MAX_SCRIPT_ELEMENT_SIZE), symbolic length\n'
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_runtime_sha256=%s\n' "$(sha256sum "$EQ/twin/runtime.inc" | cut -d' ' -f1)"
  printf 'twin_cast_to_bool_header_sha256=%s\n' "$(sha256sum build/twin_cast_to_bool.h | cut -d' ' -f1)"
  printf 'c_leaf_ir_sha256=%s\n' "$(sha256sum "build/c_${FN}.ll" | cut -d' ' -f1)"
  printf 'l_leaf_ir_sha256=%s\n' "$(sha256sum "build/l_${FN}.ll" | cut -d' ' -f1)"
  printf 'loop_present_c=%s\n' "$(grep -c '!llvm.loop' "build/c_${FN}.ll" || true)"
  printf 'loop_present_l=%s\n' "$(grep -c '!llvm.loop' "build/l_${FN}.ll" || true)"
} > build/build.txt
