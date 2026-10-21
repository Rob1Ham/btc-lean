#!/usr/bin/env bash
# Negative controls for the SCR-074 arity table.
#
# The wave16b audit (S2-2) said guard-threshold mutants survive the old
# empty-stack-only cell.  These mutants patch the generated twin_ops.h (never
# the tracked source) and ask which rows of the extended table notice:
#
#   M1  2ROT  n < 6 -> n < 2   (too weak)
#   M2  NIP   n < 2 -> n < 1   (too weak)
#   M3  2ROT  n < 6 -> n < 7   (too strict)
#
# M1/M2 at depth 0 are green -- exactly the row the old cell had.  The new
# depth rows and/or the boundary row are expected to be red.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
H="$CELL_DIR/../_harness"
CELLS="$(cd "$H/../.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/mutations"
TMP="$(mktemp -d /tmp/scr074-mut.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BUILD/twin_ops.h" ] || "$CELL_DIR/src/build.sh" >/dev/null

python3 - "$BUILD/twin_ops.h" "$TMP" <<'PY'
import re, sys
from pathlib import Path
src = Path(sys.argv[1]).read_text().splitlines(keepends=True)
out = Path(sys.argv[2])

def patch(block_name, old, new, dst):
    lines = list(src)
    start = next(i for i, l in enumerate(lines)
                 if l.startswith(f"static inline __attribute__((always_inline)) TwinErr {block_name}("))
    end = next(i for i in range(start + 1, len(lines))
               if lines[i].startswith("static inline __attribute__((always_inline)) TwinErr op_"))
    hit = 0
    for i in range(start, end):
        if old in lines[i]:
            lines[i] = lines[i].replace(old, new, 1); hit += 1
    assert hit == 1, (block_name, old, hit)
    (out / dst / "twin_ops.h").parent.mkdir(parents=True, exist_ok=True)
    (out / dst / "twin_ops.h").write_text("".join(lines))

patch("op_OP_2ROT", "st.stack.n < 6", "st.stack.n < 2", "m1")
patch("op_OP_NIP",  "st.stack.n < 2", "st.stack.n < 1", "m2")
patch("op_OP_2ROT", "st.stack.n < 6", "st.stack.n < 7", "m3")
PY

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-jump-tables
     -S -emit-llvm -fno-discard-value-names)
compile_mutant() {
  local mut="$1" fn="$2"
  "${CXX[@]}" -I "$TMP/$mut" -I "$BUILD" -I "$CELL_DIR/src" -I "$H" \
    -I "$EQ/contract" "$CELL_DIR/src/l_leaf.cpp" -o "$TMP/$mut/l_leaf.ll"
  /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
    "$TMP/$mut/l_leaf.ll" -o "$TMP/$mut/l_$fn.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$TMP/$mut/l_$fn.bc" -o "$TMP/$mut/l_$fn.ll"
}

verdict() {  # verdict C_LL L_LL -> green|red (full output in $TMP/last.txt)
  local a="$1" b="$2" o
  o="$(/usr/local/bin/alive-tv --smt-to=30000 --src-unroll=16 \
        --tgt-unroll=16 "$a" "$b" 2>&1 || true)"
  printf '%s\n' "$o" > "$TMP/last.txt"
  if printf '%s' "$o" | grep -q "1 correct transformations" \
     && printf '%s' "$o" | grep -q "0 incorrect transformations" \
     && printf '%s' "$o" | grep -q "0 failed-to-prove transformations"; then
    echo green
  else
    echo red
  fi
}
why() {  # first diagnostic line from the last alive-tv run
  grep -m1 -E "Transformation doesn.t verify|ERROR:|doesn.t reach|Source is more defined|Target is more defined" \
    "$TMP/last.txt" | cut -c1-96
}

RC=0
{
  echo "# cell: stack-ops/C-L-arity (negative controls)"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# mutants patch the generated build/twin_ops.h only; src is untouched"
  for spec in "m1:2ROT n<6->n<2:cell_2rot_d0,cell_2rot_d2,cell_2rot_d5,cell_2rot_ok" \
              "m2:NIP n<2->n<1:cell_nip_d0,cell_nip_d1,cell_nip_ok" \
              "m3:2ROT n<6->n<7:cell_2rot_d0,cell_2rot_ok"; do
    mut="${spec%%:*}"; rest="${spec#*:}"; desc="${rest%%:*}"
    fns="${rest#*:}"
    echo
    echo "== $mut: $desc"
    IFS=, read -ra FNARR <<< "$fns"
    for fn in "${FNARR[@]}"; do compile_mutant "$mut" "$fn"; done
    for fn in "${FNARR[@]}"; do
      v="$(verdict "$BUILD/c_${fn}.ll" "$TMP/$mut/l_${fn}.ll")"
      w="-"; [ "$v" = red ] && w="$(why)"
      printf '%-18s %-4s %-16s %s\n' "$fn" "$v" "$desc" "$w"
    done
  done
} > "$OUT/result.txt" 2>&1 || RC=1

# Expected.  Too-weak mutants survive exactly at depth 0 (the old cell's only
# row) and are killed by the new depth rows; the too-strict mutant is invisible
# at every underflow row and killed by the boundary row.
check() { awk -v f="$1" -v v="$2" -v d="$3" \
  '$1==f && $2==v && $3==d {found=1} END{exit !found}' "$OUT/result.txt"; }
while IFS=$'\t' read -r f v d; do
  check "$f" "$v" "$d" || { echo "EXPECTATION FAILED: $f $v $d"; RC=1; }
done <<'EOF'
cell_2rot_d0	green	2ROT
cell_2rot_d2	red	2ROT
cell_2rot_d5	red	2ROT
cell_2rot_ok	green	2ROT
cell_nip_d0	green	NIP
cell_nip_d1	red	NIP
cell_nip_ok	green	NIP
cell_2rot_d0	green	2ROT
cell_2rot_ok	red	2ROT
EOF
if [ "$RC" -eq 0 ]; then echo "STATUS=mutants-killed" >> "$OUT/result.txt"
else echo "STATUS=mutants-unexpected" >> "$OUT/result.txt"; fi

python3 "$CELL_DIR/src/normalize_cert.py" "$CELL_DIR" "$OUT/certificate.sha256"
exit "$RC"
