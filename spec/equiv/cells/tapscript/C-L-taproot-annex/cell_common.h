#ifndef CELLS_TAPSCRIPT_ANNEX_COMMON_H
#define CELLS_TAPSCRIPT_ANNEX_COMMON_H
#include <cstdint>

#define TAP_INLINE static inline __attribute__((always_inline))

// This cell's observables are the annex predicate (0/1) and the post-annex
// item count (0..2^64-1), so there is no result/error packing.
enum { TAP_ANNEX_TAG = 0x50 };

#endif
