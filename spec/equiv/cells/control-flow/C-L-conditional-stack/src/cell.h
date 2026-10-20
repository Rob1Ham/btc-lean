#ifndef CELL_COND_STACK_H
#define CELL_COND_STACK_H
#include <cstdint>
// Cell harness only.  The bounded condition stack is (n, v0, v1) with n in
// {0,1,2}: v0 is vfExec.back(), v1 the entry below it.  "executed" records
// whether the dispatched opcode ran, which is how the [OP_IF..OP_ENDIF] gate
// (interpreter.cpp:493) is observed.
#define BINLINE static inline __attribute__((always_inline))
struct CSt {
  uint32_t n;         // vfExec.size()
  uint32_t v0;        // vfExec.back() when n > 0
  uint32_t v1;        // second-from-top when n > 1
  uint32_t executed;  // 1 iff the switch body ran
};
// Observable: result(2) | error(6) | n(2)@8 | v0@10 | v1@11 | executed@12.
BINLINE uint64_t cond_pack(uint32_t err, const CSt& st) {
  uint64_t r = (err == 0) ? 1ull : 0ull;
  r += (uint64_t)(err & 0x3fu) * 4ull;
  r += (uint64_t)(st.n & 0x3u) * 256ull;
  r += (uint64_t)(st.v0 & 0x1u) * 1024ull;
  r += (uint64_t)(st.v1 & 0x1u) * 2048ull;
  r += (uint64_t)(st.executed & 0x1u) * 4096ull;
  return r;
}
#endif
