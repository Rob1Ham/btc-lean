#!/usr/bin/env bash
# Build the bounded exec-verify leaf pair.  c_cell.cpp is a line-cited Core
# excerpt; l_cell.cpp is a reviewed transliteration of the Lean defs (see the
# file headers).  The manifest is "<fn> <nargs>" per line.
set -euo pipefail
CELL_DIR="$1"
MANIFEST="${2:-$CELL_DIR/manifest.txt}"
T="$(cd "$(dirname "$0")" && pwd)"
BUILD="${X_BUILD:-$CELL_DIR/build}"
mkdir -p "$BUILD"
[ -f "$MANIFEST" ] || { echo "missing manifest: $MANIFEST" >&2; exit 2; }
FNS=()
while read -r fn nargs; do
  case "${fn:-}" in ""|\#*) continue ;; esac
  FNS+=("$fn")
done < "$MANIFEST"
[ "${#FNS[@]}" -gt 0 ] || { echo "empty manifest: $MANIFEST" >&2; exit 2; }

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$T" -c -emit-llvm)
"${CXX[@]}" "$T/c_cell.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$T/l_cell.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'manifest=%s\n' "$MANIFEST"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'source=C slices interpreter.cpp:2012-2131, script.cpp:266-282, shims/core/entry.cpp:93-100; L reviewed Lean Defs.lean:496,1326-1445 + Rules.lean:47-50\n'
} > "$BUILD/build.txt"
