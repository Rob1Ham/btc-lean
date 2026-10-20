// spec/equiv/shims/core/entry.cpp — C leg: C-ABI shim over Bitcoin Core's
// real `VerifyScript`.  NO ENGINE LOGIC lives here: decode, marshal, call,
// map the returned ScriptError to the shared enum, return.
//
// Reference pattern: reardencode/rbitcoin `script-oracle/verify.cpp` (MIT/
// Apache-2.0), which wraps Core's VerifyScript with TX_WITH_WITNESS
// deserialization, TransactionSignatureChecker, PrecomputedTransactionData
// and MissingDataBehavior::FAIL.  Differences from that oracle, all contract
// decisions documented in ../contract/tape.md:
//   * full-buffer-consumption check (trailing bytes => 2);
//   * explicit domain checks for amount, flags and pointer/length pairs;
//   * one synthetic CTxOut per input (the reference passes a single-element
//     vector, which only satisfies PrecomputedTransactionData for 1-input
//     transactions);
//   * error_kind out-parameter and result codes 0/1/2/3.
//
// Build notes (see ../README.md for the full recipe):
//   * C++20 required (script_verify_flags uses consteval/using enum).
//   * Include paths: -I <spec/equiv>/contract            (error_kind.h)
//                     -I $CORE_SRC/src
//                     -I $CORE_SRC/src/secp256k1/include
//   * Link: Core objects for interpreter.cpp, script.cpp, script_error.cpp,
//     primitives/transaction.cpp, pubkey.cpp, hash.cpp, uint256.cpp,
//     arith_uint256.cpp, crypto/{ripemd160,sha1,sha256,sha512,hmac_sha512,
//     hex_base}.cpp, util/strencodings.cpp, streams.cpp, support/cleanse.cpp,
//     plus libsecp256k1 built with SCHNORRSIG+EXTRAKEYS (rbitcoin's build.rs
//     compiles secp256k1.c + precomputed_ecmult{,_gen}.c and defines
//     ENABLE_MODULE_{SCHNORRSIG,EXTRAKEYS,ELLSWIFT,RECOVERY},
//     ECMULT_WINDOW_SIZE=15, ECMULT_GEN_PREC_BITS=4, USE_FIELD_5X52,
//     USE_SCALAR_4X64, HAVE___INT128).
//   * There is no Core build-system dependency here; this TU can be compiled
//     standalone (-fsyntax-only) and linked by any harness driver.
//   * Do not patch Core for this shim.  Core is used at
//     cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, unmodified.

#include "error_kind.h"

#include <consensus/amount.h>
#include <primitives/transaction.h>
#include <script/interpreter.h>
#include <streams.h>

#include <cstdint>
#include <ios>
#include <span>
#include <utility>
#include <vector>

// Pin guards: fail the build, not the proof, if a different Core is used.
#define EQ_PIN_VALUE(shared, core) \
    static_assert(static_cast<int>(EQUIV_ERR_##shared) == static_cast<int>(core))
EQ_PIN_VALUE(OK, SCRIPT_ERR_OK);
EQ_PIN_VALUE(UNKNOWN_ERROR, SCRIPT_ERR_UNKNOWN_ERROR);
EQ_PIN_VALUE(SCRIPTNUM, SCRIPT_ERR_SCRIPTNUM);
EQ_PIN_VALUE(BAD_OPCODE, SCRIPT_ERR_BAD_OPCODE);
EQ_PIN_VALUE(CLEANSTACK, SCRIPT_ERR_CLEANSTACK);
EQ_PIN_VALUE(WITNESS_UNEXPECTED, SCRIPT_ERR_WITNESS_UNEXPECTED);
EQ_PIN_VALUE(SIG_FINDANDDELETE, SCRIPT_ERR_SIG_FINDANDDELETE);
EQ_PIN_VALUE(COUNT, SCRIPT_ERR_ERROR_COUNT);
#undef EQ_PIN_VALUE
static_assert(MAX_SCRIPT_VERIFY_FLAGS_BITS == 21,
              "script-verify flag set changed; re-pin and review tape.md");
static_assert(EQUIV_ABI_VERSION == 2, "unexpected ABI version");

namespace {

void set_kind(equiv_error_kind* out, equiv_error_kind kind)
{
    // The contract says `out` MUST be non-NULL.  Tolerating NULL is defensive
    // only; no gate may rely on it.
    if (out != nullptr) *out = kind;
}

} // namespace

// Normative ABI v2 symbol.  `error_kind` is mandatory for callers.
extern "C" int equiv_entry(
    const uint8_t* tx_bytes,
    uint64_t tx_len,
    const uint8_t* spk,
    uint64_t spk_len,
    int64_t amount,
    uint32_t input_index,
    uint64_t flags,
    equiv_error_kind* error_kind)
{
    // ---- domain checks (result 2); no engine semantics ------------------
    set_kind(error_kind, EQUIV_ERR_UNKNOWN_ERROR);
    if (tx_len == 0 || tx_bytes == nullptr) return 2;
    if (spk_len != 0 && spk == nullptr) return 2;
    if (amount < 0 || amount > MAX_MONEY) return 2;

    const uint64_t flag_mask = static_cast<uint64_t>(MAX_SCRIPT_VERIFY_FLAGS);
    const script_verify_flags vf = script_verify_flags::from_int(flags);
    const uint64_t p2sh = (vf & SCRIPT_VERIFY_P2SH).as_int();
    const uint64_t witness = (vf & SCRIPT_VERIFY_WITNESS).as_int();
    const uint64_t cleanstack = (vf & SCRIPT_VERIFY_CLEANSTACK).as_int();
    if ((flags & ~flag_mask) != 0) return 2;
    // Core asserts these implications in VerifyScript; rejecting them here
    // keeps the ABI total instead of aborting a debug build.
    if ((flags & witness) != 0 && (flags & p2sh) == 0) return 2;
    if ((flags & cleanstack) != 0 && ((flags & p2sh) == 0 || (flags & witness) == 0)) return 2;

    // ---- decode (result 2); nothing but deserialization in this block ----
    CMutableTransaction mtx;
    try {
        DataStream ds(std::span<const unsigned char>(tx_bytes, tx_len));
        ds >> TX_WITH_WITNESS(mtx);
        if (!ds.empty()) return 2; // trailing bytes make the tape ambiguous
    } catch (const std::ios_base::failure&) {
        return 2;
    }

    if (input_index >= mtx.vin.size()) return 2;

    CTransaction tx(mtx);

    CScript script_pub;
    if (spk_len != 0) script_pub.assign(spk, spk + spk_len);

    // One spent output per input.  Only input_index's amount/script are on the
    // tape; other inputs are synthesized as (0, empty).  For BASE and
    // WITNESS_V0 this cannot affect the sighash (other inputs' outputs are not
    // hashed); for TAPROOT it defines the harness tape (see tape.md §6).
    std::vector<CTxOut> spent_outputs;
    spent_outputs.reserve(tx.vin.size());
    for (size_t i = 0; i < tx.vin.size(); ++i) {
        if (i == input_index) {
            spent_outputs.emplace_back(amount, script_pub);
        } else {
            spent_outputs.emplace_back(0, CScript());
        }
    }

    // ---- the engine call ------------------------------------------------
    try {
        PrecomputedTransactionData txdata;
        txdata.Init(tx, std::move(spent_outputs));

        TransactionSignatureChecker checker(
            &tx, input_index, amount, txdata, MissingDataBehavior::FAIL);

        ScriptError err = SCRIPT_ERR_UNKNOWN_ERROR;
        const bool ok = VerifyScript(
            tx.vin[input_index].scriptSig,
            script_pub,
            &tx.vin[input_index].scriptWitness,
            script_verify_flags::from_int(flags),
            checker,
            &err);

        // VerifyScript sets OK on success and a specific ScriptError on
        // failure; the shared enum mirrors those ordinals 1:1.
        set_kind(error_kind, static_cast<equiv_error_kind>(err));
        return ok ? 1 : 0;
    } catch (...) {
        set_kind(error_kind, EQUIV_ERR_UNKNOWN_ERROR);
        return 3;
    }
}

// Non-normative convenience wrapper.  Exists so a status-only driver can call
// the leg without an out-parameter; the normative symbol is equiv_entry.
extern "C" int entry(
    const uint8_t* tx_bytes,
    uint64_t tx_len,
    const uint8_t* spk,
    uint64_t spk_len,
    int64_t amount,
    uint32_t input_index,
    uint64_t flags)
{
    equiv_error_kind kind = EQUIV_ERR_UNKNOWN_ERROR;
    return equiv_entry(tx_bytes, tx_len, spk, spk_len, amount, input_index, flags, &kind);
}
