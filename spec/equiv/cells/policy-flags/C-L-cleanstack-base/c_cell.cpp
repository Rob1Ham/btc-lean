#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168.
//
// (a) VerifyScript tail, base/non-witness spends (:2109-2119):
//
//   // The CLEANSTACK check is only performed after potential P2SH evaluation, ...
//   if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {                     // :2110
//       assert((flags & SCRIPT_VERIFY_P2SH) != 0);                     // :2112-2113
//       assert((flags & SCRIPT_VERIFY_WITNESS) != 0);                  // :2114
//       if (stack.size() != 1) {                                       // :2115
//           return set_error(serror, SCRIPT_ERR_CLEANSTACK);           // :2116
//       }
//   }
//
// (b) ExecuteWitnessScript tail, witness-v0 spends (:1876-1878):
//
//   // Scripts inside witness implicitly require cleanstack behaviour
//   if (stack.size() != 1) return set_error(serror, SCRIPT_ERR_CLEANSTACK);   // :1877
//   if (!CastToBool(stack.back())) return set_error(serror, SCRIPT_ERR_EVAL_FALSE);  // :1878
//
// The two sites are combined in one total predicate parameterised by SigVersion
// so that "gated by the flag" and "independent of the flag" are one proof.
// The final stack length is an input (see spec.md precondition).

uint64_t c_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    if (sigversion > SV_WITNESS_V0) return OUT_OF_DOMAIN;   // cell guard (harness)
    if (sigversion == SV_BASE) {
        if ((flags & CLEANSTACK) != 0) {                    // :2110
            if (finalLen != 1) return ERR_CLEANSTACK;       // :2115-2116
        }
    } else {
        if (finalLen != 1) return ERR_CLEANSTACK;           // :1877 (no flag read)
    }
    return ERR_OK;
}

extern "C" uint64_t cell_cleanstack(uint64_t flags, uint64_t sigversion, uint64_t finalLen) {
    return c_cleanstack(flags, sigversion, finalLen);
}
