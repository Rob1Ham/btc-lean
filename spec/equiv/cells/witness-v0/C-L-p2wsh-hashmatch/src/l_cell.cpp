#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the verified Lean definition
//   spec/core/Bitcoin/Interpreter/Defs.lean:1266-1272
// (`Bitcoin.Interpreter.verifyWitnessProgram`, 32-byte v0 arm):
//
//   let script := witness.getLast!
//   let rest := witness.dropLast
//   if hashSha256 script != program then .fail .witnessProgramMismatch
//   else executeWitnessScript fuel rest ... script ... .witnessV0
//
// `digest` is the 32-byte SHA256(witnessScript) value (Lean `hashSha256
// script`), `program` is the witness program.  The equality is written as a
// conjunction of four word comparisons, deliberately different from the C
// leg's XOR/OR form, so the Alive2 comparison is semantic.  The hash primitive
// is not modelled (same-hash premise).

extern "C" uint64_t cell_p2wsh_hashmatch(uint64_t d0, uint64_t d1,
                                         uint64_t d2, uint64_t d3,
                                         uint64_t p0, uint64_t p1,
                                         uint64_t p2, uint64_t p3) {
    if (d0 == p0 && d1 == p1 && d2 == p2 && d3 == p3)
        return wv_pack(2, 0);               // executeWitnessScript continuation
    return wv_pack(0, 40);                  // .witnessProgramMismatch
}
