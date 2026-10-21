#ifndef CELL_IF_NOTIF_H
#define CELL_IF_NOTIF_H
#include <cstdint>
// Cell harness only.  The bounded stack state keeps the number of elements
// plus the top element (length <= 2, two bytes) and the condition stack.
#define BINLINE static inline __attribute__((always_inline))
struct ISt {
  uint32_t depth;   // stack.size()
  uint32_t len;     // top element length (cell domain: 0..2)
  uint8_t b0, b1;   // top element bytes
  uint32_t vf_n;    // vfExec.size()
  uint32_t vf0;     // vfExec.back() when vf_n > 0
};
// Observable: result(2) | error(6) | depth(8) | vf_n(2) | vf0(1).
BINLINE uint64_t if_pack(uint32_t err, const ISt& st) {
  uint64_t r = (err == 0) ? 1ull : 0ull;
  r += (uint64_t)(err & 0x3fu) * 4ull;
  r += (uint64_t)(st.depth & 0xffu) * 256ull;
  r += (uint64_t)(st.vf_n & 0x3u) * 65536ull;
  r += (uint64_t)(st.vf0 & 0x1u) * 262144ull;
  return r;
}
#endif
