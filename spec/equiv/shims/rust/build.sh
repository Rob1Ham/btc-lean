#!/bin/sh
# Build the clean R-leg ABI v2 shim from rbitcoin's public API.
#
#   RBTC=/path/to/rbitcoin-clean ./build.sh
#
# The source tree must be clean at the pin; the script refuses otherwise.
# No rbitcoin source is modified. The proof-IR lane is separate (rustc 1.88,
# see PINS.lock [rbitcoin]); this behavioral lane uses the repo pin 1.95.0.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RBTC=${RBTC:-/tmp/opencode/equiv-work/rbitcoin-clean}
PIN=${PIN:-ae47aa98174e04d0d8c493f13041daf65e4ac1d3}
TARGET=${TARGET:-/tmp/opencode/equiv-work/target-195-lib}
OUT=${OUT:-"$HERE/build/libequiv-rust.so"}
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
  "$HERE/entry.rs" -o "$OUT"

nm -D --defined-only "$OUT" | grep -q ' T equiv_entry' || {
  echo "build.sh: equiv_entry not exported" >&2; exit 1; }
nm -D --defined-only "$OUT" | grep -q ' T entry' || {
  echo "build.sh: entry not exported" >&2; exit 1; }

echo "R shim: $OUT"
sha256sum "$OUT"
