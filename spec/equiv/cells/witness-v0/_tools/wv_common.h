// Shared, cell-local header for the wave16 witness-v0 cells.
//
// The packed observable is the same one used by the E4 dispatch cell:
//   bits 0..1  result (0 fail, 1 pass, 2 continuation sentinel)
//   bits 2..7  Core ScriptError ordinal (0 when result != 0)
// Result 2 is a CELL SENTINEL meaning "this bounded slice has no verdict;
// consensus continues into the next engine step".  It is never an engine
// result and never appears in contract evidence outside the cell record.
#ifndef WV_COMMON_H
#define WV_COMMON_H

#include <stdint.h>
#include <stddef.h>

#define WV_INLINE static inline __attribute__((always_inline))

WV_INLINE uint64_t wv_pack(uint64_t result, uint64_t error) {
    return (result & 3u) | ((error & 63u) << 2);
}

#endif
