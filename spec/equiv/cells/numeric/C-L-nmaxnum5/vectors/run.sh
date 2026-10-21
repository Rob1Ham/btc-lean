#!/usr/bin/env bash
# Finite known-answer vectors for numeric/C-L-nmaxnum5 (not a proof).
#
#   vectors/run.sh [CELL_DIR]
#
# Compiles the C and L leaves into one driver (entry points renamed per leg)
# and checks hand-computed Core vectors against both.  Catches a shared
# transcription error that a C == L equality proof cannot see.
set -euo pipefail
CELL_DIR="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
REPO="$(cd "$CELL_DIR/../../../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/vectors"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"
/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing \
  "$CELL_DIR/src/vectors.cpp" -o "$BUILD/vectors"
RES="$OUT/result.txt"
{
  echo "# cell: numeric/C-L-nmaxnum5 (finite known-answer vectors, not a proof)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  "$BUILD/vectors"
} > "$RES" 2>&1 || true
if grep -q '^vectors=.* failures=0$' "$RES"; then
  echo "STATUS=vectors-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=vectors-not-green" >> "$RES"
  STATUS=1
fi
{
  cd "$REPO"
  for f in \
    "$CELL_DIR/vectors/run.sh" "$CELL_DIR/src/vectors.cpp" \
    "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp" \
    "$RES"; do
    rel="$(realpath --relative-to="$REPO" "$f")"
    sha256sum "$rel"
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
