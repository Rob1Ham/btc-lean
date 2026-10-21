#ifndef CELL_VERIFY_H
#define CELL_VERIFY_H
#include <cstdint>
// Cell harness only.  The bounded stack state is (depth, top element), with
// the element length fixed per exported function (0, 1 or 2).
#define BINLINE static inline __attribute__((always_inline))
struct VSt {
  uint32_t depth;  // stack.size()
};
// Observable: result(2) | error(6) | depth(8)@8.
BINLINE uint64_t verify_pack(uint32_t err, const VSt& st) {
  uint64_t r = (err == 0) ? 1ull : 0ull;
  r += (uint64_t)(err & 0x3fu) * 4ull;
  r += (uint64_t)(st.depth & 0xffu) * 256ull;
  return r;
}
#endif
