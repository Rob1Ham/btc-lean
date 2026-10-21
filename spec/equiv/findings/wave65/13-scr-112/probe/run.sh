#!/usr/bin/env bash
# Divergence probe for SCR-112 / F-DIV-004.
#
# C  = exact Core CPubKey::ValidSize / CheckPubKeyEncoding slice.
# L  = PINNED Lean `Der.isValidPubKey` header-only gate (not the fix target).
#
# alive-tv is expected to find a counterexample; the script requires that and
# then prints the concrete witness table from a native build of the same two
# functions.  This probe is evidence, not a green cell.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE" && while [ ! -f spec/equiv/contract/error_kind.h ]; do cd ..; done; pwd)"
CELL="$ROOT/spec/equiv/cells/checksig/C-L-checksig-pubkey-encoding"
BUILD="$HERE/build"
LLVM=/usr/lib/llvm-20/bin
CXX=/usr/bin/clang++-20
mkdir -p "$BUILD"

CXXFLAGS=(-std=c++17 -I "$CELL/src" -I "$ROOT/spec/equiv"
          -fno-discard-value-names -fno-strict-aliasing)

"$CXX" "${CXXFLAGS[@]}" -O1 -S -emit-llvm "$HERE/c_probe.cpp" -o "$BUILD/c_probe.ll"
# Alive2 matches functions by name.  Rename only the exported L symbol for the
# IR comparison; the native witness build below keeps probe_pinned distinct.
"$CXX" "${CXXFLAGS[@]}" -O1 -Dprobe_pinned=probe_core -S -emit-llvm \
  "$HERE/l_pinned_probe.cpp" -o "$BUILD/l_probe.ll"
for f in "$BUILD/c_probe.ll" "$BUILD/l_probe.ll"; do
  perl -0pi -e 's/,\s*!(tbaa|tbaa\.struct|alias\.scope|noalias|nonnull)(\s+![0-9]+)+//g' "$f"
done
"$LLVM/llvm-extract" --func=probe_core --recursive "$BUILD/c_probe.ll" -o "$BUILD/c_probe_fn.bc"
"$LLVM/llvm-extract" --func=probe_core --recursive "$BUILD/l_probe.ll" -o "$BUILD/l_probe_fn.bc"
"$LLVM/llvm-dis" "$BUILD/c_probe_fn.bc" -o "$BUILD/c_probe_fn.ll"
"$LLVM/llvm-dis" "$BUILD/l_probe_fn.bc" -o "$BUILD/l_probe_fn.ll"

{
  echo "# probe: SCR-112 / F-DIV-004 pinned-Lean vs Core-exact"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $("$CXX" --version | head -1)"
  echo "# c source sha256: $(sha256sum "$HERE/c_probe.cpp" | cut -d' ' -f1)"
  echo "# l source sha256: $(sha256sum "$HERE/l_pinned_probe.cpp" | cut -d' ' -f1)"
  echo "# command: /usr/local/bin/alive-tv --bidirectional build/c_probe_fn.ll build/l_probe_fn.ll (L symbol renamed probe_core for name matching)"
  echo
  /usr/local/bin/alive-tv --bidirectional "$BUILD/c_probe_fn.ll" "$BUILD/l_probe_fn.ll" 2>&1 || true
} > "$HERE/alive.log"

if grep -q "Transformation seems to be correct" "$HERE/alive.log" \
   && ! grep -q "doesn't verify" "$HERE/alive.log"; then
  echo "PROBE_UNEXPECTED_NO_DIVERGENCE" >&2
  exit 1
fi

"$CXX" "${CXXFLAGS[@]}" -O2 "$HERE/c_probe.cpp" "$HERE/l_pinned_probe.cpp" \
  "$HERE/driver.cpp" -o "$BUILD/witness"
{
  echo "# concrete outcomes, same functions as the Alive2 probe"
  echo "# C = Core-exact; L = pinned Der.isValidPubKey (header-only)"
  "$BUILD/witness"
} > "$HERE/witness.txt"

{
  echo "alive_tv=$(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "clang=$("$CXX" --version | head -1)"
  echo "c_probe_sha256=$(sha256sum "$HERE/c_probe.cpp" | cut -d' ' -f1)"
  echo "l_pinned_probe_sha256=$(sha256sum "$HERE/l_pinned_probe.cpp" | cut -d' ' -f1)"
  echo "driver_sha256=$(sha256sum "$HERE/driver.cpp" | cut -d' ' -f1)"
  echo "cell_c_sha256=$(sha256sum "$CELL/src/c_pubkey_encoding.cpp" | cut -d' ' -f1)"
  echo "cell_l_sha256=$(sha256sum "$CELL/src/l_pubkey_encoding.cpp" | cut -d' ' -f1)"
  echo "error_kind_sha256=$(sha256sum "$ROOT/spec/equiv/contract/error_kind.h" | cut -d' ' -f1)"
} > "$HERE/build.txt"

# Tracked-input certificate for the probe (repo-relative paths, sorted).
{
  cd "$ROOT"
  {
    find "$HERE" -type f ! -path "$HERE/build/*" ! -name certificate.sha256
    printf '%s\n' "$ROOT/spec/equiv/contract/error_kind.h"
  } | sed "s|^$ROOT/||" | LC_ALL=C sort | while IFS= read -r rel; do
    [ -f "$rel" ] && sha256sum "$rel"
  done
} > "$HERE/certificate.sha256"

cat "$HERE/witness.txt"
echo "PROBE_DIVERGENCE_OBSERVED (see alive.log, witness.txt)"
