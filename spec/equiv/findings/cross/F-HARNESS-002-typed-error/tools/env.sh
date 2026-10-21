#!/bin/sh
# Record the exact probe environment. Advisory/off-pin only.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RBTC=${RBTC:-/tmp/opencode/equiv-work/rbitcoin-clean}
CORE=${CORE:-/tmp/opencode/equiv-work/bitcoin}
echo "date_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "uname: $(uname -srm)"
echo "python: $(python3 --version 2>&1)"
echo "rustc_pin: $(RUSTUP_TOOLCHAIN=1.95.0 rustc --version)"
echo "rustc_default: $(rustc --version)"
echo "rbitcoin_head: $(git -C "$RBTC" rev-parse HEAD)"
echo "rbitcoin_status: $(git -C "$RBTC" status --porcelain | wc -l) modified paths"
echo "core_head: $(git -C "$CORE" rev-parse HEAD)"
echo "core_status: $(git -C "$CORE" status --porcelain | wc -l) modified paths"
echo "repo_head: $(git -C "$HERE/../../../.." rev-parse HEAD)"
echo "repo_branch: $(git -C "$HERE/../../../.." rev-parse --abbrev-ref HEAD)"
echo
echo "== source/artifact sha256 =="
sha256sum \
  "$HERE/src/typed_error.rs" \
  "$HERE/src/witness.rs" \
  "$HERE/cases.tsv" \
  "$HERE/entry-typed.diff" \
  "$HERE/../../../shims/rust/entry.rs" \
  "$HERE/build/witness" \
  "$HERE/build/typed_error_tests" \
  "$HERE/build/libequiv-rust-pinned.so" \
  "$HERE/build/libequiv-rust-typed.so" \
  /tmp/opencode/cbuild/libequiv-core.so
