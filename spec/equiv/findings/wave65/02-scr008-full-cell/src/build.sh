#!/usr/bin/env bash
# Build the SCR-008 full-domain probe modules.
#
#   build.sh <outdir>
#
# Emits, in <outdir>: c_core.{bc,ll}, l_pinned.{bc,ll}, l_fixed.{bc,ll},
# each bitcode module holding exactly the single exported function
# `probe_scr008` (llvm-extract --recursive).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:?usage: build.sh <outdir>}"
mkdir -p "$OUT"
for src in c_core l_pinned l_fixed; do
  /usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing \
    -fno-discard-value-names -I "$HERE" -c -emit-llvm \
    "$HERE/$src.cpp" -o "$OUT/$src.bc"
  /usr/lib/llvm-20/bin/llvm-extract --func=probe_scr008 --recursive \
    "$OUT/$src.bc" -o "$OUT/$src.x.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$OUT/$src.x.bc" -o "$OUT/$src.ll"
done
