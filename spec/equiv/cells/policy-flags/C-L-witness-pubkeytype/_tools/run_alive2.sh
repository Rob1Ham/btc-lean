#!/usr/bin/env bash
# Alive2 attempt for one wave16 policy cell.
#
# Each root is a total function over its declared symbolic domain, so this is a
# symbolic predicate proof, not a closed witness.  Both refinement directions
# are checked separately:
#
#   alive-tv ir/c_<fn>.ll ir/l_<fn>.ll   ->  L refines C   (L ⊑ C)
#   alive-tv ir/l_<fn>.ll ir/c_<fn>.ll   ->  C refines L   (C ⊑ L)
#
# The textual IR under `ir/` is tracked (unlike `build/`, which is gitignored),
# so `sha256sum -c alive2/certificate.sha256` works from a fresh checkout and
# hashes exactly the modules that were handed to alive-tv.
#
# alive-tv exits 0 even on a counterexample, so the report text is parsed: a
# cell is green only when every invocation reports "Transformation seems to be
# correct" / "1 correct transformations" and none reports a counterexample or an
# Alive2 error.
set -euo pipefail
CELL_DIR="$1"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
IRD="$CELL_DIR/ir"
OUT="$CELL_DIR/alive2"
ALIVE=/opt/equiv-tools/alive-tv-v20.0
# shellcheck disable=SC1091
source "$CELL_DIR/buildspec"
mkdir -p "$OUT"

bash "$TOOLS/build_leaf.sh" "$CELL_DIR"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# tool: alive-tv v20.0 (LLVM $($ALIVE --version 2>&1 | head -1 | sed 's/^Ubuntu LLVM version //; s/\.$//'))"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# roots: $CELL_FNS"
  echo "# direction: each root is checked in both directions (L⊑C then C⊑L)"
  echo "# modules: tracked textual IR in ir/ (llvm-dis of the compiled .bc)"
  echo
  for fn in $CELL_FNS; do
    for dir in lr rl; do
      if [ "$dir" = lr ]; then
        a="$IRD/c_${fn}.ll"; b="$IRD/l_${fn}.ll"; label="L ⊑ C"
      else
        a="$IRD/l_${fn}.ll"; b="$IRD/c_${fn}.ll"; label="C ⊑ L"
      fi
      echo "===== $fn ($label) ====="
      echo "# command: alive-tv ir/$(basename "$a") ir/$(basename "$b")"
      set +e
      fnout="$("$ALIVE" "$a" "$b" 2>&1)"
      set -e
      printf '%s\n' "$fnout"
      if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
         || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
         || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
         || printf '%s' "$fnout" | grep -q "ERROR:"; then
        OK=0
      fi
      echo
    done
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green ($(grep -c 'Transformation seems to be correct' "$RES") direction checks)" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi

FILES=("$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$CELL_DIR/buildspec"
       "$CELL_DIR/c_cell.cpp" "$CELL_DIR/l_cell.cpp"
       "$TOOLS/policy_common.h" "$TOOLS/build_leaf.sh"
       "$IRD/build.txt"
       "$IRD/c_leaf.ll" "$IRD/l_leaf.ll" "$RES")
for fn in $CELL_FNS; do
  FILES+=("$IRD/c_${fn}.ll" "$IRD/l_${fn}.ll")
done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    rel="$(realpath --relative-to="$ROOT" "$f")"
    case "$rel" in
      ../*) echo "# outside-root $(sha256sum "$f")" ;;
      *) sha256sum "$rel" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
