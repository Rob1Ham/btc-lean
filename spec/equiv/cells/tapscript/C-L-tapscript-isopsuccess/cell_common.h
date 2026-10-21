#ifndef CELLS_TAPSCRIPT_ISOPSUCCESS_COMMON_H
#define CELLS_TAPSCRIPT_ISOPSUCCESS_COMMON_H
#include <cstdint>

#define TAP_INLINE static inline __attribute__((always_inline))

// This cell's whole observable is the boolean membership test itself.
TAP_INLINE uint64_t tap_bool(bool b) { return b ? 1u : 0u; }

#endif
