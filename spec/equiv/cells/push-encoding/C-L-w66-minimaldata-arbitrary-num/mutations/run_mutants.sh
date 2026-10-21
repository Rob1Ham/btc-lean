#!/usr/bin/env bash
# Negative controls for SCR-051 (policy: MINIMALDATA numeric operands,
# arbitrary-length operands).
#
# The cell's C leaf is copied to a scratch directory and mutated; the tracked
# source is never modified.  Each mutant C leaf is compared against the
# unmodified L leaf, so a mutant that still proves green would mean the
# equivalence obligation does not constrain the rule the mutant breaks.
#
#   M1  wrong policy bit: F_MINIMALDATA 0x40 -> 0x20
#   M2  dropped ±255 exception: any len>0 operand whose top byte's low seven
#       bits are zero is non-minimal
#   M3  negative-zero acceptance: top-byte mask 0x7f -> 0xff, so 0x80 is
#       treated as a minimal encoding of zero
#   M4  width guard off-by-one: len > maxsize -> len > maxsize + 1
#   M5  CHECKMULTISIG precedence: OP_COUNT tested before PUBKEY_COUNT
#   M6  dropped NEGATIVE_LOCKTIME at CLTV/CSV (decode succeeds, no error)
#   M7  round-trip polarity flipped in the predicate observable
#
# Expected verdicts are per (mutant, entry point): a mutation that cannot
# change a given observable must stay green there.  This is a stronger
# statement than "every mutant is red everywhere": it pins which obligation
# each function actually carries.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
W32="$(cd "$CELL_DIR/../../_tools/w32-push" && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/mutations"
TMP="$(mktemp -d /tmp/scr051w66-mut.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BUILD/l_cell_cltv.ll" ] || "$W32/build.sh" "$CELL_DIR" >/dev/null

CXX=(/usr/bin/clang++-20 -std=c++17 -O2 -fno-strict-aliasing -fno-jump-tables
     -mllvm -inline-threshold=3000
     -I "$W32" -I "$BUILD" -I "$EQ/contract"
     -S -emit-llvm -fno-discard-value-names)

mutate() {  # mutate NAME OLD NEW [ALL]
  local name="$1" old="$2" new="$3" all="${4:-}"
  mkdir -p "$TMP/$name"
  python3 - "$CELL_DIR/src/c_leaf.cpp" "$TMP/$name/c_leaf.cpp" "$old" "$new" "$all" <<'PY'
import sys
from pathlib import Path
src, dst, old, new, all_ = sys.argv[1:]
s = Path(src).read_text()
n = s.count(old)
if all_ == "all":
    assert n >= 1, (old, n)
else:
    assert n == 1, (old, n)
Path(dst).write_text(s.replace(old, new))
PY
}

compile_mutant() {  # compile_mutant NAME FN
  local name="$1" fn="$2"
  "${CXX[@]}" "$TMP/$name/c_leaf.cpp" -o "$TMP/$name/c_leaf.ll"
  /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
    "$TMP/$name/c_leaf.ll" -o "$TMP/$name/c_${fn}.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$TMP/$name/c_${fn}.bc" \
    -o "$TMP/$name/c_${fn}.ll"
}

verdict() {  # verdict C_LL L_LL -> green|red|other (full output in $TMP/last)
  local a="$1" b="$2" o
  o="$(/usr/local/bin/alive-tv --bidirectional --smt-to=300000 "$a" "$b" 2>&1 || true)"
  printf '%s\n' "$o" > "$TMP/last"
  if printf '%s' "$o" | grep -q "1 correct transformations" \
     && printf '%s' "$o" | grep -q "0 incorrect transformations" \
     && printf '%s' "$o" | grep -q "0 failed-to-prove transformations"; then
    echo green
  elif printf '%s' "$o" | grep -q "Transformation doesn't verify"; then
    echo red
  else
    echo other
  fi
}
why() {  # first diagnostic line from the last alive-tv run
  grep -m1 -E "Transformation doesn.t verify|ERROR:|doesn.t reach|Source is more defined|Target is more defined|failed-to-prove" \
    "$TMP/last" | cut -c1-110
}

mutate m1 'constexpr uint64_t F_MINIMALDATA = 0x000040ull;' \
          'constexpr uint64_t F_MINIMALDATA = 0x000020ull;'
mutate m2 '      if (len <= 1) return {false, 0};
      const uint8_t prev = (uint8_t)((p >> (8u * (len - 2u))) & 0xffu);
      if ((prev & 0x80u) == 0) return {false, 0};' \
          '      return {false, 0};'
mutate m3 'if ((last & 0x7fu) == 0) {' 'if ((last & 0xffu) == 0) {'
mutate m4 'if (len > maxsize) return {false, 0};' \
          'if (len > maxsize + 1u) return {false, 0};'
mutate m5 '  if (k.v < 0 || k.v > (int64_t)MAX_PUBKEYS_PER_MULTISIG)
    return cell_pack(0, EQUIV_ERR_PUBKEY_COUNT);
  int32_t nOpCount = (int32_t)opcount + (int32_t)k.v;
  if (nOpCount > MAX_OPS_PER_SCRIPT) return cell_pack(0, EQUIV_ERR_OP_COUNT);' \
          '  int32_t nOpCount = (int32_t)opcount + (int32_t)k.v;
  if (nOpCount > MAX_OPS_PER_SCRIPT) return cell_pack(0, EQUIV_ERR_OP_COUNT);
  if (k.v < 0 || k.v > (int64_t)MAX_PUBKEYS_PER_MULTISIG)
    return cell_pack(0, EQUIV_ERR_PUBKEY_COUNT);'
mutate m6 'if (d.v < 0) return cell_pack(0, EQUIV_ERR_NEGATIVE_LOCKTIME);' \
          'if (false) return cell_pack(0, EQUIV_ERR_NEGATIVE_LOCKTIME);' all
mutate m7 'rt = roundtrip_eq(p, len, value);' \
          'rt = !roundtrip_eq(p, len, value);'

# mutant | entry point | expected verdict
CASES=(
  "m1:pred_cap5:red"   "m1:cell_cltv:red" "m1:cell_cms:red"
  "m2:cell_cltv:red"   "m2:cell_cms:red"
  "m3:cell_cltv:red"   "m3:cell_cms:red"
  "m4:cell_cltv:red"   "m4:cell_cms:red"
  "m5:cell_cms:red"
  "m6:cell_cltv:red"
  "m7:pred_cap5:red"   "m7:cell_cltv:green"
)

RC=0
{
  echo "# cell: push-encoding/C-L-w66-minimaldata-arbitrary-num (negative controls)"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# c_leaf.cpp sha256 $(sha256sum "$CELL_DIR/src/c_leaf.cpp" | cut -d' ' -f1)"
  echo "# l_leaf.cpp sha256 $(sha256sum "$CELL_DIR/src/l_leaf.cpp" | cut -d' ' -f1)"
  echo "# mutants patch a scratch copy of src/c_leaf.cpp only; tracked src untouched"
  echo
  echo "== m1: F_MINIMALDATA 0x40 -> 0x20"
  echo "== m2: drop second-byte (0x80) exception"
  echo "== m3: negative-zero (0x80) accepted as minimal"
  echo "== m4: width guard len > maxsize + 1"
  echo "== m5: CHECKMULTISIG OP_COUNT before PUBKEY_COUNT"
  echo "== m6: dropped NEGATIVE_LOCKTIME (CLTV and CSV)"
  echo "== m7: round-trip bit polarity flipped in pred_body"
  echo
  for c in "${CASES[@]}"; do
    name="${c%%:*}"; rest="${c#*:}"; fn="${rest%%:*}"; want="${rest#*:}"
    [ -f "$TMP/$name/c_leaf.ll" ] || compile_mutant "$name" "$fn"
    cc="$TMP/$name/c_${fn}.ll"
    [ -f "$cc" ] || compile_mutant "$name" "$fn"
    got="$(verdict "$cc" "$BUILD/l_${fn}.ll")"
    w="-"; [ "$got" != green ] && w="$(why)"
    printf '%-12s %-5s %-5s %-5s %s\n' "$fn" "$name" "$got" "$want" "$w"
    [ "$got" = "$want" ] || RC=1
  done
  echo
} > "$OUT/result.txt" 2>&1 || RC=1

if [ "$RC" -eq 0 ]; then
  echo "STATUS=mutants-killed" >> "$OUT/result.txt"
else
  echo "STATUS=mutants-unexpected" >> "$OUT/result.txt"
fi

"$W32/certify.sh" "$CELL_DIR" "$OUT/certificate.sha256" "$OUT/result.txt" \
  "$OUT/run_mutants.sh"
exit "$RC"
