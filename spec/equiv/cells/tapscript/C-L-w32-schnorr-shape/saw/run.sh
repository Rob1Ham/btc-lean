#!/usr/bin/env bash
# SAW lane for C-L-w32-schnorr-shape.
#
# Two tail builds (0 and 47) are linked into BOTH legs.  Each scenario is the
# same packed shape constant verified against the C module and the L module.
# Expected constants come from src/oracle.py, which is written from the SCR
# rows and the Core source, not from either leg.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$OUT"

RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-w32-schnorr-shape"
  echo "# command: (cd build && saw cell_<tail>.saw), tail returns 0 and 47"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# expected constants: src/oracle.py (independent of both legs)"
  echo
} > "$RES"

for TAIL in 0 47; do
  "$SRC/build.sh" saw "$TAIL" >/dev/null
  python3 "$SRC/oracle.py" "$TAIL" "$BUILD/scenarios_${TAIL}.json"
  python3 - "$BUILD/scenarios_${TAIL}.json" "$BUILD/cell_${TAIL}.saw" "$TAIL" <<'PY'
import json, sys
scen = json.load(open(sys.argv[1]))
out = open(sys.argv[2], "w")
tail = sys.argv[3]
out.write('mC <- llvm_load_module "c_shape_saw_%s.bc";\n' % tail)
out.write('mL <- llvm_load_module "l_shape_saw_%s.bc";\n' % tail)
TY = ["[64]", "[32]", "[32]"]
for i, s in enumerate(scen):
    args = ", ".join("llvm_term {{ %d : %s }}" % (a, t)
                     for a, t in zip(s["args"], TY))
    out.write('let s%d = do {\n  llvm_execute_func [%s];\n'
              '  llvm_return (llvm_term {{ 0x%016x : [64] }});\n};\n'
              % (i, args, s["expected"]))
    out.write('llvm_verify mC "%s" [] false s%d abc;\n' % (s["fn"], i))
    out.write('llvm_verify mL "%s" [] false s%d abc;\n' % (s["fn"], i))
out.write('print "TAPSCRIPT_SAW_GREEN";\n')
out.close()
PY
  {
    echo "===== tail_result=$TAIL ($(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$BUILD/scenarios_${TAIL}.json") scenarios x 2 legs) ====="
    ( cd "$BUILD" && PATH=$SAWPATH saw "cell_${TAIL}.saw" ) || true
    echo
  } >> "$RES"
done

WANT=$(python3 - "$BUILD" <<'PY'
import json, sys
b = sys.argv[1]
print(2 * (len(json.load(open(f"{b}/scenarios_0.json")))
           + len(json.load(open(f"{b}/scenarios_47.json")))))
PY
)
GOT=$(grep -cE "Proof succeeded! (cell_)" "$RES" || true)
if [ "$GOT" -ge "$WANT" ] && ! grep -q "Proof failed" "$RES"; then
  echo "STATUS=saw-green ($GOT/$WANT proofs)" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green ($GOT/$WANT proofs)" >> "$RES"
  OK=0
fi

FILES=("$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$SRC/build.sh"
       "$SRC/tap_common.h" "$SRC/c_tap.cpp" "$SRC/l_tap.cpp"
       "$SRC/tail_stub.cpp" "$SRC/oracle.py" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}"; done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
