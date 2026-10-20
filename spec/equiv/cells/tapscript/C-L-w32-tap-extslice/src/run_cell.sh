#!/usr/bin/env bash
# Alive2 and SAW runner for one tapscript row cell.
#   run_cell.sh <cell_dir> alive2|saw
set -euo pipefail
CELL_DIR="$1"; MODE="$2"
SRC="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$SRC/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
CELL_ID="$(basename "$CELL_DIR")"
. "$SRC/fns.sh"

case "$MODE" in
alive2)
  OUT="$CELL_DIR/alive2"; mkdir -p "$OUT"
  "$SRC/build.sh" "$CELL_DIR" "${FNS[@]}"
  RES="$OUT/result.txt"; OK=1
  {
    echo "# cell: $CELL_ID"
    echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
    echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
    echo "# build: build/build.txt"
    for fn in "${FNS[@]}"; do
      echo "# command: alive-tv --bidirectional build/c_${fn}.ll build/l_${fn}.ll"
      fnout="$(/usr/local/bin/alive-tv --bidirectional "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
      printf '%s\n' "$fnout"
      if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
         || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
         || ! printf '%s' "$fnout" | grep -q "These functions seem to be equivalent!" \
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
    "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/alive2/run.sh"
    "$SRC/build.sh" "$SRC/run_cell.sh" "$SRC/fns.sh"
    "$SRC/c_leaf.cpp" "$SRC/l_leaf.cpp"
    "$EQ/contract/error_kind.h"
    "$BUILD/build.txt" "$RES"
  )
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
  ;;
saw)
  OUT="$CELL_DIR/saw"; mkdir -p "$OUT"
  "$SRC/build.sh" "$CELL_DIR" "${FNS[@]}"
  cp "$SRC/cell.cry" "$BUILD/cell.cry"
  cp "$SRC/cell.saw" "$BUILD/cell.saw"
  RES="$OUT/result.txt"
  {
    echo "# cell: $CELL_ID"
    echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
    echo "# spec: build/cell.cry"
    echo "# script: build/cell.saw"
    echo
    ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
  } > "$RES" 2>&1 || true
  OK=0
  if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge $((2 * ${#FNS[@]})) ] \
     && ! grep -q 'Proof failed' "$RES"; then
    echo "STATUS=saw-green" >> "$RES"
    OK=1
  else
    echo "STATUS=saw-not-green" >> "$RES"
  fi
  FILES=(
    "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh"
    "$SRC/build.sh" "$SRC/run_cell.sh" "$SRC/fns.sh"
    "$SRC/c_leaf.cpp" "$SRC/l_leaf.cpp"
    "$SRC/cell.cry" "$SRC/cell.saw"
    "$EQ/contract/error_kind.h"
    "$BUILD/build.txt" "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES"
  )
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
  ;;
*)
  echo "usage: run_cell.sh <cell_dir> alive2|saw" >&2; exit 2 ;;
esac
