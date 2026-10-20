#!/usr/bin/env bash
# SAW attempt for one wave-32 CHECKMULTISIG cell.
#
#   run_saw.sh <cell_dir> <fns_csv> <cell_id> <c_src> <l_src> <oracle.py> [checkers]
#
# The oracle script emits scenario JSON ({"fn","args","expected"}) from an
# independent Python model; the same packed constant is verified against the
# C module and the L module in one build.  `checkers` is a comma list of
# concrete checker returns (0,1) for cells that call the shared checker stub,
# or empty for pure cells.
set -euo pipefail

CELL_DIR="$1"; FNS="$2"; ID="$3"; C_SRC="$4"; L_SRC="$5"; ORACLE="$6"
CHECKERS="${7:-}"
if [ -z "${E32_CELL_LOCKED:-}" ]; then
  export E32_CELL_LOCKED=1
  exec flock "$CELL_DIR/.w32.lock" "$0" "$@"
fi
E3="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E3/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# command: (cd build && saw cell_<lane>.saw)"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# functions: $FNS"
  echo "# oracle: cells/_tools/w32cms/$ORACLE (independent of the C/L code)"
  echo
} > "$RES"

TOTAL=0; OKRUN=1
IFS=',' read -r -a CKS <<< "$CHECKERS"
[ -z "$CHECKERS" ] && CKS=("")
for CK in "${CKS[@]}"; do
  "$E3/build_cell.sh" "$CELL_DIR" saw "$C_SRC" "$L_SRC" "$ID" "$CK" >/dev/null
  python3 "$E3/$ORACLE" "$BUILD/scenarios_${CK:-none}.json" "$CK" >/dev/null

  python3 - "$BUILD/scenarios_${CK:-none}.json" "$BUILD/cell_${CK:-none}.saw" \
      "${CK:-none}" <<'PY'
import json, sys
scen = json.load(open(sys.argv[1]))
lane = sys.argv[3]
out = open(sys.argv[2], "w")
suffix = "_saw" if lane == "none" else "_saw_" + lane
out.write('mC <- llvm_load_module "c_leaf%s.bc";\n' % suffix)
out.write('mL <- llvm_load_module "l_leaf%s.bc";\n' % suffix)
for i, s in enumerate(scen):
    args = ", ".join("llvm_term {{ (0x%016x : [64]) }}" % a for a in s["args"])
    out.write('let s%d = do {\n  llvm_execute_func [%s];\n'
              '  llvm_return (llvm_term {{ (0x%016x : [64]) }});\n};\n'
              % (i, args, s["expected"]))
    out.write('print "CASE %d";\n' % i)
    out.write('llvm_verify mC "%s" [] false s%d abc;\n' % (s["fn"], i))
    out.write('llvm_verify mL "%s" [] false s%d abc;\n' % (s["fn"], i))
out.write('print "E32_SAW_GREEN";\n')
out.close()
PY

  {
    echo "===== lane=${CK:-none} ($(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$BUILD/scenarios_${CK:-none}.json") scenarios x 2 legs) ====="
    ( cd "$BUILD" && PATH=$SAWPATH saw "cell_${CK:-none}.saw" ) || true
    echo
  } >> "$RES"
  N=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$BUILD/scenarios_${CK:-none}.json")
  TOTAL=$((TOTAL + 2 * N))
done

GOT=$(grep -cE "Proof succeeded! (cell_)" "$RES" || true)
if [ "$GOT" -ge "$TOTAL" ] && ! grep -q "Proof failed" "$RES"; then
  echo "STATUS=saw-green ($GOT/$TOTAL proofs)" >> "$RES"
  OKRUN=1
else
  echo "STATUS=saw-not-green ($GOT/$TOTAL proofs)" >> "$RES"
  OKRUN=0
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh"
  "$CELLS/_tools/mk_leaf.py" "$E3/build_cell.sh" "$E3/e32_common.h"
  "$E3/$C_SRC" "$E3/$L_SRC" "$E3/$ORACLE"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$RES"
)
if [ -n "$CHECKERS" ]; then
  FILES+=("$E3/checker_stub.cpp")
  for CK in "${CKS[@]}"; do
    FILES+=("$BUILD/c_leaf_saw_${CK}.bc" "$BUILD/l_leaf_saw_${CK}.bc"
            "$BUILD/scenarios_${CK}.json" "$BUILD/cell_${CK}.saw")
  done
else
  FILES+=("$BUILD/c_leaf_saw.bc" "$BUILD/l_leaf_saw.bc"
          "$BUILD/scenarios_none.json" "$BUILD/cell_none.saw")
fi
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" 2>/dev/null || true ;;
      *) echo "# outside-root $(sha256sum "$f" 2>/dev/null || echo missing)" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$OKRUN" -eq 1 ]
