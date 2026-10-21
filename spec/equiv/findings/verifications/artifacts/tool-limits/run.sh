#!/bin/sh
# Reproduce the tool-limit experiments. Requires clang++-20, LLVM 20 tools,
# Alive2 v20.0, and SAW 1.6 with solvers on PATH.
set -e
LLVM=/usr/lib/llvm-20/bin
/usr/bin/clang++-20 -O0 -emit-llvm -c features.cpp -o features.bc
$LLVM/llvm-dis features.bc -o features.ll
for f in ex_edges indirect ptr_roundtrip; do
  $LLVM/llvm-extract --func=$f features.bc -o $f.bc
done

alive-tv features.bc > alive2_features.out 2>&1 || true
alive-tv ex_edges.bc > alive2_ex_edges.out 2>&1 || true
alive-tv --always-verify indirect.bc > alive2_indirect_always.out 2>&1 || true
alive-tv --always-verify ptr_roundtrip.bc > alive2_ptr_always.out 2>&1 || true

saw ex_nonneg.saw > saw_ex_nonneg.out 2>&1 || true

sha256sum features.ll features.bc ex_edges.bc indirect.bc ptr_roundtrip.bc \
          > hashes.txt
