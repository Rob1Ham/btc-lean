#!/usr/bin/env bash
# SAW attempt for a wave-32 exec-verify cell.  The cell's saw/cell.cry defines
# `spec_<fn>` for every manifest function; both the C slice and the Lean
# transliteration are verified against that same Cryptol function, which is an
# independent statement of the packed postcondition.
#
# usage: run_saw.sh <cell-dir> [manifest] [expected: green|red]
set -euo pipefail
CELL_DIR="$1"
MANIFEST="${2:-$CELL_DIR/manifest.txt}"
EXPECT="${3:-green}"
T="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$T/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="${X_BUILD:-$CELL_DIR/build}"
OUT="${X_OUT:-$CELL_DIR/saw}"
RUNSH="${X_RUNSH:-$OUT/run.sh}"
CRY="${X_CRY:-$CELL_DIR/saw/cell.cry}"
SOLVER="${X_SOLVER:-$(cat "$CELL_DIR/saw/solver.txt" 2>/dev/null || echo abc)}"
mkdir -p "$OUT"
[ -f "$CRY" ] || { echo "missing $CRY" >&2; exit 2; }
"$T/build_leaf.sh" "$CELL_DIR" "$MANIFEST"
cp "$CRY" "$BUILD/cell.cry"
mapfile -t FNS < <(awk 'NF && $1 !~ /^#/ {print $1}' "$MANIFEST")
mapfile -t ARGS < <(awk 'NF && $1 !~ /^#/ {print $2}' "$MANIFEST")
{
  echo 'import "cell.cry";'
  for i in "${!FNS[@]}"; do
    fn="${FNS[$i]}"; n="${ARGS[$i]}"
    echo "mC_${fn} <- llvm_load_module \"c_${fn}.bc\";"
    echo "mL_${fn} <- llvm_load_module \"l_${fn}.bc\";"
    printf 'let s_%s = do {\n' "$fn"
    for ((k = 0; k < n; k++)); do
      echo "  a${k} <- llvm_fresh_var \"${fn}_a${k}\" (llvm_int 64);"
    done
    args=""
    for ((k = 0; k < n; k++)); do args+="a${k}"; [ $((k+1)) -lt "$n" ] && args+=" "; done
    term=""
    for ((k = 0; k < n; k++)); do term+=" a${k}"; done
    echo "  llvm_execute_func [$(printf 'llvm_term a%s, ' $(seq 0 $((n-1))) | sed 's/, $//')];"
    echo "  llvm_return (llvm_term {{ spec_${fn}${term} }});"
    echo "};"
    echo "llvm_verify mC_${fn} \"${fn}\" [] false s_${fn} ${SOLVER};"
    echo "llvm_verify mL_${fn} \"${fn}\" [] false s_${fn} ${SOLVER};"
    echo "print \"CELL_${fn}_SAW_GREEN\";"
  done
} > "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: ${CELL_DIR#"$CELLS"/}"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry (copied from saw/cell.cry)"
  echo "# expected: $EXPECT"
  echo "# solver: $SOLVER"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw 2>&1 || true )
} > "$RES" 2>&1
if [ "$EXPECT" = green ]; then
  WANT=$(( ${#FNS[@]} * 2 ))
  GOT="$(grep -c 'Proof succeeded!' "$RES" || true)"
  if [ "$GOT" -ge "$WANT" ] && ! grep -q 'Proof failed' "$RES"; then
    for fn in "${FNS[@]}"; do
      grep -q "CELL_${fn}_SAW_GREEN" "$RES" || { echo "STATUS=saw-not-green" >> "$RES"; exit 1; }
    done
    echo "STATUS=saw-green" >> "$RES"
    OK=1
  else
    echo "STATUS=saw-not-green" >> "$RES"
    OK=0
  fi
else
  if grep -q 'Proof failed' "$RES"; then
    echo "STATUS=saw-proof-failed-as-expected" >> "$RES"
    OK=1
  else
    echo "STATUS=saw-unexpected" >> "$RES"
    OK=0
  fi
fi
FILES=(
  "$CELL_DIR/spec.md" "$RUNSH" "$MANIFEST" "$CRY"
  "$CELL_DIR/saw/solver.txt"
  "$T/x_common.h" "$T/c_cell.cpp" "$T/l_cell.cpp" "$T/build_leaf.sh"
  "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES"
)
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.bc" "$BUILD/l_${fn}.bc")
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
[ "$OK" -eq 1 ]
