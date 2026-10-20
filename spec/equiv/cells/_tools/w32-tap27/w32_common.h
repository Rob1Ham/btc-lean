#ifndef CELLS_W32_COMMON_H
#define CELLS_W32_COMMON_H
#include <cstdint>

// Wave-32 tapscript dispatch cells.
//
// Packed observable shared by every function in this tool directory:
//
//   bits 0..1   result       0 fail | 1 pass | 2 bad input (harness domain marker)
//   bits 2..7   error_kind   Core ScriptError ordinal (contract/error_kind.h)
//   bits 8..39  aux          optional second observable (e.g. nOpCount)
//
// The packing is cell harness, not engine semantics: it is the ABI's
// (result, error_kind) pair plus one integer where a second observable is
// needed.  Both legs pack identically.
#define W32INLINE static inline __attribute__((always_inline))

W32INLINE uint64_t w32_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}
W32INLINE uint64_t w32_pack_aux(uint32_t result, uint32_t error, uint32_t aux) {
  return w32_pack(result, error) | ((uint64_t)aux << 8);
}
// Harness domain marker: the input is outside the cell's stated domain.  It is
// result=2 (ABI "bad input") with EQUIV_ERR_UNKNOWN_ERROR, and is used only so
// the functions stay total; no engine verdict is smuggled for those inputs.
W32INLINE uint64_t w32_bad_domain(void) { return w32_pack(2, 1); }

#endif
