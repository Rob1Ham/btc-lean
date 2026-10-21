#!/usr/bin/env bash
# Negative control: a wrong-order C module must NOT be equivalent to L.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$CELL/tools/ordering_mutant.out"
B="$CELL/build/mutant"
ALIVE=/opt/equiv-tools/alive-tv-v20.0
mkdir -p "$B"
/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names \
  -I "$CELL/_tools" -c -emit-llvm "$CELL/tools/ordering_mutant.cpp" -o "$B/mutant.bc"
/usr/lib/llvm-20/bin/llvm-extract --func=cell_flag_source --recursive \
  "$B/mutant.bc" -o "$B/mutant_cell_flag_source.bc"
/usr/lib/llvm-20/bin/llvm-dis "$B/mutant_cell_flag_source.bc" \
  -o "$B/mutant_cell_flag_source.ll"

set +e
"$ALIVE" "$B/mutant_cell_flag_source.ll" "$CELL/ir/l_cell_flag_source.ll" \
  > "$B/alive.txt" 2>&1
RC=$?
set -e
{
  echo "# cell: policy-flags/C-L-flag-source (negative control)"
  echo "# mutant: exception replacement moved AFTER the four buried ORs"
  echo "# command: alive-tv mutant_cell_flag_source.ll ir/l_cell_flag_source.ll"
  cat "$B/alive.txt"
} > "$OUT"

if grep -q "Transformation doesn't verify" "$B/alive.txt" \
   && grep -q "0 correct transformations" "$B/alive.txt"; then
  echo "MUTANT=caught (rc=$RC)" >> "$OUT"
  cat "$OUT"
else
  echo "MUTANT=NOT-caught (rc=$RC)" >> "$OUT"
  cat "$OUT"
  exit 1
fi
