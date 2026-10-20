#!/usr/bin/env bash
# Reproduce the C-side and Lean-side witnesses for the Wave-64/SCR-112
# isValidPubKey divergence (F-DIV).
#
#   BITCOIN_CORE_SRC=/path/to/core   (default /tmp/opencode/core-pin)
#   BITCOIN_CORE_BUILD=/path/to/build (default /tmp/opencode/core-build/build)
#
# The Core source checkout MUST be at the pinned commit.  The script
# refuses to run (and records why) otherwise: the C witness is only
# meaningful against the pin.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ ! -d "$ROOT/spec/core" ]; do
  ROOT="$(cd "$ROOT/.." && pwd)"
done

CORE_SRC="${BITCOIN_CORE_SRC:-/tmp/opencode/core-pin}"
CORE_BUILD="${BITCOIN_CORE_BUILD:-/tmp/opencode/core-build/build}"
PIN="cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
OUT="$HERE/c_core_pubkey.out"
META="$HERE/build.txt"
LEAN_OUT="$HERE/l_isvalidpubkey.out"
BUILD_DIR="$(mktemp -d)"
BIN="$BUILD_DIR/c_core_pubkey"
trap 'rm -rf "$BUILD_DIR"' EXIT

{
  printf 'core_src=%s\n' "$CORE_SRC"
  printf 'core_build=%s\n' "$CORE_BUILD"
  printf 'expected_pin=%s\n' "$PIN"
  printf 'core_head=%s\n' "$(git -C "$CORE_SRC" rev-parse HEAD 2>/dev/null || echo MISSING)"
  printf 'pubkey_h_sha256=%s\n' "$(sha256sum "$CORE_SRC/src/pubkey.h" | cut -d' ' -f1)"
  printf 'driver_sha256=%s\n' "$(sha256sum "$HERE/c_core_pubkey.cpp" | cut -d' ' -f1)"
  printf 'lean_witness_sha256=%s\n' "$(sha256sum "$HERE/IsValidPubKeyWitness.lean" | cut -d' ' -f1)"
  printf 'runner_sha256=%s\n' "$(sha256sum "$HERE/run.sh" | cut -d' ' -f1)"
  printf 'compiler=%s\n' "$(g++ --version | head -1)"
  printf 'lean=%s\n' "$(lean --version | head -1)"
} > "$META"

HEAD="$(git -C "$CORE_SRC" rev-parse HEAD 2>/dev/null || true)"
if [ "$HEAD" != "$PIN" ]; then
  printf 'REFUSING: Core checkout is at %s, expected %s\n' "${HEAD:-<none>}" "$PIN" | tee "$OUT"
  exit 2
fi

g++ -std=c++20 -O2 \
  -I "$CORE_SRC/src" -I "$CORE_BUILD/src" \
  "$HERE/c_core_pubkey.cpp" -o "$BIN"

"$BIN" | tee "$OUT"

# Lean side: kernel-check the same witnesses (and print the two values).
cd "$ROOT/spec/core"
lake env lean "$HERE/IsValidPubKeyWitness.lean" 2>&1 | tee "$LEAN_OUT"

# Cross-check: every C-side Lean-model bit must equal the Lean definition.
# The C driver prints the values; the Lean file pins them by `decide`.
printf '\n# artifacts\n'
{
  printf 'c_out_sha256=%s\n' "$(sha256sum "$OUT" | cut -d' ' -f1)"
  printf 'l_out_sha256=%s\n' "$(sha256sum "$LEAN_OUT" | cut -d' ' -f1)"
} | tee -a "$META"
