#include "common.h"

// L leg — REVIEWED TRANSLITERATION, not generated from the twin.
//
// Sources of record:
//   spec/core/Bitcoin/Interpreter/Defs.lean:1313-1316  (`isPayToScriptHash`)
//   spec/core/Bitcoin/Interpreter/Defs.lean:1328-1355  (`p2shInner`)
//
//   def isPayToScriptHash (b : ByteArray) : Bool :=
//     b.size = 23 ∧ (b.get! 0).toNat = 0xa9 ∧ (b.get! 1).toNat = 0x14 ∧
//       (b.get! 22).toNat = 0x87
//
//   def p2shInner ... (ss : ByteArray) (stackCopy : Stack) ... :=
//     match parseWire ss with
//     | none => .fail .badOpcode
//     | some ops =>
//       if !isPushOnlyWire ops then .fail .sigPushOnly
//       else
//         match stackCopy with
//         | [] => .fail .unknownError          -- Core: assert(!stack.empty())
//         | pubKeySerialized :: rest =>
//           let pubKey2 := pubKeySerialized
//           match evalScriptBytes ... pubKey2 rest ... with ...
//
// The twin has no VerifyScript handler, so both are transcribed by review.
// The one thing to read carefully is the *list orientation*: Lean's `Stack` is
// head = top (`stack[0]!` is the top in verifyScriptFull), while Core's
// `std::vector` is back = top.  The cell's inputs t0..t2 use Core's
// bottom-to-top order (so the observable is well-defined), and the L leg
// builds Lean's head-first `stackCopy` list from them, destructures
// `pubKeySerialized :: rest`, then reverses `rest` back to bottom-to-top for
// the packed observable.  That reversal is the transliteration's real content:
// it is where a wrong stack orientation shows up as an Alive2 counterexample.
//
// `parseWire ss` / `isPushOnlyWire ops` are the SCR-006 precondition proved in
// `C-L-pushonly`; the handoff is proved for every push-only scriptSig.  The
// `| [] => .fail .unknownError` arm is Lean's totalization of Core's
// unreachable assert; both legs report the declared out-of-model marker 3.

enum LVerdict { L_FAIL = 0, L_OK = 1, L_OOM = 3 };

EVINLINE uint64_t l_p2sh_shape(uint64_t len, uint64_t b0, uint64_t b1,
                               uint64_t b_last) {
    // `b.size = 23 ∧ b[0] = 0xa9 ∧ b[1] = 0x14 ∧ b[22] = 0x87`, as four
    // independent Bool conjuncts (Lean `∧`).
    const uint64_t ok_len = (len == 23);
    const uint64_t ok_0 = (b0 == 0xa9);
    const uint64_t ok_1 = (b1 == 0x14);
    const uint64_t ok_last = (b_last == 0x87);
    return ok_len & ok_0 & ok_1 & ok_last;
}

EVINLINE uint64_t l_p2sh_handoff(uint64_t p2sh, uint64_t spk_shape,
                                 uint64_t sn, uint64_t t0, uint64_t t1,
                                 uint64_t t2) {
    const uint64_t in_arm = p2sh & spk_shape;
    if (!in_arm) return ev_pack_handoff(L_OOM, 0, 0, 0, 0, 0, 0, 0);

    // Lean's `stackCopy`, head-first (= top-first).  Built from the Core-order
    // inputs, then destructured as `pubKeySerialized :: rest`.
    uint64_t pubKeySerialized, rest_n, r0, r1;
    if (sn == 0) {
        pubKeySerialized = 0; rest_n = 0; r0 = 0; r1 = 0;
    } else if (sn == 1) {
        pubKeySerialized = t0; rest_n = 0; r0 = 0; r1 = 0;
    } else if (sn == 2) {
        pubKeySerialized = t1; rest_n = 1; r0 = t0; r1 = 0;
    } else {
        pubKeySerialized = t2; rest_n = 2; r0 = t1; r1 = t0;
    }

    // Lean's `| [] => .fail .unknownError` (Core asserts instead).
    if (sn == 0) return ev_pack_handoff(L_OOM, 0, 0, 0, 0, 0, 0, 0);

    // Observable is Core's bottom-to-top order: reverse Lean's head-first
    // `rest`.  rest = [r0] (n=2) or [r0, r1] (n=3).
    const uint64_t b0 = (rest_n >= 1) ? ((rest_n == 2) ? r1 : r0) : 0;
    const uint64_t b1 = (rest_n >= 2) ? r0 : 0;
    const uint64_t b2 = 0;   // rest_n <= 2

    return ev_pack_handoff(L_OK, 0, rest_n, b0, b1, b2, pubKeySerialized, 1);
}

extern "C" uint64_t cell_p2sh_shape(uint64_t len, uint64_t b0, uint64_t b1,
                                    uint64_t b_last) {
    return l_p2sh_shape(len & 0x3fu, b0 & 0xffu, b1 & 0xffu, b_last & 0xffu);
}

extern "C" uint64_t cell_p2sh_handoff(uint64_t p2sh, uint64_t spk_shape,
                                      uint64_t sn, uint64_t t0, uint64_t t1,
                                      uint64_t t2) {
    return l_p2sh_handoff(p2sh & 1u, spk_shape & 1u, sn & 3u, t0 & 0xffu,
                          t1 & 0xffu, t2 & 0xffu);
}
