#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// Root 1 -- OP_IF/OP_NOTIF argument check (:623-637):
//
//   if (fExec) {                                                            // :629
//       ...
//       valtype& vch = stacktop(-1);
//       // Tapscript requires minimal IF/NOTIF inputs as a consensus rule.
//       if (sigversion == SigVersion::TAPSCRIPT) {                          // :624-629
//           // exactly 0 (empty vector) or exactly 1 (one-byte vector with value 1)
//           if (vch.size() > 1 || (vch.size() == 1 && vch[0] != 1)) {
//               return set_error(serror, SCRIPT_ERR_TAPSCRIPT_MINIMALIF);   // :628
//           }
//       }
//       // Under witness v0 rules it is only a policy rule ...                // :631-637
//       if (sigversion == SigVersion::WITNESS_V0 && (flags & SCRIPT_VERIFY_MINIMALIF)) { ... }
//
// The tapscript arm is an `if` that returns, not an `else if`, so it precedes
// the witness-v0 arm: the policy bit is unreachable for TAPSCRIPT.
//
// Root 2 -- ExecuteWitnessScript tail (:1876-1878), shared by v0 and tapscript:
//
//   // Scripts inside witness implicitly require cleanstack behaviour
//   if (stack.size() != 1) return set_error(serror, SCRIPT_ERR_CLEANSTACK);
//
// Both roots take the post-state/argument as inputs (see spec.md).

uint64_t c_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                               uint64_t vchLen, uint64_t vch0Arg) {
    if (sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (fExec == 0) return ERR_OK;                         // :629
    const uint64_t b0 = byte_of(vch0Arg);
    const bool notMinimal = (vchLen > 1) || (vchLen == 1 && b0 != 1);
    if (sigversion == SV_TAPSCRIPT && notMinimal) {
        return ERR_TAPSCRIPT_MINIMALIF;                    // :624-629 (no flag read)
    }
    if (sigversion == SV_WITNESS_V0 && (flags & MINIMALIF) != 0 && notMinimal) {
        return ERR_MINIMALIF;                              // :631-637 (policy, for contrast)
    }
    return ERR_OK;
}

uint64_t c_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion < SV_WITNESS_V0 || sigversion > SV_TAPSCRIPT) return OUT_OF_DOMAIN;
    (void)flags;                                           // :1877 reads no policy bit
    if (finalLen != 1) return ERR_CLEANSTACK;              // :1877
    return ERR_OK;
}

extern "C" uint64_t cell_tapscript_minimalif(uint64_t flags, uint64_t sigversion, uint64_t fExec,
                                             uint64_t vchLen, uint64_t vch0Arg) {
    return c_tapscript_minimalif(flags, sigversion, fExec, vchLen, vch0Arg);
}

extern "C" uint64_t cell_tapscript_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return c_tapscript_cleanstack(flags, sigversion, finalLen);
}
