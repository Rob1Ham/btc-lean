#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// Root 1 -- decode-time gate (:484-486):
//
//   // With SCRIPT_VERIFY_CONST_SCRIPTCODE, OP_CODESEPARATOR in non-segwit script
//   // is rejected even in an unexecuted branch
//   if (opcode == OP_CODESEPARATOR && sigversion == SigVersion::BASE &&
//       (flags & SCRIPT_VERIFY_CONST_SCRIPTCODE))
//       return set_error(serror, SCRIPT_ERR_OP_CODESEPARATOR);              // :486
//
// Root 2 -- FindAndDelete gate inside EvalChecksigPreTapscript (:332-343):
//
//   CScript scriptCode(pbegincodehash, pend);
//   if (sigversion == SigVersion::BASE) {                                   // :337
//       int found = FindAndDelete(scriptCode, CScript() << vchSig);         // :339
//       if (found > 0 && (flags & SCRIPT_VERIFY_CONST_SCRIPTCODE))          // :340
//           return set_error(serror, SCRIPT_ERR_SIG_FINDANDDELETE);         // :341
//   }
//
// `found` is modelled as a 0/1 input (the rule only tests `found > 0`).

uint64_t c_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    if (opcode == OP_CODESEPARATOR && sigversion == SV_BASE &&
        (flags & CONST_SCRIPTCODE) != 0) {
        return ERR_OP_CODESEPARATOR;
    }
    return ERR_OK;
}

uint64_t c_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    if (foundPositive > 1) return OUT_OF_DOMAIN;              // cell guard (harness)
    if (sigversion == SV_BASE && foundPositive != 0 &&
        (flags & CONST_SCRIPTCODE) != 0) {
        return ERR_SIG_FINDANDDELETE;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_const_scriptcode_codesep(uint64_t flags, uint64_t sigversion, uint64_t opcode) {
    return c_const_scriptcode_codesep(flags, sigversion, opcode);
}

extern "C" uint64_t cell_const_scriptcode_finddelete(uint64_t flags, uint64_t sigversion, uint64_t foundPositive) {
    return c_const_scriptcode_finddelete(flags, sigversion, foundPositive);
}
