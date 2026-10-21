#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the Verified Lean definition
//   spec/core/Bitcoin/Interpreter/Defs.lean:1259-1300
// (`Bitcoin.Interpreter.verifyWitnessProgram`, `version = 0` arm).
//
// Lean order:
//   if program.size = 32 then
//     if witness.length = 0 then .fail .witnessProgramWitnessEmpty
//     else if hashSha256 script != program then .fail .witnessProgramMismatch
//     else executeWitnessScript ...
//   else if program.size = 20 then
//     if witness.length ≠ 2 then .fail .witnessProgramMismatch
//     else executeWitnessScript ...
//   else .fail .witnessProgramWrongLength
//
// `hash_match` abstracts `hashSha256 script = program`; `executeWitnessScript`
// is the continuation sentinel.  Neither abstraction is part of
// SCR-134/135/137.  Error ordinals are the shared EQUIV_ERR_* values:
// witnessProgramWrongLength=38, witnessProgramWitnessEmpty=39,
// witnessProgramMismatch=40.

extern "C" uint64_t cell_v0_dispatch(uint64_t program_len, uint64_t witness_n,
                                     uint64_t hash_match) {
    if (program_len == 32) {
        if (witness_n == 0) return wv_pack(0, 39);        // .witnessProgramWitnessEmpty
        if (!hash_match) return wv_pack(0, 40);           // .witnessProgramMismatch
        return wv_pack(2, 0);                             // executeWitnessScript
    } else if (program_len == 20) {
        if (witness_n != 2) return wv_pack(0, 40);        // .witnessProgramMismatch
        return wv_pack(2, 0);                             // executeWitnessScript
    }
    return wv_pack(0, 38);                                // .witnessProgramWrongLength
}
