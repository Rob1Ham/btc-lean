#!/usr/bin/env bash
# SAW attempt for C-L-taproot-gate.  The Cryptol module states the packed
# postcondition independently of either C++ leg.
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
// result 0=fail, 1=success, 2=continued, 3=outside arm
// interpreter.cpp:1957-1969 / Defs.lean:1280-1284
gate : [64] -> [64] -> [64] -> [64] -> [64] -> [64]
gate v plen p2sh taproot_flag wn =
  if v == 1 /\ plen == 32 /\ p2sh == 0 then
    if taproot_flag == 0 then 1
    else if wn == 0 then 156      // (0,39): 39*4 = 156
    else 2
  else 3
EOF
cat > "$BUILD/cell.saw" <<'EOF'
import "cell.cry";
mC <- llvm_load_module "c_leaf.bc";
mL <- llvm_load_module "l_leaf.bc";
let spec = do {
  v <- llvm_fresh_var "v" (llvm_int 64);
  plen <- llvm_fresh_var "plen" (llvm_int 64);
  p2sh <- llvm_fresh_var "p2sh" (llvm_int 64);
  tf <- llvm_fresh_var "tf" (llvm_int 64);
  wn <- llvm_fresh_var "wn" (llvm_int 64);
  llvm_execute_func [llvm_term v, llvm_term plen, llvm_term p2sh,
                     llvm_term tf, llvm_term wn];
  llvm_return (llvm_term {{ gate v plen p2sh tf wn }});
};
llvm_verify mC "cell_taproot_gate" [] false spec abc;
llvm_verify mL "cell_taproot_gate" [] false spec abc;
print "CELL_tapscript_gate_SAW_GREEN";
EOF
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-gate"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd build && saw cell.saw)"
  echo "# spec: build/cell.cry (independent packed postcondition)"
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) || true
} > "$RES" 2>&1
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge 2 ] \
   && grep -q 'CELL_tapscript_gate_SAW_GREEN' "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green ($GOT/2 proofs)" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green ($GOT/2 proofs)" >> "$RES"; OK=0
fi
FILES=("$CELL/spec.md" "$CELL/notes.md" "$CELL/build.sh"
       "$CELL/cell_common.h" "$CELL/c_leg.cpp" "$CELL/l_leg.cpp"
       "$CELL/saw/run.sh" "$BUILD/cell.cry" "$BUILD/cell.saw"
       "$BUILD/c_leaf.bc" "$BUILD/l_leaf.bc" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
