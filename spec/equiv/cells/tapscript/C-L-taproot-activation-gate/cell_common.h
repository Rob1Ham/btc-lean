#ifndef CELLS_TAPSCRIPT_TAPROOT_ACTIVATION_GATE_COMMON_H
#define CELLS_TAPSCRIPT_TAPROOT_ACTIVATION_GATE_COMMON_H
#include <cstdint>

#define TAP_INLINE static inline __attribute__((always_inline))

// Packed observable: result(2) | error_ordinal(6) << 2 | taproot_on(1) << 8.
//
// result 0 = failure (error field = Core ScriptError ordinal)
//        1 = success (Core set_success / Lean .ok)
//        2 = continuation into the annex/key/script dispatch (sibling cells)
//        3 = shape outside the v1-32 non-P2SH arm
// Codes 2 and 3 are cell-harness markers, not engine results.
//
// taproot_on is the SCRIPT_VERIFY_TAPROOT bit of GetBlockScriptFlags
// (validation.cpp:2249-2288) projected to one bit.  It is carried as an
// explicit observable so the activation/exception claim is checked, not
// implicit in the gate branch.
TAP_INLINE uint64_t tap_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

enum { TAP_FAIL = 0, TAP_OK = 1, TAP_CONTINUE = 2, TAP_OUTSIDE = 3 };

// contract/error_enum.md:69, contract/error_kind.h:78
enum { TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY = 39 };

// script_verify_flags bit values at the pin:
//   src/script/verify_flags.h:31 (`value_type{1} << static_cast<uint8_t>(f)`)
//   with the ordinals in src/script/interpreter.h:49-153.
enum : uint64_t {
  TAP_SV_NONE       = 0,
  TAP_SV_P2SH       = 1ull << 0,
  TAP_SV_DERSIG     = 1ull << 2,   // BIP66
  TAP_SV_NULLDUMMY  = 1ull << 4,   // BIP147 (rides segwit)
  TAP_SV_CLTV       = 1ull << 9,   // BIP65
  TAP_SV_CSV        = 1ull << 10,  // BIP112
  TAP_SV_WITNESS    = 1ull << 11,  // BIP141
  TAP_SV_TAPROOT    = 1ull << 17,  // BIP341
};

// Mainnet buried heights (kernel/chainparams.cpp:119-124 at the pin).
constexpr uint32_t TAP_BIP34_HEIGHT  = 227931;
constexpr uint32_t TAP_BIP66_HEIGHT  = 363725;   // DERSIG
constexpr uint32_t TAP_BIP65_HEIGHT  = 388381;   // CLTV
constexpr uint32_t TAP_CSV_HEIGHT    = 419328;   // CSV
constexpr uint32_t TAP_SEGWIT_HEIGHT = 481824;   // NULLDUMMY
// Historical taproot BIP9 activation height, from the comment at
// kernel/chainparams.cpp:125 (`MinBIP9WarningHeight = 711648; // taproot
// activation height + miner confirmation window`).  It is NOT a term in the
// pinned GetBlockScriptFlags; see GAP-CONTEXT.md.
constexpr uint32_t TAP_TAPROOT_ACTIVATION_HEIGHT = 709632;

// Heights of the two script_flag_exceptions blocks on mainnet.  Core keys
// the map by block hash; the height pair is informational and matches
// spec/core/Bitcoin/Activation/Flags.lean:42-57.
constexpr uint32_t TAP_BIP16_EXCEPTION_HEIGHT   = 170060;
constexpr uint32_t TAP_TAPROOT_EXCEPTION_HEIGHT = 692261;

// kernel/chainparams.cpp:115-116 -- BIP16 exception block hash
// 00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22
constexpr uint64_t TAP_BIP16_H0 = 0x00000000000002dcull;
constexpr uint64_t TAP_BIP16_H1 = 0x756eebf4f49723edull;
constexpr uint64_t TAP_BIP16_H2 = 0x8d30cc28a5f108ebull;
constexpr uint64_t TAP_BIP16_H3 = 0x94b1ba88ac4f9c22ull;

// kernel/chainparams.cpp:117-118 -- taproot exception block hash
// 0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad
constexpr uint64_t TAP_TR_H0 = 0x0000000000000000ull;
constexpr uint64_t TAP_TR_H1 = 0x000f14c35b2d841eull;
constexpr uint64_t TAP_TR_H2 = 0x986ab5441de8c585ull;
constexpr uint64_t TAP_TR_H3 = 0xd5ffe55ea1e395adull;

#endif
