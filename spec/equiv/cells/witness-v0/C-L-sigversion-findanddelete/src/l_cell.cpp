#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the verified Lean definition
//   spec/core/Bitcoin/Interpreter/Defs.lean:717-739
// (`Bitcoin.Interpreter.evalChecksigPreTapscript`):
//
//   let scriptCode0 := bytes.extract codeSep bytes.size
//   let sc : Except ExecError ByteArray :=
//     if sv = .base then
//       let (found, sc') := findAndDelete scriptCode0 (pushBytesWire sig)
//       if 0 < found ∧ pol.constScriptCode then .error .sigFindAndDelete
//       else .ok sc'
//     else .ok scriptCode0
//
// `script_id` identifies scriptCode0 and `fd_script_id` identifies the
// findAndDelete result.  The Lean function's error branch is mapped to
// ordinal 54 (`sigFindAndDelete`); the scriptCode identity is the value handed
// to the checker in the non-error branch.  `sigversion` uses the Core enum
// numbering, which is also what the Lean `SigVersion` derives to in the twin
// ABI: BASE=0, WITNESS_V0=1.

extern "C" uint64_t cell_checksig_verdict(uint64_t sigversion, uint64_t found,
                                          uint64_t const_scriptcode_flag) {
    if (sigversion == 0 && found > 0 && const_scriptcode_flag)
        return wv_pack(0, 54);                    // .sigFindAndDelete
    return wv_pack(1, 0);
}

extern "C" uint64_t cell_checksig_scriptcode(uint64_t sigversion, uint64_t found,
                                             uint64_t const_scriptcode_flag,
                                             uint64_t script_id, uint64_t fd_script_id) {
    if (sigversion == 0) {
        if (found > 0 && const_scriptcode_flag) return script_id;  // .error e
        return fd_script_id;                      // findAndDelete result
    }
    return script_id;                             // else .ok scriptCode0
}
