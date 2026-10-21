#include "common.h"

// C leg — line-cited source-excerpt slice of Core `EvalScript` at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-003 cites `interpreter.cpp:EvalScript:449,1248`:
//
//   449   for (; pc < pend; ++opcode_pos) { ... }        // the eval loop
//  1248   if (!vfExec.empty())
//  1249       return set_error(serror, SCRIPT_ERR_UNBALANCED_CONDITIONAL);
//  1250   return set_success(serror);
//
// A script parses to *no* opcodes only when it is empty (GetScriptOp yields at
// least one opcode — possibly OP_INVALIDOPCODE — for any non-empty input), so
// the zero-op frame is: the loop body never executes, the stack is untouched,
// and the trailing conditional check decides between success and
// UNBALANCED_CONDITIONAL.
//
// The frame is modelled with the post-loop conditional-vector depth as an
// input.  Core derives `vfExec` internally; the parameter is the frame's
// prefix state (Lean's `State.vf` is an explicit argument of `evalFrom`, so
// the L leg has the same input).  Any opcode step is the E5 dispatch residual
// (GetScriptOp, stepBody, the opcode limit, PUSH_SIZE) and is out of this
// cell: `ops_len != 0` returns the declared out-of-model marker.
//
// Error ordinals (contract/error_kind.h): 20 UNBALANCED_CONDITIONAL.

EVINLINE uint64_t c_eval_frame(uint64_t ops_len, uint64_t vf_depth,
                               uint64_t st_n, uint64_t b0, uint64_t b1,
                               uint64_t b2, uint64_t b3) {
    // Out-of-model marker first: no opcode semantics are claimed here.
    if (ops_len != 0) return ev_pack_stack4(3, 1, st_n, b0, b1, b2, b3);
    // interpreter.cpp:449 — `pc < pend` is false immediately: loop not entered,
    // so neither the stack nor vchPushValue/nOpCount are touched.
    // interpreter.cpp:1248-1249 — trailing conditional guard.
    if (vf_depth != 0) return ev_pack_stack4(0, 20, st_n, b0, b1, b2, b3);
    // interpreter.cpp:1250 — set_success(serror); stack unchanged.
    return ev_pack_stack4(1, 0, st_n, b0, b1, b2, b3);
}

extern "C" uint64_t cell_eval_frame(uint64_t ops_len, uint64_t vf_depth,
                                    uint64_t st_n, uint64_t b0, uint64_t b1,
                                    uint64_t b2, uint64_t b3) {
    return c_eval_frame(ops_len & 3u, vf_depth & 3u, st_n & 3u,
                        b0 & 0xffu, b1 & 0xffu, b2 & 0xffu, b3 & 0xffu);
}
