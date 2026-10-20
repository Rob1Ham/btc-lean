#!/usr/bin/env bash
# twin/smoke.sh -- smoke test for the generated twin.
#
# Pinned lane: compile the generated C++ with the pinned clang at -O0, the
# same front-end as the C leg.  If clang++ is absent the pinned lane is
# SKIPPED (never simulated) and, unless --require-clang is given, a clearly
# labelled development lane runs with g++ so the generator itself is still
# exercised.  Development-lane output is NOT equivalence evidence.
#
# Usage:
#   ./smoke.sh                 # pinned lane if possible, else dev fallback
#   ./smoke.sh --require-clang # exit 77 if clang++ is absent
#   CLANGXX=/path/to/clang++ ./smoke.sh
#   CXX=clang++-20 ./smoke.sh  # CXX/CLANGXX both honoured
#
# Exit: 0 all executed lanes passed; 1 failure; 77 pinned lane unavailable
#       under --require-clang.

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HERE/build"
GEN="$BUILD/twin.cpp"
IR="$BUILD/twin.ir.json"
DRV="$HERE/smoke_driver.cpp"
CONTRACT="$HERE/../contract"
BIN="$BUILD/smoke"

REQUIRE_CLANG=0
[ "${1:-}" = "--require-clang" ] && REQUIRE_CLANG=1

mkdir -p "$BUILD"

echo "== generate =="
python3 "$HERE/gen.py" --out "$GEN" --dump-ir "$IR" || exit 1
python3 "$HERE/gen.py" --check "$GEN" || exit 1
echo "generated sha256: $(sha256sum "$GEN" | cut -d' ' -f1)"
echo "ir        sha256: $(sha256sum "$IR" | cut -d' ' -f1)"

FLAGS=(-std=c++17 -O0 -fno-strict-aliasing -Wall -Wextra -I "$CONTRACT")
DEVFLAGS=(-fsanitize=address,undefined -fno-omit-frame-pointer)

run_lane() {
  local label="$1" cxx="$2"; shift 2
  echo
  echo "== $label: $cxx =="
  "$cxx" --version | head -1
  echo "flags: ${FLAGS[*]} $*"
  if ! "$cxx" "${FLAGS[@]}" "$@" -o "$BIN" "$GEN" "$DRV"; then
    echo "RESULT[$label]: COMPILE FAILED"
    return 1
  fi
  "$BIN"
  local rc=$?
  if [ $rc -eq 0 ]; then
    echo "RESULT[$label]: PASS"
  else
    echo "RESULT[$label]: FAIL"
  fi
  return $rc
}

# CLANGXX wins, then CXX; otherwise prefer the pinned clang++-20 on this host.
CLANGXX_BIN="${CLANGXX:-${CXX:-}}"
if [ -z "$CLANGXX_BIN" ]; then
  if command -v clang++-20 >/dev/null 2>&1; then
    CLANGXX_BIN=clang++-20
  else
    CLANGXX_BIN=clang++
  fi
fi
HAVE_CLANG=0
if command -v "$CLANGXX_BIN" >/dev/null 2>&1; then
  HAVE_CLANG=1
fi

overall=0
pinned_ran=0

if [ $HAVE_CLANG -eq 1 ]; then
  run_lane "pinned-clang" "$CLANGXX_BIN"
  overall=$?
  pinned_ran=1
else
  echo
  echo "PINNED CLANG LANE: NOT RUN -- '$CLANGXX_BIN' not found."
  echo "  No clang compile/run result exists for this smoke test."
  if [ $REQUIRE_CLANG -eq 1 ]; then
    exit 77
  fi
fi

if [ $pinned_ran -eq 0 ]; then
  if command -v g++ >/dev/null 2>&1; then
    echo
    echo "NOTE: development lane uses g++, NOT the pinned front-end."
    echo "      This exercises generation/compilation but is NOT L-leg evidence."
    run_lane "dev-g++ (NOT EVIDENCE)" "g++" "${DEVFLAGS[@]}"
    overall=$?
  else
    echo "No clang++ and no g++; smoke test NOT RUN." >&2
    exit 77
  fi
fi

if [ -f "$GEN" ]; then
  echo
  echo "artifact: $GEN"
  echo "artifact: $IR"
  echo "artifact: $BIN"
fi

echo
if [ $overall -eq 0 ]; then
  if [ $pinned_ran -eq 1 ]; then
    echo "SMOKE: PASS (pinned clang lane ran)"
  else
    echo "SMOKE: PASS (only the development lane ran; pinned clang lane NOT RUN)"
  fi
else
  echo "SMOKE: FAIL"
fi
exit $overall
