#!/usr/bin/env bash
# Non-certificate probe: show that Alive2's input pointer block size is
# nondeterministic, so the cell's pointer-argument proofs quantify over every
# vin length rather than a fixed bound.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../size-probe.txt"
CXX=(/usr/bin/clang++-20 -std=c++20 -O0 -fno-strict-aliasing -S -emit-llvm -fno-discard-value-names)
for x in size_src size_tgt; do
  "${CXX[@]}" "$HERE/$x.c" -o "$HERE/$x.ll"
  sed -E 's/ nocapture//g' "$HERE/$x.ll" > "$HERE/$x.clean.ll"
  /usr/lib/llvm-20/bin/llvm-extract --func=probe "$HERE/$x.clean.ll" -o "$HERE/$x.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$HERE/$x.bc" -o "$HERE/$x.dis.ll"
done
{
  echo "# probe: Alive2 input block size is nondeterministic"
  echo "# command: alive-tv --smt-to=120000 probe/size_src.dis.ll probe/size_tgt.dis.ll"
  echo "# expected: a value mismatch at i=100 with a huge NON-LOCAL block size"
  /opt/equiv-tools/alive-tv-v20.0 "$HERE/size_src.dis.ll" "$HERE/size_tgt.dis.ll" --smt-to=120000 2>&1 || true
} > "$OUT" 2>&1
