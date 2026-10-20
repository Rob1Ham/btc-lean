// l_flags.cpp -- L leg for the wave-32 exec-verify flag cells.
//
// The L leg is a REVIEWED HAND TRANSLITERATION of the Lean definitions, the
// documented fallback in spec/equiv/README.md section 3 ("hand-transliterated
// twin ... labelled as such").  The Activation module is not covered by
// twin/gen.py, so no generated twin exists for these definitions.  Sources:
//
//   flagsComboOk          spec/core/Bitcoin/Interpreter/Rules.lean:48-50
//   ScriptFlags/PolicyFlags spec/core/Bitcoin/Activation/Interface.lean
//   mainnetExceptionMap   spec/core/Bitcoin/Activation/Flags.lean:69-76
//   buriedActive          spec/core/Bitcoin/Activation/Flags.lean:127-128
//   getBlockScriptFlagsP  spec/core/Bitcoin/Activation/Flags.lean:145-157
//
// The point of the separation from c_flags.cpp is representation: the Lean
// definitions are record-valued with Bool fields and Option, while Core uses
// a 64-bit bitmask and a std::map lookup.  The cell proves the two
// representations agree.
#include "w32_common.h"

using namespace w32;

// Bitcoin.Activation.ScriptFlags (the fields flag selection reads).
struct ScriptFlagsRec {
    bool p2sh;
    bool witness;
    bool taproot;
    bool dersig;
    bool cltv;
    bool csv;
    bool nullDummy;
};

// Option ScriptFlags: `has = false` is `none`.
struct MaybeFlags {
    bool has;
    ScriptFlagsRec v;
};

// Bitcoin.Activation.buriedActive P since height := since ≤ height
static inline bool buried_active(uint32_t since, uint32_t height)
{
    return since <= height;
}

// Bitcoin.Activation.mainnetExceptionMap (hash as a 256-bit Nat, carried as
// four limbs; Nat equality is component-wise equality of the limbs).
static inline MaybeFlags mainnet_exception_map(uint64_t h0, uint64_t h1,
                                               uint64_t h2, uint64_t h3)
{
    if (h0 == BIP16_H0 && h1 == BIP16_H1 && h2 == BIP16_H2 && h3 == BIP16_H3) {
        // some { p2sh := false, witness := false, taproot := false }
        return {true, {false, false, false, false, false, false, false}};
    } else if (h0 == TAPROOT_H0 && h1 == TAPROOT_H1 && h2 == TAPROOT_H2 && h3 == TAPROOT_H3) {
        // some { p2sh := true, witness := true, taproot := false }
        return {true, {true, true, false, false, false, false, false}};
    }
    return {false, {false, false, false, false, false, false, false}};
}

// script_verify_flags projection (only the fields the row reads).
static inline uint64_t pack_flags(const ScriptFlagsRec& f)
{
    uint64_t out = 0;
    if (f.p2sh) out |= SCRIPT_VERIFY_P2SH;
    if (f.witness) out |= SCRIPT_VERIFY_WITNESS;
    if (f.taproot) out |= SCRIPT_VERIFY_TAPROOT;
    if (f.dersig) out |= SCRIPT_VERIFY_DERSIG;
    if (f.cltv) out |= SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY;
    if (f.csv) out |= SCRIPT_VERIFY_CHECKSEQUENCEVERIFY;
    if (f.nullDummy) out |= SCRIPT_VERIFY_NULLDUMMY;
    return out;
}

// ---------------------------------------------------------------------------
// SCR-014 -- Bitcoin.Interpreter.flagsComboOk.
// ---------------------------------------------------------------------------
struct PolicyFlagsRec {
    bool cleanstack;
};

extern "C" uint32_t cell_flags_combo(uint64_t flags, uint32_t cleanstack)
{
    const ScriptFlagsRec f{
        (flags & SCRIPT_VERIFY_P2SH) != 0,    // p2sh
        (flags & SCRIPT_VERIFY_WITNESS) != 0, // witness
        (flags & SCRIPT_VERIFY_TAPROOT) != 0, // taproot
        (flags & SCRIPT_VERIFY_DERSIG) != 0,  // dersig
        (flags & SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY) != 0, // cltv
        (flags & SCRIPT_VERIFY_CHECKSEQUENCEVERIFY) != 0, // csv
        (flags & SCRIPT_VERIFY_NULLDUMMY) != 0,           // nullDummy
    };
    const PolicyFlagsRec pol{cleanstack != 0};

    // flagsComboOk flags pol :=
    //   (!pol.cleanstack ∨ (flags.p2sh ∧ flags.witness)) ∧
    //   (!flags.witness ∨ flags.p2sh)
    const bool ok = (!pol.cleanstack || (f.p2sh && f.witness)) && (!f.witness || f.p2sh);
    return ok ? 1u : 0u;
}

// ---------------------------------------------------------------------------
// SCR-015 -- Bitcoin.Activation.getBlockScriptFlagsP mainnetParams.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_block_flags(uint64_t h0, uint64_t h1, uint64_t h2,
                                     uint64_t h3, uint32_t height)
{
    const MaybeFlags exc = mainnet_exception_map(h0, h1, h2, h3);
    // let base := match P.scriptFlagExceptions hash with
    //             | some exf => exf
    //             | none => { p2sh := true, witness := true, taproot := true }
    ScriptFlagsRec base = exc.has
        ? exc.v
        : ScriptFlagsRec{true, true, true, false, false, false, false};
    // { base with dersig := base.dersig || buriedActive P P.bip66Height height, ... }
    base.dersig = base.dersig || buried_active(BIP66_HEIGHT, height);
    base.cltv = base.cltv || buried_active(BIP65_HEIGHT, height);
    base.csv = base.csv || buried_active(CSV_HEIGHT, height);
    base.nullDummy = base.nullDummy || buried_active(SEGWIT_HEIGHT, height);
    return pack_flags(base);
}

// ---------------------------------------------------------------------------
// SCR-016 -- the exception map as Option, plus the named-block schedules.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_exc_select(uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3)
{
    const MaybeFlags exc = mainnet_exception_map(h0, h1, h2, h3);
    if (!exc.has) return EXC_NONE;
    // Distinguish the two Option payloads exactly as the Lean map does.
    if (!exc.v.p2sh && !exc.v.witness && !exc.v.taproot) return EXC_BIP16;
    if (exc.v.p2sh && exc.v.witness && !exc.v.taproot) return EXC_TAPROOT;
    // Unreachable for mainnetExceptionMap; kept total for the compiler.
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
// SCR-017 -- Bitcoin.Interpreter.verifyScriptFull failure propagation.
//
// Lean models each engine call as VerifyOutcome (ok | fail e | unjudged) and
// matches on it; the cell collapses unjudged (an outside-the-seam outcome)
// and keeps the fail/error match shape.  `ErrOutcome` is that Option-shaped
// result, not a boolean.
// ---------------------------------------------------------------------------
enum class Res : uint8_t { Ok, Fail };
struct Outcome {
    Res r;
    uint32_t err;
};

static inline Outcome eval_ok(void) { return {Res::Ok, ERR_OK}; }
static inline Outcome eval_fail(uint32_t e) { return {Res::Fail, e}; }

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
    const Outcome s1 = e1_fail ? eval_fail(err1) : eval_ok();  // scriptSig
    if (s1.r == Res::Fail) return pack_verdict(0, s1.err);     // .fail e => .fail e
    const Outcome s2 = e2_fail ? eval_fail(err2) : eval_ok();  // scriptPubKey
    if (s2.r == Res::Fail) return pack_verdict(0, s2.err);
    if (!spk_truth) return pack_verdict(0, ERR_EVAL_FALSE);
    if ((flags & SCRIPT_VERIFY_WITNESS) != 0 && bare_witness) {
        const Outcome w1 = ew1_fail ? eval_fail(errw1) : eval_ok();
        if (w1.r == Res::Fail) return pack_verdict(0, w1.err);
    }
    if ((flags & SCRIPT_VERIFY_P2SH) != 0 && p2sh_path) {
        const Outcome s3 = e3_fail ? eval_fail(err3) : eval_ok(); // redeemScript
        if (s3.r == Res::Fail) return pack_verdict(0, s3.err);
        if (!redeem_truth) return pack_verdict(0, ERR_EVAL_FALSE);
        if ((flags & SCRIPT_VERIFY_WITNESS) != 0 && p2sh_redeem_witness) {
            const Outcome w2 = ew2_fail ? eval_fail(errw2) : eval_ok();
            if (w2.r == Res::Fail) return pack_verdict(0, w2.err);
        }
    }
    if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0 && !cleanstack_ok) {
        return pack_verdict(0, ERR_CLEANSTACK);
    }
    if ((flags & SCRIPT_VERIFY_WITNESS) != 0 && witness_unexpected) {
        return pack_verdict(0, ERR_WITNESS_UNEXPECTED);
    }
    return pack_verdict(1, ERR_OK);
}

// SCR-017 law face (Lean reading): if any of the five matched calls returns
// `.fail e`, verifyScriptFull returns `.fail e`; success cannot swallow it.
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
