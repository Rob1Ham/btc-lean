#include "common.h"

// L leg — REVIEWED TRANSLITERATION, not generated from the twin.
//
// Source of record: spec/core/Bitcoin/Interpreter/Defs.lean (`p2shInner`
// and `verifyScriptFull`), blob 363d3738b66049e260577e9c1fa2cd24d05f6e3b at
// this cell's base.  The twin has no VerifyScript handler, so the branch
// order is transcribed from the Lean definition.
//
// Lean, after the scriptPubKey evaluation (stack non-empty, top truthy):
//
//   if flags.witness then
//     match isWitnessProgram spk with
//     | some _ => if ss.size ≠ 0 then .fail .witnessMalleated
//                 else <verifyWitnessProgram>            -- abstracted ok
//     | none   => .ok
//   ...
//   let afterBare := if flags.witness ∧ (isWitnessProgram spk).isSome
//                    then [stack[0]!] else stack
//   if flags.p2sh ∧ isPayToScriptHash spk then
//     match p2shInner ... with
//     | .ok =>
//       let finalLen : Nat :=
//         if flags.witness ∧ (isWitnessProgram spk).isSome then 1
//         else <recompute the redeem-script eval length>
//       if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack
//       else if flags.witness ∧ witness ≠ [] ∧ ¬(A ∨ B) then .fail .witnessUnexpected
//       else .ok
//   else
//     if pol.cleanstack ∧ afterBare.length ≠ 1 then .fail .cleanstack
//     else if flags.witness ∧ witness ≠ [] ∧ ¬(flags.witness ∧ isWitProg spk)
//       then .fail .witnessUnexpected
//     else .ok
//
// `p2shInner` fails `.witnessMalleatedP2SH` when
//   flags.witness ∧ isWitProg(redeem) ∧ ss ≠ push(redeem)
// and otherwise returns ok for the witness sub-arm (the inner `EvalScript`
// leaving the redeem-program stack is abstracted to `inner_len`).
//
// NOTE — `finalLen` tests `isWitnessProgram spk`, where `spk` is the P2SH
// scriptPubKey, so the P2SH-wrapped witness arm never takes the `1` branch.
// That is the pinned model's real shape (F-DIV-W32-01); this leg reproduces
// it literally.  The cell's declared domain excludes exactly the input class
// where that shape differs from Core (:2102 `stack.resize(1)` under
// CLEANSTACK), so the difference is not hidden inside the equality proof —
// it is fenced out and exercised in findings/wave65/02-scr008-full-cell/.

EVINLINE uint64_t l_scr008_arms(uint64_t cleanstack, uint64_t witness,
                                uint64_t p2sh, uint64_t st_n, uint64_t spk_wit,
                                uint64_t spk_p2sh, uint64_t redeem_wit,
                                uint64_t ss_push_ok, uint64_t sig_n,
                                uint64_t wit_n, uint64_t inner_len) {
    if (!ev_scr008_in_domain(cleanstack, witness, p2sh, spk_wit, spk_p2sh,
                             redeem_wit, ss_push_ok))
        return EV_OUT_OF_DOMAIN;

    const uint64_t bare_wit = witness & spk_wit;
    const uint64_t p2sh_br = p2sh & spk_p2sh;
    const uint64_t wit_sub = p2sh_br & witness & redeem_wit;

    // bare arm failure (`bare` is matched before the P2SH branch)
    if (bare_wit && sig_n != 0) return ev_pack(0, EV_WITNESS_MALLEATED);

    if (p2sh_br) {
        // p2shInner's own failure precedes every ok-path tail check.
        if (wit_sub && !ss_push_ok)
            return ev_pack(0, EV_WITNESS_MALLEATED_P2SH);

        // `finalLen` exactly as the model writes it: the `1` branch is keyed
        // off the *scriptPubKey* witness-program predicate, not the redeem
        // script.  On this cell's domain spk_wit = 0 whenever spk_p2sh = 1.
        const uint64_t final_len = bare_wit ? 1u : inner_len;

        if (cleanstack && final_len != 1)
            return ev_pack(0, EV_CLEANSTACK);
        // Lean's A ∨ B: A = flags.witness ∧ isWitProg spk ∧ ss.size = 0,
        //               B = isWitProg(redeem) ∧ ss = push(redeem)
        const uint64_t a = bare_wit & (sig_n == 0);
        const uint64_t b = redeem_wit & ss_push_ok;
        if (witness && wit_n != 0 && !(a | b))
            return ev_pack(0, EV_WITNESS_UNEXPECTED);
        return ev_pack(1, 0);
    }

    // non-P2SH tail: afterBare is resize(1) or the evaluated stack.
    const uint64_t after_bare = bare_wit ? 1u : st_n;
    if (cleanstack && after_bare != 1) return ev_pack(0, EV_CLEANSTACK);
    if (witness && wit_n != 0 && !bare_wit)
        return ev_pack(0, EV_WITNESS_UNEXPECTED);
    return ev_pack(1, 0);
}

extern "C" uint64_t cell_scr008_arms(uint64_t cleanstack, uint64_t witness,
                                     uint64_t p2sh, uint64_t st_n,
                                     uint64_t spk_wit, uint64_t spk_p2sh,
                                     uint64_t redeem_wit, uint64_t ss_push_ok,
                                     uint64_t sig_n, uint64_t wit_n,
                                     uint64_t inner_len) {
    return l_scr008_arms(cleanstack & 1u, witness & 1u, p2sh & 1u, st_n & 3u,
                         spk_wit & 1u, spk_p2sh & 1u, redeem_wit & 1u,
                         ss_push_ok & 1u, sig_n & 3u, wit_n & 3u,
                         inner_len & 3u);
}
