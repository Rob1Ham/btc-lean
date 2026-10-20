#!/usr/bin/env bash
# Alive2 attempt for a wave-32 tapscript dispatch cell.
#
#   run_alive2.sh CELL_DIR CELL_ID FN [FN...]
#
# alive-tv exits 0 even on a counterexample, so the report text is parsed.
# --smt-to=60000 is used so the bounded 4-byte scan (many symbolic branches) has a
# deterministic margin above its ~10 s proof time; the other cells need <1 s.
set -euo pipefail
CELL_DIR="$1"; CELL_ID="$2"; shift 2
W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$W32/build.sh" "$CELL_DIR" "$@"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
  for fn in "$@"; do
    echo "# command: alive-tv --always-verify --smt-to=60000 build/c_${fn}.opt.ll build/l_${fn}.opt.ll"
    fnout="$(/usr/local/bin/alive-tv --always-verify --smt-to=60000 "$BUILD/c_${fn}.opt.ll" "$BUILD/l_${fn}.opt.ll" 2>&1 || true)"
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
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$W32/w32_common.h" "$W32/build.sh"
  "$EQ/contract/error_kind.h" "$BUILD/build.txt" "$RES"
)
for fn in "$@"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll"
          "$BUILD/c_${fn}.opt.ll" "$BUILD/l_${fn}.opt.ll")
done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
