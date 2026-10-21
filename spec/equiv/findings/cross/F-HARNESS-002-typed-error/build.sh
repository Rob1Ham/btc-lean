#!/bin/sh
# Build the F-HARNESS-002 typed-error probe + bounded witness.
#
#   RBTC=/path/to/rbitcoin-clean ./build.sh
#
# Advisory / off-pin: this does NOT rebuild or replace the official ABI shim.
# It links rbitcoin's public rlibs from the same clean pin and compiles the
# classifier + witness with the repo-pinned rustc 1.95.0.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RBTC=${RBTC:-/tmp/opencode/equiv-work/rbitcoin-clean}
PIN=${PIN:-ae47aa98174e04d0d8c493f13041daf65e4ac1d3}
TARGET=${TARGET:-/tmp/opencode/equiv-work/target-195-lib}
TOOLCHAIN=${TOOLCHAIN:-1.95.0}
OUT=${OUT:-"$HERE/build"}
DEPS="$TARGET/release/deps"

test -e "$RBTC/.git" || { echo "build.sh: no git checkout at $RBTC" >&2; exit 2; }
HEAD=$(git -C "$RBTC" rev-parse HEAD)
test "$HEAD" = "$PIN" || { echo "build.sh: HEAD $HEAD != pin $PIN" >&2; exit 2; }
test -z "$(git -C "$RBTC" status --porcelain)" || {
  echo "build.sh: rbitcoin tree is dirty; witness must run at the pin" >&2
  git -C "$RBTC" status --porcelain >&2
  exit 2
}

RBC=$(ls "$DEPS"/librbitcoin_consensus-*.rlib 2>/dev/null | head -1)
BTC=$(ls "$DEPS"/libbitcoin-*.rlib 2>/dev/null | head -1)
test -n "$RBC" || { echo "build.sh: no rbitcoin_consensus rlib in $DEPS" >&2; exit 2; }
test -n "$BTC" || { echo "build.sh: no bitcoin rlib in $DEPS" >&2; exit 2; }

mkdir -p "$OUT"
export RUSTUP_TOOLCHAIN="$TOOLCHAIN"

rustc --edition 2021 -O \
  --extern rbitcoin_consensus="$RBC" \
  --extern bitcoin="$BTC" \
  -L dependency="$DEPS" \
  "$HERE/src/witness.rs" -o "$OUT/witness"

rustc --edition 2021 -O --test \
  --extern rbitcoin_consensus="$RBC" \
  --extern bitcoin="$BTC" \
  -L dependency="$DEPS" \
  "$HERE/src/typed_error.rs" -o "$OUT/typed_error_tests"

"$OUT/typed_error_tests" --quiet

# Rebuild the *pinned* R shim from the repo source so the witness compares
# against the exact artifact that PINS.lock describes, not a stale local copy.
RBTC="$RBTC" PIN="$PIN" TARGET="$TARGET" OUT="$OUT/libequiv-rust-pinned.so" \
  sh "$HERE/../../../shims/rust/build.sh"

# Build the *proposed* typed-error shim: pinned entry.rs + entry-typed.diff +
# src/typed_error.rs, in a scratch dir. This does not touch shims/.
SHIMDIR="$OUT/typed-shim"
rm -rf "$SHIMDIR"
mkdir -p "$SHIMDIR"
cp "$HERE/../../../shims/rust/entry.rs" "$SHIMDIR/entry.rs"
cp "$HERE/src/typed_error.rs" "$SHIMDIR/typed_error.rs"
patch -s -p5 -d "$SHIMDIR" < "$HERE/entry-typed.diff"
rustc --crate-type cdylib --edition 2021 -O \
  --extern rbitcoin_consensus="$RBC" \
  --extern bitcoin="$BTC" \
  -L dependency="$DEPS" \
  "$SHIMDIR/entry.rs" -o "$OUT/libequiv-rust-typed.so"
nm -D --defined-only "$OUT/libequiv-rust-typed.so" | grep -q ' T equiv_entry'
nm -D --defined-only "$OUT/libequiv-rust-typed.so" | grep -q ' T entry'

echo "witness: $OUT/witness"
sha256sum "$OUT/witness" "$OUT/typed_error_tests" "$OUT/libequiv-rust-pinned.so" "$OUT/libequiv-rust-typed.so"
