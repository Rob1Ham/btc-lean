#include "e2_common.h"
extern "C" void hash160(const uint8_t* in, uint32_t len, uint8_t* out);

namespace twinleaf_hash {
// Reviewed transliteration of twin/ops_ir.py OP_HASH160 (wires [0xa9],
// lean Defs.lean:1028-1030).  The twin body is:
//
//   if (st.stack.n < 1) return TWIN_INVALID_STACK_OPERATION;
//   uint32_t l = 0; const uint8_t* p = st_top(st.stack, 1, l);
//   uint8_t out[20]; hash160(p, l, out);
//   st.stack.n -= 1; return st_push(st.stack, out, 20);
//
// The only re-binding is the cell stack element width (32 bytes) and the
// unrolled 20-byte copy.  mk_leaf cannot represent this op: its bounded
// memcpy is hard-wired to 2 bytes, so a 20-byte push cannot round-trip.
// The hash body itself is unchanged and calls the shared opaque `hash160`.
BINLINE const uint8_t* st_top(const HStack& s, uint32_t k, uint32_t& len) {
  const uint32_t i = s.n - k; len = s.len[i]; return s.e[i];
}
#define CP(dst, src, k) do { if (len > (k)) (dst)[k] = (src)[k]; } while (0)
BINLINE int st_push(HStack& s, const uint8_t* data, uint32_t len) {
  // E2_MAX_ELEM (32) is this cell's stack-slot capacity, not the consensus
  // 520-byte push limit; the cell pushes only 1- and 20-byte values.
  if (len > E2_MAX_ELEM) return 16;           // PUSH_SIZE (harness bound)
  if (s.n >= E2_MAX_DEPTH) return 8;          // STACK_SIZE
  CP(s.e[s.n], data, 0);  CP(s.e[s.n], data, 1);  CP(s.e[s.n], data, 2);  CP(s.e[s.n], data, 3);
  CP(s.e[s.n], data, 4);  CP(s.e[s.n], data, 5);  CP(s.e[s.n], data, 6);  CP(s.e[s.n], data, 7);
  CP(s.e[s.n], data, 8);  CP(s.e[s.n], data, 9);  CP(s.e[s.n], data, 10); CP(s.e[s.n], data, 11);
  CP(s.e[s.n], data, 12); CP(s.e[s.n], data, 13); CP(s.e[s.n], data, 14); CP(s.e[s.n], data, 15);
  CP(s.e[s.n], data, 16); CP(s.e[s.n], data, 17); CP(s.e[s.n], data, 18); CP(s.e[s.n], data, 19);
  s.len[s.n] = len; s.n += 1; return 0;
}
BINLINE int op_HASH160(HStack& st) {
  if (st.n < 1) return 15;                    // TWIN_INVALID_STACK_OPERATION
  uint32_t l = 0;
  const uint8_t* p = st_top(st, 1, l);
  uint8_t out[20];
  hash160(p, l, out);
  st.n -= 1;
  return st_push(st, out, 20);
}
}  // namespace twinleaf_hash

extern "C" uint64_t cell_hash160() {
  using namespace twinleaf_hash;
  HStack st{};
  const uint8_t pre[1] = {0x61};
  st_push(st, pre, 1);
  const int e = op_HASH160(st);
  return h_pack(e == 0 ? 1u : 0u, e == 0 ? 0u : 2u, st);
}
