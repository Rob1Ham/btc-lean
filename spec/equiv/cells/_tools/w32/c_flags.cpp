// c_flags.cpp -- C leg for the wave-32 exec-verify flag cells.
//
// These are line-cited *slices* of Bitcoin Core v32.99 at
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.  They are not the whole
// VerifyScript/GetBlockScriptFlags and they do not include Core headers: the
// flag bits and heights come from w32_common.h, which records the exact
// source lines.  The slice bodies below follow the pinned source expression
// by expression.
#include "w32_common.h"

using namespace w32;

// ---------------------------------------------------------------------------
// SCR-014 -- VerifyScript flag-combination constraint.
//
//   interpreter.cpp:2110-2119
//     if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {
//         assert((flags & SCRIPT_VERIFY_P2SH) != 0);
//         assert((flags & SCRIPT_VERIFY_WITNESS) != 0);
//         ...
//   interpreter.cpp:2120-2127
//     if (flags & SCRIPT_VERIFY_WITNESS) {
//         assert((flags & SCRIPT_VERIFY_P2SH) != 0);
//
// Core phrases the constraint as assert()s.  The cell models the
// well-formedness predicate those asserts encode (the row's `flagsComboOk`
// face); the assert's own UB/NDEBUG behaviour is outside the cell.
// ---------------------------------------------------------------------------
extern "C" uint32_t cell_flags_combo(uint64_t flags, uint32_t cleanstack)
{
    const bool cs = cleanstack != 0;
    const bool p2sh = (flags & SCRIPT_VERIFY_P2SH) != 0;
    const bool witness = (flags & SCRIPT_VERIFY_WITNESS) != 0;

    const bool cleanstack_arm = !cs || (p2sh && witness); // :2113-2114
    const bool witness_arm = !witness || p2sh;            // :2124
    return (cleanstack_arm && witness_arm) ? 1u : 0u;
}

// ---------------------------------------------------------------------------
// SCR-015 -- GetBlockScriptFlags (validation.cpp:2249-2288).
//
// The consensus map lookup (`script_flag_exceptions.find(hash)`,
// validation.cpp:2262-2265) is the two equality tests below.  Mainnet has
// exactly these two entries (kernel/chainparams.cpp:115-118), so the lookup
// is fail-closed for every other 256-bit hash.  The four buried deployments
// are plain `height >= DeploymentHeight` compares at the pin
// (deploymentstatus.h:27-31 + kernel/chainparams.cpp:119-124); the
// deployment-specific heights are the ones in the pinned chainparams.
// ---------------------------------------------------------------------------
static inline bool is_bip16_exception(uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3)
{
    return h0 == BIP16_H0 && h1 == BIP16_H1 && h2 == BIP16_H2 && h3 == BIP16_H3;
}

static inline bool is_taproot_exception(uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3)
{
    return h0 == TAPROOT_H0 && h1 == TAPROOT_H1 && h2 == TAPROOT_H2 && h3 == TAPROOT_H3;
}

extern "C" uint64_t cell_block_flags(uint64_t h0, uint64_t h1, uint64_t h2,
                                     uint64_t h3, uint32_t height)
{
    // validation.cpp:2259-2261
    uint64_t flags = SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS | SCRIPT_VERIFY_TAPROOT;
    // validation.cpp:2262-2265 (exception REPLACES the base)
    if (is_bip16_exception(h0, h1, h2, h3)) {
        flags = SCRIPT_VERIFY_NONE;
    } else if (is_taproot_exception(h0, h1, h2, h3)) {
        flags = SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS;
    }
    // validation.cpp:2267-2285 (buried ORs)
    if (height >= BIP66_HEIGHT) flags |= SCRIPT_VERIFY_DERSIG;
    if (height >= BIP65_HEIGHT) flags |= SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY;
    if (height >= CSV_HEIGHT) flags |= SCRIPT_VERIFY_CHECKSEQUENCEVERIFY;
    if (height >= SEGWIT_HEIGHT) flags |= SCRIPT_VERIFY_NULLDUMMY;
    return flags;
}

// ---------------------------------------------------------------------------
// SCR-016 -- the two named mainnet exception blocks.
//
// `cell_exc_select` is the exception map (kernel/chainparams.cpp:115-118) as
// an encoded Option<ScriptFlags>: 0 none, 1 BIP16 (NONE), 2 taproot
// (P2SH|WITNESS).  The two `*_at` wrappers show the complete height schedule
// for a block carrying that hash; the two `*_named` wrappers are the exact
// named blocks, at their real heights, through the SCR-015 function.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_exc_select(uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3)
{
    if (is_bip16_exception(h0, h1, h2, h3)) return EXC_BIP16;
    if (is_taproot_exception(h0, h1, h2, h3)) return EXC_TAPROOT;
    return EXC_NONE;
}

extern "C" uint64_t cell_flags_bip16_at(uint32_t height)
{
    return cell_block_flags(BIP16_H0, BIP16_H1, BIP16_H2, BIP16_H3, height);
}

extern "C" uint64_t cell_flags_taproot_at(uint32_t height)
{
    return cell_block_flags(TAPROOT_H0, TAPROOT_H1, TAPROOT_H2, TAPROOT_H3, height);
}

extern "C" uint64_t cell_flags_bip16_named(void)
{
    return cell_flags_bip16_at(BIP16_EXCEPTION_HEIGHT);
}

extern "C" uint64_t cell_flags_taproot_named(void)
{
    return cell_flags_taproot_at(TAPROOT_EXCEPTION_HEIGHT);
}

// ---------------------------------------------------------------------------
// SCR-017 -- any EvalScript / VerifyWitnessProgram failure makes the input
// invalid (interpreter.cpp:2029-2036, 2052-2054, 2080-2082, 2097-2099).
//
// The five engine calls are abstracted to their (ok|fail, error) outcome; the
// cell is the propagation skeleton: every early return, its order and the
// error it carries.  Flags are the real bit tests; path predicates
// (bare_witness, p2sh_path, ...) stand in for CScript::IsWitnessProgram /
// IsPayToScriptHash and the scriptSig checks, which are other rows.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_fail_prop(
    uint64_t flags,
    uint32_t e1_fail, uint32_t e2_fail, uint32_t e3_fail,
    uint32_t ew1_fail, uint32_t ew2_fail,
    uint32_t err1, uint32_t err2, uint32_t err3,
    uint32_t errw1, uint32_t errw2,
    uint32_t spk_truth, uint32_t redeem_truth,
    uint32_t bare_witness, uint32_t p2sh_path, uint32_t p2sh_redeem_witness,
    uint32_t cleanstack_ok, uint32_t witness_unexpected)
{
    // interpreter.cpp:2029-2030 -- scriptSig EvalScript
    if (e1_fail) return pack_verdict(0, err1);
    // interpreter.cpp:2035-2036 -- scriptPubKey EvalScript
    if (e2_fail) return pack_verdict(0, err2);
    // interpreter.cpp:2037-2040 -- EVAL_FALSE tail
    if (!spk_truth) return pack_verdict(0, ERR_EVAL_FALSE);
    // interpreter.cpp:2052-2054 -- bare witness program
    if ((flags & SCRIPT_VERIFY_WITNESS) != 0 && bare_witness) {
        if (ew1_fail) return pack_verdict(0, errw1);
    }
    // interpreter.cpp:2061-2099 -- P2SH redeemScript
    if ((flags & SCRIPT_VERIFY_P2SH) != 0 && p2sh_path) {
        // interpreter.cpp:2080-2082 -- redeemScript EvalScript
        if (e3_fail) return pack_verdict(0, err3);
        if (!redeem_truth) return pack_verdict(0, ERR_EVAL_FALSE);
        // interpreter.cpp:2097-2099 -- P2SH witness program
        if ((flags & SCRIPT_VERIFY_WITNESS) != 0 && p2sh_redeem_witness) {
            if (ew2_fail) return pack_verdict(0, errw2);
        }
    }
    // interpreter.cpp:2107-2119 -- CLEANSTACK
    if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0 && !cleanstack_ok) {
        return pack_verdict(0, ERR_CLEANSTACK);
    }
    // interpreter.cpp:2121-2127 -- WITNESS_UNEXPECTED
    if ((flags & SCRIPT_VERIFY_WITNESS) != 0 && witness_unexpected) {
        return pack_verdict(0, ERR_WITNESS_UNEXPECTED);
    }
    return pack_verdict(1, ERR_OK);
}

// SCR-017 law face: "a reachable EvalScript/VerifyWitnessProgram failure
// implies an invalid input".  The law function re-derives the reachability of
// each engine call from the same symbolic inputs and checks the verdict that
// cell_fail_prop produced.  SAW proves this returns 1 for every input.
extern "C" uint32_t cell_prop_law(
    uint64_t flags,
    uint32_t e1_fail, uint32_t e2_fail, uint32_t e3_fail,
    uint32_t ew1_fail, uint32_t ew2_fail,
    uint32_t err1, uint32_t err2, uint32_t err3,
    uint32_t errw1, uint32_t errw2,
    uint32_t spk_truth, uint32_t redeem_truth,
    uint32_t bare_witness, uint32_t p2sh_path, uint32_t p2sh_redeem_witness,
    uint32_t cleanstack_ok, uint32_t witness_unexpected)
{
    const bool p2sh = (flags & SCRIPT_VERIFY_P2SH) != 0;
    const bool wit = (flags & SCRIPT_VERIFY_WITNESS) != 0;
    const bool reachable_fail =
        (e1_fail != 0) || (e2_fail != 0) ||
        (wit && bare_witness && (ew1_fail != 0)) ||
        (p2sh && p2sh_path && (e3_fail != 0)) ||
        (p2sh && p2sh_path && wit && p2sh_redeem_witness && (ew2_fail != 0));
    const uint64_t out = cell_fail_prop(
        flags, e1_fail, e2_fail, e3_fail, ew1_fail, ew2_fail,
        err1, err2, err3, errw1, errw2, spk_truth, redeem_truth,
        bare_witness, p2sh_path, p2sh_redeem_witness,
        cleanstack_ok, witness_unexpected);
    const uint32_t pass = static_cast<uint32_t>((out >> 8) & 1u);
    return (!reachable_fail || pass == 0) ? 1u : 0u;
}
