// L leg: reviewed transliteration of the Lean twin's tapscript extension
// slice, written at byte level so it is an independent expression of the
// same three appends (not a copy of the C word arithmetic).
//
//   Crypto/Taproot/Sighash.lean:237-243  extSlice
//     if sv = tapscript then
//       if tapleafHashInit ∧ codesepPosInit then
//         some (tapleafHash ++ serU8 0 ++ serU32 codesepPos)
//       else none
//     else some ByteArray.empty
//   (caller contract: the init flags are true here; the `none` arm is the
//   fail-closed encoding of Core's assert and is outside this cell.)
//
// serU8 0 writes one zero byte; serU32 writes 4 little-endian bytes.
#include <cstdint>

static constexpr uint32_t TAPSCRIPT = 1;
static constexpr uint32_t EXT_LEN = 37;

// Unrolled byte-at-a-time 37-byte slice: 32 hash bytes, key_version, then
// codesepPos little-endian.  All indices are compile-time constants.
static inline void build(uint8_t* o, uint64_t t0, uint64_t t1, uint64_t t2,
                         uint64_t t3, uint32_t cs) {
  o[0]  = (uint8_t)(t0);       o[1]  = (uint8_t)(t0 >> 8);
  o[2]  = (uint8_t)(t0 >> 16); o[3]  = (uint8_t)(t0 >> 24);
  o[4]  = (uint8_t)(t0 >> 32); o[5]  = (uint8_t)(t0 >> 40);
  o[6]  = (uint8_t)(t0 >> 48); o[7]  = (uint8_t)(t0 >> 56);
  o[8]  = (uint8_t)(t1);       o[9]  = (uint8_t)(t1 >> 8);
  o[10] = (uint8_t)(t1 >> 16); o[11] = (uint8_t)(t1 >> 24);
  o[12] = (uint8_t)(t1 >> 32); o[13] = (uint8_t)(t1 >> 40);
  o[14] = (uint8_t)(t1 >> 48); o[15] = (uint8_t)(t1 >> 56);
  o[16] = (uint8_t)(t2);       o[17] = (uint8_t)(t2 >> 8);
  o[18] = (uint8_t)(t2 >> 16); o[19] = (uint8_t)(t2 >> 24);
  o[20] = (uint8_t)(t2 >> 32); o[21] = (uint8_t)(t2 >> 40);
  o[22] = (uint8_t)(t2 >> 48); o[23] = (uint8_t)(t2 >> 56);
  o[24] = (uint8_t)(t3);       o[25] = (uint8_t)(t3 >> 8);
  o[26] = (uint8_t)(t3 >> 16); o[27] = (uint8_t)(t3 >> 24);
  o[28] = (uint8_t)(t3 >> 32); o[29] = (uint8_t)(t3 >> 40);
  o[30] = (uint8_t)(t3 >> 48); o[31] = (uint8_t)(t3 >> 56);
  o[32] = 0;                                   // serU8 0 (key_version)
  o[33] = (uint8_t)(cs);                       // serU32 little-endian
  o[34] = (uint8_t)(cs >> 8);
  o[35] = (uint8_t)(cs >> 16);
  o[36] = (uint8_t)(cs >> 24);
  (void)EXT_LEN;
}

static inline uint64_t word_at(const uint8_t* o, uint32_t base) {
  uint64_t w = 0;
  if (base + 0 < EXT_LEN) w |= (uint64_t)o[base + 0] << 0;
  if (base + 1 < EXT_LEN) w |= (uint64_t)o[base + 1] << 8;
  if (base + 2 < EXT_LEN) w |= (uint64_t)o[base + 2] << 16;
  if (base + 3 < EXT_LEN) w |= (uint64_t)o[base + 3] << 24;
  if (base + 4 < EXT_LEN) w |= (uint64_t)o[base + 4] << 32;
  if (base + 5 < EXT_LEN) w |= (uint64_t)o[base + 5] << 40;
  if (base + 6 < EXT_LEN) w |= (uint64_t)o[base + 6] << 48;
  if (base + 7 < EXT_LEN) w |= (uint64_t)o[base + 7] << 56;
  return w;
}

extern "C" uint64_t cell_ext_w0(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  if (sv != TAPSCRIPT) return 0;
  uint8_t o[EXT_LEN];
  build(o, t0, t1, t2, t3, codesep);
  return word_at(o, 0);
}
extern "C" uint64_t cell_ext_w1(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  if (sv != TAPSCRIPT) return 0;
  uint8_t o[EXT_LEN];
  build(o, t0, t1, t2, t3, codesep);
  return word_at(o, 8);
}
extern "C" uint64_t cell_ext_w2(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  if (sv != TAPSCRIPT) return 0;
  uint8_t o[EXT_LEN];
  build(o, t0, t1, t2, t3, codesep);
  return word_at(o, 16);
}
extern "C" uint64_t cell_ext_w3(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  if (sv != TAPSCRIPT) return 0;
  uint8_t o[EXT_LEN];
  build(o, t0, t1, t2, t3, codesep);
  return word_at(o, 24);
}
extern "C" uint64_t cell_ext_w4(uint32_t sv, uint64_t t0, uint64_t t1,
                                uint64_t t2, uint64_t t3, uint32_t codesep) {
  if (sv != TAPSCRIPT) return 0;
  uint8_t o[EXT_LEN];
  build(o, t0, t1, t2, t3, codesep);
  return word_at(o, 32) | ((uint64_t)EXT_LEN << 56);
}
