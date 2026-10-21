#!/usr/bin/env bash
# Alive2 leg for locktime/C-L-locktime-input-index-general: compare the C
# source-excerpt checker bodies with the reviewed Lean transliteration of
# `locktimeEnvOf` + `checkLockTimeDef`/`checkSequenceDef` over an
# arbitrary-length vin pointer and an arbitrary uint32 index.
#
# Pairs (see build/pairs.txt):
#   cltv / csv           totalised C body  vs  Lean getD environment
#   cltv_raw / csv_raw   verbatim txTo->vin[nIn] read vs Lean environment
#                        (harness domain guard makes both sides total)
#   cltv_ni / csv_ni     two arbitrary vins agreeing on the selected slot
#   getd_len             getD depends on the length only via nIn < len
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
PAIRS=(cltv csv cltv_raw csv_raw cltv_ni csv_ni getd_len)
SMT_TO=300000
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: locktime/C-L-locktime-input-index-general"
  echo "# alive-tv: $(/opt/equiv-tools/alive-tv-v20.0 --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# build: src/build.sh (flags in build/build.txt)"
  echo "# contract: contract/error_kind.h sha256 $(sha256sum "$EQ/contract/error_kind.h" | cut -d' ' -f1)"
  echo "# vin: pointer argument; Alive2's input block size is nondeterministic,"
  echo "#      so the checked domain has arbitrary vin length (nIn in range)."
  echo "# nIn: uint32, fully symbolic."
  for pair in "${PAIRS[@]}"; do
    echo
    echo "# pair: $pair"
    echo "# command: alive-tv --smt-to=$SMT_TO build/${pair}_src.ll build/${pair}_tgt.ll"
    echo "# ir: src_sha256=$(sha256sum "$BUILD/${pair}_src.ll" | cut -d' ' -f1) tgt_sha256=$(sha256sum "$BUILD/${pair}_tgt.ll" | cut -d' ' -f1)"
    fnout="$(/opt/equiv-tools/alive-tv-v20.0 "$BUILD/${pair}_src.ll" "$BUILD/${pair}_tgt.ll" --smt-to="$SMT_TO" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$CELL_DIR/src/GeneralIndex.lean" "$CELL_DIR/src/lean_excerpt.md"
  "$CELL_DIR/alive2/probe/run.sh" "$CELL_DIR/alive2/probe/size_src.c"
  "$CELL_DIR/alive2/probe/size_tgt.c" "$CELL_DIR/alive2/size-probe.txt"
  "$EQ/contract/error_kind.h"
  "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
