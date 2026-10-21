#!/usr/bin/env bash
# SAW side of the SCR-142 pin-vs-model probe (finding-scoped).
#
# Proves the two fixed-height pinned wrappers (v1 = 709631, v2 = 709632)
# against ONE height-free pinned predicate.  The predicate does not mention
# height at all; SAW verifying both leaves against it is the machine-checked
# statement that the pinned TAPROOT bit and the gate observable are
# height-inert across the 709631/709632 boundary.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$DIR/../../../../../.." && pwd)"
BUILD="$DIR/build"; HERE="$DIR/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$HERE"
"$DIR/build.sh"
cat > "$HERE/pin.cry" <<'EOF'
module Spec where

// Height-free pinned predicate (cce32b168 validation.cpp:2249-2288 TAPROOT
// bit + interpreter.cpp:1957-1969 gate).  No height argument: both fixed
// wrappers (709631 and 709632) must satisfy this same predicate.
//
// Packed = result(2) | error_ordinal(6) << 2 | taproot_on(1) << 8.
// taproot_on = 0 iff the block hash is one of the two mainnet
// script_flag_exceptions entries; no height term exists at the pin.
pin : [64] -> [64] -> [64] -> [64] -> [64] -> [64] -> [64] -> [64] -> [64]
pin h0 h1 h2 h3 version plen p2sh wn =
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
cat > "$HERE/pin.saw" <<'EOF'
import "pin.cry";
m1 <- llvm_load_module "../build/v1.bc";
m2 <- llvm_load_module "../build/v2.bc";
let spec = do {
  h0 <- llvm_fresh_var "h0" (llvm_int 64);
  h1 <- llvm_fresh_var "h1" (llvm_int 64);
  h2 <- llvm_fresh_var "h2" (llvm_int 64);
  h3 <- llvm_fresh_var "h3" (llvm_int 64);
  version <- llvm_fresh_var "version" (llvm_int 64);
  plen <- llvm_fresh_var "plen" (llvm_int 64);
  p2sh <- llvm_fresh_var "p2sh" (llvm_int 64);
  wn <- llvm_fresh_var "wn" (llvm_int 64);
  llvm_execute_func [llvm_term h0, llvm_term h1, llvm_term h2, llvm_term h3,
                     llvm_term version, llvm_term plen, llvm_term p2sh,
                     llvm_term wn];
  llvm_return (llvm_term {{ pin h0 h1 h2 h3 version plen p2sh wn }});
};
llvm_verify m1 "cell_compare" [] false spec abc;
llvm_verify m2 "cell_compare" [] false spec abc;
print "CELL_w65_pin_height_inert_SAW_GREEN";
EOF
RES="$HERE/result.txt"
{
  echo "# probe: findings/wave65/18-scr-142/compare (pinned height-inertness)"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd saw && saw pin.saw)"
  echo "# spec: saw/pin.cry (height-free pinned predicate)"
  echo "# solver: abc"
  echo
  ( cd "$HERE" && PATH=$SAWPATH saw pin.saw ) || true
} > "$RES" 2>&1
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge 2 ] \
   && grep -q 'CELL_w65_pin_height_inert_SAW_GREEN' "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green ($GOT/2 proofs)" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green ($GOT/2 proofs)" >> "$RES"; OK=0
fi
FILES=("$DIR/README.md" "$DIR/build.sh" "$DIR/compare_common.h"
       "$DIR/variants.cpp" "$DIR/alive2/run.sh" "$HERE/run.sh"
       "$HERE/pin.cry" "$HERE/pin.saw" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$HERE/certificate.sha256"
[ "$OK" -eq 1 ]
