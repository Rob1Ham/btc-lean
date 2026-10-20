#!/usr/bin/env bash
# Concrete differential: cell C model vs the real Bitcoin Core EvalScript.
#
# Links the local Core build at the pin. Defaults can be overridden:
#   CORE_SRC   (source tree at cce32b168, default /tmp/opencode/core-pin)
#   CORE_BUILD (build dir with lib/libbitcoin_consensus.a,
#               default /tmp/opencode/core-build/build)
# Writes concrete/result.txt. Not a proof: an exhaustive-over-script-bytes
# differential on the declared leaf.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
W32="$(cd "$CELL_DIR/../../_tools/w32-exec" && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/concrete/result.txt"
CORE_SRC="${CORE_SRC:-/tmp/opencode/core-pin}"
CORE_BUILD="${CORE_BUILD:-/tmp/opencode/core-build/build}"
CONSENSUS_LIB="$CORE_BUILD/lib/libbitcoin_consensus.a"
SECP_LIB="$CORE_BUILD/src/secp256k1/lib/libsecp256k1.a"
mkdir -p "$BUILD"

for f in "$CONSENSUS_LIB" "$SECP_LIB" "$CORE_SRC/src/script/interpreter.cpp" \
         "$CORE_SRC/src/script/script.cpp"; do
  [ -e "$f" ] || { echo "missing: $f" >&2; exit 2; }
done

CXX=(/usr/bin/clang++-20 -std=c++20 -O1 -I "$W32" -I "$EQ/contract" -I "$CORE_SRC/src")
"${CXX[@]}" -c "$CELL_DIR/concrete/diff_core.cpp" -o "$BUILD/diff_core.o"
"${CXX[@]}" -c "$CELL_DIR/src/c_cell.cpp" -o "$BUILD/c_model.o"
/usr/bin/clang++-20 "$BUILD/diff_core.o" "$BUILD/c_model.o" -o "$BUILD/diff_core" \
  -L "$CORE_BUILD/lib" -L "$CORE_BUILD/src/secp256k1/lib" \
  -lbitcoin_consensus -lbitcoin_common -lbitcoin_crypto -lbitcoin_util -lsecp256k1

{
  echo "# cell: exec-verify/C-L-w64-p2sh-subscript-leaf (concrete Core differential)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# core_src: $CORE_SRC"
  echo "# core_build: $CORE_BUILD"
  echo "# interpreter.cpp sha256: $(sha256sum "$CORE_SRC/src/script/interpreter.cpp" | cut -d' ' -f1)"
  echo "# script.cpp sha256:      $(sha256sum "$CORE_SRC/src/script/script.cpp" | cut -d' ' -f1)"
  echo "# libbitcoin_consensus.a sha256: $(sha256sum "$CONSENSUS_LIB" | cut -d' ' -f1)"
  echo "# libsecp256k1.a sha256:  $(sha256sum "$SECP_LIB" | cut -d' ' -f1)"
  echo "# model src sha256:       $(sha256sum "$CELL_DIR/src/c_cell.cpp" | cut -d' ' -f1)"
  echo "# harness src sha256:     $(sha256sum "$CELL_DIR/concrete/diff_core.cpp" | cut -d' ' -f1)"
  echo "# domain: all script byte strings of length 0, 1, 2 x"
  echo "#         depth {1,2,3,12} x prev {(0,0),(1,1),(0x80,1),(0x101,2),(0x001,2),(0x080,2),(0x8100,3)}"
  echo "# flags=SCRIPT_VERIFY_P2SH (MINIMALDATA off), SigVersion::BASE, empty altstack"
  echo
  if "$BUILD/diff_core"; then
    echo "STATUS=core-differential-green"
  else
    echo "STATUS=core-differential-red"
    exit 1
  fi
} > "$OUT" 2>&1
tail -3 "$OUT"

{
  cd "$ROOT"
  for f in "$CELL_DIR/src/c_cell.cpp" "$CELL_DIR/concrete/diff_core.cpp" \
           "$CELL_DIR/concrete/run.sh" "$OUT"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$CELL_DIR/concrete/certificate.sha256"
