#ifndef CELL_CLTV_CSV_NOP_H
#define CELL_CLTV_CSV_NOP_H
#include <cstdint>

// Cell harness only -- no engine text.  The bounded state is
//   (stack depth <= 3, one-byte top element, nOpCount <= 200)
// and the observable packs
//   result(2) | error(6)<<2 | depth(3)<<8 | top_len(2)<<11 | top(8)<<13
//             | nOpCount(8)<<21
//
// result is 1 when the opcode continued (Core `break`), 0 when it returned a
// ScriptError, and 3 for the declared cell boundary: the flag-on path with a
// non-empty stack, whose decode/compare region belongs to the locktime cells.
// top_len is 1 iff depth > 0; the top byte is omitted at depth 0.

#define BINLINE static inline __attribute__((always_inline))

enum : uint32_t {
  CELL_CONT = 0,      // Core `break`: continue with the next opcode
  CELL_BOUNDARY = 3,  // declared boundary, not modelled here (see spec.md)
};

BINLINE uint64_t nop_pack(uint32_t code, uint32_t depth, uint8_t top, uint32_t opcount) {
  const uint32_t res = (code == CELL_CONT) ? 1u : ((code == CELL_BOUNDARY) ? 3u : 0u);
  const uint32_t err = (code == CELL_CONT || code == CELL_BOUNDARY) ? 0u : code;
  uint64_t r = (uint64_t)(res & 3u);
  r += (uint64_t)(err & 0x3fu) << 2;
  r += (uint64_t)(depth & 7u) << 8;
  if (depth != 0) {
    r += (uint64_t)1u << 11;
    r += (uint64_t)top << 13;
  }
  r += (uint64_t)(opcount & 0xffu) << 21;
  return r;
}
#endif
