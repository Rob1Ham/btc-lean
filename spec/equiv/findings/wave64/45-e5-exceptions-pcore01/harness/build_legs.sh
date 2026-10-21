#!/bin/sh
# Re-audit build: baseline / P-CORE-01 / P-CORE-01+amendment, same flags.
# Disposable prototype; no artifact here is a proof-lane artifact.
set -eu

W=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$W/.." && pwd)
CXX=/usr/bin/clang++-20
CC=cc
JOBS=${JOBS:-8}
OBJ=$W/obj
LIB=$W/lib
mkdir -p "$OBJ" "$LIB"

if [ ! -f "$OBJ/secp/secp256k1.o" ]; then
    mkdir -p "$OBJ/secp"
    SECP_INC="-I $W/core/src/secp256k1/include -I $W/core/src/secp256k1/src"
    SECP_DEFS="-DENABLE_MODULE_SCHNORRSIG=1 -DENABLE_MODULE_EXTRAKEYS=1 -DENABLE_MODULE_ELLSWIFT=1 -DENABLE_MODULE_RECOVERY=1 -DECMULT_WINDOW_SIZE=15 -DECMULT_GEN_PREC_BITS=4 -DUSE_FIELD_5X52=1 -DUSE_SCALAR_4X64=1 -DHAVE___INT128=1"
    for f in secp256k1 precomputed_ecmult precomputed_ecmult_gen; do
        $CC -O2 -fPIC $SECP_INC $SECP_DEFS -c "$W/core/src/secp256k1/src/$f.c" -o "$OBJ/secp/$f.o"
    done
fi

cat > "$OBJ/test_stubs.cpp" <<'EOF'
#include <cstdio>
bool FileCommit(FILE*) { return true; }
bool TruncateFile(FILE*, unsigned int) { return true; }
EOF

CORE_FILES="script/interpreter.cpp script/script.cpp script/script_error.cpp primitives/transaction.cpp pubkey.cpp hash.cpp uint256.cpp arith_uint256.cpp crypto/ripemd160.cpp crypto/sha1.cpp crypto/sha256.cpp crypto/sha512.cpp crypto/hmac_sha512.cpp crypto/hex_base.cpp crypto/sha256_sse4.cpp util/strencodings.cpp streams.cpp support/cleanse.cpp"

build_variant() {
    name=$1; tree=$2; macros=$3
    od=$OBJ/$name
    mkdir -p "$od"
    echo "== building $name ($tree) macros='$macros'"
    for f in $CORE_FILES; do printf '%s\n' "$f"; done | xargs -P "$JOBS" -I{} sh -c '
        f="{}"; out="'"$od"'/core-$(echo "$f" | tr / _ | sed s/\.cpp$/.o/)"
        '"$CXX"' -std=c++20 -O0 -g0 -fPIC '"$macros"' \
            -I '"$tree"'/src -I '"$tree"'/build-ir/src \
            -I '"$tree"'/src/secp256k1/include \
            -c '"$tree"'/src/"$f" -o "$out"
    '
    $CXX -std=c++20 -O0 -g0 -fPIC $macros \
        -I "$REPO/spec/equiv/contract" -I "$tree/src" \
        -I "$tree/src/secp256k1/include" \
        -c "$REPO/spec/equiv/shims/core/entry.cpp" -o "$od/entry-core.o"
    $CXX -std=c++20 -O0 -g0 -fPIC -c "$OBJ/test_stubs.cpp" -o "$od/test_stubs.o"
    $CXX -shared -o "$LIB/libequiv-core-$name.so" \
        "$od"/entry-core.o "$od"/core-*.o "$od"/test_stubs.o "$OBJ"/secp/*.o
    sha256sum "$LIB/libequiv-core-$name.so"
}

build_variant baseline "$W/core" ""
build_variant p01 "$W/core-p1" "-DBTC_EQUIV_NO_SCRIPTNUM_THROW"
build_variant p01amend "$W/core-p1-amend" "-DBTC_EQUIV_NO_SCRIPTNUM_THROW"

echo "== done"
