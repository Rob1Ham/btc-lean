#!/usr/bin/env bash
# Alive2 attempt for limits/C-L-scr-040-loop-fold.
#
# Compares the C leg (serializer accumulator loop) with the L leg (model fold)
# per function.  Alive2 v20 times out on the symbolic-count unrolled loop
# (2^8 outer guard paths), so this run uses the per-count instantiations
# cell_vector_ser_0..8 and cell_seed_0..8: every item length is symbolic and
# every count 0..8 is checked.  The symbolic-count version of the same loop is
# checked by SAW (count <= 8) and, at arbitrary count, by the Lean bridge.
# src/normalize_alive2.py drops nocapture/readonly/writeonly/memory(...) ABI
# hints and clang's inferred nsw/nuw overflow flags; no instruction is changed.
# --always-verify keeps syntactically identical legs from being counted as
# vacuous passes.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELL_ID="limits/C-L-scr-040-loop-fold"
SHARED="$(cd "$CELL_DIR/../_shared" && pwd)"
CELLS="$(cd "$SHARED/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
FNS=()
while IFS= read -r fn; do
  [ -z "$fn" ] && continue
  case "$fn" in \#*) continue ;; esac
  FNS+=("$fn")
done < "$CELL_DIR/src/alive_fns.txt"

mkdir -p "$OUT"
"$CELL_DIR/src/build_cell.sh" "$CELL_DIR" "${FNS[@]}"

for fn in "${FNS[@]}"; do
  for leg in c l; do
    python3 "$CELL_DIR/src/normalize_alive2.py" \
      "$BUILD/${leg}_${fn}.ll" "$BUILD/${leg}_${fn}.alive.ll"
  done
done

RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# ir prep: src/normalize_alive2.py drops nocapture/readonly/writeonly/memory() ABI hints and clang-inferred nsw/nuw flags"
  echo "# flags: --always-verify --smt-to=60000 --time-verify"
  echo "# scope: per-count instantiations k=0..8, all item lengths symbolic"
  for fn in "${FNS[@]}"; do
    echo "# command: alive-tv --always-verify --smt-to=60000 --time-verify build/c_${fn}.alive.ll build/l_${fn}.alive.ll"
    fnout="$(/usr/local/bin/alive-tv --always-verify --smt-to=60000 --time-verify \
      "$BUILD/c_${fn}.alive.ll" "$BUILD/l_${fn}.alive.ll" 2>&1 || true)"
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

{
  cd "$ROOT"
  find "spec/equiv/cells/$CELL_ID" -type f \
    ! -path '*/build/*' ! -name 'certificate.sha256' ! -path '*/lean/build/*' -print | sort \
    | while IFS= read -r f; do sha256sum "$f"; done
  if [ -f "$CELL_DIR/src/cert-inputs.txt" ]; then
    while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      case "$rel" in \#*) continue ;; esac
      sha256sum "$rel"
    done < "$CELL_DIR/src/cert-inputs.txt"
  fi
} > "$OUT/certificate.sha256"
exit "$STATUS"
