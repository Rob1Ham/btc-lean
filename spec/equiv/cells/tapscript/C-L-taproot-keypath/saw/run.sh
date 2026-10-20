#!/usr/bin/env bash
# SAW attempt for C-L-taproot-keypath.  A shared checker stub is linked into
# BOTH legs, pinned first to success (1) and then to a SCHNORR_SIG rejection
# (error ordinal 47, encoded 94 = 47<<1).  The Cryptol postcondition is
# derived from the Core branch table, not from either C++ leg.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$OUT"
"$CELL/build.sh"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where

// packed = result(2 bits) | error_ordinal(6 bits) << 2
// result 0=fail, 1=success, 2=script path (sibling cell)
// interpreter.cpp:1970-1975 / Defs.lean:1298 + schnorrOutcome 1190-1193

// checker success (encoded 1)
keypath_ok : [64] -> [64]
keypath_ok n = if n == 1 then 1 else 2

// checker rejection with SCRIPT_ERR_SCHNORR_SIG = 47 (encoded 94 = 47<<1)
keypath_fail : [64] -> [64]
keypath_fail n = if n == 1 then 188 else 2   // (0,47): 47*4 = 188
EOF
for CK in 1 94; do
  if [ "$CK" -eq 1 ]; then SPEC=keypath_ok; else SPEC=keypath_fail; fi
  cat > "$BUILD/cell_${CK}.saw" <<EOF
import "cell.cry";
mC <- llvm_load_module "c_leaf_saw_${CK}.bc";
mL <- llvm_load_module "l_leaf_saw_${CK}.bc";
let spec = do {
  n <- llvm_fresh_var "n" (llvm_int 64);
  llvm_execute_func [llvm_term n, llvm_term {{ 7 : [32] }},
                     llvm_term {{ 9 : [32] }}];
  llvm_return (llvm_term {{ ${SPEC} n }});
};
llvm_verify mC "cell_keypath" [] false spec abc;
llvm_verify mL "cell_keypath" [] false spec abc;
print "CELL_tapscript_keypath_${CK}_SAW_GREEN";
EOF
done
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-keypath"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd build && saw cell_1.saw; saw cell_94.saw)"
  echo "# checker stub linked into both legs: 1=success, 94=(ok=0,err=47)"
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell_1.saw ) || true
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell_94.saw ) || true
} > "$RES" 2>&1
WANT=4
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge "$WANT" ] \
   && grep -q 'CELL_tapscript_keypath_1_SAW_GREEN' "$RES" \
   && grep -q 'CELL_tapscript_keypath_94_SAW_GREEN' "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green ($GOT/$WANT proofs)" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green ($GOT/$WANT proofs)" >> "$RES"; OK=0
fi

FILES=("$CELL/spec.md" "$CELL/notes.md" "$CELL/build.sh"
       "$CELL/cell_common.h" "$CELL/checker_abi.h" "$CELL/checker_stub.cpp"
       "$CELL/c_leg.cpp" "$CELL/l_leg.cpp" "$CELL/saw/run.sh"
       "$BUILD/cell.cry" "$BUILD/cell_1.saw" "$BUILD/cell_94.saw"
       "$BUILD/c_leaf_saw_1.bc" "$BUILD/l_leaf_saw_1.bc"
       "$BUILD/c_leaf_saw_94.bc" "$BUILD/l_leaf_saw_94.bc" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
