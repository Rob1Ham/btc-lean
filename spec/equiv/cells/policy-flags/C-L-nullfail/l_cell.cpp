#include "policy_common.h"
using namespace policy_cell;

// L leg: REVIEWED TRANSLITERATION (not generated) of
//   spec/core/Bitcoin/Interpreter/Defs.lean:730-739:
//
//   match sc with
//   | .error e => .error e
//   | .ok scriptCode =>
//     match checkSigEncoding flags pol sig, checkPubKeyEncoding flags pol sv pk with
//     | some e, _ => .error e
//     | _, some e => .error e
//     | none, none =>
//       let fSuccess := chk.base.checkECDSASignature sig pk scriptCode sv ed
//       if !fSuccess ∧ pol.nullFail ∧ sig.size ≠ 0 then .error .sigNullFail   -- :738
//       else .ok fSuccess                                                     -- :739
//
// The `none, none` arm is the cell precondition (both encoding gates passed).
// `pol.nullFail` is PolicyFlags.nullFail (Defs.lean:187-205), fed by
// parsePolicyFlags from the corpus "NULLFAIL" string; Core carries the same bit
// in script_verify_flags (interpreter.cpp:351).

uint64_t l_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    const bool nullFail = (flags & NULLFAIL) != 0;
    if (fSuccess == 0 && nullFail && sigLen != 0) return ERR_SIG_NULLFAIL;
    return ERR_OK;
}

extern "C" uint64_t cell_nullfail(uint64_t flags, uint64_t fSuccess, uint64_t sigLen) {
    return l_nullfail(flags, fSuccess, sigLen);
}
