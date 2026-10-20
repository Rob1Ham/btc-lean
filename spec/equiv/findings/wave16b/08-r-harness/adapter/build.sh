#!/bin/sh
# Build the F-HARNESS-002 adapter prototype against the clean rbitcoin pin.
#
#   RBTC=/path/to/rbitcoin-clean ./build.sh
#
# Refuses a dirty tree or a HEAD other than the pin. No rbitcoin source is
# modified; the adapter links the *public* crate API. The rlibs may be reused
# from an earlier clean build via TARGET.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RBTC=${RBTC:-/tmp/opencode/equiv-work/rbitcoin-clean}
PIN=${PIN:-ae47aa98174e04d0d8c493f13041daf65e4ac1d3}
TARGET=${TARGET:-/tmp/opencode/equiv-work/target-195-lib}
OUT=${OUT:-/tmp/opencode/wave16b-scratch/08-r-harness/libequiv-rust-r3.so}
TOOLCHAIN=${TOOLCHAIN:-1.95.0}

test -e "$RBTC/.git" || { echo "build.sh: no git checkout at $RBTC" >&2; exit 2; }
HEAD=$(git -C "$RBTC" rev-parse HEAD)
test "$HEAD" = "$PIN" || { echo "build.sh: HEAD $HEAD != pin $PIN" >&2; exit 2; }
test -z "$(git -C "$RBTC" status --porcelain)" || {
  echo "build.sh: tree is dirty; official artifacts require a clean tree" >&2
  git -C "$RBTC" status --porcelain >&2
  exit 2
}

export CARGO_TARGET_DIR="$TARGET"
export RUSTUP_TOOLCHAIN="$TOOLCHAIN"
(cd "$RBTC" && cargo build --release --ignore-rust-version -p rbitcoin-consensus --lib)

DEPS="$TARGET/release/deps"
RBC=$(ls "$DEPS"/librbitcoin_consensus-*.rlib 2>/dev/null | head -1)
BTC=$(ls "$DEPS"/libbitcoin-*.rlib 2>/dev/null | head -1)
test -n "$RBC" || { echo "build.sh: no rbitcoin_consensus rlib" >&2; exit 2; }
test -n "$BTC" || { echo "build.sh: no bitcoin rlib" >&2; exit 2; }

mkdir -p "$(dirname "$OUT")"
rustc --crate-type cdylib --edition 2021 -O \
  --extern rbitcoin_consensus="$RBC" \
  --extern bitcoin="$BTC" \
  -L dependency="$DEPS" \
  "$HERE/entry_r3.rs" -o "$OUT"

nm -D --defined-only "$OUT" | grep -q ' T equiv_entry' || {
  echo "build.sh: equiv_entry not exported" >&2; exit 1; }
nm -D --defined-only "$OUT" | grep -q ' T entry' || {
  echo "build.sh: entry not exported" >&2; exit 1; }

echo "R adapter: $OUT"
sha256sum "$OUT"
