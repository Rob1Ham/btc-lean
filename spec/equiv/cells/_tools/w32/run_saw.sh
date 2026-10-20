#!/usr/bin/env bash
# SAW attempt for a wave-32 exec-verify cell.  The cell's checked-in
# saw/spec.saw is run against the freshly built modules; each manifest
# function is verified on both the C and the L module.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
NAME="$(basename "$CELL_DIR")"
mkdir -p "$OUT"
"$GATE/build_leaf.sh" "$CELL_DIR"
mapfile -t FNS < <(grep -v '^\s*#' "$CELL_DIR/manifest.txt" | grep -v '^\s*$' | awk '{print $1}')
WANT=$(( ${#FNS[@]} * 2 ))

RES="$OUT/result.txt"
{
  echo "# cell: exec-verify/$NAME"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: saw/spec.saw + saw/spec.cry (symbolic preconditions; no unsafe assume)"
  echo "# expected proofs: ${WANT} (each of ${#FNS[@]} functions on the C and L modules)"
  echo
  ( cd "$CELL_DIR/saw" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw spec.saw )
} > "$RES" 2>&1 || true

GOT="$(grep -c 'Proof succeeded!' "$RES" || true)"
OK=1
if [ "${GOT:-0}" -lt "$WANT" ] || grep -q 'Proof failed' "$RES" \
   || grep -q '^Error:' "$RES" || grep -q 'Subgoal failed' "$RES"; then
  OK=0
fi
if [ "$OK" -eq 1 ]; then
  echo "STATUS=saw-green" >> "$RES"
else
  echo "STATUS=saw-not-green (proofs=${GOT}/${WANT})" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/manifest.txt" "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/saw/spec.saw" "$CELL_DIR/saw/spec.cry"
  "$GATE/w32_common.h" "$GATE/c_flags.cpp" "$GATE/l_flags.cpp"
  "$GATE/build_leaf.sh" "$GATE/run_saw.sh"
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
