// L leg: reviewed transliteration of the Lean twin's SIGHASH_SINGLE
// output-existence gate.
//
//   Crypto/Taproot/Sighash.lean:168  htSingle ht = (ht &&& 3).toNat == 3
//   Crypto/Taproot/Sighash.lean:219-226  singleSlice
//     if htSingle ht then
//       if inPos ≥ env.tx.vout.length then none
//       else some (outputHash or shaSingleOutput ...)
//     else some ByteArray.empty
//   Capstone/RealChecker.lean:131-132  none => throw schnorrSigHashtype
//
// `none` is Core's `return false` from SignatureHashSchnorr, which
// CheckSchnorrSignature maps to SCHNORR_SIG_HASHTYPE (interpreter.cpp:1747).
// The output-hash value is abstracted; this cell is the gate.
#include <cstdint>

static constexpr uint32_t SCHNORR_SIG_HASHTYPE = 46;

static inline uint64_t pack(uint32_t ok, uint32_t present, uint32_t err) {
  return (uint64_t)(ok & 1u) | ((uint64_t)(present & 1u) << 1)
       | ((uint64_t)(err & 0xffu) << 8);
}

// Sighash.lean:168
static inline bool lean_ht_single(uint32_t ht) {
  return (ht & 0x03u) == 0x03u;
}

extern "C" uint64_t cell_single_output(uint8_t hash_type, uint32_t in_pos,
                                       uint32_t vout_size) {
  if (lean_ht_single(hash_type)) {
    if (in_pos >= vout_size) return pack(0, 0, SCHNORR_SIG_HASHTYPE);
    return pack(1, 1, 0);
  }
  return pack(1, 0, 0);
}
