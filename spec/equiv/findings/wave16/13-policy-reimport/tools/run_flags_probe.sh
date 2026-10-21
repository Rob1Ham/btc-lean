#!/usr/bin/env bash
# Reproduce tools/flags_probe.out from the pinned Core tree.
#   CORE_PIN=/tmp/opencode/core-pin tools/run_flags_probe.sh
# The probe includes src/script/interpreter.h and prints 1<<enum-value for every
# flag name the cells use.  Output is committed so reviewers do not need a Core
# tree, but this script is the provenance of the numbers.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CORE_PIN="${CORE_PIN:-/tmp/opencode/core-pin}"
CXX=/usr/bin/clang++-20
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
{
  "$CXX" -std=c++20 -I "$CORE_PIN/src" -I "$CORE_PIN/src/script" \
    -c "$HERE/flags_probe.cpp" -o "$TMP/flags_probe.o"
  "$CXX" "$TMP/flags_probe.o" -o "$TMP/flags_probe"
  echo "# core_pin=$CORE_PIN"
  echo "# core_head=$(git -C "$CORE_PIN" rev-parse HEAD)"
  echo "# probe: include <script/interpreter.h>, print 1<<uint8_t(name)"
  "$TMP/flags_probe"
} | tee "$HERE/flags_probe.out"
