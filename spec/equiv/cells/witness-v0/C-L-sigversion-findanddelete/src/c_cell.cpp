#include "wv_common.h"

// C leg: line-cited slice of Bitcoin Core src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66,
// EvalChecksigPreTapscript (interpreter.cpp:331-343):
//
//   assert(sigversion == SigVersion::BASE || sigversion == SigVersion::WITNESS_V0);
//   CScript scriptCode(pbegincodehash, pend);
//
//   // Drop the signature in pre-segwit scripts but not segwit scripts
//   if (sigversion == SigVersion::BASE) {
//       int found = FindAndDelete(scriptCode, CScript() << vchSig);
//       if (found > 0 && (flags & SCRIPT_VERIFY_CONST_SCRIPTCODE))
//           return set_error(serror, SCRIPT_ERR_SIG_FINDANDDELETE);
//   }
//
// A scriptCode byte string is identified by the opaque `script_id`; the
// deletion result of FindAndDelete is the opaque `fd_script_id` plus its
// `found` count.  FindAndDelete's own algorithm is a different ledger row and
// is not modelled.  The observable is exactly what this branch does to the
// scriptCode: BASE may replace it (or fail with ordinal 54), every other
// allowed sigversion (WITNESS_V0) returns it untouched.
//
// SigVersion: BASE=0, WITNESS_V0=1 (interpreter.h:201-207).

extern "C" uint64_t cell_checksig_verdict(uint64_t sigversion, uint64_t found,
                                          uint64_t const_scriptcode_flag) {
    // 333-337: only BASE runs FindAndDelete; 338-340 is the CONST_SCRIPTCODE error.
    if (sigversion == 0 && found > 0 && const_scriptcode_flag)
        return wv_pack(0, 54);                    // SCRIPT_ERR_SIG_FINDANDDELETE
    return wv_pack(1, 0);
}

extern "C" uint64_t cell_checksig_scriptcode(uint64_t sigversion, uint64_t found,
                                             uint64_t const_scriptcode_flag,
                                             uint64_t script_id, uint64_t fd_script_id) {
    if (sigversion == 0) {
        if (found > 0 && const_scriptcode_flag) return script_id;  // error path: unused
        return fd_script_id;                      // BASE: FindAndDelete ran
    }
    return script_id;                             // WITNESS_V0: no deletion
}
