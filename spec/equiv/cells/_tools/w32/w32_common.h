// w32_common.h -- shared harness constants for the wave-32 exec-verify cells.
//
// This header is CELL HARNESS, not engine code.  Every constant is a
// line-cited transcription of the pinned Core tree:
//
//   * script flag bit values: 1 << ordinal, src/script/verify_flags.h:31
//     (`value_type{1} << static_cast<uint8_t>(f)`) with the ordinals from
//     src/script/interpreter.h:49-153 at pin cce32b168.
//   * mainnet buried heights: src/kernel/chainparams.cpp:119-124.
//   * mainnet script_flag_exceptions: src/kernel/chainparams.cpp:115-118.
//   * error ordinals: contract/error_kind.h (Core script_error.h at the pin).
//
// The 256-bit exception hashes are carried as four 64-bit limbs of the
// displayed hex string.  Equality is the only operation, so the limb
// grouping is a representation choice, not a semantic one.
#pragma once

#include <cstdint>
#include <cstddef>

namespace w32 {

// script_verify_flags bit values (verify_flags.h:31 + interpreter.h ordinals)
enum : uint64_t {
    SCRIPT_VERIFY_NONE = 0,
    SCRIPT_VERIFY_P2SH = 1ull << 0,                          // interpreter.h:50-51
    SCRIPT_VERIFY_STRICTENC = 1ull << 1,
    SCRIPT_VERIFY_DERSIG = 1ull << 2,                        // BIP66
    SCRIPT_VERIFY_LOW_S = 1ull << 3,
    SCRIPT_VERIFY_NULLDUMMY = 1ull << 4,                     // BIP147
    SCRIPT_VERIFY_SIGPUSHONLY = 1ull << 5,
    SCRIPT_VERIFY_MINIMALDATA = 1ull << 6,
    SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS = 1ull << 7,
    SCRIPT_VERIFY_CLEANSTACK = 1ull << 8,
    SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY = 1ull << 9,           // BIP65
    SCRIPT_VERIFY_CHECKSEQUENCEVERIFY = 1ull << 10,          // BIP112
    SCRIPT_VERIFY_WITNESS = 1ull << 11,                      // BIP141
    SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM = 1ull << 12,
    SCRIPT_VERIFY_MINIMALIF = 1ull << 13,
    SCRIPT_VERIFY_NULLFAIL = 1ull << 14,
    SCRIPT_VERIFY_WITNESS_PUBKEYTYPE = 1ull << 15,
    SCRIPT_VERIFY_CONST_SCRIPTCODE = 1ull << 16,
    SCRIPT_VERIFY_TAPROOT = 1ull << 17,                      // BIP341
    SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION = 1ull << 18,
    SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS = 1ull << 19,
    SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_PUBKEYTYPE = 1ull << 20,
};

// Mainnet buried deployment heights (kernel/chainparams.cpp:119-124 at pin).
constexpr uint32_t BIP34_HEIGHT = 227931;
constexpr uint32_t BIP66_HEIGHT = 363725;  // DERSIG
constexpr uint32_t BIP65_HEIGHT = 388381;  // CHECKLOCKTIMEVERIFY
constexpr uint32_t CSV_HEIGHT = 419328;    // CHECKSEQUENCEVERIFY
constexpr uint32_t SEGWIT_HEIGHT = 481824; // NULLDUMMY rides segwit

// Heights of the two script_flag_exceptions blocks on mainnet.  The
// hash<->height pairs are the ones recorded in
// spec/core/Bitcoin/Activation/Flags.lean:42-57 (verified 2026-10-16).
constexpr uint32_t BIP16_EXCEPTION_HEIGHT = 170060;
constexpr uint32_t TAPROOT_EXCEPTION_HEIGHT = 692261;

// kernel/chainparams.cpp:115-116 -- BIP16 exception block hash
// 00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22
constexpr uint64_t BIP16_H0 = 0x00000000000002dcull;
constexpr uint64_t BIP16_H1 = 0x756eebf4f49723edull;
constexpr uint64_t BIP16_H2 = 0x8d30cc28a5f108ebull;
constexpr uint64_t BIP16_H3 = 0x94b1ba88ac4f9c22ull;

// kernel/chainparams.cpp:117-118 -- taproot exception block hash
// 0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad
constexpr uint64_t TAPROOT_H0 = 0x0000000000000000ull;
constexpr uint64_t TAPROOT_H1 = 0x000f14c35b2d841eull;
constexpr uint64_t TAPROOT_H2 = 0x986ab5441de8c585ull;
constexpr uint64_t TAPROOT_H3 = 0xd5ffe55ea1e395adull;

// Encoded Option<ScriptFlags> for the exception map: 0 = none,
// 1 = BIP16 entry (SCRIPT_VERIFY_NONE), 2 = taproot entry (P2SH|WITNESS).
enum : uint64_t { EXC_NONE = 0, EXC_BIP16 = 1, EXC_TAPROOT = 2 };

// Core script-error ordinals (contract/error_kind.h).
enum : uint32_t {
    ERR_OK = 0,
    ERR_EVAL_FALSE = 2,
    ERR_SIG_PUSHONLY = 26,
    ERR_CLEANSTACK = 30,
    ERR_WITNESS_MALLEATED = 41,
    ERR_WITNESS_MALLEATED_P2SH = 42,
    ERR_WITNESS_UNEXPECTED = 43,
};

// Packed observable for the propagation cell: (result:1) << 8 | error:8.
static inline uint64_t pack_verdict(uint32_t pass, uint32_t err)
{
    return (static_cast<uint64_t>(pass & 1u) << 8) | static_cast<uint64_t>(err & 0xffu);
}

} // namespace w32
