#include "probe_common.h"

// L leg of the *full-domain* SCR-008 probe: the pinned Lean model's
// `finalLen` rule, verbatim (no domain restriction).
//
// Source of record: spec/core/Bitcoin/Interpreter/Defs.lean, blob
// 363d3738b66049e260577e9c1fa2cd24d05f6e3b (base 76dbfe5):
//
//   let finalLen : Nat :=
//     if flags.witness ∧ (isWitnessProgram spk).isSome then 1
//     else <recompute the redeem-script eval length>
//
// `spk` is the P2SH scriptPubKey in this branch, so the `1` branch is taken
// only for the *bare* arm; the P2SH-wrapped witness arm keeps the inner
// length.  Core instead resizes to 1 at :2102 for both arms.
//
// Everything else (error order, hadWitness, WITNESS_UNEXPECTED) is the
// model's own shape and is identical to the C leg.

EVINLINE uint64_t l_lean_pinned(uint64_t cleanstack, uint64_t witness,
                                uint64_t p2sh, uint64_t st_n,
                                uint64_t spk_wit, uint64_t spk_p2sh,
                                uint64_t redeem_wit, uint64_t ss_push_ok,
                                uint64_t sig_n, uint64_t wit_n,
                                uint64_t inner_len) {
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
        // pinned `finalLen`: keyed off the scriptPubKey predicate
        const uint64_t final_len = bare_wit ? 1u : inner_len;
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
    return l_lean_pinned(cleanstack & 1u, witness & 1u, p2sh & 1u, st_n & 3u,
                         spk_wit & 1u, spk_p2sh & 1u, redeem_wit & 1u,
                         ss_push_ok & 1u, sig_n & 3u, wit_n & 3u,
                         inner_len & 3u);
}
