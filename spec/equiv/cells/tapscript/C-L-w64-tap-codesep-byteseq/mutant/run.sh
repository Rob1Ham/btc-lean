#!/usr/bin/env bash
# Mutation control for SCR-167: conflate the legacy byte offset with the
# 0-based opcode index in the L leaf and require BOTH lanes to reject it.
# The cell sources are copied; the originals are never modified.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
WORK="$CELL_DIR/build-mutant"
OUT="$CELL_DIR/mutant"
LLVM=/usr/lib/llvm-20/bin
ALIVE=/usr/local/bin/alive-tv
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
FN=cell_codesep_byteseq
CXX=/usr/bin/clang++-20

rm -rf "$WORK"; mkdir -p "$WORK" "$OUT"
cp "$SRC/c_leaf.cpp" "$SRC/l_leaf.cpp" "$SRC/cell.cry" "$SRC/cell.saw" "$WORK/"

# The mutation: the separator arm stores the opcode index into the legacy
# byte-offset field as well.
if ! grep -q 'codeSep = nx;' "$WORK/l_leaf.cpp"; then
  echo "mutation site not found" >&2; exit 2
fi
python3 - "$WORK/l_leaf.cpp" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
assert 'codeSep = nx;' in s
open(p, 'w').write(s.replace('codeSep = nx;', 'codeSep = opcodeIndex;', 1))
PY
grep -n 'codeSep = opcodeIndex\|codeSepPos = opcodeIndex' "$WORK/l_leaf.cpp" > "$WORK/mutation.txt"

CXXFLAGS=(-std=c++17 -O1 -fno-strict-aliasing -fno-exceptions -fno-rtti
          -I "$WORK" -S -emit-llvm -fno-discard-value-names)
"$CXX" "${CXXFLAGS[@]}" "$WORK/c_leaf.cpp" -o "$WORK/c_leaf.ll"
"$CXX" "${CXXFLAGS[@]}" "$WORK/l_leaf.cpp" -o "$WORK/l_leaf.ll"
for leg in c l; do
  "$LLVM/llvm-extract" --func="$FN" --recursive "$WORK/${leg}_leaf.ll" -o "$WORK/${leg}_${FN}.bc"
  "$LLVM/llvm-dis" "$WORK/${leg}_${FN}.bc" -o "$WORK/${leg}_${FN}.ll"
done

RES="$OUT/result.txt"
{
  echo "# mutation control for tapscript/C-L-w64-tap-codesep-byteseq"
  echo "# mutation: L separator arm codeSep = nx  ->  codeSep = opcodeIndex"
  echo "# site:"
  sed 's/^/#   /' "$WORK/mutation.txt"
  echo
  echo "===== alive2 ====="
  "$ALIVE" --fail-src-ub --smt-to=180000 --bidirectional \
    "$WORK/c_${FN}.ll" "$WORK/l_${FN}.ll" 2>&1 || true
  echo
  echo "===== saw ====="
  ( cd "$WORK" && PATH=$SAWPATH saw cell.saw ) 2>&1 || true
} > "$RES"

ALIVE_BAD=0; SAW_BAD=0
grep -Eq '^  1 incorrect transformations$|Transformation doesn.t verify|ERROR' "$RES" && ALIVE_BAD=1
grep -Eq 'Proof failed|Counterexample' "$RES" && SAW_BAD=1
{
  echo
  echo "# alive2 detected mutant: $ALIVE_BAD"
  echo "# saw detected mutant: $SAW_BAD"
} >> "$RES"
if [ "$ALIVE_BAD" -eq 1 ] && [ "$SAW_BAD" -eq 1 ]; then
  echo "STATUS=mutant-detected-by-both" >> "$RES"
else
  echo "STATUS=mutant-NOT-detected" >> "$RES"
  exit 1
fi
