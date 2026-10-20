#ifndef CELLS_GATE_COMMON_H
#define CELLS_GATE_COMMON_H
#include <cstdint>
#define BINLINE static inline __attribute__((always_inline))
struct BStack { uint32_t n; uint32_t len[6]; uint32_t val[6]; };
BINLINE void b_clear(BStack& s) {
  s.n = 0;
  s.len[0]=0; s.len[1]=0; s.len[2]=0; s.len[3]=0; s.len[4]=0; s.len[5]=0;
  s.val[0]=0; s.val[1]=0; s.val[2]=0; s.val[3]=0; s.val[4]=0; s.val[5]=0;
}
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
// Packed observable: result (2), error ordinal (6), depth (2), then the
// TOP THREE stack elements (len 2 + val 16 each).  For depth 4 (pick-depth)
// the bottom element is not packed; depth 4 is still observable.
BINLINE uint64_t b_pack(uint32_t res, uint32_t err, const BStack& s) {
  const uint32_t m = s.n > 3 ? 3u : s.n;
  uint32_t k = 0;
  if (s.n == 4) k = 1; else if (s.n == 5) k = 2; else if (s.n == 6) k = 3;
  uint64_t r = 0;
  r |= (uint64_t)(res & 3u);
  r |= (uint64_t)(err & 0x3fu) << 2;
  r |= (uint64_t)(s.n & 7u) << 8;
  if (m > 0) { r |= (uint64_t)(s.len[k] & 3u) << 11;   r |= (uint64_t)(s.val[k] & 0xffu) << 13; }
  if (m > 1) { r |= (uint64_t)(s.len[k+1] & 3u) << 21; r |= (uint64_t)(s.val[k+1] & 0xffu) << 23; }
  if (m > 2) { r |= (uint64_t)(s.len[k+2] & 3u) << 31; r |= (uint64_t)(s.val[k+2] & 0xffu) << 33; }
  return r;
}
#endif
