#include "probe_common.h"

// L leg of the *full-domain* SCR-008 probe under the one-line model fix
// proposed in findings/wave64/41-div-w32-p2sh-cleanstack (§8):
//
//   let redeemIsWitnessProgram :=
//     match stackCopy with
//     | [] => false
//     | p :: _ => (isWitnessProgram p).isSome
//   let finalLen : Nat :=
//     if flags.witness ∧ redeemIsWitnessProgram then 1
//     else <recompute the redeem-script eval length>
//
// i.e. key the resize off the P2SH *redeem* script (the script actually
// verified by `p2shInner`), not the scriptPubKey.  This file is a shadow of
// the proposed model, NOT the pinned model: it exists only to show that the
// full three-arm cell becomes a single green comparison once Defs.lean is
// fixed.  Nothing in spec/core is changed by this workstream.

EVINLINE uint64_t l_lean_fixed(uint64_t cleanstack, uint64_t witness,
                               uint64_t p2sh, uint64_t st_n, uint64_t spk_wit,
                               uint64_t spk_p2sh, uint64_t redeem_wit,
                               uint64_t ss_push_ok, uint64_t sig_n,
                               uint64_t wit_n, uint64_t inner_len) {
    if (spk_wit && spk_p2sh) return 0xffffffffffffffffULL;  // impossible shape
    // Reachable ok-path preconditions: the post-scriptPubKey evaluation
    // left a non-empty stack (2037-2040), and the P2SH subscript
    // evaluation left a non-empty stack (2083-2086 / p2shInner).
    if (st_n == 0 || ((p2sh && spk_p2sh) && inner_len == 0))
        return 0xffffffffffffffffULL;
    const uint64_t bare_wit = witness & spk_wit;
    const uint64_t p2sh_br = p2sh & spk_p2sh;
    const uint64_t wit_sub = p2sh_br & witness & redeem_wit;

    if (bare_wit && sig_n != 0) return ev_pack(0, EV_WITNESS_MALLEATED);

    if (p2sh_br) {
        if (wit_sub && !ss_push_ok)
            return ev_pack(0, EV_WITNESS_MALLEATED_P2SH);
        // fixed `finalLen`: keyed off the redeem-script predicate
        const uint64_t final_len = wit_sub ? 1u : inner_len;
        if (cleanstack && final_len != 1) return ev_pack(0, EV_CLEANSTACK);
        const uint64_t a = bare_wit & (sig_n == 0);
        const uint64_t b = redeem_wit & ss_push_ok;
        if (witness && wit_n != 0 && !(a | b))
            return ev_pack(0, EV_WITNESS_UNEXPECTED);
        return ev_pack(1, 0);
    }

    const uint64_t after_bare = bare_wit ? 1u : st_n;
    if (cleanstack && after_bare != 1) return ev_pack(0, EV_CLEANSTACK);
    if (witness && wit_n != 0 && !bare_wit)
        return ev_pack(0, EV_WITNESS_UNEXPECTED);
    return ev_pack(1, 0);
}

extern "C" uint64_t probe_scr008(uint64_t cleanstack, uint64_t witness,
                                 uint64_t p2sh, uint64_t st_n, uint64_t spk_wit,
                                 uint64_t spk_p2sh, uint64_t redeem_wit,
                                 uint64_t ss_push_ok, uint64_t sig_n,
                                 uint64_t wit_n, uint64_t inner_len) {
    return l_lean_fixed(cleanstack & 1u, witness & 1u, p2sh & 1u, st_n & 3u,
                        spk_wit & 1u, spk_p2sh & 1u, redeem_wit & 1u,
                        ss_push_ok & 1u, sig_n & 3u, wit_n & 3u,
                        inner_len & 3u);
}
