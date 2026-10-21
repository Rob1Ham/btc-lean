#include "common.h"

// C leg — line-cited source-excerpt slice of Core `VerifyScript` at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Region: every computation that decides the CLEANSTACK-relevant final stack
// length, and the terminal CLEANSTACK / WITNESS_UNEXPECTED checks, for the
// row's three paths:
//
//   plain script            2045-2131 with no witness program and no P2SH
//   native witness program  2045-2058  (`stack.resize(1)` at 2057)
//   P2SH-wrapped witness    2062-2105  (`stack.resize(1)` at 2102)
//
// with the error precedence of the probe (2048-2050 WITNESS_MALLEATED,
// 2092-2095 WITNESS_MALLEATED_P2SH, 2110-2118 CLEANSTACK, 2120-2127
// WITNESS_UNEXPECTED).
//
// Declared inputs (see spec.md):
//   st_n       post-scriptPubKey stack depth, 0..3.  `st_n >= 1` and a truthy
//              top element are preconditions of this cell (the EVAL_FALSE
//              checks 2037-2040 are `exec-verify/C-L-verifyscript-tail`).
//   spk_wit    scriptPubKey.IsWitnessProgram(...)      (2046)
//   spk_p2sh   scriptPubKey.IsPayToScriptHash()        (2062)
//   redeem_wit redeemScript.IsWitnessProgram(...)      (2091)
//   ss_push_ok scriptSig == CScript() << redeemScript  (2092) — the length
//              bound of that comparison is the tail cell's `cell_single_push_eq`
//   sig_n      scriptSig.size()                          (2048)
//   wit_n      witness stack item count                  (2126)
//   inner_len  depth of the stack after the P2SH subscript `EvalScript`
//              returns ok (2080-2086 abstraction); it is the same quantity
//              Lean's `finalLen` recomputes.
//
// `VerifyWitnessProgram` is abstracted to success (its failure propagation is
// SCR-017, `exec-verify/C-L-failure-propagation`); the P2SH push-only check
// (2065-2066) is a precondition (SCR-006, `exec-verify/C-L-pushonly`).

EVINLINE uint64_t c_scr008_arms(uint64_t cleanstack, uint64_t witness,
                                uint64_t p2sh, uint64_t st_n, uint64_t spk_wit,
                                uint64_t spk_p2sh, uint64_t redeem_wit,
                                uint64_t ss_push_ok, uint64_t sig_n,
                                uint64_t wit_n, uint64_t inner_len) {
    if (!ev_scr008_in_domain(cleanstack, witness, p2sh, spk_wit, spk_p2sh,
                             redeem_wit, ss_push_ok))
        return EV_OUT_OF_DOMAIN;

    uint64_t len = st_n, had = 0;

    // interpreter.cpp:2045-2058 — native witness program
    if (witness && spk_wit) {
        had = 1;
        // 2048-2050: scriptSig must be exactly CScript().
        if (sig_n != 0) return ev_pack(0, EV_WITNESS_MALLEATED);
        // 2052-2054: VerifyWitnessProgram abstracted to success.
        len = 1;                                          // 2057 resize(1)
    }

    // interpreter.cpp:2062-2105 — P2SH
    if (p2sh && spk_p2sh) {
        // 2065-2066 push-only, 2069 swap/poppstack, 2080-2086 subscript
        // EvalScript + EVAL_FALSE: preconditions/abstraction, see above.
        if (witness && redeem_wit) {
            had = 1;
            // 2092-2095: scriptSig must be exactly a single push of redeem.
            if (!ss_push_ok) return ev_pack(0, EV_WITNESS_MALLEATED_P2SH);
            // 2097-2099: VerifyWitnessProgram abstracted to success.
            len = 1;                                      // 2102 resize(1)
        } else {
            len = inner_len;         // subscript eval stack, 2080-2086
        }
    }

    // interpreter.cpp:2110-2118 — CLEANSTACK
    if (cleanstack && len != 1) return ev_pack(0, EV_CLEANSTACK);

    // interpreter.cpp:2120-2127 — unexpected witness data
    if (witness && !had && wit_n != 0) return ev_pack(0, EV_WITNESS_UNEXPECTED);

    return ev_pack(1, 0);
}

extern "C" uint64_t cell_scr008_arms(uint64_t cleanstack, uint64_t witness,
                                     uint64_t p2sh, uint64_t st_n,
                                     uint64_t spk_wit, uint64_t spk_p2sh,
                                     uint64_t redeem_wit, uint64_t ss_push_ok,
                                     uint64_t sig_n, uint64_t wit_n,
                                     uint64_t inner_len) {
    return c_scr008_arms(cleanstack & 1u, witness & 1u, p2sh & 1u, st_n & 3u,
                         spk_wit & 1u, spk_p2sh & 1u, redeem_wit & 1u,
                         ss_push_ok & 1u, sig_n & 3u, wit_n & 3u,
                         inner_len & 3u);
}
