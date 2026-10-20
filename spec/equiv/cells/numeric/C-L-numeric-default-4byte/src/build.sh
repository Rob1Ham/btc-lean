#!/usr/bin/env bash
# Build the bounded C/L leaves for numeric/C-L-numeric-default-4byte.
#
#   src/build.sh CELL_DIR
#
# Emits build/twin_ops.h (the twin's own handlers + the loop-free runtime
# primitives, from findings/wave16/07-numeric-ops/tools/mk_num_leaf.py),
# compiles both legs with clang++-20 -O2, and extracts one loop-free module per
# decode-site entry point for Alive2/SAW.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"          # spec/equiv
REPO="$(cd "$EQ/../.." && pwd)"
NUMTOOLS="$EQ/findings/wave16/07-numeric-ops/tools"
TOOLS="$EQ/findings/wave64/15-scr-080/tools"
BUILD="$CELL_DIR/build"
# FNS comes from src/build.cfg so every runner keeps one source of truth.
# shellcheck disable=SC1091
source "$CELL_DIR/src/build.cfg"
mkdir -p "$BUILD"

# One handler per site family is enough: the generated header supplies the
# twin's decode_num/st_top/Stack/core_ord; the handlers themselves are not
# called by this cell (the L slice stops at the decode boundary).  Keeping the
# four handlers makes `mk_num_leaf.py --check` assert that the emitted bodies
# are still byte-identical to cells/_tools/mk_leaf.py output.
python3 "$NUMTOOLS/mk_num_leaf.py" --ops "$OPS" \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$NUMTOOLS/mk_num_leaf.py" --ops "$OPS" --check "$BUILD/twin_ops.h"

CXX=(/usr/bin/clang++-20 -std=c++17 -O2 -fno-jump-tables -fno-strict-aliasing
     -I "$CELL_DIR/src" -I "$BUILD" -I "$TOOLS" -I "$NUMTOOLS" -I "$EQ/contract"
     -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    # Post-extract normalization, applied identically to both legs: with a
    # single entry point the mid-end can scalarise the bounded stack alloca.
    # This is tool ingestion, not a semantic change (stock O2 on both legs).
    /usr/lib/llvm-20/bin/opt -passes='default<O2>' "$BUILD/${leg}_${fn}.bc" \
      -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
    # Derived return-range attribute: stripped identically from both legs, see
    # tools/strip_range.py (Alive2 compares it as a return-domain constraint).
    python3 "$TOOLS/strip_range.py" "$BUILD/${leg}_${fn}.ll"
    # Re-assemble from the stripped text so Alive2 and SAW ingest byte-identical
    # modules (SAW loads the .bc, Alive2 the .ll).
    /usr/lib/llvm-20/bin/llvm-as "$BUILD/${leg}_${fn}.ll" -o "$BUILD/${leg}_${fn}.bc"
    # Memory intrinsics are modelled by Alive2/SAW; reject only the ones that
    # are not (e.g. llvm.abs, which Alive2 v20 mis-handles).
    if grep -h "call.*@llvm\." "$BUILD/${leg}_${fn}.ll" \
         | grep -v "@llvm\.lifetime" \
         | grep -v "@llvm\.memset" \
         | grep -v "@llvm\.memcpy" \
         | grep -q .; then
      echo "unexpected intrinsic in ${leg}_${fn}.ll" >&2
      exit 1
    fi
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'ops=%s\n' "$OPS"
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  printf 'mk_num_leaf_sha256=%s\n' "$(sha256sum "$NUMTOOLS/mk_num_leaf.py" | cut -d' ' -f1)"
  printf 'ops_ir_sha256=%s\n' "$(sha256sum "$EQ/twin/ops_ir.py" | cut -d' ' -f1)"
  printf 'dflt_common_sha256=%s\n' "$(sha256sum "$TOOLS/dflt_common.h" | cut -d' ' -f1)"
  printf 'dflt_core_sha256=%s\n' "$(sha256sum "$TOOLS/dflt_core.h" | cut -d' ' -f1)"
  printf 'repo_head=%s\n' "$(cd "$REPO" && git rev-parse --short HEAD)"
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
