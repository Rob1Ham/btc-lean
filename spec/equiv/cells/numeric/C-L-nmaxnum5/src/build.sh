#!/usr/bin/env bash
# Build the bounded C/L leaves of numeric/C-L-nmaxnum5.
#
#   src/build.sh CELL_DIR
#
# Compiles both legs with the pinned clang, extracts one module per entry
# point for Alive2/SAW and records the tool versions and input hashes.
set -euo pipefail
CELL_DIR="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
REPO="$(cd "$CELL_DIR/../../../../.." && pwd)"
BUILD="$CELL_DIR/build"
FNS=(cell_cltv cell_csv cell_default4)
mkdir -p "$BUILD"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-jump-tables -fno-strict-aliasing
     -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" \
      -o "$BUILD/${leg}_${fn}.ll"
    if grep -h "call.*@llvm\." "$BUILD/${leg}_${fn}.ll" \
       | grep -v "@llvm\.lifetime" | grep -q .; then
      echo "unexpected intrinsic in ${leg}_${fn}.ll" >&2
      exit 1
    fi
  done
done
{
  printf 'cell=C-L-nmaxnum5\n'
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'alive-tv=%s\n' "$(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  printf 'saw=%s\n' "$(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/c_leaf.cpp" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/l_leaf.cpp" | cut -d' ' -f1)"
  printf 'cell_cry_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/cell.cry" | cut -d' ' -f1)"
  printf 'cell_saw_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/cell.saw" | cut -d' ' -f1)"
  printf 'repo_head=%s\n' "$(cd "$REPO" && git rev-parse HEAD)"
  printf 'generated_ll:\n'
  for fn in "${FNS[@]}"; do
    for leg in c l; do
      printf '  %s_%s.ll %s\n' "$leg" "$fn" \
        "$(sha256sum "$BUILD/${leg}_${fn}.ll" | cut -d' ' -f1)"
    done
  done
} > "$BUILD/build.txt"
