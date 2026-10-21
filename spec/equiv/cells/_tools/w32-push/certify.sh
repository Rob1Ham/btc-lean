#!/usr/bin/env bash
# Write a cell certificate from the repository root.
# Usage: certify.sh CELL_DIR OUT_FILE RESULT_FILE [EXTRA_FILE...]
# Every hashed path is relative to the worktree root, so verification is
#   cd <worktree-root> && sha256sum -c <cell>/<leg>/certificate.sha256
set -euo pipefail
CELL_DIR="$1"; OUT="$2"; RES="$3"; shift 3
W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"

FILES=(
  "$CELL_DIR/spec.md"
  "$CELL_DIR/notes.md"
  "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/saw/run.sh"
  "$W32/w32_common.h" "$W32/build.sh" "$W32/run_alive2.sh"
  "$W32/run_saw.sh" "$W32/certify.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/twin/runtime.inc"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin.cpp" "$BUILD/build.txt"
  "$RES"
)
if [ -f "$BUILD/twin_ops.h" ]; then FILES+=("$BUILD/twin_ops.h"); fi
if [ -f "$BUILD/twin_ops.meta.json" ]; then FILES+=("$BUILD/twin_ops.meta.json"); fi
for extra in "$@"; do FILES+=("$extra"); done
while IFS= read -r f; do FILES+=("$f"); done < <(find "$CELL_DIR/src" -maxdepth 1 -type f | sort)

{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT"
