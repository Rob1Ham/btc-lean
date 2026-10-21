// Cell-local harness header for disabled/C-L-w65-row172-arbscan.
//
// Both legs are plain leaf functions: no memory, no calls, no loops (the
// decode walk is a fixed 8-iteration template unroll, one script byte per
// iteration).  The helpers below only spell the packing and the two byte
// tables that the cell shares with its Cryptol spec.
#ifndef W65_ROW172_COMMON_H
#define W65_ROW172_COMMON_H

#include <cstdint>

#define W65INLINE static inline __attribute__((always_inline))

#define W65_MAX_SCAN_LEN 8u
#define W65_BAD_DOMAIN 254u

using w65_reg_t = uint64_t;

// script.cpp:365-371 (IsOpSuccess) at Core cce32b168.
W65INLINE bool w65_is_success(uint32_t c) {
    return c == 80 || c == 98 || (c >= 126 && c <= 129) ||
           (c >= 131 && c <= 134) || (c >= 137 && c <= 138) ||
           (c >= 141 && c <= 142) || (c >= 149 && c <= 153) ||
           (c >= 187 && c <= 254);
}

// interpreter.cpp:472-483 disabled table at Core cce32b168.  NOTE: the
// parser's `isDisabled` in spec/core copies 0x9a for OP_RSHIFT; Core's
// script.h:168 says OP_RSHIFT = 0x99, and the interpreter's disabled table
// (which this cell transcribes) uses OP_RSHIFT, so 0x99 is the wire.
W65INLINE bool w65_is_disabled(uint32_t c) {
    return c == 0x7e || c == 0x7f || c == 0x80 || c == 0x81 ||
           c == 0x83 || c == 0x84 || c == 0x85 || c == 0x86 ||
           c == 0x8d || c == 0x8e || c == 0x95 || c == 0x96 ||
           c == 0x97 || c == 0x98 || c == 0x99;
}

W65INLINE uint32_t w65_peek(w65_reg_t reg, uint32_t sh) {
    return (uint32_t)((reg >> sh) & 0xffu);
}

W65INLINE uint64_t w65_pack(uint32_t base, uint32_t tap) {
    return ((uint64_t)base << 32) | (uint64_t)tap;
}

#endif  // W65_ROW172_COMMON_H
