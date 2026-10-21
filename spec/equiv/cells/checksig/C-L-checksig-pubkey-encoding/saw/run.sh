#!/usr/bin/env bash
# SAW lane for cell checksig/C-L-checksig-pubkey-encoding (SCR-112).
#
# Each leg is compiled at -O0 and verified independently against the same
# hand-written Cryptol predicate in saw/pk_encoding.cry.  C |- spec and
# L |- spec together give C == L over the cell domain.  The predicate is an
# independent restatement of the pinned rule, not extracted from either leg.
# There are no external calls in either module (EC verification is an input),
# so no stub linking is required.
set -euo pipefail

CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR" && while [ ! -f spec/equiv/contract/error_kind.h ]; do cd ..; done; pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/saw"
SRC="$CELL_DIR/src"
CXX=/usr/bin/clang++-20
LLVM=/usr/lib/llvm-20/bin
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$OUT" "$BUILD"

CXXFLAGS=(-std=c++17 -I "$SRC" -I "$ROOT/spec/equiv" -fno-discard-value-names
          -fno-strict-aliasing)
"$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm "$SRC/c_pubkey_encoding.cpp" -o "$BUILD/c_leaf_saw.bc"
"$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm "$SRC/l_pubkey_encoding.cpp" -o "$BUILD/l_leaf_saw.bc"
"$LLVM/llvm-dis" "$BUILD/c_leaf_saw.bc" -o "$BUILD/c_leaf_saw.ll"
"$LLVM/llvm-dis" "$BUILD/l_leaf_saw.bc" -o "$BUILD/l_leaf_saw.ll"
for f in "$CELL_DIR"/saw/*.cry "$CELL_DIR"/saw/*.saw; do
  [ -e "$f" ] && cp "$f" "$BUILD/"
done
{
  printf 'mode=saw key=pubkey_encoding\n'
  printf 'clang=%s\n' "$("$CXX" --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-link" --version | head -1)"
  printf 'saw=%s\n' "$(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  printf 'error_kind_sha256=%s\n' "$(sha256sum "$ROOT/spec/equiv/contract/error_kind.h" | cut -d' ' -f1)"
  printf 'c_src_sha256=%s\n' "$(sha256sum "$SRC/c_pubkey_encoding.cpp" | cut -d' ' -f1)"
  printf 'l_src_sha256=%s\n' "$(sha256sum "$SRC/l_pubkey_encoding.cpp" | cut -d' ' -f1)"
  printf 'cryptol_sha256=%s\n' "$(sha256sum "$CELL_DIR/saw/pk_encoding.cry" | cut -d' ' -f1)"
  printf 'c_bc_sha256=%s\n' "$(sha256sum "$BUILD/c_leaf_saw.bc" | cut -d' ' -f1)"
  printf 'l_bc_sha256=%s\n' "$(sha256sum "$BUILD/l_leaf_saw.bc" | cut -d' ' -f1)"
} > "$BUILD/build_saw.txt"

RES="$OUT/result.txt"
{
  echo "# cell: checksig/C-L-checksig-pubkey-encoding"
  echo "# key: pubkey_encoding"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# cryptol spec: sha256 $(sha256sum "$CELL_DIR/saw/"*.cry | cut -d' ' -f1 | tr '\n' ' ')"
  echo "# command: (cd build && saw cell.saw)"
  echo
} > "$RES"

OK=1
{
  ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) 2>&1 | tee -a "$RES" || OK=0
}
if ! grep -q "Proof failed" "$RES" && grep -q "Proof succeeded!" "$RES"; then
  :
else
  OK=0
fi
if [ "$OK" -eq 1 ]; then
  echo "STATUS=saw-green" >> "$RES"
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

# Same file set and ordering as tools/normalize_certificates.py.
{
  cd "$ROOT"
  {
    find "$CELL_DIR" -type f \
      ! -path "$CELL_DIR/build/*" ! -name certificate.sha256
    printf '%s\n' "$ROOT/spec/equiv/contract/error_kind.h"
  } | sed "s|^$ROOT/||" | LC_ALL=C sort | while IFS= read -r rel; do
    [ -f "$rel" ] && sha256sum "$rel"
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
