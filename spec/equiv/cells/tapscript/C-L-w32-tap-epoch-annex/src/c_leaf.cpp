// C leg: line-cited source slices from Bitcoin Core cce32b16874e8
// src/script/interpreter.cpp, SignatureHashSchnorr (1493-1580):
//
//   1529-1533  static constexpr uint8_t EPOCH = 0;  ss << EPOCH;
//   1531       output_type/input_type derived from hash_type
//   1533       ss << hash_type;
//   1543-1546  have_annex = execdata.m_annex_present;
//              spend_type = (ext_flag << 1) + (have_annex ? 1 : 0); ss << spend_type;
//   1554-1556  if (have_annex) ss << execdata.m_annex_hash;
//
// SHA256 / HashWriter are NOT modelled: the epoch/hashtype byte pair, the
// spend_type byte and the annex-hash *inclusion* are the slice.  The
// annex-hash value is an uninterpreted 32-byte uint256
// (interpreter.cpp:1964 computes it as SHA256(CSize(len) || annex)).
#include <cstdint>

static constexpr uint32_t TAPROOT = 0;
static constexpr uint32_t TAPSCRIPT = 1;
static constexpr uint64_t DOMAIN_REJECT = 0xdeadbeefULL;

// callback: bit0..7 epoch, bit8..15 hashtype
extern "C" uint64_t cell_epoch_ht(uint8_t hash_type) {
  const uint64_t epoch = 0;  // interpreter.cpp:1529
  return (epoch & 0xffULL) | ((uint64_t)hash_type << 8);
}

// callback: bits0..7 spend_type, bits8..15 ext_flag
extern "C" uint64_t cell_spend_type(uint32_t sv, bool annex_present) {
  uint32_t ext_flag;
  if (sv == TAPROOT) ext_flag = 0;
  else if (sv == TAPSCRIPT) ext_flag = 1;  // interpreter.cpp:1500-1505
  else return DOMAIN_REJECT;               // Core assert(false) at 1506
  // interpreter.cpp:1545
  const uint32_t spend_type = (ext_flag << 1) + (annex_present ? 1u : 0u);
  return (uint64_t)(spend_type & 0xffu) | ((uint64_t)(ext_flag & 0xffu) << 8);
}

// callback: bit0 annex present, bits8..15 slice length (0 or 32),
// bits16..47 first four bytes of the annex hash (uint256 word 0 low half)
extern "C" uint64_t cell_annex_slice(bool annex_present, uint64_t h0) {
  if (!annex_present) return 0;
  // interpreter.cpp:1554-1556: ss << execdata.m_annex_hash; (32 bytes)
  return 1ULL | ((uint64_t)32 << 8) | ((h0 & 0xffffffffULL) << 16);
}
