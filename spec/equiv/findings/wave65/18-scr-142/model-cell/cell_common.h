#ifndef FINDINGS_W65_18_SCR142_MODEL_CELL_COMMON_H
#define FINDINGS_W65_18_SCR142_MODEL_CELL_COMMON_H
#include <cstdint>

// SCR-142 historical-window MODEL cell (finding-scoped, not a ledger cell).
//
// THIS IS NOT A cce32b168 RESULT.  The C and L legs below are two
// transliterations of the *historical* taproot BIP9 height abstraction
// recorded in spec/core/Bitcoin/Activation/Taproot.lean (TPR-075/076/078).
// The pinned Core tree has no DEPLOYMENT_TAPROOT and no height term on the
// TAPROOT bit (validation.cpp:2249-2288 @cce32b168), so no C source at the
// pin implements the gate this cell models.  The pin-vs-model probe next to
// this cell (../compare/) machine-checks that the model and the pin differ at
// height 709631 and agree at 709632 / at the exception block.
//
// The ABI here is CELL-LOCAL: the entry takes a block hash (four 64-bit
// limbs, equality only) and a uint32 block height.  contract/tape.md is NOT
// changed; this is the "add height/hash to the cell-local tape/ABI" option
// named in the row's gap record.

#define TAP_INLINE static inline __attribute__((always_inline))

// Packed observable: result(2) | error_ordinal(6) << 2 | taproot_on(1) << 8.
TAP_INLINE uint64_t tap_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

enum { TAP_FAIL = 0, TAP_OK = 1, TAP_CONTINUE = 2, TAP_OUTSIDE = 3 };

// contract/error_enum.md:69, contract/error_kind.h:78
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

// Mainnet buried heights (kernel/chainparams.cpp:119-124 @cce32b168).
constexpr uint32_t TAP_BIP66_HEIGHT  = 363725;
constexpr uint32_t TAP_BIP65_HEIGHT  = 388381;
constexpr uint32_t TAP_CSV_HEIGHT    = 419328;
constexpr uint32_t TAP_SEGWIT_HEIGHT = 481824;

// TPR-075 / bip-0341:346-347: min_activation_height = 709632.
// TPR-078: deploymentActiveAt d height := d.minActivation <= height.
constexpr uint32_t TAP_BIP9_TAPROOT_ACTIVATION_HEIGHT = 709632;

// kernel/chainparams.cpp:115-118 @cce32b168 (also TPR-076).
constexpr uint64_t TAP_BIP16_H0 = 0x00000000000002dcull;
constexpr uint64_t TAP_BIP16_H1 = 0x756eebf4f49723edull;
constexpr uint64_t TAP_BIP16_H2 = 0x8d30cc28a5f108ebull;
constexpr uint64_t TAP_BIP16_H3 = 0x94b1ba88ac4f9c22ull;

constexpr uint64_t TAP_TR_H0 = 0x0000000000000000ull;
constexpr uint64_t TAP_TR_H1 = 0x000f14c35b2d841eull;
constexpr uint64_t TAP_TR_H2 = 0x986ab5441de8c585ull;
constexpr uint64_t TAP_TR_H3 = 0xd5ffe55ea1e395adull;

#endif
