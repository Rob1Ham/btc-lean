#ifndef CELLS_TAPSCRIPT_KEYPATH_COMMON_H
#define CELLS_TAPSCRIPT_KEYPATH_COMMON_H
#include <cstdint>

#define TAP_INLINE static inline __attribute__((always_inline))

// Packed observable: result (2 bits) | error ordinal (6 bits) << 2.
TAP_INLINE uint64_t tap_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// Harness result codes (not engine semantics).
//   0 = failure, error field is the Core ScriptError ordinal
//   1 = success
//   2 = post-annex stack size > 1, script path (sibling cell)
enum { TAP_FAIL = 0, TAP_OK = 1, TAP_SCRIPT_PATH = 2 };

#endif
