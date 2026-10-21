#ifndef CELLS_E4_COMMON_H
#define CELLS_E4_COMMON_H
#include <cstdint>
#define E4INLINE static inline __attribute__((always_inline))

// Packed observable for the E4 dispatch cells:
//   result (2 bits) | error ordinal (6 bits) << 2.
// This is the ABI's (result, error_kind) pair and nothing else; unlike the
// stack cells there is no stack projection.  The packing is cell harness,
// not engine semantics.
E4INLINE uint64_t e4_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}
#endif
