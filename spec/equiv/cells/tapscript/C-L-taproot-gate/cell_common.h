#ifndef CELLS_TAPSCRIPT_GATE_COMMON_H
#define CELLS_TAPSCRIPT_GATE_COMMON_H
#include <cstdint>

#define TAP_INLINE static inline __attribute__((always_inline))

// Packed observable: result (2 bits) | error ordinal (6 bits) << 2.
// Error ordinals are the shared EQUIV_ERR_* values from
// contract/error_kind.h (Core ScriptError ordinals at the pin).
TAP_INLINE uint64_t tap_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

// Harness result codes (not engine semantics). The engine result is
// success/failure; 2 and 3 mark where this bounded cell stops.
//   0 = failure, error field is the Core ScriptError ordinal
//   1 = success (Core set_success / return true)
//   2 = v1-32 non-P2SH arm entered, dispatch continues in a sibling cell
//   3 = shape outside this arm (handled by another part of the engine)
enum { TAP_FAIL = 0, TAP_OK = 1, TAP_CONTINUE = 2, TAP_OUTSIDE = 3 };

// contract/error_enum.md
enum { TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY = 39 };

#endif
