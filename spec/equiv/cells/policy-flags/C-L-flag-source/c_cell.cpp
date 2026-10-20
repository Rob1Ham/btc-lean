#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/validation.cpp @ pin cce32b168.
//
// GetBlockScriptFlags (:2249-2288), the whole selector:
//
//   script_verify_flags flags{SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS |
//                             SCRIPT_VERIFY_TAPROOT};                    // :2258
//   const auto it{consensusparams.script_flag_exceptions.find(*Assert(
//       block_index.phashBlock))};                                     // :2259
//   if (it != consensusparams.script_flag_exceptions.end())
//       flags = it->second;                                            // :2262-2265
//   if (DeploymentActiveAt(... DEPLOYMENT_DERSIG)) flags |= DERSIG;    // :2267-2270
//   if (DeploymentActiveAt(... DEPLOYMENT_CLTV))   flags |= CLTV;      // :2271-2274
//   if (DeploymentActiveAt(... DEPLOYMENT_CSV))    flags |= CSV;       // :2275-2278
//   if (DeploymentActiveAt(... DEPLOYMENT_SEGWIT)) flags |= NULLDUMMY; // :2279-2282
//   return flags;                                                      // :2284
//
// The exception map is hash-keyed (kernel/chainparams.cpp:113-118), but it
// has exactly two entries (TXV-056):
//   BIP16   block hash -> SCRIPT_VERIFY_NONE
//   taproot block hash -> SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS
// every other hash falls through to P2SH|WITNESS|TAPROOT.  This cell takes
// the hash's *equivalence class* under that two-entry map as a bounded input
// (EXC_NONE / EXC_BIP16 / EXC_TAPROOT); it does not model the 256-bit hash.
//
// For the four buried deployments, DeploymentActiveAt is the plain height
// compare `height >= since` (deploymentstatus.h:27-31), so the bounded input
// is the mainnet block height.  The order is load-bearing: the exception
// replacement happens BEFORE the four ORs, so DERSIG/CLTV/CSV/NULLDUMMY stay
// on for the two exception blocks once their heights are reached.
//
// LOW_S and CONST_SCRIPTCODE do not appear anywhere in :2249-2284.  They are
// policy bits from policy.h:118-133 (STANDARD_SCRIPT_VERIFY_FLAGS), not
// mandatory bits (policy.h:104-110) and not block-selector bits.

static constexpr uint64_t SCRIPT_VERIFY_NONE = 0;

// policy.h:104-110 @ pin.
static constexpr uint64_t MANDATORY_SCRIPT_VERIFY_FLAGS =
    P2SH | DERSIG | NULLDUMMY | CLTV | CSV | WITNESS | TAPROOT;

// policy.h:118-133 @ pin (all 13 standard-only flags; SIGPUSHONLY is absent).
static constexpr uint64_t STANDARD_SCRIPT_VERIFY_FLAGS =
    MANDATORY_SCRIPT_VERIFY_FLAGS |
    STRICTENC | LOW_S | MINIMALDATA | DISCOURAGE_NOPS | CLEANSTACK |
    DISCOURAGE_WITNESS | MINIMALIF | NULLFAIL | WITNESS_PUBKEYTYPE |
    CONST_SCRIPTCODE | DISCOURAGE_TAPROOT_VERSION | DISCOURAGE_OP_SUCCESS |
    DISCOURAGE_PUBKEYTYPE;

static constexpr uint64_t PAYMENT_FLAGS = LOW_S | CONST_SCRIPTCODE;

// Core `GetBlockScriptFlags`, bounded to (exception-map class, height).
static inline __attribute__((always_inline))
uint64_t c_block_script_flags(uint64_t exceptionKind, uint64_t height) {
    uint64_t flags = P2SH | WITNESS | TAPROOT;              // :2258

    // script_flag_exceptions lookup (:2259-2265).  The map has two entries.
    if (exceptionKind == EXC_BIP16) {
        flags = SCRIPT_VERIFY_NONE;                          // SCRIPT_VERIFY_NONE
    } else if (exceptionKind == EXC_TAPROOT) {
        flags = P2SH | WITNESS;                              // P2SH | WITNESS
    }

    // The four buried ORs, in Core's order (:2267-2282).
    if (BIP66_HEIGHT  <= height) flags |= DERSIG;            // BIP66
    if (BIP65_HEIGHT  <= height) flags |= CLTV;              // BIP65
    if (CSV_HEIGHT    <= height) flags |= CSV;               // BIP112
    if (SEGWIT_HEIGHT <= height) flags |= NULLDUMMY;         // BIP147/segwit
    return flags;
}

uint64_t c_flag_source(uint64_t exceptionKind, uint64_t height) {
    return c_block_script_flags(exceptionKind, height % 0x100000000ULL);
}

// The row's negative half, made an observable: which policy-only bits the
// block selector can emit.  Expected 0 for every (kind, height).
uint64_t c_flag_source_policy_mask(uint64_t exceptionKind, uint64_t height) {
    return c_block_script_flags(exceptionKind, height % 0x100000000ULL) &
           PAYMENT_FLAGS;
}

// The positive half: the mempool standard word sets both bits (policy.h:118-133).
uint64_t c_standard_policy_mask() {
    return STANDARD_SCRIPT_VERIFY_FLAGS & PAYMENT_FLAGS;
}

// The mandatory (block-adjacent) word does not set either bit (policy.h:104-110).
uint64_t c_mandatory_policy_mask() {
    return MANDATORY_SCRIPT_VERIFY_FLAGS & PAYMENT_FLAGS;
}

// Integration roots: feed the *block selector's* word to the two policy gates.
// If the source claim is right, the LOW_S branch (SIG_HIGH_S = 27) and the
// CONST_SCRIPTCODE branches (53/54) are unreachable for every block input.
//
// LOW_S skeleton: the sibling cell's canonical DER shape
//   30 25 02 01 <R> 02 20 <S:32> <hashtype>
// (sig.size()==40, lenR==1, lenS==32), so IsValidSignatureEncoding reduces to
// the three free conditions at interpreter.cpp:149,172,177 and CheckLowS is
// the 256-bit S <= n/2 predicate (Defs.lean:88-91, :355-362).
static constexpr uint64_t H0 = 0x7fffffffffffffffULL;
static constexpr uint64_t H1 = 0xffffffffffffffffULL;
static constexpr uint64_t H2 = 0x5d576e7357a4501dULL;
static constexpr uint64_t H3 = 0xdfe92f46681b20a0ULL;

static inline __attribute__((always_inline))
bool c_le_half(uint64_t s0, uint64_t s1, uint64_t s2, uint64_t s3) {
    if (s0 != H0) return s0 < H0;
    if (s1 != H1) return s1 < H1;
    if (s2 != H2) return s2 < H2;
    return s3 <= H3;
}

uint64_t c_lows_gate_block(uint64_t exceptionKind, uint64_t height,
                           uint64_t rByte, uint64_t s0, uint64_t s1,
                           uint64_t s2, uint64_t s3) {
    const uint64_t flags = c_block_script_flags(exceptionKind,
                                                height % 0x100000000ULL);
    const uint64_t r       = rByte & 0xff;
    const uint64_t sTop    = (s0 >> 56) & 0xff;
    const uint64_t sSecond = (s0 >> 48) & 0xff;
    const bool valid = r < 0x80 && sTop < 0x80 &&
                       (sTop != 0 || (sSecond & 0x80) != 0);
    const bool lowS = valid && c_le_half(s0, s1, s2, s3);
    if ((flags & (DERSIG | LOW_S | STRICTENC)) != 0 && !valid) {
        return ERR_SIG_DER;                        // :217-218
    }
    if ((flags & LOW_S) != 0 && !lowS) {
        return ERR_SIG_HIGH_S;                     // :219-221 (never taken)
    }
    return ERR_OK;
}

uint64_t c_const_gate_block(uint64_t exceptionKind, uint64_t height,
                            uint64_t sigversion, uint64_t opcode,
                            uint64_t foundPositive) {
    if (foundPositive > 1) return OUT_OF_DOMAIN;   // cell guard (harness)
    const uint64_t flags = c_block_script_flags(exceptionKind,
                                                height % 0x100000000ULL);
    if (opcode == OP_CODESEPARATOR && sigversion == SV_BASE &&
        (flags & CONST_SCRIPTCODE) != 0) {
        return ERR_OP_CODESEPARATOR;               // :484-486 (never taken)
    }
    if (sigversion == SV_BASE && foundPositive != 0 &&
        (flags & CONST_SCRIPTCODE) != 0) {
        return ERR_SIG_FINDANDDELETE;              // :339-343 (never taken)
    }
    return ERR_OK;
}

extern "C" uint64_t cell_flag_source(uint64_t exceptionKind, uint64_t height) {
    return c_flag_source(exceptionKind, height);
}

extern "C" uint64_t cell_lows_gate_block(uint64_t exceptionKind,
                                         uint64_t height, uint64_t rByte,
                                         uint64_t s0, uint64_t s1, uint64_t s2,
                                         uint64_t s3) {
    return c_lows_gate_block(exceptionKind, height, rByte, s0, s1, s2, s3);
}

extern "C" uint64_t cell_const_gate_block(uint64_t exceptionKind,
                                          uint64_t height, uint64_t sigversion,
                                          uint64_t opcode,
                                          uint64_t foundPositive) {
    return c_const_gate_block(exceptionKind, height, sigversion, opcode,
                              foundPositive);
}

extern "C" uint64_t cell_flag_source_policy_mask(uint64_t exceptionKind,
                                                  uint64_t height) {
    return c_flag_source_policy_mask(exceptionKind, height);
}

extern "C" uint64_t cell_standard_policy_mask() {
    return c_standard_policy_mask();
}

extern "C" uint64_t cell_mandatory_policy_mask() {
    return c_mandatory_policy_mask();
}
