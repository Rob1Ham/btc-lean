#!/usr/bin/env bash
# SAW attempt for the E4 witness-v0 dispatch cell.  Both the C slice and the
# reviewed Lean transliteration are verified against the SAME Cryptol function,
# which encodes the declared (result, error) postcondition.
set -euo pipefail
CELL_DIR="$1"
E4="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E4/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$E4/build_leaf.sh" "$CELL_DIR"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where
// packed = result(2 bits) | error_ordinal(6 bits) << 2
//   (0,38)=152  WITNESS_PROGRAM_WRONG_LENGTH
//   (0,39)=156  WITNESS_PROGRAM_WITNESS_EMPTY
//   (0,40)=160  WITNESS_PROGRAM_MISMATCH
//   (1,0) =1    success (hash/script execution abstracted true)
v0_dispatch : [64] -> [64] -> [64]
v0_dispatch plen wn =
  if plen == 32 then
    if wn == 0 then 156 else 1
  else if plen == 20 then
    if wn != 2 then 160 else 1
  else 152
EOF
cat > "$BUILD/cell.saw" <<'EOF'
import "cell.cry";
mC <- llvm_load_module "c_cell_v0_dispatch.bc";
mL <- llvm_load_module "l_cell_v0_dispatch.bc";
let spec = do {
  plen <- llvm_fresh_var "plen" (llvm_int 64);
  wn <- llvm_fresh_var "wn" (llvm_int 64);
  llvm_execute_func [llvm_term plen, llvm_term wn];
  llvm_return (llvm_term {{ v0_dispatch plen wn }});
};
llvm_verify mC "cell_v0_dispatch" [] false spec abc;
llvm_verify mL "cell_v0_dispatch" [] false spec abc;
print "CELL_e4_witness_v0_dispatch_SAW_GREEN";
EOF
RES="$OUT/result.txt"
{
  echo "# cell: e4-witness/C-L-witness-v0-dispatch"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# expected: (plen=32,wn=0)->156; (plen=20,wn!=2)->160; plen!={20,32}->152; else 1"
  echo "# abstraction: SHA256 match and ExecuteWitnessScript are inputs fixed to success"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge 2 ] \
   && grep -q 'CELL_e4_witness_v0_dispatch_SAW_GREEN' "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh"
  "$E4/e4_common.h" "$E4/c_cell.cpp" "$E4/l_cell.cpp"
  "$E4/build_leaf.sh" "$BUILD/cell.cry" "$BUILD/cell.saw"
  "$BUILD/c_cell_v0_dispatch.bc" "$BUILD/l_cell_v0_dispatch.bc" "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
