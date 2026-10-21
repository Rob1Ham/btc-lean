#!/bin/sh
# E0 triple entry point expected by tools/run_e0.py --strict-e0.
# The actual runner is e0_triple.py; it loads the three real shared libraries
# and prints E0_TRIPLE_OK only when every leg agrees with every expected tape.
#
# Defaults are the tracked L build and the current behavioral C/R artifacts.
# Every path can be overridden by an environment variable or by passing the
# corresponding flag later on the command line (argparse takes the last one).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)

CORE_SO=${CORE_SO:-/tmp/opencode/cbuild/libequiv-core.so}
TWIN_SO=${TWIN_SO:-"$ROOT/twin/build/libtwin.so"}
RUST_SO=${RUST_SO:-"$ROOT/shims/rust/build/libequiv-rust.so"}
if [ ! -f "$RUST_SO" ]; then
  RUST_SO=/tmp/opencode/shim-build/libequiv_rust.so
fi

if [ -f "$TWIN_SO" ]; then
  exec python3 "$HERE/e0_triple.py" \
    --core-so "$CORE_SO" --twin-so "$TWIN_SO" --rust-so "$RUST_SO" "$@"
fi
# No tracked twin library: run with the runner's stub default and let it
# report L as a stub. Do not silently substitute a foreign .so.
exec python3 "$HERE/e0_triple.py" \
  --core-so "$CORE_SO" --rust-so "$RUST_SO" "$@"
