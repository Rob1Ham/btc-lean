#!/usr/bin/env bash
# SAW attempt for the SCR-142 historical-window MODEL (finding-scoped).
#
# saw/cell.cry states the model's packed postcondition independently of
# either leg: the TPR-078 height abstraction (709632 <= height) composed with
# the interpreter.cpp:1957-1969 branch table.  SAW proves each leg against it
# for every hash/height/shape tuple.  MODEL ONLY: not a cce32b168 claim.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../../.." && pwd)"
BUILD="$CELL/build"; HERE="$CELL/saw"
FN=cell_model_taproot
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$HERE"
"$CELL/build.sh"
cat > "$HERE/cell.cry" <<'EOF'
module Spec where

// MODEL of the historical taproot BIP9 height abstraction (TPR-075/076/078).
// NOT cce32b168: the pin has no height term on the TAPROOT bit.
//
// Packed = result(2) | error_ordinal(6) << 2 | taproot_on(1) << 8.
//
// taproot_on = 0 for the two hash-keyed exception blocks (any height),
//              = (709632 <= height) otherwise        (TPR-078).
// Branch table from interpreter.cpp:1957-1969:
//   v1, 32-byte program, non-P2SH, TAPROOT off -> (1, 0) silent success
//   ... TAPROOT on, empty witness               -> (0, 39)
//   ... TAPROOT on, non-empty witness           -> (2, 0) continue
//   any other shape                             -> (3, 0) outside arm
model : [64] -> [64] -> [64] -> [64] -> [32] -> [64] -> [64] -> [64] -> [64] -> [64]
model h0 h1 h2 h3 height version plen p2sh wn =
  gate || taproot_bit
  where
    exc_bip16 = (h0 == (0x00000000000002dc : [64])) &&
                (h1 == (0x756eebf4f49723ed : [64])) &&
                (h2 == (0x8d30cc28a5f108eb : [64])) &&
                (h3 == (0x94b1ba88ac4f9c22 : [64]))
    exc_taproot = (h0 == (0x0000000000000000 : [64])) &&
                  (h1 == (0x000f14c35b2d841e : [64])) &&
                  (h2 == (0x986ab5441de8c585 : [64])) &&
                  (h3 == (0xd5ffe55ea1e395ad : [64]))
    taproot_off = exc_bip16 || exc_taproot || (height < (709632 : [32]))
    taproot_bit : [64]
    taproot_bit = if taproot_off then (0 : [64]) else (0x0000000000000100 : [64])
    gate : [64]
    gate = if version == 1 /\ plen == 32 /\ p2sh == 0 then
             (if taproot_off then (1 : [64])
              else if wn == 0 then (156 : [64])
              else (2 : [64]))
           else (3 : [64])
EOF
cat > "$HERE/cell.saw" <<'EOF'
import "cell.cry";
mC <- llvm_load_module "../build/c_leaf.bc";
mL <- llvm_load_module "../build/l_leaf.bc";
let spec = do {
  h0 <- llvm_fresh_var "h0" (llvm_int 64);
  h1 <- llvm_fresh_var "h1" (llvm_int 64);
  h2 <- llvm_fresh_var "h2" (llvm_int 64);
  h3 <- llvm_fresh_var "h3" (llvm_int 64);
  height <- llvm_fresh_var "height" (llvm_int 32);
  version <- llvm_fresh_var "version" (llvm_int 64);
  plen <- llvm_fresh_var "plen" (llvm_int 64);
  p2sh <- llvm_fresh_var "p2sh" (llvm_int 64);
  wn <- llvm_fresh_var "wn" (llvm_int 64);
  llvm_execute_func [llvm_term h0, llvm_term h1, llvm_term h2, llvm_term h3,
                     llvm_term height, llvm_term version, llvm_term plen,
                     llvm_term p2sh, llvm_term wn];
  llvm_return (llvm_term {{ model h0 h1 h2 h3 height version plen p2sh wn }});
};
llvm_verify mC "cell_model_taproot" [] false spec abc;
llvm_verify mL "cell_model_taproot" [] false spec abc;
print "CELL_w65_taproot_bip9_model_SAW_GREEN";
EOF
RES="$HERE/result.txt"
{
  echo "# cell: findings/wave65/18-scr-142/model-cell (MODEL, not a ledger cell)"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd saw && saw cell.saw)"
  echo "# spec: saw/cell.cry (TPR-078 height abstraction, not cce32b168)"
  echo "# solver: abc"
  echo
  ( cd "$HERE" && PATH=$SAWPATH saw cell.saw ) || true
} > "$RES" 2>&1
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge 2 ] \
   && grep -q 'CELL_w65_taproot_bip9_model_SAW_GREEN' "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green ($GOT/2 proofs, model-only)" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green ($GOT/2 proofs)" >> "$RES"; OK=0
fi
FILES=("$CELL/spec.md" "$CELL/notes.md"
       "$CELL/build.sh" "$CELL/cell_common.h"
       "$CELL/c_leg.cpp" "$CELL/l_leg.cpp"
       "$CELL/alive2/run.sh" "$HERE/run.sh" "$HERE/cell.cry" "$HERE/cell.saw"
       "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$HERE/certificate.sha256"
[ "$OK" -eq 1 ]
