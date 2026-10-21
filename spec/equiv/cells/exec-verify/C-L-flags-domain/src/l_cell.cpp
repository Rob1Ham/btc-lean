#include "common.h"

// L leg — REVIEWED TRANSLITERATION, not generated from the twin.
//
// The Lean model does not carry a single flag word.  `verifyScriptFull`
// (spec/core/Bitcoin/Interpreter/Defs.lean:1363-1455) takes `ScriptFlags`
// (p2sh, dersig, cltv, csv, nullDummy, witness, taproot) and `PolicyFlags`
// (…, cleanstack, sigPushOnly) as *typed* records, so the combination the
// Core asserts forbid can be *constructed* in the model (cleanstack is an
// independent boolean) but is never a caller-supplied mask.  The contract
// totalizes the assert to result 2 (contract/tape.md §5), and the L-leg
// obligation is the same predicate over the packed mask.
//
// This transliteration is branchless on purpose: it is written from the
// contract table, not from the C code, so the Alive2 comparison is a real
// bit-level obligation rather than two copies of one body.

EVINLINE uint64_t l_flags_guard(uint64_t flags) {
    const uint64_t in_domain = (flags >> 21) == 0;      // bits 21..63 are 0
    const uint64_t p2sh = flags & SCRIPT_VERIFY_P2SH;
    const uint64_t cleanstack = (flags & SCRIPT_VERIFY_CLEANSTACK) != 0;
    const uint64_t witness = (flags & SCRIPT_VERIFY_WITNESS) != 0;
    // witness -> p2sh, as a bit (1 = implication holds).
    const uint64_t w_imp = (!witness) | (p2sh != 0);
    // cleanstack -> p2sh /\ witness.
    const uint64_t c_imp = (!cleanstack) | ((p2sh != 0) & witness);
    return in_domain & w_imp & c_imp & 1u;
}

EVINLINE uint64_t l_flags_assertsafe(uint64_t flags) {
    const uint64_t p2sh = flags & SCRIPT_VERIFY_P2SH;
    const uint64_t cleanstack = (flags & SCRIPT_VERIFY_CLEANSTACK) != 0;
    const uint64_t witness = (flags & SCRIPT_VERIFY_WITNESS) != 0;
    const uint64_t w_imp = (!witness) | (p2sh != 0);
    const uint64_t c_imp = (!cleanstack) | ((p2sh != 0) & witness);
    return w_imp & c_imp & 1u;
}

EVINLINE uint64_t l_flags_implication(uint64_t flags) {
    // Lean-side reading of the same contract statement: a mask the ABI
    // rejects never reaches `verifyScriptFull`, so the two assert conditions
    // are vacuous on that input.
    const uint64_t accepted = l_flags_guard(flags);
    const uint64_t safe = l_flags_assertsafe(flags);
    return (accepted == 0) | safe;
}

extern "C" uint64_t cell_flags_guard(uint64_t flags) {
    return l_flags_guard(flags);
}

extern "C" uint64_t cell_flags_assertsafe(uint64_t flags) {
    return l_flags_assertsafe(flags);
}

extern "C" uint64_t cell_flags_implication(uint64_t flags) {
    return l_flags_implication(flags);
}
