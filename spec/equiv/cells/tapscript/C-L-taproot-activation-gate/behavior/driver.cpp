// Concrete behavior witness for C-L-taproot-activation-gate.
//
// NOT proof evidence: this is the human-readable table that names the
// SCR-142 corners (exception hash, activation-height boundary, pre-activation
// inertness).  The proof evidence is alive2/result.txt and saw/result.txt.
#include "cell_common.h"

#include <cstdio>
#include <cstdint>

extern "C" uint64_t cell_taproot_activation(
    uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3, uint32_t height,
    uint64_t version, uint64_t program_len, uint64_t is_p2sh,
    uint64_t witness_n);

namespace {

struct Vec {
  const char* name;
  uint64_t h0, h1, h2, h3;
  uint32_t height;
  uint64_t version, plen, p2sh, wn;
  uint64_t expect;
};

uint64_t run(const Vec& v) {
  return cell_taproot_activation(v.h0, v.h1, v.h2, v.h3, v.height,
                                 v.version, v.plen, v.p2sh, v.wn);
}

void print(const Vec& v, uint64_t got) {
  std::printf("%-46s h=%u v=%llu plen=%llu p2sh=%llu wn=%llu -> 0x%03llx"
              " (result=%llu err=%llu taproot=%llu)%s\n",
              v.name, v.height,
              (unsigned long long)v.version, (unsigned long long)v.plen,
              (unsigned long long)v.p2sh, (unsigned long long)v.wn,
              (unsigned long long)got,
              (unsigned long long)(got & 3u),
              (unsigned long long)((got >> 2) & 0x3fu),
              (unsigned long long)((got >> 8) & 1u),
              got == v.expect ? "  [ok]" : "  [MISMATCH]");
}

}  // namespace

int main() {
  // 0x0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad
  const uint64_t arbitrary[4] = {0x0123456789abcdefull, 0xfedcba9876543210ull,
                                 0x0f1e2d3c4b5a6978ull, 0x8877665544332211ull};
  const uint64_t near_taproot[4] = {TAP_TR_H0, TAP_TR_H1, TAP_TR_H2,
                                    TAP_TR_H3 ^ 1ull};

  const Vec vecs[] = {
      // SCR-142 exception arm: the taproot-violating block, hash-keyed.
      {"taproot exception hash, its height", TAP_TR_H0, TAP_TR_H1, TAP_TR_H2,
       TAP_TR_H3, TAP_TAPROOT_EXCEPTION_HEIGHT, 1, 32, 0, 0, 1},
      {"taproot exception hash, activation height", TAP_TR_H0, TAP_TR_H1,
       TAP_TR_H2, TAP_TR_H3, TAP_TAPROOT_ACTIVATION_HEIGHT, 1, 32, 0, 0, 1},
      {"taproot exception hash, non-empty witness", TAP_TR_H0, TAP_TR_H1,
       TAP_TR_H2, TAP_TR_H3, TAP_TAPROOT_EXCEPTION_HEIGHT, 1, 32, 0, 3, 1},
      // BIP16 exception hash also clears TAPROOT at the pin (SCRIPT_VERIFY_NONE).
      {"bip16 exception hash, its height", TAP_BIP16_H0, TAP_BIP16_H1,
       TAP_BIP16_H2, TAP_BIP16_H3, TAP_BIP16_EXCEPTION_HEIGHT, 1, 32, 0, 0, 1},
      // Activation boundary, no exception: identical on both sides of 709632.
      {"last pre-activation height 709631, empty", arbitrary[0], arbitrary[1],
       arbitrary[2], arbitrary[3], TAP_TAPROOT_ACTIVATION_HEIGHT - 1, 1, 32, 0,
       0, 412},
      {"activation height 709632, empty", arbitrary[0], arbitrary[1],
       arbitrary[2], arbitrary[3], TAP_TAPROOT_ACTIVATION_HEIGHT, 1, 32, 0, 0,
       412},
      {"activation height 709632, non-empty", arbitrary[0], arbitrary[1],
       arbitrary[2], arbitrary[3], TAP_TAPROOT_ACTIVATION_HEIGHT, 1, 32, 0, 2,
       258},
      // Fail-closed lookup: three matching limbs are not an exception.
      {"near-miss hash, last limb flipped", near_taproot[0], near_taproot[1],
       near_taproot[2], near_taproot[3], TAP_TAPROOT_ACTIVATION_HEIGHT, 1, 32,
       0, 0, 412},
      // Outside the arm.
      {"v1 31-byte program", arbitrary[0], arbitrary[1], arbitrary[2],
       arbitrary[3], TAP_TAPROOT_ACTIVATION_HEIGHT, 1, 31, 0, 0, 259},
      {"v1 32-byte P2SH-wrapped", arbitrary[0], arbitrary[1], arbitrary[2],
       arbitrary[3], TAP_TAPROOT_ACTIVATION_HEIGHT, 1, 32, 1, 0, 259},
      {"v0 32-byte program", arbitrary[0], arbitrary[1], arbitrary[2],
       arbitrary[3], TAP_TAPROOT_ACTIVATION_HEIGHT, 0, 32, 0, 0, 259},
  };

  int bad = 0;
  for (const Vec& v : vecs) {
    const uint64_t got = run(v);
    print(v, got);
    if (got != v.expect) ++bad;
  }
  std::printf("vectors=%zu mismatches=%d\n", sizeof(vecs) / sizeof(vecs[0]), bad);
  if (bad != 0) {
    std::printf("STATUS=behavior-mismatch\n");
    return 1;
  }
  std::printf("STATUS=behavior-match\n");
  return 0;
}
