#!/usr/bin/env bash
# SAW attempt for C-L-tapscript-isopsuccess.  The Cryptol predicate is written
# from the documented BIP342 byte set in the ledger row, not from the C++ legs.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$OUT"
"$CELL/build.sh"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where

// SCR-152 set: {80, 98, 126-129, 131-134, 137-138, 141-142, 149-153,
//               187-254}
isop : [64] -> [64]
isop w =
  if w == 80 \/ w == 98 \/ (w >= 126 /\ w <= 129) \/
     (w >= 131 /\ w <= 134) \/ (w >= 137 /\ w <= 138) \/
     (w >= 141 /\ w <= 142) \/ (w >= 149 /\ w <= 153) \/
     (w >= 187 /\ w <= 254)
  then 1 else 0
EOF
cat > "$BUILD/cell.saw" <<'EOF'
import "cell.cry";
mC <- llvm_load_module "c_leaf.bc";
mL <- llvm_load_module "l_leaf.bc";
let spec = do {
  w <- llvm_fresh_var "w" (llvm_int 64);
  llvm_execute_func [llvm_term w];
  llvm_return (llvm_term {{ isop w }});
};
llvm_verify mC "cell_is_op_success" [] false spec abc;
llvm_verify mL "cell_is_op_success" [] false spec abc;
print "CELL_tapscript_isopsuccess_SAW_GREEN";
EOF
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-tapscript-isopsuccess"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd build && saw cell.saw)"
  echo "# spec: build/cell.cry (independent byte-set membership test)"
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) || true
} > "$RES" 2>&1
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge 2 ] \
   && grep -q 'CELL_tapscript_isopsuccess_SAW_GREEN' "$RES" \
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
