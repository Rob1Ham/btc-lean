#!/usr/bin/env bash
# Concrete witness table for the SCR-142 pin-vs-model distinction.
# Witness only; the proofs are ../model-cell/{alive2,saw} and ../compare/.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../../../.." && pwd)"
BUILD="$HERE/build"; OUT="$HERE"
mkdir -p "$BUILD"
/usr/bin/clang++-20 -std=c++17 -O1 -I "$HERE/.." "$HERE/driver.cpp" \
  -o "$BUILD/driver"
{
  echo "# probe: findings/wave65/18-scr-142/behavior"
  echo "# compiler: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: behavior/build/driver"
  echo
  "$BUILD/driver"
} > "$OUT/result.txt" 2>&1
FILES=("$HERE/driver.cpp" "$HERE/run.sh" "$OUT/result.txt")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
cat "$OUT/result.txt"
