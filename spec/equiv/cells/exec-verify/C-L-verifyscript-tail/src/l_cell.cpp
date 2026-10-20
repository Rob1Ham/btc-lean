#include "common.h"

// L leg — REVIEWED TRANSLITERATION, not generated from the twin.
//
// Source of record: spec/core/Bitcoin/Interpreter/Defs.lean:1328-1455
// (`p2shInner` + `verifyScriptFull`).  The twin has no VerifyScript handler,
// so the branch order below is transcribed from the Lean definition, which is
// itself cited to interpreter.cpp:2012-2111.  Where the Lean model recomputes
// a value instead of carrying Core's state, the cell says so explicitly.
//
// Lean's tail (paraphrased):
//
//   if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
//   else
//     let bare := if flags.witness then
//         match isWitnessProgram spk with
//         | some _ => if ss.size ≠ 0 then .fail .witnessMalleated
//                     else verifyWitnessProgram ...          -- abstracted ok
//         | none   => .ok
//       else .ok
//     ...
//     if flags.p2sh ∧ isPayToScriptHash spk then
//       match p2shInner ... with                             -- .fail e -> .fail e
//       | .ok =>
//         let finalLen := ...                                 -- see note below
//         if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack
//         else if flags.witness ∧ witness ≠ [] ∧
//                 ¬( (flags.witness ∧ isWitProg spk ∧ ss.size = 0) ∨
//                    (isWitProg redeem ∧ ss = pushBytesWire redeem) )
//           then .fail .witnessUnexpected
//         else .ok
//     else
//       if pol.cleanstack ∧ afterBare.length ≠ 1 then .fail .cleanstack
//       else if flags.witness ∧ witness ≠ [] ∧ ¬(flags.witness ∧ isWitProg spk)
//         then .fail .witnessUnexpected
//       else .ok
//
// Lean's `finalLen` on the P2SH branch recomputes the inner eval length.  On
// the reachable P2SH-witness domain the 42 guard forces scriptSig to be
// exactly `push(redeemScript)`, so stackCopy has one element, the subscript
// `OP_n <program>` leaves exactly one item, and the recomputation equals
// Core's `stack.resize(1)` (interpreter.cpp:2102).  The cell uses the constant
// 1 there and states that premise; the general recomputation is not modelled.
//
// `l_single_push_eq` mirrors `ss == pushBytesWire punkKey2` for redeemScript
// lengths 0..2 (single-byte push opcode).

enum LVerdict { L_FAIL = 0, L_OK = 1 };

EVINLINE uint64_t l_cast_to_bool(uint64_t len, uint64_t b) {
    // Lean castToBool: `vch.any (· ≠ 0) && ¬(last = 0x80)`, one-byte bound.
    if (len == 0) return 0;
    return (b != 0) & (b != 0x80);
}

EVINLINE uint64_t l_single_push_eq(uint64_t sig_len, uint64_t sig_b0,
                                   uint64_t sig_b1, uint64_t sig_b2,
                                   uint64_t redeem_len, uint64_t redeem_b0,
                                   uint64_t redeem_b1) {
    if (redeem_len > 2) return 0;              // out of the claimed push encoding
    // pushBytesWire redeem = [len] ++ redeem for len <= 75; == is length+bytes.
    const uint64_t len_ok = (sig_len == redeem_len + 1);
    const uint64_t op_ok = (sig_b0 == redeem_len);
    const uint64_t b0_ok = (redeem_len < 1) | (sig_b1 == redeem_b0);
    const uint64_t b1_ok = (redeem_len < 2) | (sig_b2 == redeem_b1);
    return len_ok & op_ok & b0_ok & b1_ok;
}

EVINLINE uint64_t l_vs_tail(uint64_t witness, uint64_t p2sh, uint64_t cleanstack,
                            uint64_t st_n, uint64_t top_len, uint64_t top_b,
                            uint64_t spk_wit, uint64_t spk_p2sh, uint64_t sig_n,
                            uint64_t sig_push_ok, uint64_t wit_n,
                            uint64_t p2sh_wit_prog, uint64_t p2sh_len) {
    // `if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse`
    if (st_n == 0 || !l_cast_to_bool(top_len, top_b)) {
        return ev_pack(L_FAIL, EV_EVAL_FALSE);
    }

    const uint64_t bare_wit = witness & spk_wit;          // flags.witness ∧ isWitProg spk
    const uint64_t p2sh_br = p2sh & spk_p2sh;             // flags.p2sh ∧ isPayToScriptHash spk
    const uint64_t wit_sub = p2sh_br & witness & p2sh_wit_prog;

    // bare arm: `if ss.size ≠ 0 then .fail .witnessMalleated`
    if (bare_wit && sig_n != 0) return ev_pack(L_FAIL, EV_WITNESS_MALLEATED);

    // p2shInner's own failure comes first, before any ok-path tail check.
    if (wit_sub && !sig_push_ok) return ev_pack(L_FAIL, EV_WITNESS_MALLEATED_P2SH);

    if (p2sh_br) {
        // finalLen: witness sub-arm resizes to 1; otherwise the inner stack.
        const uint64_t final_len = wit_sub ? 1u : p2sh_len;
        if (cleanstack && final_len != 1) return ev_pack(L_FAIL, EV_CLEANSTACK);
        // ¬(A ∨ B), A = witness ∧ isWitProg spk ∧ ss.size = 0,
        //            B = isWitProg redeem ∧ ss = push(redeem)
        const uint64_t a = bare_wit & (sig_n == 0);
        const uint64_t b = wit_sub & sig_push_ok;
        if (witness && wit_n != 0 && !(a | b)) {
            return ev_pack(L_FAIL, EV_WITNESS_UNEXPECTED);
        }
        return ev_pack(L_OK, 0);
    }
    // non-P2SH tail: afterBare = resize(1) or the evaluated stack.
    const uint64_t after_bare = bare_wit ? 1u : st_n;
    if (cleanstack && after_bare != 1) return ev_pack(L_FAIL, EV_CLEANSTACK);
    if (witness && wit_n != 0 && !bare_wit) {
        return ev_pack(L_FAIL, EV_WITNESS_UNEXPECTED);
    }
    return ev_pack(L_OK, 0);
}

extern "C" uint64_t cell_single_push_eq(uint64_t sig_len, uint64_t sig_b0,
                                        uint64_t sig_b1, uint64_t sig_b2,
                                        uint64_t redeem_len, uint64_t redeem_b0,
                                        uint64_t redeem_b1) {
    return l_single_push_eq(sig_len & 3u, sig_b0 & 0xffu, sig_b1 & 0xffu,
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
    return l_vs_tail(witness & 1u, p2sh & 1u, cleanstack & 1u, st_n & 3u,
                     top_len & 1u, top_b & 0xffu, spk_wit & 1u, spk_p2sh & 1u,
                     sig_n & 3u, sig_push_ok & 1u, wit_n & 3u,
                     p2sh_wit_prog & 1u, p2sh_len & 3u);
}
