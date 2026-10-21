#!/usr/bin/env bash
# SAW attempt for C-L-taproot-activation-gate.
#
# build/cell.cry states the packed postcondition independently of either C++
# leg: it is the composition of the pinned GetBlockScriptFlags TAPROOT bit and
# the interpreter.cpp:1957-1969 branch table, written from the source.  SAW
# proves each leg against it for every hash/height/shape tuple.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/saw"
FN=cell_taproot_activation
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$OUT"
"$CELL/build.sh"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where

// Packed = result(2) | error_ordinal(6) << 2 | taproot_on(1) << 8.
//
// taproot_on is the SCRIPT_VERIFY_TAPROOT bit of GetBlockScriptFlags
// (validation.cpp:2249-2288).  At the pin the base set is
// P2SH|WITNESS|TAPROOT for every height; only the two hash-keyed
// script_flag_exceptions entries replace it, and both replacements clear
// TAPROOT.  The buried ORs never touch TAPROOT, so height is inert here.
//
// Branch table from interpreter.cpp:1957-1969 (Defs.lean:1280-1285):
//   v1, 32-byte program, non-P2SH, TAPROOT off      -> (1, 0)
//   ... TAPROOT on, empty witness                   -> (0, 39)
//   ... TAPROOT on, non-empty witness               -> (2, 0) continue
//   any other shape                                 -> (3, 0) outside arm
activation : [64] -> [64] -> [64] -> [64] -> [32] -> [64] -> [64] -> [64] -> [64] -> [64]
activation h0 h1 h2 h3 height version plen p2sh wn =
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
    taproot_off = exc_bip16 || exc_taproot
    taproot_bit : [64]
    taproot_bit = if taproot_off then (0 : [64]) else (0x0000000000000100 : [64])
    gate : [64]
    gate = if version == 1 /\ plen == 32 /\ p2sh == 0 then
             (if taproot_off then (1 : [64])
              else if wn == 0 then (156 : [64])
              else (2 : [64]))
           else (3 : [64])
EOF
cat > "$BUILD/cell.saw" <<'EOF'
import "cell.cry";
mC <- llvm_load_module "c_leaf.bc";
mL <- llvm_load_module "l_leaf.bc";
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
  llvm_return (llvm_term {{ activation h0 h1 h2 h3 height version plen p2sh wn }});
};
llvm_verify mC "cell_taproot_activation" [] false spec abc;
llvm_verify mL "cell_taproot_activation" [] false spec abc;
print "CELL_taproot_activation_SAW_GREEN";
EOF
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-activation-gate"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd build && saw cell.saw)"
  echo "# spec: build/cell.cry (independent packed postcondition)"
  echo "# solver: abc"
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) || true
} > "$RES" 2>&1
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge 2 ] \
   && grep -q 'CELL_taproot_activation_SAW_GREEN' "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green ($GOT/2 proofs)" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green ($GOT/2 proofs)" >> "$RES"; OK=0
fi
FILES=("$CELL/spec.md" "$CELL/notes.md" "$CELL/GAP-CONTEXT.md"
       "$CELL/build.sh" "$CELL/cell_common.h"
       "$CELL/c_leg.cpp" "$CELL/l_leg.cpp"
       "$CELL/saw/run.sh" "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
