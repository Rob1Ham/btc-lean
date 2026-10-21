#!/usr/bin/env bash
# Build and run the concrete behavioural cross-check (concrete_check.cpp).
#
# The C excerpt and the Lean transliteration of every cell are compiled as
# separate translation units; the L symbols are renamed lcell_* so both legs can
# be linked into one binary.  The driver's expectations are hand-computed from
# src/script/interpreter.cpp, so agreement means: hand expectation == C excerpt
# == Lean transliteration on every listed vector.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIND="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$FIND/../../../../.." && pwd)"
CELLS="$ROOT/spec/equiv/cells"
TOOLS="$HERE/harness"
BUILD="$FIND/tools/.concrete-build"
OBJCOPY=/usr/lib/llvm-20/bin/llvm-objcopy
CXX=/usr/bin/clang++-20
mkdir -p "$BUILD"

CELL_DIRS=(
  "$CELLS/policy-flags/C-L-cleanstack-base"
  "$CELLS/policy-flags/C-L-const-scriptcode"
  "$CELLS/policy-flags/C-L-lows-policy"
  "$CELLS/policy-flags/C-L-minimaldata-push"
  "$CELLS/policy-flags/C-L-minimalif-v0"
  "$CELLS/policy-flags/C-L-nullfail"
  "$CELLS/policy-flags/C-L-strictenc-pubkey"
  "$CELLS/policy-flags/C-L-witness-pubkeytype"
  "$CELLS/tapscript-reimport/C-L-tapscript-reimport"
)

OBJS=()
for d in "${CELL_DIRS[@]}"; do
  name="$(basename "$d")"
  # shellcheck disable=SC1090,SC1091
  source "$d/buildspec"
  "$CXX" -std=c++17 -O1 -I "$TOOLS" -c "$d/c_cell.cpp" -o "$BUILD/${name}_c.o"
  "$CXX" -std=c++17 -O1 -I "$TOOLS" -c "$d/l_cell.cpp" -o "$BUILD/${name}_l.o"
  for fn in $CELL_FNS; do
    lfn="l${fn}"            # cell_x -> lcell_x
    "$OBJCOPY" --redefine-sym "$fn=$lfn" "$BUILD/${name}_l.o"
  done
  OBJS+=("$BUILD/${name}_c.o" "$BUILD/${name}_l.o")
done

"$CXX" -std=c++17 -O1 -I "$TOOLS" \
  "$HERE/concrete_check.cpp" "${OBJS[@]}" -o "$BUILD/concrete_check"
"$BUILD/concrete_check" | tee "$HERE/concrete_check.out"
