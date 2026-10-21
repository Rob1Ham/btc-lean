#!/usr/bin/env bash
# SAW lane for C-L-w32-checksigadd.
#
# Two checker builds (0 and 1) are linked into BOTH legs.  Each scenario is
# the same packed constant verified against the C module and the L module.
# Expected constants come from src/oracle.py, an independent Python model.
# The checker is a shared stub: no crypto is proved.
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
  echo "# cell: tapscript/C-L-w32-checksigadd"
  echo "# command: (cd build && saw cell_<checker>.saw), checker returns 0 and 1"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# expected constants: src/oracle.py (independent of both legs)"
  echo
} > "$RES"

for CK in 0 1; do
  "$SRC/build.sh" saw "$CK" >/dev/null
  python3 "$SRC/oracle.py" dispatch "$CK" "$BUILD/scenarios_dispatch_${CK}.json"
  python3 "$SRC/oracle.py" num "$CK" "$BUILD/scenarios_num_${CK}.json"
  python3 - "$BUILD/scenarios_dispatch_${CK}.json" \
            "$BUILD/scenarios_num_${CK}.json" \
            "$BUILD/cell_${CK}.saw" "$CK" <<'PY'
import json, sys
disp = json.load(open(sys.argv[1]))
num = json.load(open(sys.argv[2]))
out = open(sys.argv[3], "w")
ck = sys.argv[4]
out.write('mC <- llvm_load_module "c_leaf_saw_%s.bc";\n' % ck)
out.write('mL <- llvm_load_module "l_leaf_saw_%s.bc";\n' % ck)
TYPES = {"cell_add_dispatch": ["[32]", "[32]"],
         "cell_add_num": ["[64]", "[64]", "[64]", "[32]", "[32]", "[32]", "[32]"]}
i = 0
for s in disp + num:
    ty = TYPES[s["fn"]]
    args = ", ".join("llvm_term {{ %d : %s }}" % (a, t)
                     for a, t in zip(s["args"], ty))
    out.write('let s%d = do {\n  llvm_execute_func [%s];\n'
              '  llvm_return (llvm_term {{ 0x%016x : [64] }});\n};\n'
              % (i, args, s["expected"]))
    out.write('llvm_verify mC "%s" [] false s%d abc;\n' % (s["fn"], i))
    out.write('llvm_verify mL "%s" [] false s%d abc;\n' % (s["fn"], i))
    i += 1
out.write('print "TAPSCRIPT_SAW_GREEN";\n')
out.close()
PY
  {
    echo "===== checker_result=$CK (dispatch $(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$BUILD/scenarios_dispatch_${CK}.json") + num $(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$BUILD/scenarios_num_${CK}.json") scenarios x 2 legs) ====="
    ( cd "$BUILD" && PATH=$SAWPATH saw "cell_${CK}.saw" ) || true
    echo
  } >> "$RES"
done

WANT=$(python3 - "$BUILD" <<'PY'
import json, sys
b = sys.argv[1]
n = 0
for ck in (0, 1):
    n += len(json.load(open(f"{b}/scenarios_dispatch_{ck}.json")))
    n += len(json.load(open(f"{b}/scenarios_num_{ck}.json")))
print(2 * n)
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
       "$SRC/checker_stub.cpp" "$SRC/oracle.py" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}"; done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
