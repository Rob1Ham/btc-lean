#!/usr/bin/env bash
# Behavioral corroboration for an E3 cell (NOT proof evidence).
# Builds one binary per concrete checker result and compares C vs L packed
# observables against the independent oracle.
set -euo pipefail

CELL_DIR="$1"; FNS="$2"; ID="$3"; KEY="$4"
E3="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E3/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/behavior"
mkdir -p "$OUT"
CXX=/usr/bin/clang++-20

if [ "$KEY" = "checksig" ]; then
  CSRC="$E3/c_checksig.cpp"; LSRC="$E3/l_checksig.cpp"; DEFS="-DBEHAVIOR_CHECKER"
  REN=(-Dcell_checksig=c_cell_checksig -Dcell_checksigverify=c_cell_checksigverify
       -Dcell_checksig_underflow=c_cell_checksig_underflow)
  LREN=(-Dcell_checksig=l_cell_checksig -Dcell_checksigverify=l_cell_checksigverify
        -Dcell_checksig_underflow=l_cell_checksig_underflow)
else
  CSRC="$E3/c_cms.cpp"; LSRC="$E3/l_cms.cpp"; DEFS=""
  REN=(-Dcell_cms=c_cell_cms -Dcell_cmsverify=c_cell_cmsverify
       -Dcell_cms_nulldummy=c_cell_cms_nulldummy -Dcell_cms_empty=c_cell_cms_empty)
  LREN=(-Dcell_cms=l_cell_cms -Dcell_cmsverify=l_cell_cmsverify
        -Dcell_cms_nulldummy=l_cell_cms_nulldummy -Dcell_cms_empty=l_cell_cms_empty)
fi

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# behavioral only; not proof evidence"
  echo "# clang: $($CXX --version | head -1)"
  echo
} > "$RES"

OK=1
for CK in 0 1; do
  "$CXX" -std=c++17 -O0 -I "$E3" -I "$BUILD" $DEFS "${REN[@]}" \
    -c "$CSRC" -o "$BUILD/behavior_c_${CK}.o"
  "$CXX" -std=c++17 -O0 -I "$E3" -I "$BUILD" $DEFS "${LREN[@]}" \
    -c "$LSRC" -o "$BUILD/behavior_l_${CK}.o"
  "$CXX" -std=c++17 -O0 -I "$E3" -I "$BUILD" -DBTC_EQUIV_CHECKER_RESULT="$CK" \
    -c "$E3/checker_stub.cpp" -o "$BUILD/behavior_stub_${CK}.o"
  "$CXX" -std=c++17 -O0 $DEFS "$E3/behavior_runner.cpp" \
    "$BUILD/behavior_c_${CK}.o" "$BUILD/behavior_l_${CK}.o" \
    "$BUILD/behavior_stub_${CK}.o" -o "$BUILD/behavior_${CK}"
  python3 "$E3/oracle.py" "$KEY" "$BUILD/behavior_expect_${CK}.json" "$CK" >/dev/null

  OUTTXT="$(mktemp)"
  "$BUILD/behavior_${CK}" > "$OUTTXT"
  echo "===== checker_result=$CK =====" >> "$RES"
  cat "$OUTTXT" >> "$RES"
  python3 - "$OUTTXT" "$BUILD/behavior_expect_${CK}.json" "$CK" >> "$RES" <<'PY' || OK=0
import json, sys
rows = {}
for line in open(sys.argv[1]):
    fn, c, l = line.split()
    rows[fn] = (int(c, 16), int(l, 16))
exp = {s["fn"]: s["expected"] for s in json.load(open(sys.argv[2]))}
bad = 0
for fn, want in exp.items():
    c, l = rows[fn]
    ok = (c == want and l == want)
    print(f"{fn}: c=0x{c:x} l=0x{l:x} expected=0x{want:x} {'MATCH' if ok else 'MISMATCH'}")
    bad += 0 if ok else 1
sys.exit(1 if bad else 0)
PY
  echo >> "$RES"
  rm -f "$OUTTXT"
done

if [ "$OK" -eq 1 ]; then echo "STATUS=behavior-match" >> "$RES"; else echo "STATUS=behavior-mismatch" >> "$RES"; fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/behavior/run.sh"
  "$E3/e3_common.h" "$E3/checker_abi.h" "$E3/checker_stub.cpp"
  "$E3/oracle.py" "$E3/behavior_runner.cpp"
  "$E3/c_checksig.cpp" "$E3/l_checksig.cpp" "$E3/c_cms.cpp" "$E3/l_cms.cpp"
  "$BUILD/twin_ops.h" "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" 2>/dev/null || true ;;
      *) echo "# outside-root $(sha256sum "$f" 2>/dev/null || echo missing)" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
