#include "../compare/compare_common.h"
#include <cstdio>

// Concrete witness table for the SCR-142 pin-vs-model distinction.
// Witness only: the proofs are alive2/ and saw/.
static uint64_t row(uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3,
                    uint32_t height, uint64_t version, uint64_t plen,
                    uint64_t p2sh, uint64_t wn, bool model) {
  const uint64_t f = model ? model_flags(h0, h1, h2, h3, height)
                           : pin_flags(h0, h1, h2, h3, height);
  return gate_and_pack(f, version, plen, p2sh, wn);
}

static void show(const char* label, uint64_t pin, uint64_t model) {
  std::printf("%-52s pin=0x%03llx model=0x%03llx  %s\n", label,
              (unsigned long long)pin, (unsigned long long)model,
              pin == model ? "SAME" : "DIFF");
}

int main() {
  const uint64_t N0 = 0x1111111111111111ull, N1 = 0x2222222222222222ull,
                 N2 = 0x3333333333333333ull, N3 = 0x4444444444444444ull;
  const uint64_t B0 = TAP_BIP16_H0, B1 = TAP_BIP16_H1, B2 = TAP_BIP16_H2,
                 B3 = TAP_BIP16_H3;
  const uint64_t T0 = TAP_TR_H0, T1 = TAP_TR_H1, T2 = TAP_TR_H2,
                 T3 = TAP_TR_H3;
  std::printf("# SCR-142 pin (cce32b168) vs historical BIP9 model (TPR-078)\n");
  std::printf("# packed = result(2) | error(6)<<2 | taproot_on<<8\n");
  std::printf("# v1-32 non-P2SH unless stated; wn = witness item count\n\n");
  show("non-exc h=709631 wn=0 (last pre-activation)",
       row(N0, N1, N2, N3, H709631, 1, 32, 0, 0, false),
       row(N0, N1, N2, N3, H709631, 1, 32, 0, 0, true));
  show("non-exc h=709631 wn=2",
       row(N0, N1, N2, N3, H709631, 1, 32, 0, 2, false),
       row(N0, N1, N2, N3, H709631, 1, 32, 0, 2, true));
  show("non-exc h=709632 wn=0 (activation)",
       row(N0, N1, N2, N3, H709632, 1, 32, 0, 0, false),
       row(N0, N1, N2, N3, H709632, 1, 32, 0, 0, true));
  show("non-exc h=709632 wn=2",
       row(N0, N1, N2, N3, H709632, 1, 32, 0, 2, false),
       row(N0, N1, N2, N3, H709632, 1, 32, 0, 2, true));
  show("taproot exc (..1e395ad) h=692261 wn=0",
       row(T0, T1, T2, T3, H_EXC, 1, 32, 0, 0, false),
       row(T0, T1, T2, T3, H_EXC, 1, 32, 0, 0, true));
  show("taproot exc (..1e395ad) h=709632 wn=0",
       row(T0, T1, T2, T3, H709632, 1, 32, 0, 0, false),
       row(T0, T1, T2, T3, H709632, 1, 32, 0, 0, true));
  show("bip16 exc (..4f9c22) h=170060 wn=0",
       row(B0, B1, B2, B3, 170060u, 1, 32, 0, 0, false),
       row(B0, B1, B2, B3, 170060u, 1, 32, 0, 0, true));
  show("non-exc h=709631 v1 plen=31",
       row(N0, N1, N2, N3, H709631, 1, 31, 0, 0, false),
       row(N0, N1, N2, N3, H709631, 1, 31, 0, 0, true));
  show("non-exc h=709631 v1 plen=32 p2sh=1",
       row(N0, N1, N2, N3, H709631, 1, 32, 1, 0, false),
       row(N0, N1, N2, N3, H709631, 1, 32, 1, 0, true));
  show("non-exc h=709631 v0 plen=32",
       row(N0, N1, N2, N3, H709631, 0, 32, 0, 0, false),
       row(N0, N1, N2, N3, H709631, 0, 32, 0, 0, true));
  show("non-exc h=0 wn=0 (genesis-height shape)",
       row(N0, N1, N2, N3, 0u, 1, 32, 0, 0, false),
       row(N0, N1, N2, N3, 0u, 1, 32, 0, 0, true));
  return 0;
}
