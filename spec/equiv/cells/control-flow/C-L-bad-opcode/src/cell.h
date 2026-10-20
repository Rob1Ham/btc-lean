#ifndef CELL_BAD_OPCODE_H
#define CELL_BAD_OPCODE_H
#include <cstdint>
// Cell harness only.  The observable is the success/error outcome plus the
// post-dispatch opcode counter, so the OP_COUNT-before-BAD_OPCODE precedence
// and the "OP_VER still counts" behaviour are both visible.
#define BINLINE static inline __attribute__((always_inline))
// Observable: result(2) | error(6) | opCount(9)@8.
BINLINE uint64_t bad_pack(uint32_t err, uint32_t opcount) {
  uint64_t r = (err == 0) ? 1ull : 0ull;
  r += (uint64_t)(err & 0x3fu) * 4ull;
  r += (uint64_t)(opcount & 0x1ffu) * 256ull;
  return r;
}
#endif
