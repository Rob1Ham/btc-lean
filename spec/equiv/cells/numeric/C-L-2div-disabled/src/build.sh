#!/usr/bin/env bash
# Build the bounded C/L leaves for one wave-16 numeric cell.
#
#   src/build.sh CELL_DIR
#
# Emits build/twin_ops.h (twin IR handlers, byte-identical to mk_leaf output,
# with the bounded runtime primitives re-bound to an 8-byte element), compiles
# both legs with clang++-20 -O1, and extracts one loop-free module per entry
# point for Alive2/SAW.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"          # spec/equiv
REPO="$(cd "$EQ/../.." && pwd)"
TOOLS="$EQ/findings/wave16/07-numeric-ops/tools"
BUILD="$CELL_DIR/build"
# OPS, FNS and (optionally) LFNS come from src/build.cfg so every cell keeps
# one source of truth.  LFNS lists the entry points present only in the C leg
# (e.g. an excerpt of a code path the twin leaves out of contract); it defaults
# to FNS.
# shellcheck disable=SC1091
source "$CELL_DIR/src/build.cfg"
# LFNS lists entry points only the C leg defines; it defaults to FNS.
if [ "${LFNS+x}" != "x" ]; then LFNS=("${FNS[@]}"); fi
mkdir -p "$BUILD"

python3 "$TOOLS/mk_num_leaf.py" --ops "$OPS" \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$TOOLS/mk_num_leaf.py" --ops "$OPS" --check "$BUILD/twin_ops.h"

CXX=(/usr/bin/clang++-20 -std=c++17 -O2 -fno-jump-tables -fno-strict-aliasing
     -I "$CELL_DIR/src" -I "$BUILD" -I "$TOOLS" -I "$EQ/contract"
     -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for leg in c l; do
  if [ "$leg" = "l" ]; then LEGFNS=("${LFNS[@]}"); else LEGFNS=("${FNS[@]}"); fi
  for fn in "${LEGFNS[@]}"; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    # Post-extract normalization, applied identically to both legs:
    # once the module holds a single entry point the mid-end can specialise
    # the shared twin State (constant operand slot) and scalarise it.  Without
    # this Alive2 has to reason about a dynamically indexed 200-byte alloca
    # and times out; see notes.md.  `opt` is a tool-ingestion normalisation,
    # not a semantic change: it runs the stock O2 pipeline on both legs.
    /usr/lib/llvm-20/bin/opt -passes='default<O2>' "$BUILD/${leg}_${fn}.bc" \
      -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
    # Alive2 v20 has no model for @llvm.abs (it reports identical modules as
    # miscompiles).  Expand it to its poison-faithful select form, identically
    # on both legs; see expand_abs.py.
    python3 "$TOOLS/expand_abs.py" "$BUILD/${leg}_${fn}.ll"
    if grep -h "call.*@llvm\." "$BUILD/${leg}_${fn}.ll" | grep -v "@llvm\.lifetime" | grep -q .; then
      echo "unexpected intrinsic in ${leg}_${fn}.ll" >&2
      exit 1
    fi
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'ops=%s\n' "$OPS"
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'lfns=%s\n' "${LFNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  printf 'mk_num_leaf_sha256=%s\n' "$(sha256sum "$TOOLS/mk_num_leaf.py" | cut -d' ' -f1)"
  printf 'ops_ir_sha256=%s\n' "$(sha256sum "$EQ/twin/ops_ir.py" | cut -d' ' -f1)"
  printf 'num_common_sha256=%s\n' "$(sha256sum "$TOOLS/num_common.h" | cut -d' ' -f1)"
  printf 'num_core_sha256=%s\n' "$(sha256sum "$TOOLS/num_core.h" | cut -d' ' -f1)"
  printf 'num_cry_sha256=%s\n' "$(sha256sum "$TOOLS/num.cry" | cut -d' ' -f1)"
  printf 'repo_head=%s\n' "$(cd "$REPO" && git rev-parse --short HEAD)"
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
