#!/usr/bin/env bash
# Concrete sanity matrix for the C leg (not a proof): decode both exports on
# the row's edges and on the oracle-interface selectors.  Evidence only; the
# proofs are alive2/run.sh + saw/run.sh.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$CELL_DIR/build"
EVID="$CELL_DIR/evidence"
mkdir -p "$BUILD" "$EVID"
cat > "$BUILD/matrix.cpp" <<'CPP'
#include <cstdio>
#include <cstdint>
#include <cassert>

extern "C" uint64_t cell_p2wpkh_scr136(uint64_t,uint64_t,uint64_t,uint64_t,
                                       uint64_t,uint64_t,uint64_t,uint64_t,
                                       uint64_t,uint64_t,uint64_t);
extern "C" uint64_t cell_p2wpkh_seam(uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t,
                                     uint64_t,uint64_t,uint64_t,uint64_t);

static const uint64_t SENT = 0xffffffffffffffffull;

static void row(const char* name, uint64_t r) {
  if (r == SENT)
    std::printf("%-40s sentinel=SENT\n", name);
  else
    std::printf("%-40s packed=0x%02llx result=%llu error=%llu word=0x%016llx\n",
                name, (unsigned long long)r, (unsigned long long)(r & 3),
                (unsigned long long)((r >> 2) & 0x3f),
                (unsigned long long)r);
}

// Transcript rows are raw 64-bit words (or the sentinel), not packed verdicts.
static void wrow(const char* name, uint64_t r) {
  if (r == SENT)
    std::printf("%-40s word=SENT\n", name);
  else
    std::printf("%-40s word=0x%016llx\n", name, (unsigned long long)r);
}

// Shared fixtures.
static const uint64_t P0 = 0x0706050403020100ull;  // program bytes 00..07
static const uint64_t P1 = 0x0f0e0d0c0b0a0908ull;  // 08..15
static const uint64_t P2 = 0x13121110ull;          // 16..19
static const uint64_t H0 = P0, H1 = P1, H2 = P2;   // program == hash

static const uint64_t S0 = 0x0706050403020100ull;
static const uint64_t S1 = 0x0f0e0d0c0b0a0908ull;
static const uint64_t S2 = 0x1716151413121110ull;
static const uint64_t S3 = 0x1f1e1d1c1b1a1918ull;
static const uint64_t S4 = 0x2726252423222120ull;
static const uint64_t S5 = 0x2f2e2d2c2b2a2928ull;
static const uint64_t S6 = 0x3736353433323130ull;
static const uint64_t S7 = 0x3f3e3d3c3b3a3938ull;
static const uint64_t S8 = 0x4746454443424140ull;
static const uint64_t S9 = 0x4f4e4d4c4b4a4948ull;
static const uint64_t K0 = 0x0706050403020100ull;
static const uint64_t K1 = 0x0f0e0d0c0b0a0908ull;
static const uint64_t K2 = 0x1716151413121110ull;
static const uint64_t K3 = 0x1f1e1d1c1b1a1918ull;
static const uint64_t K4 = 0x0000000000002021ull;  // byte 32 = 0x21
static const uint64_t K5 = 0x2f2e2d2c2b2a2928ull;
static const uint64_t K6 = 0x3736353433323130ull;
static const uint64_t K7 = 0x3f3e3d3c3b3a3938ull;
static const uint64_t K8 = 0x4746454443424140ull;

#define SEAM(sel,k,p0,p1,p2,nw,sl,pl,h0,h1,h2,ce,co) \
  cell_p2wpkh_seam((sel),(k),(p0),(p1),(p2),(nw),(sl),(pl),(h0),(h1),(h2), \
                   (ce),(co), S0,S1,S2,S3,S4,S5,S6,S7,S8,S9, \
                   K0,K1,K2,K3,K4,K5,K6,K7,K8)

int main() {
  std::printf("# (A) outcome export\n");
  row("ok", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0,H1,H2, 0, 1));
  row("checksig false", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0,H1,H2, 0, 0));
  row("hash mismatch (byte 0)", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0^1,H1,H2, 0, 1));
  row("hash mismatch (byte 19)", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0,H1,H2^0x01000000ull, 0, 1));
  row("hash high bits ignored", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0,H1,H2|0xffffffff00000000ull, 0, 1));
  row("checksig DER error 24", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0,H1,H2, 24, 1));
  row("checksig error, mismatch wins", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0^1,H1,H2, 24, 1));
  row("arity 1 -> mismatch", cell_p2wpkh_scr136(P0,P1,P2, 1, 73, 33, H0,H1,H2, 0, 1));
  row("sig 520 (boundary)", cell_p2wpkh_scr136(P0,P1,P2, 2, 520, 33, H0,H1,H2, 0, 1));
  row("sig 521 -> push size", cell_p2wpkh_scr136(P0,P1,P2, 2, 521, 33, H0,H1,H2, 0, 1));
  row("checksig err low 6 bits (64->0)", cell_p2wpkh_scr136(P0,P1,P2, 2, 73, 33, H0,H1,H2, 64, 1));

  std::printf("# (B) oracle-interface export\n");
  wrow("sel0 HASH160 preimage word 0", SEAM(0,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel0 preimage word 4 (byte 32 only)", SEAM(0,4,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel0 preimage word 5 (past pk_len)", SEAM(0,5,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel0 preimage word 0, pk_len 0", SEAM(0,0,P0,P1,P2,2,73,0,H0,H1,H2,0,1));
  wrow("sel4 HASH160 preimage length", SEAM(4,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel5 HASH160 output width", SEAM(5,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel1 checksig sig word 0", SEAM(1,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel1 checksig sig word 9", SEAM(1,9,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel1 checksig sig word 10", SEAM(1,10,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel2 checksig pubkey word 0", SEAM(2,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel3 scriptCode word 0", SEAM(3,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel3 scriptCode word 3 (byte 24)", SEAM(3,3,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel6 checksig sig length", SEAM(6,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel7 checksig pubkey length", SEAM(7,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel8 checksig scriptCode length", SEAM(8,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));

  std::printf("# (B) sentinel / precedence / truncation edges\n");
  wrow("sel2, hash mismatch -> sentinel", SEAM(2,0,P0,P1,P2,2,73,33,H0^1,H1,H2,0,1));
  wrow("sel1, n_wit 1 -> sentinel", SEAM(1,0,P0,P1,P2,1,73,33,H0,H1,H2,0,1));
  wrow("sel0, sig_len 521 -> sentinel", SEAM(0,0,P0,P1,P2,2,521,33,H0,H1,H2,0,1));
  wrow("sel1, pk_len 521 -> sentinel", SEAM(1,0,P0,P1,P2,2,73,521,H0,H1,H2,0,1));
  wrow("sel none (0xffffffff) -> sentinel", SEAM(0xffffffffull,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel 9 (outside slice) -> sentinel", SEAM(9,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("sel 2^32 truncates to 0 (preimage)", SEAM(0x100000000ull,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("k 2^32+4 truncates to 4", SEAM(0,0x100000004ull,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  wrow("ck_err/ck_ok do not affect transcript", SEAM(0,0,P0,P1,P2,2,73,33,H0,H1,H2,24,0));

  // Independent spot checks on the interesting words.
  assert(SEAM(0,4,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == 0x21ull);
  assert(SEAM(0,5,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == 0ull);
  assert(SEAM(3,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == 0x040302010014a976ull);
  assert(SEAM(3,3,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == 0xacull);
  assert(SEAM(4,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == 33ull);
  assert(SEAM(5,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == 20ull);
  assert(SEAM(8,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == 25ull);
  assert(SEAM(0x100000000ull,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1) == SEAM(0,0,P0,P1,P2,2,73,33,H0,H1,H2,0,1));
  std::printf("# asserts: OK\n");
  return 0;
}
CPP
/usr/bin/clang++-20 -std=c++17 -O1 -I "$CELL_DIR/src" \
  "$CELL_DIR/src/c_leaf.cpp" "$BUILD/matrix.cpp" -o "$BUILD/matrix"
"$BUILD/matrix" | tee "$BUILD/matrix.txt" | tee "$EVID/matrix.txt"
