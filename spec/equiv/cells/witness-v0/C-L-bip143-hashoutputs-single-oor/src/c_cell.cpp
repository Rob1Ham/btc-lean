#include "wv_common.h"

// C leg: line-cited slice of Bitcoin Core src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, SignatureHash WITNESS_V0
// (interpreter.cpp:1643-1653):
//
//   uint256 hashOutputs;                       // default-constructed: 32 zero bytes
//   ...
//   if ((nHashType & 0x1f) != SIGHASH_SINGLE &&
//       (nHashType & 0x1f) != SIGHASH_NONE) {
//       hashOutputs = cacheready ? cache->hashOutputs
//                                : SHA256Uint256(GetOutputsSHA256(txTo));
//   } else if ((nHashType & 0x1f) == SIGHASH_SINGLE &&
//              nIn < txTo.vout.size()) {
//       HashWriter inner_ss{};
//       inner_ss << txTo.vout[nIn];
//       hashOutputs = inner_ss.GetHash();
//   }
//
// The cell observes which value the BIP143 preimage slot receives.  The three
// SHA256 computations are opaque; the row is the ZERO selection, so the
// observable is a mode:
//   0 = `uint256 hashOutputs` default (32 zero bytes)  <- SCR-141 claim
//   1 = uint256::ONE (legacy SIGHASH_SINGLE overflow; NEVER produced here)
//   2 = SHA256d over all outputs
//   3 = SHA256d over the single output at nIn
//
// SIGHASH_ALL=1, SIGHASH_NONE=2, SIGHASH_SINGLE=3; the base class is
// `nHashType & 0x1f` and every value other than 2/3 behaves as ALL.

extern "C" uint64_t cell_bip143_hashoutputs_mode(uint64_t hash_type,
                                                 uint64_t n_in,
                                                 uint64_t vout_len) {
    const uint64_t base = hash_type % 32;         // nHashType & 0x1f
    if (base != 3 && base != 2) return 2;         // ALL / unrecognised base
    if (base == 3 && n_in < vout_len) return 3;   // SINGLE in range
    return 0;                                     // NONE or SINGLE out of range
}
