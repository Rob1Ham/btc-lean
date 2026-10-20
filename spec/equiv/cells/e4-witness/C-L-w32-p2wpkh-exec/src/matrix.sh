#!/usr/bin/env bash
# Concrete sanity matrix for the C leg (not a proof): decode the packed
# observable on the row's branch edges.  Evidence only; the proof is
# alive2/run.sh + saw/run.sh.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
cat > "$BUILD/matrix.cpp" <<'CPP'
#include <cstdio>
#include <cstdint>
extern "C" uint64_t cell_p2wpkh_exec(uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t);
static void row(const char* name, uint64_t r) {
  std::printf("%-34s packed=0x%02llx result=%llu error=%llu\n", name,
              (unsigned long long)r, (unsigned long long)(r & 3),
              (unsigned long long)((r >> 2) & 0x3f));
}
int main() {
  const uint64_t p0 = 0x0706050403020100ull;
  const uint64_t p1 = 0x0f0e0d0c0b0a0908ull;
  const uint64_t p2 = 0x13121110ull;
  const uint64_t h0 = 0x0706050403020100ull;
  const uint64_t h1 = 0x0f0e0d0c0b0a0908ull;
  const uint64_t h2 = 0x13121110ull;
  row("ok", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0,h1,h2, 0, 1));
  row("checksig false", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0,h1,h2, 0, 0));
  row("hash mismatch (byte 0)", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0^1,h1,h2, 0, 1));
  row("hash mismatch (byte 19)", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0,h1,h2^0x01000000ull, 0, 1));
  row("hash high bits ignored", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0,h1,h2|0xffffffff00000000ull, 0, 1));
  row("checksig DER error 24", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0,h1,h2, 24, 1));
  row("checksig error, mismatch wins", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0^1,h1,h2, 24, 1));
  row("arity 1 -> mismatch", cell_p2wpkh_exec(p0,p1,p2, 1, 73, 33, h0,h1,h2, 0, 1));
  row("arity 3 -> mismatch", cell_p2wpkh_exec(p0,p1,p2, 3, 73, 33, h0,h1,h2, 0, 1));
  row("sig 520 (boundary)", cell_p2wpkh_exec(p0,p1,p2, 2, 520, 33, h0,h1,h2, 0, 1));
  row("sig 521 -> push size", cell_p2wpkh_exec(p0,p1,p2, 2, 521, 33, h0,h1,h2, 0, 1));
  row("pk 521 -> push size", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 521, h0,h1,h2, 0, 1));
  row("checksig err low 6 bits (64->0)", cell_p2wpkh_exec(p0,p1,p2, 2, 73, 33, h0,h1,h2, 64, 1));
  return 0;
}
CPP
/usr/bin/clang++-20 -std=c++17 -O1 -I "$CELL_DIR/src" \
  "$CELL_DIR/src/c_leaf.cpp" "$BUILD/matrix.cpp" -o "$BUILD/matrix"
"$BUILD/matrix" | tee "$BUILD/matrix.txt"
