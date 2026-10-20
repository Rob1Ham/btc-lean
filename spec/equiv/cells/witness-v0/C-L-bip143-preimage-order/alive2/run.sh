#!/usr/bin/env bash
# Alive2 attempt for witness-v0/C-L-bip143-preimage-order.
#
# Same build and certificate shape as the shared witness-v0 runner, but the
# refinement check is run with --bidirectional so that L ⊑ C and C ⊑ L are each
# a real tool result for the buffer-writing functions (the shared runner only
# runs alive-tv C L).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$(cd "$CELL_DIR/../_tools" && pwd)"
BUILD="$CELL_DIR/build"
IR="$CELL_DIR/ir"
OUT="$CELL_DIR/alive2"
SRC="$CELL_DIR/src"
mkdir -p "$OUT"
"$TOOLS/build.sh" "$CELL_DIR"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $(basename "$CELL_DIR")"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# functions: $(grep -v '^#' "$SRC/fns.txt" | tr '\n' ' ')"
  while IFS= read -r fn; do
    [ -z "$fn" ] && continue
    case "$fn" in \#*) continue;; esac
    echo "# command: alive-tv --bidirectional ir/c_${fn}.ll ir/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv --bidirectional "$IR/c_${fn}.ll" "$IR/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -Eq "[12] correct transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 incorrect transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done < "$SRC/fns.txt"
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi
{
  ROOT="$(cd "$CELL_DIR" && git rev-parse --show-toplevel)"
  cd "$ROOT"
  for f in "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" \
           "$TOOLS/wv_common.h" "$TOOLS/build.sh" \
           "$CELL_DIR/src/c_cell.cpp" "$CELL_DIR/src/l_cell.cpp" \
           "$CELL_DIR/src/fns.txt" "$IR"/*.ll "$RES"; do
    case "$f" in
      "$PWD"/*) sha256sum "${f#"$PWD"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
