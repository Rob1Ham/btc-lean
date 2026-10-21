#!/usr/bin/env bash
# Build/run the C side against the ACTUAL pinned Bitcoin Core header.
# Usage: CORE_SRC=/path/to/bitcoin tools/run_c.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CORE_SRC="${CORE_SRC:-/tmp/opencode/equiv-work/bitcoin}"
PIN="cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
OUT="$ROOT/results"
mkdir -p "$OUT"

if [[ ! -f "$CORE_SRC/src/pubkey.h" ]]; then
  echo "missing $CORE_SRC/src/pubkey.h (set CORE_SRC)" >&2
  exit 2
fi
HEAD="$(git -C "$CORE_SRC" rev-parse HEAD)"
printf 'core_src=%s\ncore_head=%s\nexpected_pin=%s\n' "$CORE_SRC" "$HEAD" "$PIN" > "$OUT/c_commit.txt"
if [[ "$HEAD" != "$PIN" ]]; then
  echo "WARNING: Core HEAD $HEAD != expected pin $PIN" | tee -a "$OUT/c_commit.txt" >&2
fi

g++ -std=c++20 -O2 -Wall -Wextra \
  -I "$CORE_SRC/src" -I "$CORE_SRC/src/secp256k1/include" \
  "$HERE/c_cpubkey_validity.cpp" -o "$HERE/c_cpubkey_validity"

"$HERE/c_cpubkey_validity" > "$OUT/c_table.txt"
echo "wrote $OUT/c_table.txt (Core $HEAD)"
