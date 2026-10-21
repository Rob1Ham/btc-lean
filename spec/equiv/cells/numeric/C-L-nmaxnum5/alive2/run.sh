#!/usr/bin/env bash
# Alive2 leg: C vs L for each entry point of numeric/C-L-nmaxnum5.
#
#   alive2/run.sh [CELL_DIR]
#
# Every comparison must report "Transformation seems to be correct!" and
# "1 correct transformations", with no "Transformation doesn't verify" and no
# "ERROR:".  The raw output is alive2/result.txt; alive2/certificate.sha256
# chains it to the tracked inputs.
set -euo pipefail
CELL_DIR="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
REPO="$(cd "$CELL_DIR/../../../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
FNS=(cell_cltv cell_csv cell_default4)
ALIVE=/usr/local/bin/alive-tv
SMT_TO="${SMT_TO:-120000}"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

RES="$OUT/result.txt"
OK=1
{
  echo "# cell: numeric/C-L-nmaxnum5"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# flags: --smt-to=$SMT_TO"
  echo "# build: build/build.txt"
  for fn in "${FNS[@]}"; do
    echo
    echo "# command: alive-tv --smt-to=$SMT_TO build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$("$ALIVE" --smt-to="$SMT_TO" "$BUILD/c_${fn}.ll" \
             "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
      echo "# FAILED: $fn"
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi

# Certificate: tracked inputs + the raw log, repo-relative.
{
  cd "$REPO"
  for f in \
    "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" \
    "$CELL_DIR/alive2/run.sh" "$CELL_DIR/src/build.sh" \
    "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp" \
    spec/equiv/contract/error_kind.h \
    spec/core/Bitcoin/Numeric/ScriptNum.lean \
    spec/core/Bitcoin/Numeric/Interface.lean \
    spec/core/Bitcoin/Interpreter/Defs.lean \
    spec/db/rules.yaml \
    "$RES"; do
    rel="$(realpath --relative-to="$REPO" "$f")"
    sha256sum "$rel"
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
