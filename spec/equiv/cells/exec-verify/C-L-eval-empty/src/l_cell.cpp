#include "common.h"

// L leg — REVIEWED TRANSLITERATION, not generated from the twin.
//
// Source of record: spec/core/Bitcoin/Interpreter/Defs.lean:1140-1157,
// `evalFrom` (the twin has no handler for the eval loop; the twin's
// `ops_ir.py` table is a per-opcode stepBody only, so the frame is
// transliterated by review):
//
//   evalFrom ctx : Nat -> List WireOp -> State -> Except ExecError State
//     | 0,      _,        _ => .error .unknownError
//     | _+1,    [],       st => if st.vf = [] then .ok st
//                              else .error .unbalancedConditional
//     | f+1, op :: rest, st => match stepChecked ctx op st with ...
//
// The cell excludes `fuel = 0` (a caller that supplies no budget cannot run
// even the empty list; `evalScriptBytes` always passes the script's opcode
// budget, which for a zero-op script is >= 1) and excludes the
// `op :: rest` case (a real step is the E5 dispatch residual).  What remains
// is exactly SCR-003: the empty op list yields `.ok st` with the state
// untouched, or `.unbalancedConditional` if the threaded conditional stack is
// not empty.
//
// Written in Lean's order (conditional check decides the result; the stack is
// never rewritten) so that the Alive2 comparison is not two copies of the C
// body.  The out-of-model marker is emitted before any modelling, matching the
// C leg's declared totalization.

enum LVerdict { L_FAIL = 0, L_OK = 1, L_OOM = 3 };

EVINLINE uint64_t l_eval_frame(uint64_t ops_len, uint64_t vf_depth,
                               uint64_t st_n, uint64_t b0, uint64_t b1,
                               uint64_t b2, uint64_t b3) {
    if (ops_len != 0) return ev_pack_stack4(L_OOM, 1, st_n, b0, b1, b2, b3);
    // evalFrom _+1 [] st — `if st.vf = [] then .ok st else .error ...`
    const uint64_t vf_empty = (vf_depth == 0);
    const uint64_t verdict = vf_empty ? (uint64_t)L_OK : (uint64_t)L_FAIL;
    const uint64_t error = vf_empty ? 0u : 20u;   // .unbalancedConditional
    return ev_pack_stack4(verdict, error, st_n, b0, b1, b2, b3);
}

extern "C" uint64_t cell_eval_frame(uint64_t ops_len, uint64_t vf_depth,
                                    uint64_t st_n, uint64_t b0, uint64_t b1,
                                    uint64_t b2, uint64_t b3) {
    return l_eval_frame(ops_len & 3u, vf_depth & 3u, st_n & 3u,
                        b0 & 0xffu, b1 & 0xffu, b2 & 0xffu, b3 & 0xffu);
}
