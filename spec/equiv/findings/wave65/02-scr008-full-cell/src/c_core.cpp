#include "probe_common.h"

// C leg of the *full-domain* SCR-008 probe: Core's VerifyScript tail at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, with no domain restriction.
//
// This is the same excerpt as the cell's C leg
// (cells/exec-verify/C-L-w65-scr008-cleanstack-arms/src/c_cell.cpp) with the
// F-DIV-W32-01 class *included*: the two `stack.resize(1)` sites (2057 bare,
// 2102 P2SH-wrapped) feed the terminal CLEANSTACK check (2110-2118), and
// hadWitness feeds the WITNESS_UNEXPECTED tail (2120-2127).
//
// The only domain restriction kept is the script-shape one: a scriptPubKey
// cannot be both a witness program (leading OP_0 / OP_1..OP_16) and P2SH
// (leading OP_HASH160, 23 bytes).  Core's two arms are mutually exclusive on
// real inputs; an unconstrained symbolic variable would otherwise invent the
// intersection and produce an out-of-domain counterexample (the wave-32
// mistake this finding deliberately avoids).
//
//   2057  stack.resize(1);   // bare witness program
//   2102  stack.resize(1);   // P2SH-wrapped witness program
//   2115  if (stack.size() != 1) return CLEANSTACK;
//
// Inputs: st_n (post-spk depth, >= 1), spk_wit, spk_p2sh, redeem_wit,
// ss_push_ok, sig_n, wit_n, inner_len (P2SH subscript eval depth).

EVINLINE uint64_t c_core(uint64_t cleanstack, uint64_t witness, uint64_t p2sh,
                         uint64_t st_n, uint64_t spk_wit, uint64_t spk_p2sh,
                         uint64_t redeem_wit, uint64_t ss_push_ok,
                         uint64_t sig_n, uint64_t wit_n, uint64_t inner_len) {
    if (spk_wit && spk_p2sh) return 0xffffffffffffffffULL;  // impossible shape
    // Reachable ok-path preconditions: the post-scriptPubKey evaluation
    // left a non-empty stack (2037-2040), and the P2SH subscript
    // evaluation left a non-empty stack (2083-2086 / p2shInner).
    if (st_n == 0 || ((p2sh && spk_p2sh) && inner_len == 0))
        return 0xffffffffffffffffULL;
    uint64_t len = st_n, had = 0;

    if (witness && spk_wit) {                 // 2045-2058
        had = 1;
        if (sig_n != 0) return ev_pack(0, EV_WITNESS_MALLEATED);
        len = 1;                              // 2057 resize(1)
    }

    if (p2sh && spk_p2sh) {                   // 2062-2105
        if (witness && redeem_wit) {
            had = 1;
            if (!ss_push_ok) return ev_pack(0, EV_WITNESS_MALLEATED_P2SH);
            len = 1;                          // 2102 resize(1)
        } else {
            len = inner_len;
        }
    }

    if (cleanstack && len != 1) return ev_pack(0, EV_CLEANSTACK);   // 2110-2118
    if (witness && !had && wit_n != 0)                              // 2120-2127
        return ev_pack(0, EV_WITNESS_UNEXPECTED);
    return ev_pack(1, 0);
}

extern "C" uint64_t probe_scr008(uint64_t cleanstack, uint64_t witness,
                                 uint64_t p2sh, uint64_t st_n, uint64_t spk_wit,
                                 uint64_t spk_p2sh, uint64_t redeem_wit,
                                 uint64_t ss_push_ok, uint64_t sig_n,
                                 uint64_t wit_n, uint64_t inner_len) {
    return c_core(cleanstack & 1u, witness & 1u, p2sh & 1u, st_n & 3u,
                  spk_wit & 1u, spk_p2sh & 1u, redeem_wit & 1u,
                  ss_push_ok & 1u, sig_n & 3u, wit_n & 3u, inner_len & 3u);
}
