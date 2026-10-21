#!/usr/bin/env bash
# Build one bounded C/L leaf pair.
#
#   build.sh CELL_DIR OPS MAX_DEPTH MAX_ELEM [OPT] [BUILD_NAME]
#
# OPS is the mk_leaf handler set (comma-separated, may be empty).  The L leg
# gets:
#   build/twin_ops.h     prelude + handler bodies, generated verbatim from
#                        twin/ops_ir.py by cells/_tools/mk_leaf.py
#   build/twin_extras.h  structural helpers copied verbatim from
#                        twin/runtime.inc by _harness/extract_extras.py
# The functions to extract are listed in $CELL_DIR/src/fns.txt (one per line).
# OPT defaults to O1; a cell may pass O2 when a handler loop only folds there.
set -euo pipefail
CELL_DIR="$1"; OPS="$2"; MAXD="$3"; MAXE="$4"; OPT="${5:-O1}"; BUILD_NAME="${6:-build}"
H="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$H/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/$BUILD_NAME"
FNS="$CELL_DIR/src/fns.txt"
mkdir -p "$BUILD"

python3 "$CELLS/_tools/mk_leaf.py" --ops "$OPS" --max-depth "$MAXD" --max-elem "$MAXE" \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$CELLS/_tools/mk_leaf.py" --ops "$OPS" --max-depth "$MAXD" --max-elem "$MAXE" \
  --check "$BUILD/twin_ops.h"
python3 "$H/extract_extras.py" --runtime "$EQ/twin/runtime.inc" \
  --out "$BUILD/twin_extras.h" --meta "$BUILD/twin_extras.meta.json"

CXX=(/usr/bin/clang++-20 -std=c++17 "-$OPT" -fno-strict-aliasing -fno-jump-tables
     -I "$H" -I "$BUILD" -I "$EQ/contract" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"

while IFS= read -r fn; do
  [ -n "$fn" ] || continue
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done < "$FNS"

# Deterministic build record: no absolute paths (certificates must verify with
# `sha256sum -c` from any checkout of the same tree).
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'cell_dir=%s\n' "${CELL_DIR#*/spec/equiv/}"
  printf 'mk_leaf ops=%s max_depth=%s max_elem=%s opt=%s\n' "${OPS:-<none>}" "$MAXD" "$MAXE" "$OPT"
  printf 'fns=%s\n' "$(tr '\n' ' ' < "$FNS")"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  printf 'twin_extras_sha256=%s\n' "$(sha256sum "$BUILD/twin_extras.h" | cut -d' ' -f1)"
} > "$BUILD/build.txt"
