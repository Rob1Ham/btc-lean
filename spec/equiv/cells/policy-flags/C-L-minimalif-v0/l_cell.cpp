#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean:878-891 (stepBody, OP_IF/OP_NOTIF):
//
//   else if w = 0x63 ∨ w = 0x64 then
//     if fExec then
//       if st.stack.length < 1 then .error .stackUnderflow
//       else
//         let vch := topAt st.stack 1
//         if ctx.sv = .tapscript ∧ (1 < vch.size ∨ (vch.size = 1 ∧ byte ≠ 1)) then
//           .error .tapscriptMinimalIf                                       -- :883-884 (SCR-183)
//         else if ctx.sv = .witnessV0 ∧ pol.minimalIf ∧
//             (1 < vch.size ∨ (vch.size = 1 ∧ byte ≠ 1)) then
//           .error .minimalIf                                                -- :885-887
//         else .ok { ... }
//     else .ok { st with vf := false :: st.vf }                              -- :891
//
// `pol.minimalIf` is PolicyFlags.minimalIf (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "MINIMALIF" string; Core carries the same bit
// in script_verify_flags (interpreter.cpp:631).

uint64_t l_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                        uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;
    const uint64_t b0 = byte_of(vch0Arg);
    const bool minimalIf = (flags & MINIMALIF) != 0;
    const bool notMinimal = (vchLen > 1) || (vchLen == 1 && b0 != 1);
    if (sigversion == SV_WITNESS_V0 && minimalIf && notMinimal) {
        return ERR_MINIMALIF;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                      uint64_t vchLen, uint64_t vch0Arg) {
    return l_minimalif_v0(flags, sigversion, fExec, vchLen, vch0Arg);
}
