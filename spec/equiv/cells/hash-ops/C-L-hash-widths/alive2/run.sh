#!/usr/bin/env bash
# Alive2: C leaf vs L leaf for every hash width/empty function.
# The five hash primitives (including SHA1) are uninterpreted externals
# declared identically in both modules.  The compared functions return only
# the defined meta fields (result, error, depth, pushed length): an external
# write is unmodelled memory in Alive2, so reading the digest would poison the
# observable and make the check vacuous.  The digest bytes are SAW-only
# witnesses.  SHA1 is a cell-local reviewed L arm: the shared twin's wire 0xa7
# is OP_UNSUPPORTED_SHA1, so this cell does not claim a shared-twin change.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELLS="$(cd "$CELL_DIR/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"

FNS=(
  cell_ripemd160_empty_meta cell_ripemd160_a_meta
  cell_sha1_empty_meta cell_sha1_a_meta
  cell_sha256_empty_meta cell_sha256_a_meta
  cell_hash160_empty_meta cell_hash160_a_meta
  cell_hash256_empty_meta cell_hash256_a_meta
)
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: hash-ops/C-L-hash-widths"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# twin_ops provenance: build/twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# build: build/build.txt"
  echo "# externals: ripemd160/sha1/sha256/hash160/hash256, uninterpreted and shared"
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
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/hash_common.h" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELLS/_tools/mk_leaf.py"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$BUILD/build.txt"
  "$BUILD/c_leaf.ll" "$BUILD/l_leaf.ll" "$BUILD/c_leaf.bc" "$BUILD/l_leaf.bc"
  "$RES"
)
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll")
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
