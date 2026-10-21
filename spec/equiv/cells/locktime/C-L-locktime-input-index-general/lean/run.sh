#!/usr/bin/env bash
# Lean leg for locktime/C-L-locktime-input-index-general: machine-check the
# arbitrary-list induction (the general-vin closure) against the pinned model
# at 4d62a97e (PINS.lock [lean] model_rev).  Prints the #print axioms lines;
# no `sorryAx` is permitted.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
SPEC="$ROOT/spec"
OUT="$CELL_DIR/lean"
LEANFILE="$CELL_DIR/src/GeneralIndex.lean"
RES="$OUT/result.txt"
mkdir -p "$OUT"
{
  echo "# cell: locktime/C-L-locktime-input-index-general"
  echo "# lean: $(cd "$SPEC/core" && lake env lean --version 2>&1 | head -1)"
  echo "# toolchain: $(cat "$SPEC/lean-toolchain")"
  echo "# model: $(cd "$ROOT" && git rev-parse 4d62a97e 2>/dev/null || true)"
  echo "# source: src/GeneralIndex.lean sha256 $(sha256sum "$LEANFILE" | cut -d' ' -f1)"
  echo "# command: (cd spec/core && lake build Bitcoin.Interpreter.Rules && lake env lean <abs>/src/GeneralIndex.lean)"
  echo
  ( cd "$SPEC/core" && lake build Bitcoin.Interpreter.Rules >/dev/null && lake env lean "$LEANFILE" )
} > "$RES" 2>&1
if grep -q "sorryAx" "$RES"; then
  echo "STATUS=lean-not-green" >> "$RES"
  STATUS=1
else
  echo "STATUS=lean-green" >> "$RES"
  STATUS=0
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/lean/run.sh"
  "$LEANFILE" "$CELL_DIR/src/lean_excerpt.md"
  "$RES"
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
exit "$STATUS"
