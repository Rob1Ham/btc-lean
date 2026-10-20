#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
//   case OP_IF:
//   case OP_NOTIF:
//   {
//       bool fValue = false;
//       if (fExec) {                                                              // :629
//           if (stack.size() < 1)
//               return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
//           valtype& vch = stacktop(-1);
//           // Tapscript requires minimal IF/NOTIF inputs as a consensus rule.   // :624-629
//           if (sigversion == SigVersion::TAPSCRIPT) { ... TAPSCRIPT_MINIMALIF }
//           // Under witness v0 rules it is only a policy rule, enabled through
//           // SCRIPT_VERIFY_MINIMALIF.                                          // :631
//           if (sigversion == SigVersion::WITNESS_V0 && (flags & SCRIPT_VERIFY_MINIMALIF)) {
//               if (vch.size() > 1)                                               // :632-633
//                   return set_error(serror, SCRIPT_ERR_MINIMALIF);
//               if (vch.size() == 1 && vch[0] != 1)                               // :634-635
//                   return set_error(serror, SCRIPT_ERR_MINIMALIF);
//           }
//           fValue = CastToBool(vch);                                             // :638
//
// The TAPSCRIPT arm is deliberately not modelled here (SCR-183).  The stack
// non-empty precondition discharges :630-631.

uint64_t c_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                        uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;                          // :629: branch not entered
    const uint64_t b0 = byte_of(vch0Arg);
    if (sigversion == SV_WITNESS_V0 && (flags & MINIMALIF) != 0) {
        if (vchLen > 1) return ERR_MINIMALIF;               // :632-633
        if (vchLen == 1 && b0 != 1) return ERR_MINIMALIF;   // :634-635
    }
    return ERR_OK;                                          // BASE ignores the bit
}

extern "C" uint64_t cell_minimalif_v0(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                      uint64_t vchLen, uint64_t vch0Arg) {
    return c_minimalif_v0(flags, sigversion, fExec, vchLen, vch0Arg);
}
