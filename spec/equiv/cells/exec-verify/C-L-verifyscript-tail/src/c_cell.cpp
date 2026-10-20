#include "common.h"

// C leg — line-cited source-excerpt slice of Core `VerifyScript` at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// The slice starts *after* the scriptPubKey evaluation (interpreter.cpp:2034)
// and therefore covers, in Core's order:
//
//   2037-2040  stack.empty() / CastToBool(stack.back()) -> EVAL_FALSE
//   2045-2058  bare witness program: scriptSig must be empty (41);
//              VerifyWitnessProgram (abstracted to success here); resize(1)
//   2062-2105  P2SH arm: scriptSig push-only (see the pushonly cell),
//              swap(stack, stackCopy), pop redeemScript, subscript EvalScript
//              (abstracted to "ok with p2sh_len"), EVAL_FALSE checks
//              (abstracted), P2SH witness: scriptSig must be exactly one push
//              of redeemScript (42); VerifyWitnessProgram (abstracted);
//              resize(1)
//   2110-2118  CLEANSTACK: stack.size() != 1 -> CLEANSTACK (30)
//   2120-2127  WITNESS tail: !hadWitness && !witness->IsNull() -> 43
//
// The three sub-calls (EvalScript of the subscript, VerifyWitnessProgram) are
// declared inputs: the tail is proved for *every* outcome the abstractions can
// produce (the P2SH inner stack length is symbolic).  `cast_to_bool` is the
// real Core body (interpreter.cpp:46-59) bounded to 0- or 1-byte elements,
// which is exact for that domain.
//
// `c_single_push_eq` is the 2092 comparison, bounded to redeemScript lengths
// 0..2 and the single-byte push encoding (script.h:408-423, 484-489).

EVINLINE uint64_t c_cast_to_bool(uint64_t len, uint64_t b) {
    // interpreter.cpp:46-59, elements of at most one byte: 0x00 and the
    // negative zero 0x80 are false, every other non-empty byte is true.
    if (len == 0) return 0;
    if (b == 0) return 0;
    if (b == 0x80) return 0;
    return 1;
}

EVINLINE uint64_t c_single_push_eq(uint64_t sig_len, uint64_t sig_b0,
                                   uint64_t sig_b1, uint64_t sig_b2,
                                   uint64_t redeem_len, uint64_t redeem_b0,
                                   uint64_t redeem_b1) {
    // Out-of-model: only redeemScript lengths 0..2 are claimed.
    if (redeem_len > 2) return 0;
    // CScript() << std::vector(pubKey2) appends AppendDataSize(len) ++ data;
    // for len <= 75 that is the single byte `len`.  operator== is length +
    // byte equality (prevector.h:429).
    if (sig_len != redeem_len + 1) return 0;
    if (sig_b0 != redeem_len) return 0;
    if (redeem_len >= 1 && sig_b1 != redeem_b0) return 0;
    if (redeem_len >= 2 && sig_b2 != redeem_b1) return 0;
    return 1;
}

EVINLINE uint64_t c_vs_tail(uint64_t witness, uint64_t p2sh, uint64_t cleanstack,
                            uint64_t st_n, uint64_t top_len, uint64_t top_b,
                            uint64_t spk_wit, uint64_t spk_p2sh, uint64_t sig_n,
                            uint64_t sig_push_ok, uint64_t wit_n,
                            uint64_t p2sh_wit_prog, uint64_t p2sh_len) {
    uint64_t len, had = 0;

    // interpreter.cpp:2037-2040
    if (st_n == 0) return ev_pack(0, EV_EVAL_FALSE);
    if (!c_cast_to_bool(top_len, top_b)) return ev_pack(0, EV_EVAL_FALSE);

    // interpreter.cpp:2045-2058 — bare witness program
    if (witness && spk_wit) {
        had = 1;
        // 2048-2050: the scriptSig must be exactly CScript().
        if (sig_n != 0) return ev_pack(0, EV_WITNESS_MALLEATED);
        // 2052-2054: VerifyWitnessProgram abstracted to success.
        len = 1;                                   // 2057 stack.resize(1)
    } else {
        len = st_n;
    }

    // interpreter.cpp:2062-2105 — P2SH
    if (p2sh && spk_p2sh) {
        // 2065-2066 push-only: precondition of this cell (pushonly cell), and
        //   2069 swap(stack, stackCopy): the subscript runs on the scriptSig
        //        stack minus the redeemScript (p2sh-handoff cell).
        // 2080-2086: subscript EvalScript + EVAL_FALSE abstracted to
        //        "ok with p2sh_len".
        if (witness && p2sh_wit_prog) {
            had = 1;
            // 2092-2095: must be exactly a single push of the redeemScript.
            if (!sig_push_ok) return ev_pack(0, EV_WITNESS_MALLEATED_P2SH);
            // 2097-2098: VerifyWitnessProgram abstracted to success.
            len = 1;                               // 2102 stack.resize(1)
        } else {
            len = p2sh_len;
        }
    }

    // interpreter.cpp:2110-2118 — CLEANSTACK
    if (cleanstack && len != 1) return ev_pack(0, EV_CLEANSTACK);

    // interpreter.cpp:2120-2127 — unexpected witness data
    if (witness && !had && wit_n != 0) return ev_pack(0, EV_WITNESS_UNEXPECTED);

    return ev_pack(1, 0);
}

extern "C" uint64_t cell_single_push_eq(uint64_t sig_len, uint64_t sig_b0,
                                        uint64_t sig_b1, uint64_t sig_b2,
                                        uint64_t redeem_len, uint64_t redeem_b0,
                                        uint64_t redeem_b1) {
    return c_single_push_eq(sig_len & 3u, sig_b0 & 0xffu, sig_b1 & 0xffu,
                            sig_b2 & 0xffu, redeem_len & 3u,
                            redeem_b0 & 0xffu, redeem_b1 & 0xffu);
}

extern "C" uint64_t cell_vs_tail(uint64_t witness, uint64_t p2sh,
                                 uint64_t cleanstack, uint64_t st_n,
                                 uint64_t top_len, uint64_t top_b,
                                 uint64_t spk_wit, uint64_t spk_p2sh,
                                 uint64_t sig_n, uint64_t sig_push_ok,
                                 uint64_t wit_n, uint64_t p2sh_wit_prog,
                                 uint64_t p2sh_len) {
    return c_vs_tail(witness & 1u, p2sh & 1u, cleanstack & 1u, st_n & 3u,
                     top_len & 1u, top_b & 0xffu, spk_wit & 1u, spk_p2sh & 1u,
                     sig_n & 3u, sig_push_ok & 1u, wit_n & 3u,
                     p2sh_wit_prog & 1u, p2sh_len & 3u);
}
