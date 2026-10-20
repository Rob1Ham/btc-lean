#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the verified Lean definition
//   spec/core/Bitcoin/SigHash/Digest.lean:288-305 (`bip143MsgL`):
//
//   serU32L tx.version.toUInt32
//     ++ hashPrevoutsL tx ht
//     ++ hashSequenceL tx ht
//     ++ serOutpointL i.prevout
//     ++ encCSL scriptCode.length ++ scriptCode
//     ++ serAmountL amount
//     ++ serU32L i.sequence
//     ++ hashOutputsL tx nIn ht
//     ++ serU32L tx.locktime
//     ++ serU32L ht
//
// The offsets are computed as explicit sums (not a running cursor), so the
// Alive2 comparison against the C cursor form is semantic.  The Lean widths
// are pinned by `serU32L`=4, `serOutpointL`=36, `encCSL`=1 for len <= 252,
// `serAmountL`=8 (Digest.lean:279-286 and Numeric/Serial.lean).  The cell
// proves layout only: the sub-hash definitions and dshaL are not modelled.
//
// Precondition: 0 <= script_len <= 75 (one-byte CompactSize prefix).

extern "C" uint64_t cell_bip143_field(uint64_t field, uint64_t script_len) {
    if (field == 0) return 4  + (0ULL << 8);                         // version
    if (field == 1) return 32 + (4ULL << 8);                         // hashPrevouts
    if (field == 2) return 32 + (36ULL << 8);                        // hashSequence
    if (field == 3) return 36 + (68ULL << 8);                        // outpoint
    if (field == 4) return (1 + script_len) + (104ULL << 8);         // scriptCode
    if (field == 5) return 8  + ((105 + script_len) << 8);           // amount
    if (field == 6) return 4  + ((113 + script_len) << 8);           // nSequence
    if (field == 7) return 32 + ((117 + script_len) << 8);           // hashOutputs
    if (field == 8) return 4  + ((149 + script_len) << 8);           // nLockTime
    if (field == 9) return 4  + ((153 + script_len) << 8);           // nHashType
    return 0;
}

extern "C" uint64_t cell_bip143_total_len(uint64_t script_len) {
    return (4 + 32 + 32 + 36) + (1 + script_len) + 8 +
           (4 + 32 + 4 + 4);
}
