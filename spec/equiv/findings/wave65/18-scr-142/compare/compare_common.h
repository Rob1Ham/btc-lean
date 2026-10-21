#ifndef FINDINGS_W65_18_SCR142_COMPARE_COMMON_H
#define FINDINGS_W65_18_SCR142_COMPARE_COMMON_H
#include <cstdint>

// SCR-142 pin-vs-model probe (finding-scoped).
//
// One exported symbol `cell_compare` is compiled six times with -DVARIANT=n:
//   1 pin slice   @ height 709631   (cce32b168, height-inert TAPROOT)
//   2 pin slice   @ height 709632
//   3 BIP9 model  @ height 709631   (TPR-078 threshold)
//   4 BIP9 model  @ height 709632
//   5 pin slice   @ exception hash, height 692261
//   6 BIP9 model  @ exception hash, height 692261
//
// Alive2 pairs then localise the difference: the pin is height-inert
// (1==2), the model is not (3!=4), they agree at activation (2==4) and at
// the exception block (5==6), and they differ exactly below activation
// (1!=3).  This is a MACHINE-CHECKED INEQUIVALENCE, i.e. evidence that the
// historical height clause cannot be a cce32b168 property.

#define TAP_INLINE static inline __attribute__((always_inline))

TAP_INLINE uint64_t tap_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}
enum { TAP_FAIL = 0, TAP_OK = 1, TAP_CONTINUE = 2, TAP_OUTSIDE = 3 };
enum { TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY = 39 };

enum : uint64_t {
  TAP_SV_NONE      = 0,
  TAP_SV_P2SH      = 1ull << 0,
  TAP_SV_DERSIG    = 1ull << 2,
  TAP_SV_NULLDUMMY = 1ull << 4,
  TAP_SV_CLTV      = 1ull << 9,
  TAP_SV_CSV       = 1ull << 10,
  TAP_SV_WITNESS   = 1ull << 11,
  TAP_SV_TAPROOT   = 1ull << 17,
};

constexpr uint32_t TAP_BIP66_HEIGHT  = 363725;
constexpr uint32_t TAP_BIP65_HEIGHT  = 388381;
constexpr uint32_t TAP_CSV_HEIGHT    = 419328;
constexpr uint32_t TAP_SEGWIT_HEIGHT = 481824;
constexpr uint32_t TAP_BIP9_TAPROOT_ACTIVATION_HEIGHT = 709632;
constexpr uint32_t H709631 = 709631u;
constexpr uint32_t H709632 = 709632u;
constexpr uint32_t H_EXC   = 692261u;

constexpr uint64_t TAP_BIP16_H0 = 0x00000000000002dcull;
constexpr uint64_t TAP_BIP16_H1 = 0x756eebf4f49723edull;
constexpr uint64_t TAP_BIP16_H2 = 0x8d30cc28a5f108ebull;
constexpr uint64_t TAP_BIP16_H3 = 0x94b1ba88ac4f9c22ull;
constexpr uint64_t TAP_TR_H0 = 0x0000000000000000ull;
constexpr uint64_t TAP_TR_H1 = 0x000f14c35b2d841eull;
constexpr uint64_t TAP_TR_H2 = 0x986ab5441de8c585ull;
constexpr uint64_t TAP_TR_H3 = 0xd5ffe55ea1e395adull;

TAP_INLINE bool is_bip16_exc(uint64_t h0, uint64_t h1, uint64_t h2,
                             uint64_t h3) {
  return h0 == TAP_BIP16_H0 && h1 == TAP_BIP16_H1 &&
         h2 == TAP_BIP16_H2 && h3 == TAP_BIP16_H3;
}
TAP_INLINE bool is_tr_exc(uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3) {
  return h0 == TAP_TR_H0 && h1 == TAP_TR_H1 &&
         h2 == TAP_TR_H2 && h3 == TAP_TR_H3;
}

// Pinned cce32b168 slice: always-on base, exception replaces, buried ORs.
// validation.cpp:2249-2288.
TAP_INLINE uint64_t pin_flags(uint64_t h0, uint64_t h1, uint64_t h2,
                              uint64_t h3, uint32_t height) {
  uint64_t flags = TAP_SV_P2SH | TAP_SV_WITNESS | TAP_SV_TAPROOT;
  if (is_bip16_exc(h0, h1, h2, h3)) {
    flags = TAP_SV_NONE;
  } else if (is_tr_exc(h0, h1, h2, h3)) {
    flags = TAP_SV_P2SH | TAP_SV_WITNESS;
  }
  if (height >= TAP_BIP66_HEIGHT)  flags |= TAP_SV_DERSIG;
  if (height >= TAP_BIP65_HEIGHT)  flags |= TAP_SV_CLTV;
  if (height >= TAP_CSV_HEIGHT)    flags |= TAP_SV_CSV;
  if (height >= TAP_SEGWIT_HEIGHT) flags |= TAP_SV_NULLDUMMY;
  return flags;
}

// Historical BIP9 threshold model (TPR-075/076/078): TAPROOT iff
// 709632 <= height, exception replaces.  NOT cce32b168.
TAP_INLINE uint64_t model_flags(uint64_t h0, uint64_t h1, uint64_t h2,
                                uint64_t h3, uint32_t height) {
  uint64_t flags = TAP_SV_P2SH | TAP_SV_WITNESS;
  if (TAP_BIP9_TAPROOT_ACTIVATION_HEIGHT <= height) flags |= TAP_SV_TAPROOT;
  if (is_bip16_exc(h0, h1, h2, h3)) {
    flags = TAP_SV_NONE;
  } else if (is_tr_exc(h0, h1, h2, h3)) {
    flags = TAP_SV_P2SH | TAP_SV_WITNESS;
  }
  if (height >= TAP_BIP66_HEIGHT)  flags |= TAP_SV_DERSIG;
  if (height >= TAP_BIP65_HEIGHT)  flags |= TAP_SV_CLTV;
  if (height >= TAP_CSV_HEIGHT)    flags |= TAP_SV_CSV;
  if (height >= TAP_SEGWIT_HEIGHT) flags |= TAP_SV_NULLDUMMY;
  return flags;
}

TAP_INLINE uint64_t gate_and_pack(uint64_t flags, uint64_t version,
                                  uint64_t plen, uint64_t p2sh,
                                  uint64_t wn) {
  uint64_t gate;
  if (version == 1u && plen == 32u && p2sh == 0u) {
    if (!(flags & TAP_SV_TAPROOT)) {
      gate = tap_pack(TAP_OK, 0u);
    } else if (wn == 0u) {
      gate = tap_pack(TAP_FAIL, TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
    } else {
      gate = tap_pack(TAP_CONTINUE, 0u);
    }
  } else {
    gate = tap_pack(TAP_OUTSIDE, 0u);
  }
  return gate | (((flags & TAP_SV_TAPROOT) != 0u ? 1u : 0u) << 8);
}

#endif
