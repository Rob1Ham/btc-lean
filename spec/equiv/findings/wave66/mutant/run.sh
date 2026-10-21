#!/usr/bin/env bash
# SCR-001 mutant check: a sequential arm that uses the CONCATENATED end.
#
# The mutant changes exactly one expression in the C leg's c_split_pair:
#
#   -  c_push_boundary(op, b0, b1, 0, 0, hdr + after_op)   // scriptSig end
#   +  c_push_boundary(op, b0, b1, 0, 0, hdr + declared)   // concatenated end
#
# That is the "concatenate scriptSig ++ scriptPubKey" model the row forbids.
# The unmutated cell is green (saw/certificate.sha256, alive2/certificate.sha256);
# this script must show the mutant rejected by SAW with a counterexample where
# after < declared, so the cell discriminates rather than being vacuous.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"  # repo root
CELL="$ROOT/spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary"
W32="$ROOT/spec/equiv/cells/_tools/w32-exec"
EQ="$ROOT/spec/equiv"
B="$HERE/build"
SAW=/opt/equiv-tools/saw-1.6/bin/saw
export PATH=/opt/equiv-tools/saw-1.6/bin:$PATH
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$W32" -I "$EQ/contract" -c -emit-llvm)

rm -rf "$B"
mkdir -p "$B"
cp "$CELL/src/c_cell.cpp" "$B/c_cell_mutant.cpp"
cp "$CELL/src/l_cell.cpp" "$B/l_cell.cpp"
cp "$CELL/src/cell.cry" "$B/cell.cry"
cp "$CELL/src/cell.saw" "$B/cell.saw"

python3 - "$B/c_cell_mutant.cpp" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "c_push_boundary(op, b0, b1, 0, 0, hdr + after_op)"
new = "c_push_boundary(op, b0, b1, 0, 0, hdr + declared)"
assert s.count(old) == 1, s.count(old)
open(p, "w").write(s.replace(old, new))
PY

diff -u "$CELL/src/c_cell.cpp" "$B/c_cell_mutant.cpp" > "$HERE/mutant.diff" || true

"${CXX[@]}" "$B/c_cell_mutant.cpp" -o "$B/c_leaf.bc"
"${CXX[@]}" "$B/l_cell.cpp"        -o "$B/l_leaf.bc"

RES="$HERE/result.txt"
{
  echo "# SCR-001 concatenation mutant"
  echo "# saw: $("$SAW" --version 2>&1 | head -1)"
  echo "# mutated file: build/c_cell_mutant.cpp"
  echo "# diff: mutant.diff"
  echo
  ( cd "$B" && "$SAW" cell.saw 2>&1 || true )
  echo
} > "$RES" 2>&1

# Expected: SAW rejects the sequential/concat equality and names a witness
# with after < declared.
if grep -q '^Proof succeeded!' "$RES" \
   && grep -q '^Proof failed' "$RES" \
   && grep -q '^----------Counterexample----------' "$RES"; then
  echo "STATUS=mutant-rejected" >> "$RES"
else
  echo "STATUS=mutant-unexpectedly-green" >> "$RES"
  exit 1
fi
