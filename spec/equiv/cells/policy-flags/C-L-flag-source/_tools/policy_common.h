#ifndef CELLS_POLICY_COMMON_H
#define CELLS_POLICY_COMMON_H
#include <cstdint>

// Shared harness for the wave16 policy-flag cells.
//
// OBSERVABLE.  Every cell function returns the single shared script-error
// ordinal (contract/error_enum.md) selected by the rule under test, with 0
// meaning "no error".  There is no history/stack projection here: the rows
// under test are pure flag/encoding predicates, so exactly one ordinal is
// observable.  0xff is the cell's out-of-domain guard (harness, never engine
// behaviour; no Core path returns it).
//
// FLAG WORD.  The `flags` argument is a 64-bit model of Core's
// `script_verify_flags` (src/script/verify_flags.h: a uint64_t bitmask).  The
// cells use the *real* mask constants from the pin, enumerated below; they are
// not cell-local guesses.

namespace policy_cell {

// script_verify_flag_name order at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
// (src/script/interpreter.h:46-151); numeric masks confirmed with a compiled
// probe (findings/wave16/13-policy-reimport/tools/flags_probe.out).
static constexpr uint64_t P2SH                 = 1ull << 0;
static constexpr uint64_t STRICTENC            = 1ull << 1;
static constexpr uint64_t DERSIG               = 1ull << 2;
static constexpr uint64_t LOW_S                = 1ull << 3;
static constexpr uint64_t NULLDUMMY            = 1ull << 4;
static constexpr uint64_t SIGPUSHONLY          = 1ull << 5;
static constexpr uint64_t MINIMALDATA          = 1ull << 6;
static constexpr uint64_t DISCOURAGE_NOPS      = 1ull << 7;
static constexpr uint64_t CLEANSTACK           = 1ull << 8;
static constexpr uint64_t CLTV                 = 1ull << 9;
static constexpr uint64_t CSV                  = 1ull << 10;
static constexpr uint64_t WITNESS              = 1ull << 11;
static constexpr uint64_t DISCOURAGE_WITNESS   = 1ull << 12;
static constexpr uint64_t MINIMALIF            = 1ull << 13;
static constexpr uint64_t NULLFAIL             = 1ull << 14;
static constexpr uint64_t WITNESS_PUBKEYTYPE   = 1ull << 15;
static constexpr uint64_t CONST_SCRIPTCODE     = 1ull << 16;
static constexpr uint64_t TAPROOT              = 1ull << 17;
static constexpr uint64_t DISCOURAGE_TAPROOT_VERSION = 1ull << 18;
static constexpr uint64_t DISCOURAGE_OP_SUCCESS      = 1ull << 19;
static constexpr uint64_t DISCOURAGE_PUBKEYTYPE      = 1ull << 20;

// Mainnet buried activation heights (src/kernel/chainparams.cpp:119-124 @ pin;
// `DeploymentActiveAt` for a buried deployment is the plain `height >= since`
// compare, src/deploymentstatus.h:27-31 and Bitcoin.Activation.buriedActive).
static constexpr uint64_t BIP66_HEIGHT        = 363725;  // DEPLOYMENT_DERSIG
static constexpr uint64_t BIP65_HEIGHT        = 388381;  // DEPLOYMENT_CLTV
static constexpr uint64_t CSV_HEIGHT          = 419328;  // DEPLOYMENT_CSV
static constexpr uint64_t SEGWIT_HEIGHT       = 481824;  // DEPLOYMENT_SEGWIT (NULLDUMMY)

// Mainnet exception blocks (src/kernel/chainparams.cpp:115-118 @ pin).  The
// flag-source cell does not take a 256-bit hash; it takes the hash's
// equivalence class under the two-entry `script_flag_exceptions` map
// (TXV-056: exactly two reduced entries, every other hash -> none).
static constexpr uint64_t EXC_NONE            = 0;
static constexpr uint64_t EXC_BIP16           = 1;
static constexpr uint64_t EXC_TAPROOT         = 2;

// Core ScriptError ordinals (src/script/script_error.h @ pin; mirrored 1:1 by
// contract/error_enum.md).
static constexpr uint64_t ERR_OK             = 0;
static constexpr uint64_t ERR_SIG_HASHTYPE   = 23;
static constexpr uint64_t ERR_SIG_DER        = 24;
static constexpr uint64_t ERR_MINIMALDATA    = 25;
static constexpr uint64_t ERR_SIG_HIGH_S     = 27;
static constexpr uint64_t ERR_PUBKEYTYPE     = 29;
static constexpr uint64_t ERR_CLEANSTACK     = 30;
static constexpr uint64_t ERR_MINIMALIF      = 31;
static constexpr uint64_t ERR_SIG_NULLFAIL   = 32;
static constexpr uint64_t ERR_WITNESS_PUBKEYTYPE = 44;
static constexpr uint64_t ERR_TAPSCRIPT_MINIMALIF = 51;
static constexpr uint64_t ERR_OP_CODESEPARATOR    = 53;
static constexpr uint64_t ERR_SIG_FINDANDDELETE   = 54;

// Out-of-domain guard: a SigVersion value the cell does not model.
static constexpr uint64_t OUT_OF_DOMAIN = 0xff;

// SigVersion discriminants (src/script/interpreter.h enum SigVersion).
static constexpr uint64_t SV_BASE      = 0;
static constexpr uint64_t SV_WITNESS_V0 = 1;
static constexpr uint64_t SV_TAPSCRIPT = 2;

// opcodetype constants used by the push cells (src/script/script.h).
static constexpr uint64_t OP_0          = 0x00;
static constexpr uint64_t OP_PUSHDATA1  = 0x4c;
static constexpr uint64_t OP_PUSHDATA2  = 0x4d;
static constexpr uint64_t OP_PUSHDATA4  = 0x4e;
static constexpr uint64_t OP_CODESEPARATOR = 0xab;

// Byte model: symbolic byte inputs arrive as u64 so that Alive2/SAW share one
// uniform signature; masking makes the domain exactly "one byte".
static inline __attribute__((always_inline)) uint64_t byte_of(uint64_t v) {
    return v & 0xffull;
}

}  // namespace policy_cell

#endif
