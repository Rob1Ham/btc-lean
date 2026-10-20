#!/usr/bin/env bash
# SAW attempt for one E3 cell.
#
# Two checker builds (return 0 and return 1), each linked into BOTH legs.
# For every closed scenario derived from the independent oracle, the same
# packed constant is verified against the C module and the L module.  The
# checker is a shared stub, not a crypto proof; see spec.md trust_note.
set -euo pipefail

CELL_DIR="$1"; FNS="$2"; ID="$3"; KEY="$4"
# Serialize runs for one cell (see run_alive2.sh).
if [ -z "${E3_CELL_LOCKED:-}" ]; then
  export E3_CELL_LOCKED=1
  exec flock "$CELL_DIR/.e3.lock" "$0" "$@"
fi
E3="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E3/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# command: (cd build && saw cell_<checker>.saw), checker returns 0 and 1"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# functions: $FNS"
  echo "# expected constants: cells/_tools/e3/cellsig/oracle.py (independent of C/L code)"
  echo
} > "$RES"

for CK in 0 1; do
  "$E3/build_cell.sh" "$CELL_DIR" saw "$KEY" "$ID" "$CK" >/dev/null

  python3 - "$BUILD/scenarios_${CK}.json" "$BUILD/cell_${CK}.saw" "$CK" <<'PY'
import json, sys
scen = json.load(open(sys.argv[1]))
ck = sys.argv[3]
out = open(sys.argv[2], "w")
out.write('mC <- llvm_load_module "c_leaf_saw_%s.bc";\n' % ck)
out.write('mL <- llvm_load_module "l_leaf_saw_%s.bc";\n' % ck)
for i, s in enumerate(scen):
    out.write('let s%d = do {\n  llvm_execute_func [];\n'
              '  llvm_return (llvm_term {{ 0x%016x }});\n};\n'
              % (i, s["expected"]))
    out.write('llvm_verify mC "%s" [] false s%d abc;\n' % (s["fn"], i))
    out.write('llvm_verify mL "%s" [] false s%d abc;\n' % (s["fn"], i))
out.write('print "E3_SAW_GREEN";\n')
out.close()
PY

  {
    echo "===== checker_result=$CK ($(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$BUILD/scenarios_${CK}.json") scenarios x 2 legs) ====="
    ( cd "$BUILD" && PATH=$SAWPATH saw "cell_${CK}.saw" ) || true
    echo
  } >> "$RES"
done

WANT=$(python3 -c "import json;print(2*(len(json.load(open('$BUILD/scenarios_0.json')))+len(json.load(open('$BUILD/scenarios_1.json')))))")
GOT=$(grep -cE "Proof succeeded! (cell_)" "$RES" || true)
if [ "$GOT" -ge "$WANT" ] && ! grep -q "Proof failed" "$RES"; then
  echo "STATUS=saw-green ($GOT/$WANT proofs)" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green ($GOT/$WANT proofs)" >> "$RES"
  OK=0
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh"
  "$CELLS/_tools/mk_leaf.py" "$E3/build_cell.sh" "$E3/e3_common.h"
  "$E3/checker_abi.h" "$E3/checker_stub.cpp" "$E3/oracle.py"
  "$E3/c_checksig.cpp" "$E3/l_checksig.cpp" "$E3/c_cms.cpp" "$E3/l_cms.cpp"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h"
  "$BUILD/c_leaf_saw_0.bc" "$BUILD/l_leaf_saw_0.bc"
  "$BUILD/c_leaf_saw_1.bc" "$BUILD/l_leaf_saw_1.bc"
  "$BUILD/scenarios_0.json" "$BUILD/scenarios_1.json"
  "$BUILD/cell_0.saw" "$BUILD/cell_1.saw" "$RES"
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
