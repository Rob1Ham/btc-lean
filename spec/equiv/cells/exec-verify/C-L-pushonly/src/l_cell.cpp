#include "common.h"

// L leg — REVIEWED TRANSLITERATION, not generated from the twin.
//
// Sources of record:
//   spec/core/Bitcoin/Interpreter/Defs.lean:421-431  (`parseWireFrom`,
//     `parseWire`)
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-228 (`getOpAux`, `getOp`)
//   spec/core/Bitcoin/Interpreter/Defs.lean:496  (`isPushOnlyWire`)
//
//   parseWireFrom : Nat → ByteArray → Nat → Option (List WireOp)
//     | 0,      _, _ => none
//     | f+1, b, i =>
//       if b.size ≤ i then some []
//       else match getOp b i with
//         | none => none
//         | some (o, i') => (parseWireFrom f b i').map (... :: tl)
//
//   isPushOnlyWire (ops : List WireOp) : Bool :=
//     ops.all (fun o => o.wire ≤ 0x60)
//
// and `getOpAux` (Parser/Defs.lean:206-224) is the 0x00-0xff table:
// direct push for 0x01-0x4b, PUSHDATA1/2/4 with 1/2/4 LE length bytes for
// 0x4c/0x4d/0x4e, no payload for >= 0x4f.  `sliceOpt` failure = truncated
// push = `none` (Core GetScriptOp's `end - pc < nSize`).
//
// Lean defines *two passes*: `parseWire` walks the whole script and fails on
// any truncated push, then `isPushOnlyWire` checks every decoded wire byte.
// This cell combines them into one walk: a truncated push and an opcode >
// OP_16 both make `IsPushOnly` false, so the conjunction is insensitive to
// the order, and `parseWire`'s strictness (all-or-nothing) is preserved
// because a truncation anywhere sets `ok = 0`.  The combination is a
// disclosed deviation from Lean's literal shape; it does not change the
// Boolean.  Relative to the C leg the L leg still differs: it carries an
// explicit (ok, push) pair through a shared decode helper instead of Core's
// early-return control flow, and its decode sums the PUSHDATA lengths with
// `zext` before the single bounds test.
//
// BOUND: script length 0..8 (packed u64).  Longer scripts are marker 3 (the
// general loop is the E5 residual).  Lean's fuel is `b.size + 1`; each pass
// is unrolled to eight steps, and each step consumes at least one byte, so
// no fuel can be exhausted on the claimed domain.  The unrolling is the exact
// loop body, not a weakened check.

EVINLINE uint64_t l_decode(uint64_t len, uint64_t script, uint64_t pc,
                           uint64_t *next, uint64_t *nsize, uint64_t *ok) {
    // One `getOpAux` step at index pc.  Returns the wire byte in the result
    // and the decoded next index / payload length through the pointers.
    const uint64_t op = ev_script_byte(script, pc);
    uint64_t p = pc + 1;
    uint64_t n = 0;
    uint64_t good = 1;
    if (op <= 0x4b) {
        n = op;
    } else if (op == 0x4c) {
        if (len - p < 1) good = 0;
        else { n = ev_script_byte(script, p); p += 1; }
    } else if (op == 0x4d) {
        if (len - p < 2) good = 0;
        else {
            n = ev_script_byte(script, p) |
                (ev_script_byte(script, p + 1) << 8);
            p += 2;
        }
    } else if (op == 0x4e) {
        if (len - p < 4) good = 0;
        else {
            n = ev_script_byte(script, p) |
                (ev_script_byte(script, p + 1) << 8) |
                (ev_script_byte(script, p + 2) << 16) |
                (ev_script_byte(script, p + 3) << 24);
            p += 4;
        }
    }
    // `sliceOpt b p n`: payload must fit.
    if (good) {
        if (len - p < n) good = 0;
        else p += n;
    }
    *next = p;
    *nsize = n;
    *ok = good;
    return op;
}

EVINLINE void l_push_step(uint64_t len, uint64_t script, uint64_t *pcp,
                          uint64_t *okp, uint64_t *pushp) {
    if (!*okp || *pcp >= len) return;
    uint64_t next, nsize, dok;
    const uint64_t op = l_decode(len, script, *pcp, &next, &nsize, &dok);
    if (!dok) { *okp = 0; return; }
    if (op > 0x60) *pushp = 0;                  // isPushOnlyWire
    *pcp = next;
}

EVINLINE void l_walk8(uint64_t len, uint64_t script, uint64_t *pc,
                      uint64_t *ok, uint64_t *push) {
    l_push_step(len, script, pc, ok, push);
    l_push_step(len, script, pc, ok, push);
    l_push_step(len, script, pc, ok, push);
    l_push_step(len, script, pc, ok, push);
    l_push_step(len, script, pc, ok, push);
    l_push_step(len, script, pc, ok, push);
    l_push_step(len, script, pc, ok, push);
    l_push_step(len, script, pc, ok, push);
}

EVINLINE uint64_t l_ispushonly(uint64_t len, uint64_t script) {
    if (len > EV_SCRIPT_MAX) return 3;       // out of model

    // One walk: parse failure and a non-push wire byte both end in false.
    uint64_t pc = 0;
    uint64_t ok = 1;
    uint64_t push = 1;
    l_walk8(len, script, &pc, &ok, &push);
    return (ok && push) ? 1 : 0;
}

EVINLINE uint64_t l_pushonly_early(uint64_t sigpushonly, uint64_t len,
                                   uint64_t script) {
    if (!sigpushonly) return ev_pack(1, 0);
    const uint64_t po = l_ispushonly(len, script);
    if (po == 3) return ev_pack(3, 0);
    if (!po) return ev_pack(0, EV_SIG_PUSHONLY);
    return ev_pack(1, 0);
}

EVINLINE uint64_t l_pushonly_p2sh(uint64_t p2sh, uint64_t spk_p2sh,
                                  uint64_t len, uint64_t script) {
    if (!(p2sh && spk_p2sh)) return ev_pack(1, 0);
    const uint64_t po = l_ispushonly(len, script);
    if (po == 3) return ev_pack(3, 0);
    if (!po) return ev_pack(0, EV_SIG_PUSHONLY);
    return ev_pack(1, 0);
}

extern "C" uint64_t cell_ispushonly(uint64_t len, uint64_t script) {
    return l_ispushonly(len & 0x0fu, script);
}

extern "C" uint64_t cell_pushonly_early(uint64_t sigpushonly, uint64_t len,
                                        uint64_t script) {
    return l_pushonly_early(sigpushonly & 1u, len & 0x0fu, script);
}

extern "C" uint64_t cell_pushonly_p2sh(uint64_t p2sh, uint64_t spk_p2sh,
                                       uint64_t len, uint64_t script) {
    return l_pushonly_p2sh(p2sh & 1u, spk_p2sh & 1u, len & 0x0fu, script);
}
