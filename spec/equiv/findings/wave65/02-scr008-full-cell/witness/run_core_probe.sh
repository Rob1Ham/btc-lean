#!/usr/bin/env bash
# Wave65 / 02-scr008-full-cell
# Re-run the concrete Core probe for F-DIV-W32-01 against the *real* pinned
# interpreter, at this wave's base (76dbfe5).  The probe sources are carried
# over unchanged from findings/wave64/41-div-w32-p2sh-cleanstack (same tape,
# same checker) so the wave-64 result is independently re-established here
# rather than quoted.
#
# Requires a Bitcoin Core checkout at the pin.  Defaults to /tmp/pcore01
# (local, outside this repository); override with CORE_SRC=/path.  Pristine
# interpreter.cpp/script.cpp/script.h are extracted from git at the pin, so
# local unrelated edits in $CORE_SRC do not enter the measurement.
#
# usage: CORE_SRC=/tmp/pcore01 ./run_core_probe.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CORE_SRC="${CORE_SRC:-/tmp/pcore01}"
PIN=cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66

[ -f "$CORE_SRC/src/script/interpreter.cpp" ] || { echo "no Core tree at $CORE_SRC" >&2; exit 2; }
head="$(git -C "$CORE_SRC" rev-parse HEAD)"
[ "$head" = "$PIN" ] || { echo "CORE_SRC HEAD $head != pin $PIN" >&2; exit 2; }

SECP="$CORE_SRC/src/secp256k1"
if [ ! -f "$SECP/build/lib/libsecp256k1.so" ]; then
  cmake -S "$SECP" -B "$SECP/build" -DCMAKE_BUILD_TYPE=Release \
    -DSECP256K1_ENABLE_MODULE_RECOVERY=ON \
    -DSECP256K1_ENABLE_MODULE_ECDH=ON \
    -DSECP256K1_ENABLE_MODULE_SCHNORRSIG=ON \
    -DSECP256K1_ENABLE_MODULE_EXTRAKEYS=ON >/dev/null
  cmake --build "$SECP/build" -j"$(nproc)" >/dev/null
fi

BIN="$HERE/build/core_probe"
CLEAN="$HERE/build/core-clean/src/script"
mkdir -p "$CLEAN"
for f in interpreter.cpp script.cpp script.h; do
  git -C "$CORE_SRC" show "$PIN:src/script/$f" > "$CLEAN/$f"
done
/usr/bin/clang++-20 -std=c++20 -O1 \
  -I "$HERE/build/core-clean/src" \
  -I "$CORE_SRC/src" -I "$SECP/include" \
  "$HERE/core_probe.cpp" \
  "$CLEAN/interpreter.cpp" \
  "$CLEAN/script.cpp" \
  "$CORE_SRC/src/pubkey.cpp" \
  "$CORE_SRC/src/uint256.cpp" \
  "$CORE_SRC/src/hash.cpp" \
  "$CORE_SRC/src/util/strencodings.cpp" \
  "$CORE_SRC/src/crypto/hex_base.cpp" \
  "$CORE_SRC/src/crypto/sha256.cpp" \
  "$CORE_SRC/src/crypto/sha256_sse4.cpp" \
  "$CORE_SRC/src/crypto/sha256_avx2.cpp" \
  "$CORE_SRC/src/crypto/sha256_sse41.cpp" \
  "$CORE_SRC/src/crypto/sha256_x86_shani.cpp" \
  "$CORE_SRC/src/crypto/sha1.cpp" \
  "$CORE_SRC/src/crypto/sha512.cpp" \
  "$CORE_SRC/src/crypto/hmac_sha512.cpp" \
  "$CORE_SRC/src/crypto/ripemd160.cpp" \
  "$CORE_SRC/src/support/cleanse.cpp" \
  -L "$SECP/build/lib" -lsecp256k1 -Wl,-rpath,"$SECP/build/lib" -lpthread \
  -o "$BIN"

{
  echo "# F-DIV-W32-01 concrete Core probe — wave65 re-run"
  echo "# core_src=$CORE_SRC"
  echo "# core_head=$(git -C "$CORE_SRC" rev-parse HEAD)"
  echo "# pristine_interpreter_blob=$(git -C "$CORE_SRC" rev-parse "$PIN:src/script/interpreter.cpp")"
  echo "# pristine_script_cpp_blob=$(git -C "$CORE_SRC" rev-parse "$PIN:src/script/script.cpp")"
  echo "# pristine_script_h_blob=$(git -C "$CORE_SRC" rev-parse "$PIN:src/script/script.h")"
  echo "# clang=$(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: $BIN"
  echo "# expected: P2SH-P2WPKH/P2WSH cleanstack=1 verify=true; bare and plain-P2SH controls verify=true"
  echo
  "$BIN"
} > "$HERE/core-probe.txt" 2>&1
cat "$HERE/core-probe.txt"

{
  cd "$(git -C "$HERE" rev-parse --show-toplevel)"
  for f in \
    spec/equiv/findings/wave65/02-scr008-full-cell/witness/core_probe.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/witness/run_core_probe.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/witness/core-probe.txt ; do
    sha256sum "$f"
  done
} > "$HERE/core-probe.sha256"
