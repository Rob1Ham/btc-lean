// C leg: line-cited source slices from Bitcoin Core cce32b16874e8
// src/script/interpreter.cpp (Schnorr hashtype normalization and validity).
//
// Slice composition (stated in spec.md trust_note):
//   - CheckSchnorrSignature, interpreter.cpp:1736-1743: size gate and the
//     64-byte => SIGHASH_DEFAULT rule; 65-byte explicit-byte rule.
//   - SignatureHashSchnorr, interpreter.cpp:1524-1526: output_type
//     normalization and the hashtype validity gate.
//   - CheckSchnorrSignature, interpreter.cpp:1747-1748: a failed
//     SignatureHashSchnorr maps to SCRIPT_ERR_SCHNORR_SIG_HASHTYPE.
// The composition is a cell harness; each statement is an exact copy of
// the cited line.  This is not the whole EvalScript or checker.
#include <cstdint>

// = 0x00 (BIP341 SIGHASH_DEFAULT / SIGHASH_ALL / SIGHASH_NONE / SIGHASH_SINGLE)
static constexpr uint32_t SIGHASH_DEFAULT = 0;
static constexpr uint32_t SIGHASH_ALL = 0x01;
static constexpr uint32_t SIGHASH_OUTPUT_MASK = 0x03;
// contract/error_kind.h:45,46
static constexpr uint32_t SCHNORR_SIG_SIZE = 45;
static constexpr uint32_t SCHNORR_SIG_HASHTYPE = 46;

// interpreter.cpp:1526:
//   if (!(hash_type <= 0x03 || (hash_type >= 0x81 && hash_type <= 0x83)))
//       return false;
static inline bool core_hashtype_valid(uint32_t hash_type) {
  return hash_type <= 0x03 || (hash_type >= 0x81 && hash_type <= 0x83);
}

// interpreter.cpp:1524:
//   const uint8_t output_type = (hash_type == SIGHASH_DEFAULT)
//       ? SIGHASH_ALL : (hash_type & SIGHASH_OUTPUT_MASK);
static inline uint32_t core_output_type(uint32_t hash_type) {
  return (hash_type == SIGHASH_DEFAULT) ? SIGHASH_ALL
                                        : (hash_type & SIGHASH_OUTPUT_MASK);
}

// interpreter.cpp:1736-1743:
//   if (sig.size() != 64 && sig.size() != 65) return set_error(...SIG_SIZE);
//   uint8_t hashtype = SIGHASH_DEFAULT;
//   if (sig.size() == 65) {
//       hashtype = SpanPopBack(sig);
//       if (hashtype == SIGHASH_DEFAULT) return set_error(...HASHTYPE);
//   }
// Return: bit0 = error flag, bits 8..15 = hashtype, bits 16..23 = error
// ordinal, bits 24..31 = Core output_type for that hashtype.
extern "C" uint64_t cell_sig_to_ht(uint32_t sig_size, uint8_t last_byte) {
  uint32_t hashtype = SIGHASH_DEFAULT;
  uint32_t err = 0;
  if (sig_size != 64 && sig_size != 65) {
    err = SCHNORR_SIG_SIZE;
  } else if (sig_size == 65) {
    hashtype = last_byte & 0xffu;
    if (hashtype == SIGHASH_DEFAULT) err = SCHNORR_SIG_HASHTYPE;
  }
  const uint32_t out_type = err ? 0u : core_output_type(hashtype);
  uint64_t r = 0;
  r |= (uint64_t)(err ? 1u : 0u);
  r |= (uint64_t)(hashtype & 0xffu) << 8;
  r |= (uint64_t)(err & 0xffu) << 16;
  r |= (uint64_t)(out_type & 0xffu) << 24;
  return r;
}

// interpreter.cpp:1526 + 1747-1748: an invalid hashtype makes the preimage
// construction return false, which the checker maps to
// SCRIPT_ERR_SCHNORR_SIG_HASHTYPE.  Observable: bit0 = valid,
// bits 8..15 = error ordinal, bits 16..23 = the hashtype byte.
extern "C" uint64_t cell_ht_valid(uint8_t hash_type) {
  const bool valid = core_hashtype_valid(hash_type);
  const uint32_t err = valid ? 0u : SCHNORR_SIG_HASHTYPE;
  uint64_t r = 0;
  r |= (uint64_t)(valid ? 1u : 0u);
  r |= (uint64_t)(err & 0xffu) << 8;
  r |= (uint64_t)(hash_type & 0xffu) << 16;
  return r;
}

// interpreter.cpp:1524 (the DEFAULT=>ALL equivalence, isolated).
extern "C" uint64_t cell_output_type(uint8_t hash_type) {
  return (uint64_t)core_output_type(hash_type);
}
