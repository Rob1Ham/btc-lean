#include "policy_common.h"
using namespace policy_cell;

// C leg: Bitcoin Core src/script/interpreter.cpp @ pin cce32b168,
// EvalChecksigPreTapscript (:328-368).  The cited branch:
//
//   if (!CheckSignatureEncoding(vchSig, flags, serror) || !CheckPubKeyEncoding(vchPubKey, flags, sigversion, serror)) {
//       return false;                                                              // :344-350
//   }
//   fSuccess = checker.CheckECDSASignature(vchSig, vchPubKey, scriptCode, sigversion);  // :349
//
//   if (!fSuccess && (flags & SCRIPT_VERIFY_NULLFAIL) && vchSig.size())             // :351
//       return set_error(serror, SCRIPT_ERR_SIG_NULLFAIL);                          // :352
//
//   return true;                                                                    // :354
//
// Precondition of this cell: the encoding gates at :344-350 passed (they are
// separate rows).  `fSuccess` is the shared checker's verdict, an input.

uint64_t c_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    if (fSuccess == 0 && (flags & NULLFAIL) != 0 && sigLen != 0) {
        return ERR_SIG_NULLFAIL;
    }
    return ERR_OK;
}

extern "C" uint64_t cell_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    return c_nullfail(flags, fSuccess, sigLen);
}
