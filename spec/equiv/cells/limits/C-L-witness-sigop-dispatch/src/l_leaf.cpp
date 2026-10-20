#include "limits_common.h"

// L leg: reviewed transliteration of the btc-lean twin's witnessSigOps,
// spec/core/Bitcoin/Interpreter/SigOps.lean:
//
//   def witnessSigOps (version : Nat) (program : ByteArray)
//       (witness : List ByteArray) : Nat :=
//     if version = 0 then
//       if program.size = 20 then 1
//       else if program.size = 32 then
//         match witness.getLast? with
//         | some script => witnessScriptSigOps script
//         | none => 0
//       else 0
//     else 0
//
// SWT-025 (v0-20 -> 1), SWT-026 (v0-32 -> accurate last item),
// SWT-028 (v1+ -> 0).  `witnessScriptSigOps` is the Lean name for Core's
// `subscript.GetSigOpCount(true)`; it is an input here, proved by
// limits/C-L-sigop-site-weights.  `last_item_sigops`/`has_last` stand for
// `witness.getLast?` and its count.

constexpr uint32_t L_WITNESS_V0_KEYHASH_SIZE = 20;
constexpr uint32_t L_WITNESS_V0_SCRIPTHASH_SIZE = 32;

LIMITS_INLINE uint32_t l_witness_sigops(uint8_t version, uint32_t program_len,
                                        uint8_t has_last, uint32_t last_item_sigops) {
    if (version == 0) {
        if (program_len == L_WITNESS_V0_KEYHASH_SIZE) return 1;
        if (program_len == L_WITNESS_V0_SCRIPTHASH_SIZE && (has_last != 0))
            return last_item_sigops;
        return 0;
    }
    return 0;
}

extern "C" uint32_t cell_witness_sigops(uint8_t witversion, uint32_t program_len,
                                        uint8_t witness_nonempty, uint32_t last_item_sigops) {
    return l_witness_sigops(witversion, program_len, witness_nonempty, last_item_sigops);
}
