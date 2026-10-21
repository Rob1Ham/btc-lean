#ifndef CELLS_E2_COMMON_H
#define CELLS_E2_COMMON_H
#include <cstdint>

// Shared bounded observables for the E2 numeric and hash cells.
//
// BStack is the numeric op-cell stack: depth 4, element value packed into a
// uint32 (the numeric cells use at most 2-byte elements).  HStack is the hash
// op-cell stack: depth 4, 32-byte elements so a 20/32-byte digest fits.
//
// h_* / b_* are cell harness, not engine code.  The packed formats are
// deliberately explicit and identical on both legs; the tools compare them.

#define BINLINE static inline __attribute__((always_inline))
struct BStack { uint32_t n; uint32_t len[4]; uint32_t val[4]; };

BINLINE uint32_t b_byte(const BStack& s, uint32_t i, uint32_t k) {
  return (s.val[i] >> (8u*k)) & 0xffu;
}
BINLINE uint32_t b_truth(const BStack& s, uint32_t i) {
  const uint32_t l = s.len[i];
  if (l == 0) return 0;
  if (l == 1) return (b_byte(s,i,0) == 0 || b_byte(s,i,0) == 0x80) ? 0u : 1u;
  if (b_byte(s,i,0) != 0) return 1;
  return (b_byte(s,i,1) == 0 || b_byte(s,i,1) == 0x80) ? 0u : 1u;
}
// Packed numeric observable: result(2) | error(6) | depth(2) | then the top
// three elements as (len 2 | val 8).  A zero-length element canonicalises to
// value 0: Core's vchFalse is the empty vector, and stale slot bytes are not
// part of the element.
BINLINE uint64_t b_pack(uint32_t res, uint32_t err, const BStack& s) {
  const uint32_t m = s.n > 3 ? 3u : s.n;
  uint32_t k = 0;
  if (s.n == 4) k = 1;
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(s.n & 7u) << 8;
  if (m > 0) { r |= (uint64_t)(s.len[k]   & 3u) << 11; r |= (uint64_t)(s.len[k]   == 0 ? 0u : (s.val[k]   & 0xffu)) << 13; }
  if (m > 1) { r |= (uint64_t)(s.len[k+1] & 3u) << 21; r |= (uint64_t)(s.len[k+1] == 0 ? 0u : (s.val[k+1] & 0xffu)) << 23; }
  if (m > 2) { r |= (uint64_t)(s.len[k+2] & 3u) << 31; r |= (uint64_t)(s.len[k+2] == 0 ? 0u : (s.val[k+2] & 0xffu)) << 33; }
  return r;
}

#define E2_MAX_ELEM 32
#define E2_MAX_DEPTH 4
struct HStack { uint32_t n; uint32_t len[E2_MAX_DEPTH]; uint8_t e[E2_MAX_DEPTH][E2_MAX_ELEM]; };
// Packed hash observable: result(2) | error(6) | depth(2) | length(8) at bit
// 11 | first five digest bytes at bit 24.  The digest is 20/32 bytes; the
// cell claims the output width and a 40-bit prefix, not the whole value.
BINLINE uint64_t h_pack(uint32_t res, uint32_t err, const HStack& s) {
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(s.n & 3u) << 8;
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
#endif
