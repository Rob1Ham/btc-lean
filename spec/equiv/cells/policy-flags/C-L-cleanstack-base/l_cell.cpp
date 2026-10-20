#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
// executeWitnessScript tail (:1236-1239):
//   | .ok st =>
//     -- witness scripts implicitly require cleanstack
//     if st.length ≠ 1 then .fail .cleanstack                            -- :1238
//     else if castToBool st[0]! then .ok else .fail .evalFalse           -- :1239
//
// VerifyScript, bare path (:1442-1443) and P2SH path (:1431):
//     if pol.cleanstack ∧ afterBare.length ≠ 1 then .fail .cleanstack    -- :1443
//     if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack            -- :1431
//
// `pol.cleanstack` is PolicyFlags.cleanstack (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "CLEANSTACK" string; Core carries the same
// bit in script_verify_flags (:2110).  The witness arm reads no policy bit at
// all, which is exactly the row's point.

uint64_t l_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    const bool cleanstack = (flags & CLEANSTACK) != 0;
    if (sigversion == SV_BASE) {
        if (cleanstack && finalLen != 1) return ERR_CLEANSTACK;
    } else {
        (void)cleanstack;                                   // :1238 never consults it
        if (finalLen != 1) return ERR_CLEANSTACK;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return l_cleanstack(flags, sigversion, finalLen);
}
