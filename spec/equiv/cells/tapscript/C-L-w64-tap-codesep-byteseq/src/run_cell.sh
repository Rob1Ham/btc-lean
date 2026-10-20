#!/usr/bin/env bash
# Alive2 and SAW runner for tapscript/C-L-w64-tap-codesep-byteseq.
#   run_cell.sh <cell_dir> alive2|saw
set -euo pipefail
CELL_DIR="$1"; MODE="$2"
SRC="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$SRC/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
CELL_ID="$(basename "$CELL_DIR")"
LLVM=/usr/lib/llvm-20/bin
ALIVE=/usr/local/bin/alive-tv
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
SMT_TO="${SMT_TO:-180000}"
. "$SRC/fns.sh"

cert() {
  python3 "$SRC/cert.py" "$1"
}

case "$MODE" in
alive2)
  OUT="$CELL_DIR/alive2"; mkdir -p "$OUT"
  "$SRC/build.sh" "$CELL_DIR" "${FNS[@]}"
  RES="$OUT/result.txt"; OK=1
  {
    echo "# cell: $CELL_ID"
    echo "# lane: alive2 (symbolic, bidirectional, bounded six-byte script)"
    echo "# alive-tv: $($ALIVE --version 2>&1 | head -1)"
    echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
    echo "# smt-to: $SMT_TO ms"
    echo "# domain: six symbolic script bytes + symbolic fExec mask; all GetOp forms"
    for fn in "${FNS[@]}"; do
      CLOOPS="$("$LLVM/opt" -passes='print<loops>' -disable-output "$BUILD/c_${fn}.ll" 2>&1 | grep -c 'Loop at depth' || true)"
      LLOOPS="$("$LLVM/opt" -passes='print<loops>' -disable-output "$BUILD/l_${fn}.ll" 2>&1 | grep -c 'Loop at depth' || true)"
      echo "# c loops: $CLOOPS; l loops: $LLOOPS"
      echo "# command: alive-tv --fail-src-ub --smt-to=$SMT_TO --bidirectional build/c_${fn}.ll build/l_${fn}.ll"
      fnout="$($ALIVE --fail-src-ub --smt-to="$SMT_TO" --bidirectional \
        "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
      printf '%s\n' "$fnout"
      if [ "$CLOOPS" -ne 0 ] || [ "$LLOOPS" -ne 0 ] \
         || ! printf '%s' "$fnout" | grep -q '^  1 correct transformations$' \
         || ! printf '%s' "$fnout" | grep -q '^  0 incorrect transformations$' \
         || ! printf '%s' "$fnout" | grep -q '^  0 failed-to-prove transformations$' \
         || ! printf '%s' "$fnout" | grep -q '^  0 Alive2 errors$' \
         || printf '%s' "$fnout" | grep -q 'ERROR' \
         || printf '%s' "$fnout" | grep -q 'always UB'; then
        OK=0
      fi
    done
  } > "$RES" 2>&1
  if [ "$OK" -eq 1 ]; then echo "STATUS=alive2-green" >> "$RES"
  else echo "STATUS=alive2-not-green" >> "$RES"; fi
  [ "$OK" -eq 1 ] || { cert alive2; exit 1; }
  cert alive2
  ;;
saw)
  OUT="$CELL_DIR/saw"; mkdir -p "$OUT"
  "$SRC/build.sh" "$CELL_DIR" "${FNS[@]}"
  cp "$SRC/cell.cry" "$BUILD/cell.cry"
  cp "$SRC/cell.saw" "$BUILD/cell.saw"
  RES="$OUT/result.txt"
  {
    echo "# cell: $CELL_ID"
    echo "# lane: saw (symbolic: six script bytes + mask free)"
    echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
    echo "# spec: build/cell.cry"
    echo "# script: build/cell.saw"
    echo "# domain: six symbolic script bytes + symbolic fExec mask; all GetOp forms"
    echo
    ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw )
  } > "$RES" 2>&1 || true
  OK=0
  if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge $((2 * ${#FNS[@]})) ] \
     && ! grep -q 'Proof failed' "$RES" \
     && ! grep -q 'ERROR' "$RES"; then
    echo "STATUS=saw-green" >> "$RES"; OK=1
  else
    echo "STATUS=saw-not-green" >> "$RES"
  fi
  [ "$OK" -eq 1 ] || { cert saw; exit 1; }
  cert saw
  ;;
*)
  echo "usage: run_cell.sh <cell_dir> alive2|saw" >&2; exit 2 ;;
esac
