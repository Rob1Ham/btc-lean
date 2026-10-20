#ifndef CELL_OPCOUNT_H
#define CELL_OPCOUNT_H
#include <cstdint>
// Cell harness only: the opcode budget is observed as (outcome, opCount).
// MAX_OPS_PER_SCRIPT is 201 (script.h), kept as a literal in both legs.
#define BINLINE static inline __attribute__((always_inline))
// Observable: result(2) | error(6) | opCount(9)@8.
BINLINE uint64_t opc_pack(uint32_t err, uint32_t opcount) {
  uint64_t r = (err == 0) ? 1ull : 0ull;
  r += (uint64_t)(err & 0x3fu) * 4ull;
  r += (uint64_t)(opcount & 0x1ffu) * 256ull;
  return r;
}
#endif
