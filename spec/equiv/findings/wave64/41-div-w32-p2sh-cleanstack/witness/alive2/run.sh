#!/usr/bin/env bash
# Wave64 / 41-div-w32-p2sh-cleanstack
# Bounded differential probe for F-DIV-W32-01.  A counterexample is the
# expected observation (the finding is a recorded model divergence).
#
# usage: run.sh            (from anywhere)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
mkdir -p "$BUILD"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names)
"${CXX[@]}" -c -emit-llvm "$HERE/c_probe.cpp" -o "$BUILD/c_probe.bc"
"${CXX[@]}" -c -emit-llvm "$HERE/l_probe.cpp" -o "$BUILD/l_probe.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_probe.bc" -o "$BUILD/c_probe.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_probe.bc" -o "$BUILD/l_probe.ll"

RES="$HERE/result.txt"
{
  echo "# probe: exec-verify/C-L-w32-cleanstack witness-implicit (domain-exact)"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# expected: counterexample at bare=0 wrapped=1 cs=1 inner_len!=1"
  echo "# command: alive-tv build/c_probe.ll build/l_probe.ll"
  /usr/local/bin/alive-tv "$BUILD/c_probe.ll" "$BUILD/l_probe.ll" 2>&1 || true
} > "$RES"

if grep -q "Transformation doesn't verify" "$RES"; then
  echo "STATUS=alive2-counterexample-as-expected" >> "$RES"
else
  echo "STATUS=alive2-unexpected-green" >> "$RES"
  exit 1
fi

{
  cd "$(git -C "$HERE" rev-parse --show-toplevel)"   # repository root
  for f in \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/c_probe.cpp \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/l_probe.cpp \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/run.sh \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/result.txt \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/build/c_probe.ll \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/build/l_probe.ll ; do
    sha256sum "$f"
  done
} > "$HERE/certificate.sha256"
