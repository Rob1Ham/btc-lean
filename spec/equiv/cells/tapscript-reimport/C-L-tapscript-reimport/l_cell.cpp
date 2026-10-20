#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
// Root 1 -- stepBody, OP_IF/OP_NOTIF (:878-891):
//   else if w = 0x63 ∨ w = 0x64 then
//     if fExec then
//       if st.stack.length < 1 then .error .stackUnderflow
//       else
//         let vch := topAt st.stack 1
//         if ctx.sv = .tapscript ∧ (1 < vch.size ∨ (vch.size = 1 ∧ byte ≠ 1)) then
//           .error .tapscriptMinimalIf                                   -- :883-884
//         else if ctx.sv = .witnessV0 ∧ pol.minimalIf ∧ (...) then
//           .error .minimalIf                                            -- :885-887
//         else .ok { ... }
//
// The Lean `if ... else if` is itself the precedence evidence: the tapscript
// arm is selected first and does not mention pol.minimalIf.
//
// Root 2 -- executeWitnessScript tail (:1236-1239), the same code for
// SigVersion::WITNESS_V0 and SigVersion::TAPSCRIPT:
//   | .ok st =>
//     -- witness scripts implicitly require cleanstack
//     if st.length ≠ 1 then .fail .cleanstack                           -- :1238
//     else if castToBool st[0]! then .ok else .fail .evalFalse          -- :1239

uint64_t l_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                               uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;
    const uint64_t b0 = byte_of(vch0Arg);
    const bool notMinimal = (vchLen > 1) || (vchLen == 1 && b0 != 1);
    const bool minimalIf = (flags & MINIMALIF) != 0;
    if (sigversion == SV_TAPSCRIPT && notMinimal) return ERR_TAPSCRIPT_MINIMALIF;
    if (sigversion == SV_WITNESS_V0 && minimalIf && notMinimal) return ERR_MINIMALIF;
    return ERR_OK;
}

uint64_t l_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion < SV_WITNESS_V0 || sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;
    (void)flags;                                           // the Lean tail reads no policy bit
    if (finalLen != 1) return ERR_CLEANSTACK;
    return ERR_OK;
}

extern "C" uint64_t cell_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                             uint64_t vchLen, uint64_t vch0Arg) {
    return l_tapscript_minimalif(flags, sigversion, fExec, vchLen, vch0Arg);
}

extern "C" uint64_t cell_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return l_tapscript_cleanstack(flags, sigversion, finalLen);
}
