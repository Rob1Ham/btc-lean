#!/usr/bin/env bash
# SAW attempt for C-L-taproot-annex.  The Cryptol predicate is the documented
# BIP341 annex rule, independent of either C++ leg.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
FNS=(cell_annex_detected cell_annex_remaining)
mkdir -p "$OUT"
"$CELL/build.sh"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where

// interpreter.cpp:1961 / Defs.lean:1287-1288
annex_detected : [64] -> [64] -> [64] -> [64]
annex_detected wn llen lfirst =
  if wn >= 2 /\ llen != 0 /\ (lfirst && 255) == 80 then 1 else 0

// interpreter.cpp:1965 SpanPopBack / Defs.lean:1289 dropLast
annex_remaining : [64] -> [64] -> [64] -> [64]
annex_remaining wn llen lfirst =
  if annex_detected wn llen lfirst == 1 then wn - 1 else wn
EOF
cat > "$BUILD/cell.saw" <<'EOF'
import "cell.cry";
mC <- llvm_load_module "c_leaf.bc";
mL <- llvm_load_module "l_leaf.bc";

let det_spec = do {
  wn <- llvm_fresh_var "awn" (llvm_int 64);
  llen <- llvm_fresh_var "allen" (llvm_int 64);
  lfirst <- llvm_fresh_var "alfirst" (llvm_int 64);
  llvm_execute_func [llvm_term wn, llvm_term llen, llvm_term lfirst];
  llvm_return (llvm_term {{ annex_detected wn llen lfirst }});
};
llvm_verify mC "cell_annex_detected" [] false det_spec abc;
llvm_verify mL "cell_annex_detected" [] false det_spec abc;

let rem_spec = do {
  wn <- llvm_fresh_var "rwn" (llvm_int 64);
  llen <- llvm_fresh_var "rlen" (llvm_int 64);
  lfirst <- llvm_fresh_var "rfirst" (llvm_int 64);
  llvm_execute_func [llvm_term wn, llvm_term llen, llvm_term lfirst];
  llvm_return (llvm_term {{ annex_remaining wn llen lfirst }});
};
llvm_verify mC "cell_annex_remaining" [] false rem_spec abc;
llvm_verify mL "cell_annex_remaining" [] false rem_spec abc;
print "CELL_tapscript_annex_SAW_GREEN";
EOF
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-annex"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# command: (cd build && saw cell.saw)"
  echo "# spec: build/cell.cry (independent detection + dropLast statement)"
  echo
  ( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) || true
} > "$RES" 2>&1
WANT=$(( ${#FNS[@]} * 2 ))
GOT=$(grep -c 'Proof succeeded!' "$RES" || true)
if [ "$GOT" -ge "$WANT" ] \
   && grep -q 'CELL_tapscript_annex_SAW_GREEN' "$RES" \
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
