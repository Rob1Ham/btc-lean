#!/usr/bin/env bash
# Alive2 attempt for a wave-32 exec-verify cell.  One symbolic C-vs-L compare
# per manifest function; alive-tv exits 0 even on a counterexample, so the
# report text is parsed.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
NAME="$(basename "$CELL_DIR")"
mkdir -p "$OUT"
"$GATE/build_leaf.sh" "$CELL_DIR"
mapfile -t FNS < <(grep -v '^\s*#' "$CELL_DIR/manifest.txt" | grep -v '^\s*$' | awk '{print $1}')

RES="$OUT/result.txt"
OK=1
{
  echo "# cell: exec-verify/$NAME"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# mode: symbolic C-vs-L compare (no closed inputs)"
  for fn in "${FNS[@]}"; do
    echo "# command: alive-tv build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1

if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/manifest.txt" "$CELL_DIR/alive2/run.sh"
  "$GATE/w32_common.h" "$GATE/c_flags.cpp" "$GATE/l_flags.cpp"
  "$GATE/build_leaf.sh" "$GATE/run_alive2.sh"
  "$EQ/contract/error_kind.h"
)
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll")
done
FILES+=("$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
