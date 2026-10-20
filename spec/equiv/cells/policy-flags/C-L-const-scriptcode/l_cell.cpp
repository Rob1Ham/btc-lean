#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean
//
// Root 1 -- stepBody decode-time gate (:831-834):
//   -- (3) disabled opcodes (CVE-2010-5137) — unexecuted branches included
//   else if disabledWire w then .error .disabledOpcode
//   -- (4) OP_CODESEPARATOR under CONST_SCRIPTCODE in non-segwit script
//   else if w = 0xab ∧ ctx.sv = .base ∧ ctx.pol.constScriptCode
//     then .error .opCodeSeparator                                      -- :833
//
// Root 2 -- evalChecksigPreTapscript (:724-729):
//   if sv = .base then
//     let (found, sc') := findAndDelete scriptCode0 (pushBytesWire sig)
//     if 0 < found ∧ pol.constScriptCode then .error .sigFindAndDelete  -- :728
//     else .ok sc'
//   else .ok scriptCode0
//
// `ctx.pol.constScriptCode` is PolicyFlags.constScriptCode (Defs.lean:187-205),
// fed by parsePolicyFlags from the corpus "CONST_SCRIPTCODE" string; Core
// carries the same bit in script_verify_flags.

uint64_t l_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    const bool constScriptCode = (flags & CONST_SCRIPTCODE) != 0;
    if (opcode == 0xab && sigversion == SV_BASE && constScriptCode) {
        return ERR_OP_CODESEPARATOR;
    }
    return ERR_OK;
}

uint64_t l_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    if (foundPositive > 1) return OUT_OF_DOMAIN;              // cell guard (harness)
    const bool constScriptCode = (flags & CONST_SCRIPTCODE) != 0;
    const bool found = foundPositive != 0;
    if (sigversion == SV_BASE && found && constScriptCode) {
        return ERR_SIG_FINDANDDELETE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    return l_const_scriptcode_codesep(flags, sigversion, opcode);
}

extern "C" uint64_t cell_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    return l_const_scriptcode_finddelete(flags, sigversion, foundPositive);
}
