#include "w32_common.h"

// L leg: REVIEWED TRANSLITERATION of the Lean stepBody guard
//   spec/core/Bitcoin/Interpreter/Defs.lean:816-836
//
//   let counts := (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < w
//   let opCount' := if counts then st.opCount + 1 else st.opCount
//   if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount
//   ...
//   let st₁ := { st with opCount := opCount' }
//
// plus Defs.lean:856 (`if w = 0x61 then .ok st`, OP_NOP) and the
// executeWitnessScript post-checks at Defs.lean:1238-1241
// (`if st.length ≠ 1 then .fail .cleanstack else if castToBool st[0]! then .ok
// else .fail .evalFalse`).
//
// Written in Lean's form (0x60 < w, opCount + 1, comparison on the incremented
// value) rather than Core's pre-increment form.  MAX_OPS_PER_SCRIPT is 201 on
// both sides (Defs.lean's constant equals script.h:32).
//
// The generated twin has no whole-step entry point (mk_leaf.py emits handler
// bodies only, and the guard lives in the model's stepBody wrapper, not in a
// handler), so this is a reviewed transliteration.

#define W32_MAX_OPS 201

W32INLINE uint64_t l_opcount_guard(uint32_t sv, uint8_t wire,
                                   uint32_t opcount_in) {
    if (sv > 2 || opcount_in > 10000) return w32_bad_domain();
    const bool counts = (sv == 0 || sv == 1) && (0x60 < (uint32_t)wire);
    const uint32_t opCount2 = counts ? (opcount_in + 1) : opcount_in;
    if (counts && (W32_MAX_OPS < opCount2)) return w32_pack_aux(0, 7, opCount2);
    return w32_pack_aux(1, 0, opCount2);
}

W32INLINE uint64_t l_nop_overbudget(uint32_t sv, uint32_t opcount_in,
                                    uint32_t top_true) {
    if (sv > 2 || opcount_in > 10000) return w32_bad_domain();
    const bool counts = (sv == 0 || sv == 1) && (0x60 < 0x61u);
    const uint32_t opCount2 = counts ? (opcount_in + 1) : opcount_in;
    if (counts && (W32_MAX_OPS < opCount2)) return w32_pack_aux(0, 7, opCount2);
    // OP_NOP: .ok st, stack unchanged (one item, CastToBool = top_true).
    if (top_true == 0) return w32_pack_aux(0, 2, opCount2);
    return w32_pack_aux(1, 0, opCount2);
}

extern "C" uint64_t cell_opcount_guard(uint32_t sv, uint8_t wire,
                                       uint32_t opcount_in) {
    return l_opcount_guard(sv, wire, opcount_in);
}

extern "C" uint64_t cell_nop_overbudget(uint32_t sv, uint32_t opcount_in,
                                        uint32_t top_true) {
    return l_nop_overbudget(sv, opcount_in, top_true);
}
