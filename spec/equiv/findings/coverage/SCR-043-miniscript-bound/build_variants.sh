#!/bin/sh
# Build three Core shims from *clean pin* source to test whether
# MAX_PUBKEYS_PER_MULTI_A is observable through the normative ABI
# (VerifyScript(tx, spk) -> result, ScriptError).
#
#   base             : Core cce32b168, unmodified
#   mut-pubkeys      : script.h MAX_PUBKEYS_PER_MULTI_A 999 -> 1
#   mut-stack        : script.h MAX_STACK_SIZE 1000 -> 999   (positive control:
#                      a constant the interpreter *does* read)
#
# The mutant is not a proof-lane artifact and is not used by any cell; it is a
# sensitivity control for the inapplicability finding.
#
# Env:
#   W          scratch root                (default /tmp/opencode/w65-07)
#   CORE_SRC   clean Core checkout at pin  (default /tmp/pcore01)
#   REPO       btc-lean worktree           (default: three levels up from here)
#   CXX, CC, JOBS
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=${REPO:-$(CDPATH= cd -- "$HERE/../../../../.." && pwd)}
W=${W:-/tmp/opencode/w65-07}
CORE_SRC=${CORE_SRC:-/tmp/pcore01}
CXX=${CXX:-/usr/bin/clang++-20}
CC=${CC:-cc}
JOBS=${JOBS:-16}
CORE_PIN=cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66

[ -d "$CORE_SRC/.git" ] || { echo "no Core tree at $CORE_SRC" >&2; exit 1; }
head=$(git -C "$CORE_SRC" rev-parse HEAD)
[ "$head" = "$CORE_PIN" ] || { echo "Core HEAD $head != pin $CORE_PIN" >&2; exit 1; }

mkdir -p "$W"
for name in base mut-pubkeys mut-stack; do
    tree=$W/core-$name
    if [ ! -d "$tree" ]; then
        git -C "$CORE_SRC" archive "$CORE_PIN" | tar -x -C "$W" --one-top-level="core-$name"
        mkdir -p "$tree/build-ir/src"
        cp "$CORE_SRC/build-ir/src/bitcoin-build-config.h" "$tree/build-ir/src/"
    fi
    case $name in
        mut-pubkeys)
            sed -i 's/\(MAX_PUBKEYS_PER_MULTI_A\) = 999;/\1 = 1;/' "$tree/src/script/script.h" ;;
        mut-stack)
            sed -i 's/\(MAX_STACK_SIZE\) = 1000;/\1 = 999;/' "$tree/src/script/script.h" ;;
    esac
done

OBJ=$W/obj
LIB=$W/lib
mkdir -p "$OBJ/secp" "$LIB"

# secp256k1 is constant across variants; build once.
if [ ! -f "$OBJ/secp/secp256k1.o" ]; then
    SECP_INC="-I $W/core-base/src/secp256k1/include -I $W/core-base/src/secp256k1/src"
    SECP_DEFS="-DENABLE_MODULE_SCHNORRSIG=1 -DENABLE_MODULE_EXTRAKEYS=1 -DENABLE_MODULE_ELLSWIFT=1 -DENABLE_MODULE_RECOVERY=1 -DECMULT_WINDOW_SIZE=15 -DECMULT_GEN_PREC_BITS=4 -DUSE_FIELD_5X52=1 -DUSE_SCALAR_4X64=1 -DHAVE___INT128=1"
    for f in secp256k1 precomputed_ecmult precomputed_ecmult_gen; do
        $CC -O2 -fPIC $SECP_INC $SECP_DEFS -c "$W/core-base/src/secp256k1/src/$f.c" -o "$OBJ/secp/$f.o"
    done
fi

cat > "$OBJ/test_stubs.cpp" <<'EOF'
#include <cstdio>
bool FileCommit(FILE*) { return true; }
bool TruncateFile(FILE*, unsigned int) { return true; }
EOF

# Exactly the TUs listed in shims/core/entry.cpp "Link:" notes.
CORE_FILES="script/interpreter.cpp script/script.cpp script/script_error.cpp primitives/transaction.cpp pubkey.cpp hash.cpp uint256.cpp arith_uint256.cpp crypto/ripemd160.cpp crypto/sha1.cpp crypto/sha256.cpp crypto/sha512.cpp crypto/hmac_sha512.cpp crypto/hex_base.cpp crypto/sha256_sse4.cpp util/strencodings.cpp streams.cpp support/cleanse.cpp"

for name in base mut-pubkeys mut-stack; do
    tree=$W/core-$name
    od=$OBJ/$name
    mkdir -p "$od"
    echo "== building $name from $tree"
    for f in $CORE_FILES; do printf '%s\n' "$f"; done | xargs -P "$JOBS" -I{} sh -c '
        f="{}"; out="'"$od"'/core-$(echo "$f" | tr / _ | sed s/\.cpp$/.o/)"
        '"$CXX"' -std=c++20 -O0 -g0 -fPIC \
            -I '"$tree"'/src -I '"$tree"'/build-ir/src \
            -I '"$tree"'/src/secp256k1/include \
            -c '"$tree"'/src/"$f" -o "$out"
    '
    $CXX -std=c++20 -O0 -g0 -fPIC \
        -I "$REPO/spec/equiv/contract" -I "$tree/src" \
        -I "$tree/src/secp256k1/include" \
        -c "$REPO/spec/equiv/shims/core/entry.cpp" -o "$od/entry-core.o"
    $CXX -std=c++20 -O0 -g0 -fPIC -c "$OBJ/test_stubs.cpp" -o "$od/test_stubs.o"
    $CXX -shared -o "$LIB/libequiv-core-$name.so" \
        "$od"/entry-core.o "$od"/core-*.o "$od"/test_stubs.o "$OBJ"/secp/*.o
done

echo "== sha256"
sha256sum "$LIB"/libequiv-core-*.so
