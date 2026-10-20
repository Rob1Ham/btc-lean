#!/usr/bin/env bash
# SAW attempt for SCR-083.
#
# Both legs (the C source excerpt and the reviewed Lean transliteration) are
# verified against the SAME Cryptol function, which encodes the row's declared
# (error, value, CastToBool) predicate independently of both C++ files.  Green
# requires one "Proof succeeded!" per root *per leg* (2 x |FNS|), no
# "Proof failed", and the cell's printed marker.
#
# SAW 1.6's llvm_load_module only accepts bitcode, so the proofs run against
# build/<leg>_leaf.bc.  Before proving, each bitcode module is disassembled and
# compared byte-for-byte with the tracked ir/<leg>_leaf.ll that the certificate
# hashes, so the certificate covers the module that was actually verified even
# though build/ itself is gitignored.
set -euo pipefail
CELL_DIR="$1"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
BUILD="$CELL_DIR/build"
IRD="$CELL_DIR/ir"
OUT="$CELL_DIR/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
# shellcheck disable=SC1091
source "$CELL_DIR/buildspec"
mkdir -p "$OUT"

bash "$TOOLS/build_leaf.sh" "$CELL_DIR"
cp "$CELL_DIR/saw/cell.cry" "$CELL_DIR/saw/cell.saw" "$BUILD/"

IRMATCH=1
{
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_leaf.check.ll"
    if cmp -s "$BUILD/${leg}_leaf.check.ll" "$IRD/${leg}_leaf.ll"; then
      echo "# ir-match ${leg}_leaf.bc == ir/${leg}_leaf.ll"
    else
      echo "# IR MISMATCH for ${leg}_leaf.bc"
      IRMATCH=0
    fi
  done
} > "$BUILD/ir_match.txt"
if [ "$IRMATCH" -ne 1 ]; then
  echo "STATUS=saw-not-green (bitcode does not match tracked ir/)" > "$OUT/result.txt"
  exit 1
fi

RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# tool: saw $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd build && saw cell.saw)"
  echo "# roots: $CELL_FNS (each verified in the C module and in the L module)"
  echo "# spec: saw/cell.cry (independent predicate, written from the row's rule)"
  echo "# modules: build/<leg>_leaf.bc, byte-identical to tracked ir/<leg>_leaf.ll"
  cat "$BUILD/ir_match.txt"
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) || true
} > "$RES" 2>&1

NFN=$(printf '%s\n' $CELL_FNS | wc -l)
GREEN=0
if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge $((2 * NFN)) ] \
   && grep -q "CELL_${CELL_MARKER}_SAW_GREEN" "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  GREEN=1
fi
if [ "$GREEN" -eq 1 ]; then
  echo "STATUS=saw-green ($(grep -c 'Proof succeeded!' "$RES") proofs for $NFN root(s) x 2 legs)" >> "$RES"
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

FILES=("$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$CELL_DIR/buildspec"
       "$CELL_DIR/c_cell.cpp" "$CELL_DIR/l_cell.cpp"
       "$CELL_DIR/saw/cell.cry" "$CELL_DIR/saw/cell.saw"
       "$TOOLS/negzero_common.h" "$TOOLS/build_leaf.sh" "$TOOLS/run_saw.sh"
       "$IRD/build.txt" "$IRD/c_leaf.ll" "$IRD/l_leaf.ll" "$RES")
for fn in $CELL_FNS; do
  FILES+=("$IRD/c_${fn}.ll" "$IRD/l_${fn}.ll")
done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    rel="$(realpath --relative-to="$ROOT" "$f")"
    case "$rel" in
      ../*) echo "# outside-root $(sha256sum "$f")" ;;
      *) sha256sum "$rel" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$GREEN" -eq 1 ]
