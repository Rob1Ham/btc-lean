// C leg, cell checksig/C-L-checksig-opcount (SCR-113).
//
// Bounded, line-cited slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/script/interpreter.cpp:460-464
//     if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT)
//         return set_error(serror, SCRIPT_ERR_OP_COUNT);
// and spec/core/Bitcoin/Interpreter/Defs.lean:824-830 (stepBody budget):
//     counts  := (sv = .base ∨ sv = .witnessV0) ∧ 0x60 < w
//     opCount' := if counts then st.opCount + 1 else st.opCount
//     if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount
//
// The increment happens before the execution-branch test, so `fExec` is an
// input the rule ignores; carrying it here proves the count is independent of
// whether the op is executed.  Eight symbolic opcodes are walked from a
// symbolic starting count: the single-step rule is fully exercised because the
// start count is arbitrary, and the unrolling shows accumulation and the exact
// 201 -> 202 failure point.
#include "cell_common.h"

W16INLINE uint32_t core_counts(uint32_t sv, uint32_t wire) {
    return (sv == 0u || sv == 1u) && wire > 0x60u;
}

// One step of the budget guard; returns the new count and error ordinal.
W16INLINE void core_budget_step(uint32_t sv, uint32_t wire, uint32_t& n,
                                uint32_t& err) {
    const uint32_t counts = core_counts(sv, wire);
    const uint32_t next = counts ? n + 1u : n;
    n = next;
    if (counts && next > W16_MAX_OPS_PER_SCRIPT) err = W16_OP_COUNT;
}

extern "C" uint64_t cell_opcount(uint32_t n0, uint32_t sv, uint32_t fExec,
                                 uint32_t w0, uint32_t w1, uint32_t w2,
                                 uint32_t w3, uint32_t w4, uint32_t w5,
                                 uint32_t w6, uint32_t w7) {
    (void)fExec;   // increment precedes the fExec test in Core
    uint32_t n = n0;
    uint32_t err = W16_OK;
    const uint32_t ws[8] = {w0, w1, w2, w3, w4, w5, w6, w7};
    for (int i = 0; i < 8; ++i) {
        if (err != W16_OK) break;
        core_budget_step(sv, ws[i], n, err);
    }
    return ((uint64_t)n << 8) | (uint64_t)err;
}
