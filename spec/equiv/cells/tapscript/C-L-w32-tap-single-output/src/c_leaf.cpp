// C leg: line-cited source slice from Bitcoin Core cce32b16874e8
// src/script/interpreter.cpp:
//
//   1524  const uint8_t output_type = (hash_type == SIGHASH_DEFAULT)
//             ? SIGHASH_ALL : (hash_type & SIGHASH_OUTPUT_MASK);
//   1558-1566
//         if (output_type == SIGHASH_SINGLE) {
//             if (in_pos >= tx_to.vout.size()) return false;
//             ... ss << execdata.m_output_hash.value();
//         }
//   1747-1748
//         if (!SignatureHashSchnorr(...)) {
//             return set_error(serror, SCRIPT_ERR_SCHNORR_SIG_HASHTYPE);
//         }
//
// The output-hash computation itself is abstracted (SCR-169); this slice
// covers the existence gate and the error mapping.  `vout.size() < 2^32` is
// physically forced by the serialization limits (premise).
#include <cstdint>

static constexpr uint32_t SIGHASH_DEFAULT = 0x00;
static constexpr uint32_t SIGHASH_ALL = 0x01;
static constexpr uint32_t SIGHASH_SINGLE = 0x03;
static constexpr uint32_t SIGHASH_OUTPUT_MASK = 0x03;
static constexpr uint32_t SCHNORR_SIG_HASHTYPE = 46;

// bit0 = construction succeeds, bit1 = single-output hash is included,
// bits 8..15 = error ordinal (46 when construction fails).
static inline uint64_t pack(uint32_t ok, uint32_t present, uint32_t err) {
  return (uint64_t)(ok & 1u) | ((uint64_t)(present & 1u) << 1)
       | ((uint64_t)(err & 0xffu) << 8);
}

extern "C" uint64_t cell_single_output(uint8_t hash_type, uint32_t in_pos,
                                       uint32_t vout_size) {
  const uint32_t output_type = (hash_type == SIGHASH_DEFAULT)
      ? SIGHASH_ALL : (hash_type & SIGHASH_OUTPUT_MASK);
  if (output_type == SIGHASH_SINGLE) {
    if (in_pos >= vout_size) return pack(0, 0, SCHNORR_SIG_HASHTYPE);
    return pack(1, 1, 0);  // execdata.m_output_hash is committed
  }
  return pack(1, 0, 0);
}
