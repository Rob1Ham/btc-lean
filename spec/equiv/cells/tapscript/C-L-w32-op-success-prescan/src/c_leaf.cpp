#include "w32_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slices:
//   interpreter.cpp:1846-1862  the TAPSCRIPT OP_SUCCESSx pre-scan of
//                              ExecuteWitnessScript (GetOp loop, IsOpSuccess,
//                              DISCOURAGE_OP_SUCCESS, immediate success)
//   interpreter.cpp:1864-1865  initial main-stack size check (>1000 -> STACK_SIZE)
//   interpreter.cpp:1868-1871  per-item size check (>520 -> PUSH_SIZE)
//   interpreter.cpp:1874-1879  EvalScript call, cleanstack, CastToBool
//   script.cpp:311-362         GetScriptOp (GetOp) decode and truncation rule
//   script.cpp:365-371         IsOpSuccess
//
// The scan is written as MAX_SCAN_LEN = 4 unrolled iterations of the Core loop
// body, so it is loop-free while staying byte-faithful: each iteration decodes
// exactly one opcode with GetScriptOp's rules and advances past its push data,
// so 4 iterations cover every script of length <= 4.  Nothing about longer
// scripts is claimed (spec.md: bounded length).
//
// cell_scan_finds_success returns "the pre-scan stopped with an OP_SUCCESSx"
// (1) or not (0).  Not-found folds together the two exits that do not return
// success: end of script, and a GetOp decode failure.  Core distinguishes them
// (BAD_OPCODE for the failure); Lean's opSuccessScan also returns false for
// both.  The cell compares only the found bit, so no error kind is claimed for
// malformed tails: that ordering is a separate finding, see notes.md.

#define W32_MAX_SCAN_LEN 4

W32INLINE uint8_t w32_byte(uint32_t w, uint32_t i) {
    return (uint8_t)((w >> (8u * i)) & 0xffu);
}

W32INLINE bool w32_is_op_success(uint32_t c) {
    return c == 80 || c == 98 || (c >= 126 && c <= 129) ||
           (c >= 131 && c <= 134) || (c >= 137 && c <= 138) ||
           (c >= 141 && c <= 142) || (c >= 149 && c <= 153) ||
           (c >= 187 && c <= 254);
}

// GetScriptOp at index i (i < len).  Returns true and writes *next when the
// opcode decodes; false on any truncation (Core returns false from GetOp).
W32INLINE bool w32_getop(uint32_t w, uint32_t len, uint32_t i, uint32_t* next) {
    const uint32_t c = (uint32_t)w32_byte(w, i);
    if (c <= 0x4b) {  // direct push of c bytes
        if (len - (i + 1) < c) return false;
        *next = i + 1 + c;
        return true;
    }
    if (c == 0x4c) {  // PUSHDATA1
        if (len < i + 2) return false;
        const uint32_t k = (uint32_t)w32_byte(w, i + 1);
        if (len - (i + 2) < k) return false;
        *next = i + 2 + k;
        return true;
    }
    if (c == 0x4d) {  // PUSHDATA2, little-endian
        if (len < i + 3) return false;
        const uint32_t k = (uint32_t)w32_byte(w, i + 1) |
                           ((uint32_t)w32_byte(w, i + 2) << 8);
        if (len - (i + 3) < k) return false;
        *next = i + 3 + k;
        return true;
    }
    if (c == 0x4e) {  // PUSHDATA4, little-endian
        if (len < i + 5) return false;
        const uint32_t k = (uint32_t)w32_byte(w, i + 1) |
                           ((uint32_t)w32_byte(w, i + 2) << 8) |
                           ((uint32_t)w32_byte(w, i + 3) << 16) |
                           ((uint32_t)w32_byte(w, i + 4) << 24);
        if (len - (i + 5) < k) return false;
        *next = i + 5 + k;
        return true;
    }
    // Every remaining byte (0x4f..0xff) is one opcode with no payload.
    *next = i + 1;
    return true;
}

// One unrolled iteration of Core's `while (pc < exec_script.end())` body:
// end -> 0, GetOp failure -> 0, IsOpSuccess -> 1, else advance.
#define W32_SCAN_STEP()                                                    \
    if (i >= len) return 0u;                                               \
    {                                                                      \
        const uint32_t c = (uint32_t)w32_byte(w, i);                       \
        uint32_t nx = 0;                                                   \
        if (!w32_getop(w, len, i, &nx)) return 0u;                         \
        if (w32_is_op_success(c)) return 1u;                               \
        i = nx;                                                            \
    }

W32INLINE uint32_t c_scan_finds_success(uint32_t len, uint32_t w) {
    uint32_t i = 0;
    W32_SCAN_STEP();
    W32_SCAN_STEP();
    W32_SCAN_STEP();
    W32_SCAN_STEP();
    return 0u;
}

// The branches after the pre-scan, in Core's order.  `found`, `too_many` and
// `oversize` are the booleans the engine computes at the cited lines;
// `later_rc` is the uninterpreted packed outcome of EvalScript + the witness
// tail (interpreter.cpp:1874-1879), which this cell does not model.
W32INLINE uint64_t c_prescan_tail(uint32_t found, uint32_t discourage_op_success,
                                  uint32_t too_many, uint32_t oversize,
                                  uint64_t later_rc) {
    if (found) {
        // interpreter.cpp:1856-1860: success overrides every later check.
        if (discourage_op_success) return w32_pack(0, 36);
        return w32_pack(1, 0);
    }
    // interpreter.cpp:1864-1865
    if (too_many) return w32_pack(0, 8);
    // interpreter.cpp:1868-1871
    if (oversize) return w32_pack(0, 6);
    // interpreter.cpp:1874-1879, abstracted.
    return later_rc;
}

// Harness entry: four symbolic script bytes (little-endian packing is cell
// harness, identical on both legs).  Bytes at or past `len` are don't-care.
extern "C" uint64_t cell_scan_finds_success(uint32_t len, uint8_t b0, uint8_t b1,
                                            uint8_t b2, uint8_t b3) {
    if (len > W32_MAX_SCAN_LEN) return w32_bad_domain();
    const uint32_t bytes = (uint32_t)b0 | ((uint32_t)b1 << 8) |
                           ((uint32_t)b2 << 16) | ((uint32_t)b3 << 24);
    return (uint64_t)c_scan_finds_success(len, bytes);
}

extern "C" uint64_t cell_prescan_tail(uint32_t found, uint32_t discourage,
                                      uint32_t too_many, uint32_t oversize,
                                      uint64_t later_rc) {
    return c_prescan_tail(found, discourage, too_many, oversize, later_rc);
}
