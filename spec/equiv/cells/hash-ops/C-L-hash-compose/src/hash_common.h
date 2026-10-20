#ifndef HASH_OPS_COMMON_H
#define HASH_OPS_COMMON_H
#include <cstdint>

// Shared bounded observable for the hash-ops cells.
//
// HStack is a cell harness stack, not engine code: depth 4, 32-byte slots so
// that both 20-byte (RIPEMD160/HASH160) and 32-byte (SHA256/HASH256) digests
// fit.  The packed format is identical on both legs and is what the tools
// compare; it is derived from e2-hash/hash160-vector's h_pack with the same
// field layout (result, error, depth, length, first five digest bytes).

#define HMAX_ELEM 32
#define HMAX_DEPTH 4
#define BINLINE static inline __attribute__((always_inline))

struct HStack {
  uint32_t n;
  uint32_t len[HMAX_DEPTH];
  uint8_t e[HMAX_DEPTH][HMAX_ELEM];
};

// Bounded, loop-free copy.  A zero length writes nothing (the element is
// empty; stale slot bytes are not part of it).  Extensionally equal to
// memcpy for len <= HMAX_ELEM.
BINLINE void h_copy(uint8_t* d, const uint8_t* s, uint32_t len) {
  if (len > 0)  d[0]  = s[0];
  if (len > 1)  d[1]  = s[1];
  if (len > 2)  d[2]  = s[2];
  if (len > 3)  d[3]  = s[3];
  if (len > 4)  d[4]  = s[4];
  if (len > 5)  d[5]  = s[5];
  if (len > 6)  d[6]  = s[6];
  if (len > 7)  d[7]  = s[7];
  if (len > 8)  d[8]  = s[8];
  if (len > 9)  d[9]  = s[9];
  if (len > 10) d[10] = s[10];
  if (len > 11) d[11] = s[11];
  if (len > 12) d[12] = s[12];
  if (len > 13) d[13] = s[13];
  if (len > 14) d[14] = s[14];
  if (len > 15) d[15] = s[15];
  if (len > 16) d[16] = s[16];
  if (len > 17) d[17] = s[17];
  if (len > 18) d[18] = s[18];
  if (len > 19) d[19] = s[19];
  if (len > 20) d[20] = s[20];
  if (len > 21) d[21] = s[21];
  if (len > 22) d[22] = s[22];
  if (len > 23) d[23] = s[23];
  if (len > 24) d[24] = s[24];
  if (len > 25) d[25] = s[25];
  if (len > 26) d[26] = s[26];
  if (len > 27) d[27] = s[27];
  if (len > 28) d[28] = s[28];
  if (len > 29) d[29] = s[29];
  if (len > 30) d[30] = s[30];
  if (len > 31) d[31] = s[31];
}

// Token representation used by the Alive2 chain functions.  The primitive
// returns are 64-bit tokens standing for the digest; the token bytes fill the
// pushed element so the real push/pop width is exercised without ever reading
// an unmodelled external write.
BINLINE void h_fill_token(uint8_t* out, uint32_t width, uint64_t tok) {
#define TOKB(k, sh) if (width > (k)) out[k] = (uint8_t)(tok >> (sh));
  TOKB(0, 0)  TOKB(1, 8)  TOKB(2, 16) TOKB(3, 24)
  TOKB(4, 32) TOKB(5, 40) TOKB(6, 48) TOKB(7, 56)
  TOKB(8, 0)  TOKB(9, 8)  TOKB(10, 16) TOKB(11, 24)
  TOKB(12, 32) TOKB(13, 40) TOKB(14, 48) TOKB(15, 56)
  TOKB(16, 0) TOKB(17, 8) TOKB(18, 16) TOKB(19, 24)
  TOKB(20, 32) TOKB(21, 40) TOKB(22, 48) TOKB(23, 56)
  TOKB(24, 0) TOKB(25, 8) TOKB(26, 16) TOKB(27, 24)
  TOKB(28, 32) TOKB(29, 40) TOKB(30, 48) TOKB(31, 56)
#undef TOKB
}

// Packed hash observable:
//   result(2) | error(6) | depth(2) | length(8) at bit 11 |
//   first five digest bytes at bits 24..63.
BINLINE uint64_t h_pack(uint32_t res, uint32_t err, const HStack& s) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(s.n & 0x3u) << 8;
  if (s.n > 0) {
    const uint32_t i = s.n - 1;
    r |= (uint64_t)(s.len[i] & 0xffu) << 11;
    r |= (uint64_t)s.e[i][0] << 24;
    r |= (uint64_t)s.e[i][1] << 32;
    r |= (uint64_t)s.e[i][2] << 40;
    r |= (uint64_t)s.e[i][3] << 48;
    r |= (uint64_t)s.e[i][4] << 56;
  }
  return r;
}

BINLINE uint64_t h_pack_token(uint64_t tok, uint32_t width) {
  HStack s{};
  s.n = 1;
  s.len[0] = width;
  h_fill_token(s.e[0], width, tok);
  return h_pack(1, 0, s);
}

#endif
