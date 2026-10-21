#!/usr/bin/env bash
# Alive2 attempt for witness-v0/C-L-bip143-encoding-cs.
#
# Every function in src/fns.txt is compared as C IR vs L IR with
# --bidirectional (L ⊑ C and C ⊑ L), and with an unroll factor because the L
# integer encoders are byte-lane loops (the C leg is unrolled).
#
# Classification is stricter than the shared witness-v0 runner: a function is
# green only on the exact summary "1 correct / 0 incorrect / 0
# failed-to-prove / 0 Alive2 errors" with no "ERROR:" line.  A missing return
# in either direction is not accepted as a pass.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$CELL_DIR"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: C-L-bip143-encoding-cs"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# flags: --bidirectional --src-unroll=8 --tgt-unroll=8"
  echo "# functions: $(grep -v '^#' "$CELL_DIR/src/fns.txt" | tr '\n' ' ')"
  while IFS= read -r fn; do
    [ -z "$fn" ] && continue
    case "$fn" in \#*) continue;; esac
    echo "# command: alive-tv --bidirectional --src-unroll=8 --tgt-unroll=8 ir/c_${fn}.ll ir/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv --bidirectional --src-unroll=8 \
               --tgt-unroll=8 "ir/c_${fn}.ll" "ir/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 incorrect transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 failed-to-prove transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 Alive2 errors" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done < "$CELL_DIR/src/fns.txt"
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi

# Certificate: repo-root-relative hashes over the cell's tracked inputs and the
# shared build/header it uses, plus the raw result transcript.  build/ is not
# hashed: the committed ir/*.ll are the certificate-bound artifacts.
ROOT="$(git -C "$CELL_DIR" rev-parse --show-toplevel)"
REL="${CELL_DIR#"$ROOT"/}"
cd "$ROOT"
{
  for f in "$REL/spec.md" "$REL/notes.md" "$REL/alive2/run.sh" \
           "$REL/src/build.sh" "$REL/src/c_cell.cpp" "$REL/src/l_cell.cpp" \
           "$REL/src/fns.txt" "$REL/src/solver.txt" \
           "$REL/ir"/*.ll "$REL/alive2/result.txt" \
           "spec/equiv/cells/witness-v0/_tools/build.sh" \
           "spec/equiv/cells/witness-v0/_tools/wv_common.h"; do
    [ -f "$f" ] && sha256sum "$f"
  done | sort -k2
} > "$OUT/certificate.sha256"

exit "$STATUS"
