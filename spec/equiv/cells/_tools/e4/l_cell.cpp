#include "e4_common.h"

// L leg: REVIEWED TRANSLITERATION, not generated from the twin.
//
// The twin has no VerifyWitnessProgram handler, so this function was
// transliterated by review from the Verified Lean definition
//   spec/core/Bitcoin/Interpreter/Defs.lean:1259-1279
// (`Bitcoin.Interpreter.verifyWitnessProgram`), whose v0 arm is itself cited
// to interpreter.cpp:1927-1956.  The branch order is Lean's:
//
//   if version = 0 then
//     if program.size = 32 then
//       if witness.length = 0 then .fail .witnessProgramWitnessEmpty
//       else if hashSha256 script != program then .fail .witnessProgramMismatch
//       else executeWitnessScript ...
//     else if program.size = 20 then
//       if witness.length != 2 then .fail .witnessProgramMismatch
//       else executeWitnessScript ...
//     else .fail .witnessProgramWrongLength
//
// As on the C leg, `hashSha256 script != program` and `executeWitnessScript`
// are abstracted to success; they are outside SCR-134/135/137.  The error
// ordinals are the shared EQUIV_ERR_* values for
// witnessProgramWrongLength=38, witnessProgramWitnessEmpty=39,
// witnessProgramMismatch=40.

enum LVerdict { L_FAIL = 0, L_OK = 1 };
struct LOut { uint32_t result; uint32_t error; };

E4INLINE LOut l_v0_step(uint64_t program_len, uint64_t witness_n) {
    if (program_len == 32) {
        if (witness_n == 0) return {L_FAIL, 39};
        // hashSha256 script == program and executeWitnessScript abstracted .ok
        return {L_OK, 0};
    } else if (program_len == 20) {
        if (witness_n != 2) return {L_FAIL, 40};
        // implied P2WPKH script executeWitnessScript abstracted .ok
        return {L_OK, 0};
    }
    return {L_FAIL, 38};
}

extern "C" uint64_t cell_v0_dispatch(uint64_t program_len, uint64_t witness_n) {
    const LOut o = l_v0_step(program_len, witness_n);
    return e4_pack(o.result, o.error);
}
