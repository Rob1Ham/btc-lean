#!/usr/bin/env bash
# Build the two divergence-probe IR functions (not a cell; evidence only).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names
     -c -emit-llvm)
"${CXX[@]}" "$HERE/probe_c.cpp" -o "$BUILD/c_probe.bc"
"${CXX[@]}" "$HERE/probe_l.cpp" -o "$BUILD/l_probe.bc"
for leg in c l; do
  /usr/lib/llvm-20/bin/llvm-extract --func=probe_prescan_order --recursive \
    "$BUILD/${leg}_probe.bc" -o "$BUILD/${leg}_probe.fn.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_probe.fn.bc" -o "$BUILD/${leg}_probe.fn.ll"
  # O2 form: Alive2 20.0 silently skips the query on the raw -O1 IR above.
  /usr/lib/llvm-20/bin/opt -O2 -S "$BUILD/${leg}_probe.fn.ll" -o "$BUILD/${leg}_probe.opt.ll"
done
printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)" > "$BUILD/build.txt"
