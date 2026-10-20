#include "common.h"

// L leg — REVIEWED TRANSLITERATION, not generated from the twin.
//
// Source of record: spec/core/Bitcoin/Interpreter/Defs.lean:1363-1455
// (`verifyScriptFull`), whose failure propagation is a chain of `match`
// expressions:
//
//   match evalScriptBytes ... ss ... with
//   | .error e => .fail e
//   | .ok stack1 =>
//     match evalScriptBytes ... spk stack1 ... with
//     | .error e => .fail e
//     | .ok stack =>
//       match bare with                         -- VerifyWitnessProgram (2052)
//       | .fail e => .fail e
//       | .unjudged => .unjudged
//       | .ok =>
//         match p2shInner ... with              -- EvalScript (2080)
//         | .fail e => .fail e                  -- verifyWitnessProgram (2097)
//         | .unjudged => .unjudged
//         | .ok => .ok
//
// The cell writes that chain as nested conditional *expressions* (Lean's
// `match` is an expression), so the L IR is a select tree rather than the
// C leg's early-return branches.  `p2shInner`'s two failure sources are
// flattened into sites 4 and 5; site 5 is reachable only when site 4 ran,
// which is why both conjuncts carry `act4`.
//
// `.unjudged` is outside SCR-017 (it is not "failure ⇒ invalid"; it is
// "not judged") and is not modelled.

EVINLINE uint64_t l_failprop(uint64_t ok1, uint64_t err1,
                             uint64_t ok2, uint64_t err2,
                             uint64_t act3, uint64_t ok3, uint64_t err3,
                             uint64_t act4, uint64_t ok4, uint64_t err4,
                             uint64_t act5, uint64_t ok5, uint64_t err5) {
    const uint64_t f1 = (ok1 == 0);
    const uint64_t f2 = (ok2 == 0);
    const uint64_t f3 = (act3 && !ok3);
    const uint64_t f4 = (act4 && !ok4);
    const uint64_t f5 = (act4 && act5 && !ok5);

    // `match` chain: the first `.error`/`.fail` is the result.
    return f1 ? ev_pack(0, err1, 1)
         : f2 ? ev_pack(0, err2, 2)
         : f3 ? ev_pack(0, err3, 3)
         : f4 ? ev_pack(0, err4, 4)
         : f5 ? ev_pack(0, err5, 5)
         : ev_pack(1, 0, 0);
}

extern "C" uint64_t cell_failprop(uint64_t ok1, uint64_t err1,
                                  uint64_t ok2, uint64_t err2,
                                  uint64_t act3, uint64_t ok3, uint64_t err3,
                                  uint64_t act4, uint64_t ok4, uint64_t err4,
                                  uint64_t act5, uint64_t ok5, uint64_t err5) {
    return l_failprop(ok1 & 1u, err1 & 0x3fu, ok2 & 1u, err2 & 0x3fu,
                      act3 & 1u, ok3 & 1u, err3 & 0x3fu,
                      act4 & 1u, ok4 & 1u, err4 & 0x3fu,
                      act5 & 1u, ok5 & 1u, err5 & 0x3fu);
}
