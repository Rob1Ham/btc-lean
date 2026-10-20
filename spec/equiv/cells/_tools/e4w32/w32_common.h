#ifndef CELLS_E4W32_COMMON_H
#define CELLS_E4W32_COMMON_H
#include <cstdint>

#define W32INLINE static inline __attribute__((always_inline))

// Packed observable for the wave-32 witness-v0 cells:
//   result (2 bits) | error ordinal (6 bits) << 2.
// This is the ABI v2 (result, error_kind) pair and nothing else.  The packing
// is cell harness, not engine semantics (contract/ABI.md §2).
W32INLINE uint64_t w32_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// The ABI invariant "result 1 => EQUIV_ERR_OK" applied to the (result, error)
// pair that ExecuteWitnessScript returns.  The pair is a cell input: script
// execution is outside these cells.
W32INLINE uint64_t w32_exec(uint64_t exec_res, uint64_t exec_err) {
  const uint32_t r = (uint32_t)(exec_res & 1u);
  const uint32_t e = r ? 0u : (uint32_t)(exec_err & 0x3fu);
  return w32_pack(r, e);
}
#endif
