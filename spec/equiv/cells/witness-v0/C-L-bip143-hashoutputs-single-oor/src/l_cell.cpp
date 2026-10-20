#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the verified Lean definition
//   spec/core/Bitcoin/SigHash/Digest.lean:266-278 (`hashOutputsL`):
//
//   def hashOutputsL (tx : Tx) (nIn : Nat) (ht : UInt32) : Bytes :=
//     match htBase ht with
//     | .singleHt =>
//         if nIn < tx.vout.length then
//           bL (dshaL (serTxOutL (tx.vout.getD nIn ...)))
//         else zeroHashL
//     | .noneHt => zeroHashL
//     | .all => bL (dshaL (tx.vout.foldl ...))
//
// with `htBase ht = if (ht &&& 0x1f) == 3 then .singleHt else if ... == 2 then
// .noneHt else .all` (Digest.lean:118-121).  The branch structure below is
// Lean's; the mode encoding is documented on the C leg.  `zeroHashL` is the
// zero vector (NOT `singleOverflowOneB`); the theorem `bip143_single_oor`
// (Theorems.lean:356-362) pins exactly that for `tx.vout.length ≤ nIn`.

extern "C" uint64_t cell_bip143_hashoutputs_mode(uint64_t hash_type,
                                                 uint64_t n_in,
                                                 uint64_t vout_len) {
    const uint64_t base = hash_type % 32;
    if (base == 3) {
        if (n_in < vout_len) return 3;            // dsha(serTxOut(vout[nIn]))
        return 0;                                 // zeroHashL
    }
    if (base == 2) return 0;                      // .noneHt => zeroHashL
    return 2;                                     // .all => dsha(all outputs)
}
