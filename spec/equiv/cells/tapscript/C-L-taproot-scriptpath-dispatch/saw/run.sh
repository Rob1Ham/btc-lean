#!/usr/bin/env bash
# SAW attempt for C-L-taproot-scriptpath-dispatch.  The Cryptol module is an
# independent statement of the three dispatch postconditions, derived from the
# Core branch table; both legs are verified against it.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
FNS=(cell_control_size cell_leaf_version cell_tail)
mkdir -p "$OUT"
"$CELL/build.sh"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where

// packed = result(2 bits) | error_ordinal(6 bits) << 2
// 0=fail, 1=success, 2=tapscript arm, 3=delegated to another arm

// interpreter.cpp:1980-1982 / Program.lean:495-499
control_size : [64] -> [64]
control_size s =
  if s < 33 \/ s > 4129 \/ ((s - 33) % 32) != 0 then 192 else 1
  // 192 = (0,48) SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE

// interpreter.cpp:1988-1998 / LeafVersion.lean:36-70
leaf_version : [64] -> [64] -> [64]
leaf_version c d =
  if (c && 254) == 192 then 2
  else if d != 0 then 140        // (0,35) DISCOURAGE_UPGRADABLE_TAPROOT_VERSION
  else 1

// interpreter.cpp:2000-2008, script.cpp:216-222 / Defs.lean:523-525,1319-1321
tail_dispatch : [64] -> [64] -> [64] -> [64] -> [64] -> [64] -> [64]
tail_dispatch v plen p0 p1 p2sh dw =
  if v > 16 \/ v == 0 then 3
  else if v == 1 /\ plen == 32 /\ p2sh == 0 then 3
  else if p2sh == 0 /\ v == 1 /\ plen == 2 /\
          (p0 && 255) == 78 /\ (p1 && 255) == 115 then 1
  else if dw != 0 then 136       // (0,34) DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
  else 1
EOF
cat > "$BUILD/cell.saw" <<'EOF'
import "cell.cry";
mC <- llvm_load_module "c_leaf.bc";
mL <- llvm_load_module "l_leaf.bc";

let ctl_spec = do {
  s <- llvm_fresh_var "s" (llvm_int 64);
  llvm_execute_func [llvm_term s];
  llvm_return (llvm_term {{ control_size s }});
};
llvm_verify mC "cell_control_size" [] false ctl_spec abc;
llvm_verify mL "cell_control_size" [] false ctl_spec abc;

let leaf_spec = do {
  c <- llvm_fresh_var "c" (llvm_int 64);
  d <- llvm_fresh_var "d" (llvm_int 64);
  llvm_execute_func [llvm_term c, llvm_term d];
  llvm_return (llvm_term {{ leaf_version c d }});
};
llvm_verify mC "cell_leaf_version" [] false leaf_spec abc;
llvm_verify mL "cell_leaf_version" [] false leaf_spec abc;

let tail_spec = do {
  v <- llvm_fresh_var "v" (llvm_int 64);
  plen <- llvm_fresh_var "plen" (llvm_int 64);
  p0 <- llvm_fresh_var "p0" (llvm_int 64);
  p1 <- llvm_fresh_var "p1" (llvm_int 64);
  p2sh <- llvm_fresh_var "p2sh" (llvm_int 64);
  dw <- llvm_fresh_var "dw" (llvm_int 64);
  llvm_execute_func [llvm_term v, llvm_term plen, llvm_term p0,
                     llvm_term p1, llvm_term p2sh, llvm_term dw];
  llvm_return (llvm_term {{ tail_dispatch v plen p0 p1 p2sh dw }});
};
llvm_verify mC "cell_tail" [] false tail_spec abc;
llvm_verify mL "cell_tail" [] false tail_spec abc;

print "CELL_tapscript_scriptpath_dispatch_SAW_GREEN";
EOF
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-scriptpath-dispatch"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd build && saw cell.saw)"
  echo "# spec: build/cell.cry (independent packed postcondition)"
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) || true
} > "$RES" 2>&1
WANT=$(( ${#FNS[@]} * 2 ))
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge "$WANT" ] \
   && grep -q 'CELL_tapscript_scriptpath_dispatch_SAW_GREEN' "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green ($GOT/$WANT proofs)" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green ($GOT/$WANT proofs)" >> "$RES"; OK=0
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
