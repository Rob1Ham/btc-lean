#!/usr/bin/env bash
# Alive2 lane: symbolic, bidirectional equivalence of each C/L function pair.
# Both modules are compiled from the cell's source-slice transliterations at
# the same optimisation level; each function is extracted recursively, checked
# for loop back-edges (Alive2 is unsound on loops in this configuration), and
# compared with --fail-src-ub so a vacuous "source is always UB" cannot pass.
set -euo pipefail

CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
LLVM=/usr/lib/llvm-20/bin
ALIVE=/usr/local/bin/alive-tv
SMT_TO="${SMT_TO:-180000}"

"$SRC/build.sh" alive2
mkdir -p "$OUT"
RES="$OUT/result.txt"
{
  echo "# cell: C-L-w32-checksig-findanddelete"
  echo "# lane: alive2 (symbolic, bidirectional)"
  echo "# alive-tv: $($ALIVE --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# smt-to: $SMT_TO ms"
  echo "# domain: bounded 4/4/6-byte scripts; needle = serialized sig push of length 1/2/3 (sig bytes 0/1/2); every parsed opcode span <= script length"
  echo "# cwd: $CELL_DIR"
  echo
} > "$RES"

ALL=1
for c in "$BUILD"/c_*.ll; do
  case "$c" in *.extract.ll) continue;; esac
  base="$(basename "$c" .ll)"
  suffix="${base#c_}"
  fn="cell_$suffix"
  l="$BUILD/l_${suffix}.ll"
  if [ ! -f "$l" ]; then
    echo "# missing L module: $l" >> "$RES"
    echo "STATUS_${fn}=alive2-missing-l" >> "$RES"
    ALL=0
    continue
  fi
  "$LLVM/llvm-extract" --func="$fn" --recursive "$c" -o "$BUILD/extract_c_${suffix}.bc"
  "$LLVM/llvm-extract" --func="$fn" --recursive "$l" -o "$BUILD/extract_l_${suffix}.bc"
  "$LLVM/llvm-dis" "$BUILD/extract_c_${suffix}.bc" -o "$BUILD/c_${suffix}.extract.ll"
  "$LLVM/llvm-dis" "$BUILD/extract_l_${suffix}.bc" -o "$BUILD/l_${suffix}.extract.ll"
  CLOOPS="$("$LLVM/opt" -passes='print<loops>' -disable-output "$BUILD/c_${suffix}.extract.ll" 2>&1 | grep -c 'Loop at depth' || true)"
  LLOOPS="$("$LLVM/opt" -passes='print<loops>' -disable-output "$BUILD/l_${suffix}.extract.ll" 2>&1 | grep -c 'Loop at depth' || true)"
  TMP="$OUT/.${fn}.tmp"
  {
    echo "===== $fn ====="
    echo "# c loops: $CLOOPS; l loops: $LLOOPS"
    echo "# c IR sha256: $(sha256sum "$BUILD/c_${suffix}.extract.ll" | cut -d' ' -f1)"
    echo "# l IR sha256: $(sha256sum "$BUILD/l_${suffix}.extract.ll" | cut -d' ' -f1)"
    echo "# command: $ALIVE --fail-src-ub --smt-to=$SMT_TO --bidirectional $BUILD/c_${suffix}.extract.ll $BUILD/l_${suffix}.extract.ll"
    "$ALIVE" --fail-src-ub --smt-to="$SMT_TO" --bidirectional \
      "$BUILD/c_${suffix}.extract.ll" "$BUILD/l_${suffix}.extract.ll" || true
  } > "$TMP" 2>&1
  cat "$TMP" >> "$RES"
  echo >> "$RES"
  if [ "$CLOOPS" -eq 0 ] && [ "$LLOOPS" -eq 0 ] \
     && grep -q '^  1 correct transformations$' "$TMP" \
     && grep -q '^  0 incorrect transformations$' "$TMP" \
     && grep -q '^  0 failed-to-prove transformations$' "$TMP" \
     && grep -q '^  0 Alive2 errors$' "$TMP" \
     && ! grep -q 'ERROR' "$TMP" \
     && ! grep -q 'always UB' "$TMP"; then
    echo "STATUS_${fn}=alive2-green" >> "$RES"
  else
    echo "STATUS_${fn}=alive2-not-green" >> "$RES"
    ALL=0
  fi
  rm -f "$TMP"
done

if [ "$ALL" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/alive2/run.sh"
  "$SRC/build.sh" "$OUT/result.txt"
)
for f in "$SRC"/*.cpp "$SRC"/oracle.py; do FILES+=("$f"); done
for f in "$BUILD"/*.extract.ll "$BUILD"/build-alive2.txt; do FILES+=("$f"); done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" 2>/dev/null || true ;;
      *) echo "# outside-root $(sha256sum "$f" 2>/dev/null || echo missing)" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$ALL" -eq 1 ]
