#include <cstdint>

// Divergence probe, C leg: Bitcoin Core ExecuteWitnessScript TAPSCRIPT branch
// at pin cce32b168, interpreter.cpp:1846-1875.
//
// The probe returns the packed (result, error) of the first decisive check:
//   result(2) | error(6) << 2
//   BAD_OPCODE 16        -> 64
//   STACK_SIZE 8         -> 32
//   PUSH_SIZE 6          -> 24
//   DISCOURAGE_OP_SUCCESS 36 -> 144
//   success              -> 1
//
// Core order: pre-scan (BAD_OPCODE on a decode failure *inside* the scan),
// then success/flag, then stack size, then item size, then EvalScript
// (abstracted to success here, so the probe isolates the ordering).
//
// Script is four bytes with length len <= 4; the scan is the same four-step
// unroll as the cell, returning 0 = end, 1 = found, 2 = decode failure.

static inline __attribute__((always_inline)) uint8_t pb(uint32_t w, uint32_t i) {
    return (uint8_t)((w >> (8u * i)) & 0xffu);
}

static inline __attribute__((always_inline)) bool succeeds(uint32_t c) {
    return c == 80 || c == 98 || (c >= 126 && c <= 129) ||
           (c >= 131 && c <= 134) || (c >= 137 && c <= 138) ||
           (c >= 141 && c <= 142) || (c >= 149 && c <= 153) ||
           (c >= 187 && c <= 254);
}

static inline __attribute__((always_inline)) bool getop(uint32_t w, uint32_t len, uint32_t i, uint32_t* next) {
    const uint32_t c = (uint32_t)pb(w, i);
    if (c <= 0x4b) {
        if (len - (i + 1) < c) return false;
        *next = i + 1 + c;
        return true;
    }
    if (c == 0x4c) {
        if (len < i + 2) return false;
        const uint32_t k = (uint32_t)pb(w, i + 1);
        if (len - (i + 2) < k) return false;
        *next = i + 2 + k;
        return true;
    }
    if (c == 0x4d) {
        if (len < i + 3) return false;
        const uint32_t k = (uint32_t)pb(w, i + 1) | ((uint32_t)pb(w, i + 2) << 8);
        if (len - (i + 3) < k) return false;
        *next = i + 3 + k;
        return true;
    }
    if (c == 0x4e) {
        if (len < i + 5) return false;
        const uint32_t k = (uint32_t)pb(w, i + 1) | ((uint32_t)pb(w, i + 2) << 8) |
                           ((uint32_t)pb(w, i + 3) << 16) | ((uint32_t)pb(w, i + 4) << 24);
        if (len - (i + 5) < k) return false;
        *next = i + 5 + k;
        return true;
    }
    *next = i + 1;
    return true;
}

#define STEP()                                                             \
    if (i >= len) return 0u;                                               \
    {                                                                      \
        const uint32_t c = (uint32_t)pb(w, i);                             \
        uint32_t nx = 0;                                                   \
        if (!getop(w, len, i, &nx)) return 2u;                             \
        if (succeeds(c)) return 1u;                                        \
        i = nx;                                                            \
    }

static inline __attribute__((always_inline)) uint32_t scan(uint32_t len, uint32_t w) {
    uint32_t i = 0;
    STEP();
    STEP();
    STEP();
    STEP();
    return 0u;
}

extern "C" uint64_t probe_prescan_order(uint32_t len, uint8_t b0, uint8_t b1,
                                        uint8_t b2, uint8_t b3, uint32_t too_many,
                                        uint32_t oversize, uint32_t discourage) {
    // Cell-domain guard (4-byte probe): keeps the byte shifts in range and
    // gives len > 4 the bad-input marker 6 on both legs.
    if (len > 4) return 6;
    const uint32_t w = (uint32_t)b0 | ((uint32_t)b1 << 8) | ((uint32_t)b2 << 16) |
                       ((uint32_t)b3 << 24);
    const uint32_t s = scan(len, w);
    // interpreter.cpp:1855-1861: decode failure inside the scan.
    if (s == 2u) return 64;  // BAD_OPCODE
    if (s == 1u) return discourage != 0 ? 144 : 1;
    if (too_many) return 32;   // interpreter.cpp:1865
    if (oversize) return 24;   // interpreter.cpp:1870
    return 1;                  // EvalScript abstracted to success
}
