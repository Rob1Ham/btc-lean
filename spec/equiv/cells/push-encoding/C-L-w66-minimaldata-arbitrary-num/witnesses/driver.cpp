// Concrete witness driver for SCR-051 arbitrary-length numeric operands.
//
// Links the cell's C leaf (source-excerpt slice of Core cce32b168) and checks
// two things against independent expectations written here:
//
//   1. the error-precedence table at the five cited decode sites;
//   2. the policy/consensus lane split and the round-trip characterisation
//        operand is minimal  <=>  serialize(set_vch(operand)) == operand
//      over every 1-byte and 2-byte operand and a deterministic sample of
//      longer ones, at both settings of SCRIPT_VERIFY_MINIMALDATA.
//
// The L leg is not linked here (same symbol names); Alive2 and SAW cover the
// C/L/spec triangle.  This driver is evidence about the C slice, not a proof.
#include <cstdint>
#include <cstdio>
#include "c_leaf.cpp"

namespace {

int g_checks = 0;
int g_fails = 0;

void ck(const char* name, uint64_t got, uint64_t want) {
  ++g_checks;
  if (got != want) {
    ++g_fails;
    std::printf("FAIL %-44s got=0x%016llx want=0x%016llx\n", name,
                (unsigned long long)got, (unsigned long long)want);
  }
}

constexpr uint64_t OK = 0;
constexpr uint64_t SCRIPTNUM = 4;
constexpr uint64_t PUBKEY_COUNT = 10;
constexpr uint64_t OP_COUNT = 7;
constexpr uint64_t SIG_COUNT = 9;
constexpr uint64_t BAD_OPCODE = 16;
constexpr uint64_t INVALID_STACK_OPERATION = 18;
constexpr uint64_t NEGATIVE_LOCKTIME = 21;
constexpr uint64_t TAPSCRIPT_CHECKMULTISIG = 50;

constexpr uint64_t W_MD = 0x40;
constexpr uint64_t W_CLTV = 0x200;
constexpr uint64_t W_CSV = 0x400;

constexpr uint64_t H(uint32_t res, uint32_t err) {
  return (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2);
}

struct B5 {
  uint8_t b0, b1, b2, b3, b4;
};

constexpr B5 z5 = {0, 0, 0, 0, 0};

uint64_t cltv(B5 b, uint32_t len, uint64_t flags, uint16_t depth) {
  return cell_cltv(b.b0, b.b1, b.b2, b.b3, b.b4, len, flags, depth);
}
uint64_t csv(B5 b, uint32_t len, uint64_t flags, uint16_t depth) {
  return cell_csv(b.b0, b.b1, b.b2, b.b3, b.b4, len, flags, depth);
}
uint64_t cms(B5 k, uint32_t klen, B5 s, uint32_t slen, uint64_t flags,
             uint16_t depth, uint16_t opcount, uint8_t sv) {
  return cell_cms(k.b0, k.b1, k.b2, k.b3, k.b4, klen, s.b0, s.b1, s.b2, s.b3,
                  s.b4, slen, flags, depth, opcount, sv);
}
uint64_t csa(B5 b, uint32_t len, uint64_t flags, uint16_t depth, uint8_t sv) {
  return cell_checksigadd(b.b0, b.b1, b.b2, b.b3, b.b4, len, flags, depth, sv);
}

// ---- independent reference decode (LE sign-magnitude, set_vch) ------------

int64_t ref_value(uint64_t p, uint32_t len) {
  if (len == 0) return 0;
  uint64_t raw = 0;
  for (uint32_t i = 0; i < 5; ++i)
    if (i < len) raw |= (uint64_t)((p >> (8 * i)) & 0xffu) << (8 * i);
  const uint64_t sbit = 0x80ull << (8 * (len - 1));
  if ((raw & sbit) != 0) return -(int64_t)(raw & ~sbit);
  return (int64_t)raw;
}

bool ref_nonmin(uint64_t p, uint32_t len) {
  if (len == 0) return false;
  const uint8_t top = (uint8_t)((p >> (8 * (len - 1))) & 0xffu);
  if ((top & 0x7fu) != 0) return false;
  if (len <= 1) return true;
  const uint8_t prev = (uint8_t)((p >> (8 * (len - 2))) & 0xffu);
  return (prev & 0x80u) == 0;
}

}  // namespace

int main() {
  // ---------------- error precedence table --------------------------------
  ck("cltv flag-off NOP", cltv(z5, 0, 0, 0), H(1, OK));
  ck("cltv depth floor beats decode",
     cltv(z5, 0, W_CLTV, 0), H(0, INVALID_STACK_OPERATION));
  { B5 b = {1, 2, 3, 4, 5};
    ck("cltv width cap5 len6", cltv(b, 6, W_CLTV, 1), H(0, SCRIPTNUM));
    ck("cltv width cap5 len6 + md", cltv(b, 6, W_CLTV | W_MD, 1),
       H(0, SCRIPTNUM));
    ck("cltv minimal len5 positive", cltv(b, 5, W_CLTV | W_MD, 1), H(1, OK));
    B5 n = {0xff, 0xff, 0xff, 0xff, 0xff};
    ck("cltv len5 neg magnitude", cltv(n, 5, W_CLTV | W_MD, 1),
       H(0, NEGATIVE_LOCKTIME)); }
  { B5 b = {0x01, 0x00, 0, 0, 0};
    ck("cltv nonminimal padded, md on", cltv(b, 2, W_CLTV | W_MD, 1),
       H(0, SCRIPTNUM));
    ck("cltv same operand, md off (policy)", cltv(b, 2, W_CLTV, 1), H(1, OK)); }
  { B5 b = {0xff, 0x00, 0, 0, 0};
    ck("cltv +255 exception minimal", cltv(b, 2, W_CLTV | W_MD, 1), H(1, OK)); }
  { B5 b = {0xff, 0x80, 0, 0, 0};
    ck("cltv -255 exception minimal", cltv(b, 2, W_CLTV | W_MD, 1),
       H(0, NEGATIVE_LOCKTIME)); }
  { B5 b = {0x80, 0, 0, 0, 0};
    ck("cltv negative zero nonminimal", cltv(b, 1, W_CLTV | W_MD, 1),
       H(0, SCRIPTNUM));
    ck("cltv negative zero md off", cltv(b, 1, W_CLTV, 1), H(1, OK)); }
  { B5 b = {0x00, 0, 0, 0, 0};
    ck("cltv single zero nonminimal", cltv(b, 1, W_CLTV | W_MD, 1),
       H(0, SCRIPTNUM)); }
  { B5 b = {0x01, 0, 0, 0, 0};
    ck("cltv single one minimal", cltv(b, 1, W_CLTV | W_MD, 1), H(1, OK)); }
  { B5 b = {0x81, 0, 0, 0, 0};
    ck("cltv -1 minimal then negative", cltv(b, 1, W_CLTV | W_MD, 1),
       H(0, NEGATIVE_LOCKTIME)); }
  { B5 b = {0x01, 0x80, 0, 0, 0};
    ck("cltv nonminimal -1 -> SCRIPTNUM first",
       cltv(b, 2, W_CLTV | W_MD, 1), H(0, SCRIPTNUM));
    ck("cltv nonminimal -1 md off -> NEGATIVE_LOCKTIME",
       cltv(b, 2, W_CLTV, 1), H(0, NEGATIVE_LOCKTIME)); }

  ck("csv flag-off NOP", csv(z5, 0, 0, 0), H(1, OK));
  ck("csv depth floor beats decode",
     csv(z5, 0, W_CSV, 0), H(0, INVALID_STACK_OPERATION));
  { B5 b = {1, 2, 3, 4, 5};
    ck("csv width cap5 len6", csv(b, 6, W_CSV, 1), H(0, SCRIPTNUM)); }
  { B5 b = {0x01, 0x00, 0, 0, 0};
    ck("csv nonminimal, md on", csv(b, 2, W_CSV | W_MD, 1), H(0, SCRIPTNUM));
    ck("csv nonminimal, md off", csv(b, 2, W_CSV, 1), H(1, OK)); }
  { B5 b = {0x81, 0, 0, 0, 0};
    ck("csv -1 minimal then negative", csv(b, 1, W_CSV | W_MD, 1),
       H(0, NEGATIVE_LOCKTIME)); }

  { B5 k = {1, 2, 3, 4, 5};
    ck("cms tapscript before depth and decode",
       cms(k, 5, z5, 0, W_MD, 0, 0, 2), H(0, TAPSCRIPT_CHECKMULTISIG));
    ck("cms sigversion0 depth0", cms(k, 0, z5, 0, 0, 0, 0, 0),
       H(0, INVALID_STACK_OPERATION));
    ck("cms key width cap4 len5", cms(k, 5, z5, 0, 0, 5, 0, 0),
       H(0, SCRIPTNUM)); }
  { B5 k = {0x15, 0, 0, 0, 0};  // 21
    ck("cms key 21 -> PUBKEY_COUNT", cms(k, 1, z5, 0, 0, 10, 0, 0),
       H(0, PUBKEY_COUNT));
    ck("cms PUBKEY_COUNT before OP_COUNT",
       cms(k, 1, z5, 0, 0, 30, 200, 0), H(0, PUBKEY_COUNT)); }
  { B5 k = {0x14, 0, 0, 0, 0};  // 20
    ck("cms OP_COUNT 201+20", cms(k, 1, z5, 0, 0, 30, 201, 0), H(0, OP_COUNT));
    ck("cms 181+20 == 201 not over", cms(k, 1, z5, 0, 0, 30, 181, 0), H(1, OK));
    ck("cms key arity 20+2", cms(k, 1, z5, 0, 0, 21, 181, 0),
       H(0, INVALID_STACK_OPERATION)); }
  { B5 k = {0x01, 0, 0, 0, 0};
    B5 s = {0x01, 0x00, 0x00, 0x00, 0};
    ck("cms sig width beats SIG_COUNT", cms(k, 1, s, 4, W_MD, 10, 0, 0),
       H(0, SCRIPTNUM)); }
  { B5 k = {0x01, 0, 0, 0, 0};
    B5 s = {0x02, 0, 0, 0, 0};
    ck("cms key<sig -> SIG_COUNT", cms(k, 1, s, 1, W_MD, 10, 0, 0),
       H(0, SIG_COUNT)); }
  { B5 k = {0, 0, 0, 0, 0};
    ck("cms 0-of-0 depth1 -> arity", cms(k, 0, k, 0, 0, 1, 0, 0),
       H(0, INVALID_STACK_OPERATION));
    ck("cms 0-of-0 depth3 -> OK", cms(k, 0, k, 0, 0, 3, 0, 0), H(1, OK)); }
  { B5 k = {0x01, 0x00, 0, 0, 0};
    ck("cms nonminimal key md on", cms(k, 2, z5, 0, W_MD, 10, 0, 0),
       H(0, SCRIPTNUM));
    ck("cms nonminimal key md off", cms(k, 2, z5, 0, 0, 10, 0, 0), H(1, OK)); }

  ck("csa BASE rejected before depth", csa(z5, 0, 0, 0, 0), H(0, BAD_OPCODE));
  ck("csa WITNESS_V0 rejected before depth", csa(z5, 0, 0, 0, 1),
     H(0, BAD_OPCODE));
  ck("csa tapscript depth floor", csa(z5, 0, 0, 2, 2),
     H(0, INVALID_STACK_OPERATION));
  { B5 b = {1, 2, 3, 4, 5};
    ck("csa number width cap4 len5", csa(b, 5, 0, 3, 2), H(0, SCRIPTNUM)); }
  { B5 b = {0x01, 0, 0, 0, 0};
    ck("csa minimal one", csa(b, 1, W_MD, 3, 2), H(1, OK)); }
  { B5 b = {0x01, 0x00, 0, 0, 0};
    ck("csa nonminimal md on", csa(b, 2, W_MD, 3, 2), H(0, SCRIPTNUM));
    ck("csa nonminimal md off", csa(b, 2, 0, 3, 2), H(1, OK)); }
  { B5 b = {0x80, 0, 0, 0, 0};
    ck("csa negative zero md on", csa(b, 1, W_MD, 3, 2), H(0, SCRIPTNUM)); }
  { B5 b = {0x81, 0, 0, 0, 0};
    ck("csa negative value accepted (pushed later)",
       csa(b, 1, W_MD, 3, 2), H(1, OK)); }

  // ---------------- predicate law and policy lane -------------------------
  // For every 1- and 2-byte operand at cap 5: bit 3 (canonical round-trip)
  // equals NOT bit 2 (two-byte minimality test); bit 4 is the sign of the
  // reference decode; bit 5 is zero; bits 8.. are the reference value.
  for (uint32_t len = 1; len <= 2; ++len) {
    const uint32_t n = (len == 1) ? 256u : 65536u;
    for (uint32_t v = 0; v < n; ++v) {
      B5 b = {(uint8_t)v, (uint8_t)(v >> 8), 0, 0, 0};
      const uint64_t p = (uint64_t)b.b0 | ((uint64_t)b.b1 << 8);
      for (int mdi = 0; mdi < 2; ++mdi) {
        const uint64_t fl = mdi ? W_MD : 0;
        const uint64_t o = pred_cap5(b.b0, b.b1, b.b2, b.b3, b.b4, len, fl);
        const bool nonmin = ref_nonmin(p, len);
        const int64_t rv = ref_value(p, len);
        ck("pred rt == !nonmin", (o >> 3) & 1u, nonmin ? 0u : 1u);
        ck("pred nonmin bit", (o >> 2) & 1u, nonmin ? 1u : 0u);
        ck("pred accept lane", o & 1u,
           (mdi && nonmin) ? 0u : 1u);
        ck("pred sign bit", (o >> 4) & 1u, rv < 0 ? 1u : 0u);
        ck("pred zero bit", (o >> 5) & 1u, rv == 0 ? 1u : 0u);
        ck("pred md bit", (o >> 6) & 1u, mdi ? 1u : 0u);
        if (o & 1u)
          ck("pred value field", (o >> 8) & 0x00FFFFFFFFFFFFFFull,
             (uint64_t)rv & 0x00FFFFFFFFFFFFFFull);
      }
    }
  }
  // Deterministic sample of lengths 3..5 (cap 5) plus width rejection at 6..7.
  uint64_t seed = 0x9e3779b97f4a7c15ull;
  for (int i = 0; i < 20000; ++i) {
    seed = seed * 6364136223846793005ull + 1442695040888963407ull;
    B5 b = {(uint8_t)seed, (uint8_t)(seed >> 8), (uint8_t)(seed >> 16),
            (uint8_t)(seed >> 24), (uint8_t)(seed >> 32)};
    const uint32_t len = 3u + (uint32_t)((seed >> 40) % 3u);
    const uint64_t p = (uint64_t)b.b0 | ((uint64_t)b.b1 << 8) |
                       ((uint64_t)b.b2 << 16) | ((uint64_t)b.b3 << 24) |
                       ((uint64_t)b.b4 << 32);
    const uint64_t o = pred_cap5(b.b0, b.b1, b.b2, b.b3, b.b4, len, W_MD);
    const bool nonmin = ref_nonmin(p, len);
    ck("pred rt == !nonmin (len 3..5)", (o >> 3) & 1u, nonmin ? 0u : 1u);
    ck("pred accept lane (len 3..5)", o & 1u, nonmin ? 0u : 1u);
    if (o & 1u)
      ck("pred value (len 3..5)", (o >> 8) & 0x00FFFFFFFFFFFFFFull,
         (uint64_t)ref_value(p, len) & 0x00FFFFFFFFFFFFFFull);
  }
  for (uint32_t len = 6; len <= 7; ++len) {
    B5 b = {1, 2, 3, 4, 5};
    const uint64_t o = pred_cap5(b.b0, b.b1, b.b2, b.b3, b.b4, len, W_MD);
    ck("pred width bit over cap5", (o >> 1) & 1u, 1u);
    ck("pred width rejects", o & 1u, 0u);
    ck("pred width keeps zero bit (observable contract)", (o >> 5) & 1u, 1u);
  }
  for (uint32_t len = 5; len <= 5; ++len) {
    B5 b = {1, 2, 3, 4, 5};
    const uint64_t o = pred_cap5(b.b0, b.b1, b.b2, b.b3, b.b4, len, 0);
    ck("pred cap5 accepts len5 with md off", o & 1u, 1u);
    const uint64_t o4 = pred_cap4(b.b0, b.b1, b.b2, b.b3, b.b4, len, 0);
    ck("pred cap4 rejects len5", o4 & 1u, 0u);
    ck("pred cap4 width bit", (o4 >> 1) & 1u, 1u);
  }

  // Policy lane at a real handler: SCRIPTNUM iff md && nonminimal.
  for (uint32_t len = 0; len <= 2; ++len) {
    const uint32_t n = (len == 0) ? 1u : (len == 1 ? 256u : 65536u);
    for (uint32_t v = 0; v < n; ++v) {
      B5 b = {(uint8_t)v, (uint8_t)(v >> 8), 0, 0, 0};
      const uint64_t p = (uint64_t)b.b0 | ((uint64_t)b.b1 << 8);
      const bool nonmin = ref_nonmin(p, len);
      const uint64_t on = csa(b, len, W_MD, 3, 2);
      const uint64_t off = csa(b, len, 0, 3, 2);
      ck("policy: md on SCRIPTNUM iff nonmin", ((on >> 2) & 0x3fu) == SCRIPTNUM,
         nonmin ? 1u : 0u);
      ck("policy: md off never SCRIPTNUM", ((off >> 2) & 0x3fu) == SCRIPTNUM,
         0u);
      ck("consensus lane: md off accepts", off & 1u, 1u);
    }
  }

  std::printf("checks=%d failures=%d\n", g_checks, g_fails);
  if (g_fails == 0) {
    std::printf("WITNESSES_GREEN\n");
    return 0;
  }
  std::printf("WITNESSES_RED\n");
  return 1;
}
