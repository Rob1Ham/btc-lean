#ifndef CELLS_LIMITS_COMMON_H
#define CELLS_LIMITS_COMMON_H
#include <cstdint>

// Packed observables for the wave16 `limits` cells.  This is cell harness,
// not engine semantics: it packs the ABI's (result, error_kind) pair plus a
// small amount of accounting state so the tools can compare it.
//
//   result (2) | error ordinal (6) << 2
//   result (2) | error ordinal (6) << 2 | extra (16) << 8
//
// `result` uses the contract ABI: 0 fail, 1 pass.  The error ordinal is
// Core's ScriptError ordinal (contract/error_kind.h).
#define LIMITS_INLINE static inline __attribute__((always_inline))

LIMITS_INLINE uint64_t lim_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

LIMITS_INLINE uint64_t lim_pack32(uint32_t result, uint32_t error, uint32_t extra) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2) |
         ((uint64_t)extra << 8);
}

// decision(2) | error(6) << 2 | success(1) << 8 | w_after_i32 << 9
// `decision` 1 = no script error, 0 = script error with a known ordinal,
// 2 = the signature checker rejected (its ordinal is outside the cell).
LIMITS_INLINE uint64_t lim_pack_acc(uint32_t decision, uint32_t error,
                                    uint32_t success, int64_t w_after) {
  return (uint64_t)(decision & 3u) | ((uint64_t)(error & 0x3fu) << 2) |
         ((uint64_t)(success & 1u) << 8) |
         ((uint64_t)(uint32_t)w_after << 9);
}
#endif
