// L leg: reviewed transliteration of the Lean twin's Schnorr hashtype
// equations.  Each statement carries its Lean anchor; nothing is taken
// from the C leg.
//
//   Crypto/Seam/Entry.lean:146-163  SIGHASH_DEFAULT, schnorrHashtype
//   Crypto/Taproot/Sighash.lean:150-170  hashtypeValid, htOutputAll,
//                                        htNone, htSingle
//   Interpreter/Defs.lean:91         VALIDATION_WEIGHT_PER_SIGOP_PASSED
// (not used here)
//
// The Lean model returns Option / Bool; this leaf returns the packed
// observable defined in spec.md, which is cell harness.
#include <cstdint>

static constexpr uint32_t SIGHASH_DEFAULT = 0x00;  // Entry.lean:148
static constexpr uint32_t SIGHASH_OUTPUT_MASK = 0x03;
static constexpr uint32_t SCHNORR_SIG_SIZE = 45;
static constexpr uint32_t SCHNORR_SIG_HASHTYPE = 46;

// Sighash.lean:150-151
static inline bool lean_hashtype_valid(uint32_t ht) {
  return ht <= 3 || (0x81 <= ht && ht <= 0x83);
}

// Sighash.lean:160
static inline bool lean_ht_output_all(uint32_t ht) {
  return ht == 0 || (ht & 0x03u) == 0x01u;
}
// Sighash.lean:164
static inline bool lean_ht_none(uint32_t ht) { return (ht & 0x03u) == 0x02u; }
// Sighash.lean:168
static inline bool lean_ht_single(uint32_t ht) { return (ht & 0x03u) == 0x03u; }

// The Core numeric output_type that the two Bool predicates classify:
// ALL branches to SIGHASH_ALL, NONE/SINGLE to their own byte.  This is a
// harness projection of the Lean Booleans, in Lean's declared order.
static inline uint32_t lean_output_type(uint32_t ht) {
  if (lean_ht_output_all(ht)) return 0x01;
  if (lean_ht_none(ht)) return 0x02;
  if (lean_ht_single(ht)) return 0x03;
  return 0x00;
}

// Entry.lean:157-163:
//   if sig.size = 64 then some (sig, SIGHASH_DEFAULT)
//   else if sig.size = 65 then
//     if sig[64]! = SIGHASH_DEFAULT then none
//     else some (sig.extract 0 64, sig[64]!)
//   else none
// plus the size/hashtype error mapping from Capstone/RealChecker.lean:124-127.
extern "C" uint64_t cell_sig_to_ht(uint32_t sig_size, uint8_t last_byte) {
  uint32_t hashtype = SIGHASH_DEFAULT;
  uint32_t err = 0;
  if (!(sig_size == 64 || sig_size == 65)) {
    err = SCHNORR_SIG_SIZE;
  } else if (sig_size == 65) {
    hashtype = last_byte & 0xffu;
    if (hashtype == SIGHASH_DEFAULT) err = SCHNORR_SIG_HASHTYPE;
  }
  const uint32_t out_type = err ? 0u : lean_output_type(hashtype);
  uint64_t r = 0;
  r |= (uint64_t)(err ? 1u : 0u);
  r |= (uint64_t)(hashtype & 0xffu) << 8;
  r |= (uint64_t)(err & 0xffu) << 16;
  r |= (uint64_t)(out_type & 0xffu) << 24;
  return r;
}

// Sighash.lean:150-151 + RealChecker.lean:129-130 (hashtype gate throws
// schnorrSigHashtype).
extern "C" uint64_t cell_ht_valid(uint8_t hash_type) {
  const bool valid = lean_hashtype_valid(hash_type);
  const uint32_t err = valid ? 0u : SCHNORR_SIG_HASHTYPE;
  uint64_t r = 0;
  r |= (uint64_t)(valid ? 1u : 0u);
  r |= (uint64_t)(err & 0xffu) << 8;
  r |= (uint64_t)(hash_type & 0xffu) << 16;
  return r;
}

// Sighash.lean:160-170 (the DEFAULT=>ALL fact via the predicate).
extern "C" uint64_t cell_output_type(uint8_t hash_type) {
  return (uint64_t)lean_output_type(hash_type);
}
