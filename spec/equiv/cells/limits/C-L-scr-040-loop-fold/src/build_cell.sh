#!/usr/bin/env bash
# Cell-local variant of limits/_shared/build_leaf.sh.
#
# Identical to the shared recipe except for one added flag:
#
#   -fwrapv
#
# Rationale (recorded in spec.md / notes.md): the SCR-040 loop-to-fold cell
# compares an accumulator-threaded loop with a fold.  Without -fwrapv clang
# infers `nsw` for the signed `int64_t` additions and attaches `!range`
# metadata to one leg's return value but not the other's; Alive2 v20 models
# that metadata as poison, so the comparison reports "Target is more poisonous
# than source" at acc = INT64_MAX.  That is a codegen-metadata artefact, not an
# engine divergence, and it also makes the symbolic-trip-count loop intractable.
# -fwrapv makes signed i64 arithmetic total (wrap-around) in BOTH legs, which is
# exactly the [64] bitvector semantics SAW checks and the domain the cell's
# preconditions describe.  No instruction, operand, type or control-flow edge
# is rewritten; both legs are compiled with the same flags.
#
# Everything else (clang version, -std=c++17 -O1 -fno-strict-aliasing
# -fno-discard-value-names, llvm-extract --recursive, provenance record) is the
# shared recipe.
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
if [ "${#FNS[@]}" -eq 0 ]; then
  mapfile -t FNS < "$CELL_DIR/src/fns.txt"
fi
SHARED="$(cd "$(dirname "$0")/../../_shared" && pwd)"
CELLS="$(cd "$SHARED/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fwrapv
     -fno-discard-value-names -I "$SHARED" -c -emit-llvm)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'clang_flags=-std=c++17 -O1 -fno-strict-aliasing -fwrapv -fno-discard-value-names\n'
  printf 'recipe=cell-local copy of limits/_shared/build_leaf.sh plus -fwrapv\n'
  printf 'shared=%s\n' "$SHARED"
  printf 'limits_common_sha256=%s\n' "$(sha256sum "$SHARED/limits_common.h" | cut -d' ' -f1)"
  printf 'core_pin=cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66\n'
  printf 'contract=f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6\n'
} > "$BUILD/build.txt"
