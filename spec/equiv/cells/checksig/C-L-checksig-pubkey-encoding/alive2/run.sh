#!/usr/bin/env bash
# Alive2 lane for cell checksig/C-L-checksig-pubkey-encoding (SCR-112).
#
# Both legs are compiled at -O1 from the cell-local sources, each closed
# function is extracted with llvm-extract --recursive, and alive-tv compares C
# (source) with L (target) bidirectionally over all symbolic arguments.  No
# external calls exist in either leg (the EC verdict is a plain input), so the
# comparison is a closed-function equivalence and needs no same-symbol
# assumption.
set -euo pipefail

CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR" && while [ ! -f spec/equiv/contract/error_kind.h ]; do cd ..; done; pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/alive2"
SRC="$CELL_DIR/src"
LLVM=/usr/lib/llvm-20/bin
CXX=/usr/bin/clang++-20
FNS="cell_pubkey_encoding,cell_pubkey_encoding_checksig,cell_pubkey_encoding_continue"
mkdir -p "$OUT" "$BUILD"

CXXFLAGS=(-std=c++17 -I "$SRC" -I "$ROOT/spec/equiv" -fno-discard-value-names
          -fno-strict-aliasing)
"$CXX" "${CXXFLAGS[@]}" -O1 -S -emit-llvm "$SRC/c_pubkey_encoding.cpp" -o "$BUILD/c_leaf.ll"
"$CXX" "${CXXFLAGS[@]}" -O1 -S -emit-llvm "$SRC/l_pubkey_encoding.cpp" -o "$BUILD/l_leaf.ll"

{
  printf 'mode=alive2 key=pubkey_encoding\n'
  printf 'clang=%s\n' "$("$CXX" --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
  printf 'error_kind_sha256=%s\n' "$(sha256sum "$ROOT/spec/equiv/contract/error_kind.h" | cut -d' ' -f1)"
  printf 'c_src_sha256=%s\n' "$(sha256sum "$SRC/c_pubkey_encoding.cpp" | cut -d' ' -f1)"
  printf 'l_src_sha256=%s\n' "$(sha256sum "$SRC/l_pubkey_encoding.cpp" | cut -d' ' -f1)"
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
} > "$BUILD/build.txt"

RES="$OUT/result.txt"
{
  echo "# cell: checksig/C-L-checksig-pubkey-encoding"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $("$CXX" --version | head -1)"
  echo "# c source sha256: $(sha256sum "$SRC/c_pubkey_encoding.cpp" | cut -d' ' -f1)"
  echo "# l source sha256: $(sha256sum "$SRC/l_pubkey_encoding.cpp" | cut -d' ' -f1)"
  echo "# contract error_kind sha256: $(sha256sum "$ROOT/spec/equiv/contract/error_kind.h" | cut -d' ' -f1)"
  echo
} > "$RES"

ALL_OK=1
IFS=',' read -r -a ARR <<< "$FNS"
for FN in "${ARR[@]}"; do
  "$LLVM/llvm-extract" --func="$FN" --recursive "$BUILD/c_leaf.ll" -o "$BUILD/c_${FN}.bc"
  "$LLVM/llvm-extract" --func="$FN" --recursive "$BUILD/l_leaf.ll" -o "$BUILD/l_${FN}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_${FN}.bc" -o "$BUILD/c_${FN}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_${FN}.bc" -o "$BUILD/l_${FN}.ll"
  # Alive2 v20 refuses attached TBAA/alias.scope metadata in some shapes.  The
  # strip is identical on both legs and metadata is an optimizer hint, not
  # semantics; it is recorded in notes.md.
  for f in "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"; do
    perl -0pi -e 's/,\s*!(tbaa|tbaa\.struct|alias\.scope|noalias|nonnull)(\s+![0-9]+)+//g' "$f"
  done
  TMP="$OUT/.${FN}.tmp"
  {
    echo "# command: /usr/local/bin/alive-tv --bidirectional build/c_${FN}.ll build/l_${FN}.ll"
    echo "# c IR sha256: $(sha256sum "$BUILD/c_${FN}.ll" | cut -d' ' -f1)"
    echo "# l IR sha256: $(sha256sum "$BUILD/l_${FN}.ll" | cut -d' ' -f1)"
    /usr/local/bin/alive-tv --bidirectional "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll" || true
  } > "$TMP" 2>&1
  {
    echo "===== $FN ====="
    cat "$TMP"
    echo
  } >> "$RES"
  if grep -q "Transformation seems to be correct!" "$TMP" \
     && ! grep -q "doesn't verify" "$TMP"; then
    echo "STATUS_${FN}=alive2-green" >> "$RES"
  else
    echo "STATUS_${FN}=alive2-not-green" >> "$RES"
    ALL_OK=0
  fi
  rm -f "$TMP"
done

if [ "$ALL_OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi

# Certificate over tracked inputs only (no build/ artifacts, no absolute paths).
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

[ "$ALL_OK" -eq 1 ]
