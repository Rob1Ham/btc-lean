// C leg: line-cited source slice from Bitcoin Core cce32b16874e8
// src/script/interpreter.cpp, SignatureHashSchnorr lines 1568-1576:
//
//   if (sigversion == SigVersion::TAPSCRIPT) {
//       assert(execdata.m_tapleaf_hash_init);
//       ss << execdata.m_tapleaf_hash;
//       ss << key_version;                 // 0 for TAPSCRIPT (1517-1522)
//       assert(execdata.m_codeseparator_pos_init);
//       ss << execdata.m_codeseparator_pos;
//   }
//
// Serialization convention (cited lines' contract, not re-proved here):
// a uint256 is written as its 32 bytes (four little-endian words at the
// representation level) and a uint32_t as 4 little-endian bytes, with no
// CompactSize prefix.  The slice is expressed at word granularity so the
// tools can observe the whole 37-byte extension without an sret struct
// (Alive2 rejects sret/noalias/nocapture attributes).
//
// Caller-contract precondition (Core asserts 1571/1574): the tapleaf hash
// and codeseparator position are initialised.  A violated precondition is
// not modelled here.
#include <cstdint>

static constexpr uint32_t TAPSCRIPT = 1;
static constexpr uint32_t EXT_LEN = 37;  // 32 + 1 + 4

static inline uint64_t ext_word4(uint32_t codesep) {
  const uint64_t key_version = 0;  // interpreter.cpp:1517-1522
  return (key_version & 0xffULL)
      | ((uint64_t)(codesep & 0xffu) << 8)
      | ((uint64_t)((codesep >> 8) & 0xffu) << 16)
      | ((uint64_t)((codesep >> 16) & 0xffu) << 24)
      | ((uint64_t)((codesep >> 24) & 0xffu) << 32)
      | ((uint64_t)EXT_LEN << 56);  // harness: slice length marker
}

extern "C" uint64_t cell_ext_w0(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  (void)t1; (void)t2; (void)t3; (void)codesep;
  return sv == TAPSCRIPT ? t0 : 0;
}
extern "C" uint64_t cell_ext_w1(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  (void)t0; (void)t2; (void)t3; (void)codesep;
  return sv == TAPSCRIPT ? t1 : 0;
}
extern "C" uint64_t cell_ext_w2(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  (void)t0; (void)t1; (void)t3; (void)codesep;
  return sv == TAPSCRIPT ? t2 : 0;
}
extern "C" uint64_t cell_ext_w3(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  (void)t0; (void)t1; (void)t2; (void)codesep;
  return sv == TAPSCRIPT ? t3 : 0;
}
extern "C" uint64_t cell_ext_w4(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  (void)t0; (void)t1; (void)t2; (void)t3;
  return sv == TAPSCRIPT ? ext_word4(codesep) : 0;
}
