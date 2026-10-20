#!/usr/bin/env bash
# Build and run the concrete divergence driver.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
mkdir -p "$BUILD" "$HERE/driver"
CXX=/usr/bin/clang++-20
$CXX -std=c++17 -O1 -fno-strict-aliasing -Dprobe_prescan_order=probe_c_order \
     -c "$HERE/probe_c.cpp" -o "$BUILD/c_probe.o"
$CXX -std=c++17 -O1 -fno-strict-aliasing -Dprobe_prescan_order=probe_l_order \
     -c "$HERE/probe_l.cpp" -o "$BUILD/l_probe.o"
$CXX -std=c++17 -O1 "$HERE/driver.cpp" "$BUILD/c_probe.o" "$BUILD/l_probe.o" \
     -o "$BUILD/driver"
"$BUILD/driver" | tee "$HERE/driver/result.txt"
