#include "limits_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   interpreter.cpp:2133-2147  static size_t WitnessSigOps(...)
//       if (witversion == 0) {
//           if (witprogram.size() == WITNESS_V0_KEYHASH_SIZE)     // 20
//               return 1;
//           if (witprogram.size() == WITNESS_V0_SCRIPTHASH_SIZE   // 32
//               && witness.stack.size() > 0) {
//               CScript subscript(witness.stack.back()...);
//               return subscript.GetSigOpCount(true);             // accurate
//           }
//       }
//       return 0;   // future flags, and v1+ (taproot)
//
// `last_item_sigops` is the accurate GetSigOpCount(true) of the last witness
// item; that per-site counting rule is proved by
// limits/C-L-sigop-site-weights (SCR-032/033) and is an input here, exactly
// as Core calls out to it.  `witness_nonempty` is `witness.stack.size() > 0`.
// `program_len` is witprogram.size(); `witversion` is the IsWitnessProgram
// version (0 for v0, >=1 for future versions).
//
// The cell proves the version/length dispatch and which count is used; it
// does not claim the accurate count or witness-program classification.

constexpr uint32_t WITNESS_V0_KEYHASH_SIZE = 20;
constexpr uint32_t WITNESS_V0_SCRIPTHASH_SIZE = 32;

LIMITS_INLINE uint32_t c_witness_sigops(uint8_t witversion, uint32_t program_len,
                                        uint8_t witness_nonempty, uint32_t last_item_sigops) {
    if (witversion == 0) {
        if (program_len == WITNESS_V0_KEYHASH_SIZE)
            return 1;                                               // :2136-2137
        if (program_len == WITNESS_V0_SCRIPTHASH_SIZE && witness_nonempty)
            return last_item_sigops;                                // :2139-2142
    }
    return 0;                                                       // :2146
}

extern "C" uint32_t cell_witness_sigops(uint8_t witversion, uint32_t program_len,
                                        uint8_t witness_nonempty, uint32_t last_item_sigops) {
    return c_witness_sigops(witversion, program_len, witness_nonempty, last_item_sigops);
}
