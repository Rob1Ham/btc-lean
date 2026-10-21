#ifndef CELLS_W32_EXEC_COMMON_H
#define CELLS_W32_EXEC_COMMON_H
// Wave-32 exec-verify cell harness helpers.
//
// This header is cell harness, not engine semantics: it packs the ABI's
// (result, error_kind) pair, and it carries two independent bounded
// implementations of CastToBool so that the C leg (Core's early-exit loop)
// and the L leg (the Lean `castToBoolList` on the reversed byte list) meet.
//
// Bounded stack encoding used by the exec-verify cells: one element is a
// 64-bit little-endian word (wire byte i at bits 8i..8i+7) plus an explicit
// length. The encoding carries 0..8 bytes; a longer element is outside the
// cell and both legs return the UNKNOWN guard value (declared in spec.md).
#include <cstdint>

#define W32INLINE static inline __attribute__((always_inline))

// ABI packing: result (2 bits) | error_kind (6 bits) << 2.
// Core ordinals at the pin are 0..55, so 6 bits is lossless for real errors.
W32INLINE uint64_t w32_pack(uint32_t result, uint32_t error) {
  return (uint64_t)(result & 3u) | ((uint64_t)(error & 0x3fu) << 2);
}

W32INLINE uint64_t w32_byte(uint64_t w, uint64_t i) {
  return (w >> (8u * i)) & 0xffu;
}

// Core `CastToBool`, interpreter.cpp:46-59: first nonzero byte decides; a
// lone 0x80 in the wire-last position is negative zero and casts false.
// Unrolled to the cell's 8-byte element bound (no loop for Alive2).
W32INLINE bool w32_cast_bool_core(uint64_t w, uint64_t len) {
  if (0 < len && w32_byte(w, 0) != 0) {
    if (0 + 1 == len && w32_byte(w, 0) == 0x80u) return false;
    return true;
  }
  if (1 < len && w32_byte(w, 1) != 0) {
    if (1 + 1 == len && w32_byte(w, 1) == 0x80u) return false;
    return true;
  }
  if (2 < len && w32_byte(w, 2) != 0) {
    if (2 + 1 == len && w32_byte(w, 2) == 0x80u) return false;
    return true;
  }
  if (3 < len && w32_byte(w, 3) != 0) {
    if (3 + 1 == len && w32_byte(w, 3) == 0x80u) return false;
    return true;
  }
  if (4 < len && w32_byte(w, 4) != 0) {
    if (4 + 1 == len && w32_byte(w, 4) == 0x80u) return false;
    return true;
  }
  if (5 < len && w32_byte(w, 5) != 0) {
    if (5 + 1 == len && w32_byte(w, 5) == 0x80u) return false;
    return true;
  }
  if (6 < len && w32_byte(w, 6) != 0) {
    if (6 + 1 == len && w32_byte(w, 6) == 0x80u) return false;
    return true;
  }
  if (7 < len && w32_byte(w, 7) != 0) {
    if (7 + 1 == len && w32_byte(w, 7) == 0x80u) return false;
    return true;
  }
  return false;
}

// Lean `castToBool` (spec/core/Bitcoin/Numeric/Interface.lean:64,
// `castToBoolList` in Numeric/ScriptNum.lean:648): on the reversed byte list
// `d :: t`, the answer is `t.any (· != 0) || (d != 0 && d != 128)`, where
// `d` is the wire-last byte. Different shape from the C leg on purpose.
W32INLINE bool w32_cast_bool_lean(uint64_t w, uint64_t len) {
  if (len == 0) return false;
  const uint64_t last = len - 1;
  bool any_prefix = false;
  if (0 < last && w32_byte(w, 0) != 0) any_prefix = true;
  if (1 < last && w32_byte(w, 1) != 0) any_prefix = true;
  if (2 < last && w32_byte(w, 2) != 0) any_prefix = true;
  if (3 < last && w32_byte(w, 3) != 0) any_prefix = true;
  if (4 < last && w32_byte(w, 4) != 0) any_prefix = true;
  if (5 < last && w32_byte(w, 5) != 0) any_prefix = true;
  if (6 < last && w32_byte(w, 6) != 0) any_prefix = true;
  if (7 < last && w32_byte(w, 7) != 0) any_prefix = true;
  const uint64_t d = w32_byte(w, last);   // caller guards len <= 8
  return any_prefix || (d != 0 && d != 0x80u);
}
#endif
