#include "w32_common.h"

// L leg: REVIEWED TRANSLITERATION of the Lean model:
//
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-224 (`getOpAux` / `getOp`)
//     decode order: 0x00 -> pushBytes empty; 0x01..0x4b direct push;
//     0x4c/0x4d/0x4e PUSHDATA1/2/4 with 1/2/4 LE length bytes (readLE fails
//     unless all length bytes are present; sliceOpt fails unless all payload
//     bytes are present); 0x4f -> pushNum 0; 0x50 -> .op 0x50;
//     0x51..0x60 -> pushNum; >= 0x61 -> .op.
//   spec/core/Bitcoin/Interpreter/Defs.lean:479-492 (`opSuccessScanFrom`)
//     walk until b.size <= i; getOp none -> false; `.op c` -> test
//     isOpSuccessWire c; any push -> continue.
//   spec/core/Bitcoin/Interpreter/Defs.lean:463-468 (`isOpSuccessWire`)
//
// and of executeWitnessScript's post-scan branches,
//   Defs.lean:1211-1226:
//     if opSuccessScan exec then
//       if pol.discourageOpSuccess then .fail .discourageOpSuccess else .ok
//     else if MAX_STACK_SIZE < items.length then .fail .stackSize
//     else runExec items          -- item size, EvalScript, cleanstack, castToBool
//   with the item-size check at Defs.lean:1230-1233 (`runExec`).
//
// The scan is 4 unrolled iterations of the Lean recursive step (`opSuccessScanFrom`
// with the canonical fuel b.size + 1, bounded here to script length <= 4).
// Unlike the C leg, the L scan keeps Lean's push-vs-op distinction and tests
// the success table only for `.op` payloads.

#define W32_MAX_SCAN_LEN 4

W32INLINE uint8_t l_byte(uint32_t w, uint32_t i) {
    return (uint8_t)((w >> (8u * i)) & 0xffu);
}

W32INLINE bool l_is_op_success(uint32_t w) {
    return w == 80 || w == 98 || (126 <= w && w <= 129) ||
           (131 <= w && w <= 134) || (137 <= w && w <= 138) ||
           (141 <= w && w <= 142) || (149 <= w && w <= 153) ||
           (187 <= w && w <= 254);
}

// Lean getOp at index i (i < len): true and (*is_op, *next) when the opcode
// decodes, false when a push is truncated (getOp none).
W32INLINE bool l_getop(uint32_t w, uint32_t len, uint32_t i, bool* is_op,
                       uint32_t* next) {
    const uint32_t c = (uint32_t)l_byte(w, i);
    if (c == 0) {  // pushBytes empty
        *is_op = false;
        *next = i + 1;
        return true;
    }
    if (c <= 0x4b) {  // direct push
        if ((uint64_t)i + 1u + (uint64_t)c > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 1 + c;
        return true;
    }
    if (c == 0x4c) {  // PUSHDATA1
        if ((uint64_t)i + 2u > (uint64_t)len) return false;
        const uint32_t k = (uint32_t)l_byte(w, i + 1);
        if ((uint64_t)i + 2u + (uint64_t)k > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 2 + k;
        return true;
    }
    if (c == 0x4d) {  // PUSHDATA2
        if ((uint64_t)i + 3u > (uint64_t)len) return false;
        const uint32_t k = (uint32_t)l_byte(w, i + 1) |
                           ((uint32_t)l_byte(w, i + 2) << 8);
        if ((uint64_t)i + 3u + (uint64_t)k > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 3 + k;
        return true;
    }
    if (c == 0x4e) {  // PUSHDATA4
        if ((uint64_t)i + 5u > (uint64_t)len) return false;
        const uint32_t k = (uint32_t)l_byte(w, i + 1) |
                           ((uint32_t)l_byte(w, i + 2) << 8) |
                           ((uint32_t)l_byte(w, i + 3) << 16) |
                           ((uint32_t)l_byte(w, i + 4) << 24);
        if ((uint64_t)i + 5u + (uint64_t)k > (uint64_t)len) return false;
        *is_op = false;
        *next = i + 5 + k;
        return true;
    }
    if (c == 0x4f) {  // pushNum 0
        *is_op = false;
        *next = i + 1;
        return true;
    }
    if (c == 0x50) {  // .op 0x50 (OP_RESERVED; in the success set)
        *is_op = true;
        *next = i + 1;
        return true;
    }
    if (c <= 0x60) {  // pushNum (c - 0x50)
        *is_op = false;
        *next = i + 1;
        return true;
    }
    *is_op = true;  // .op c
    *next = i + 1;
    return true;
}

#define W32_L_SCAN_STEP()                                                   \
    if (i >= len) return 0u;                                                \
    {                                                                       \
        const uint32_t c = (uint32_t)l_byte(w, i);                          \
        bool is_op = false;                                                 \
        uint32_t nx = 0;                                                    \
        if (!l_getop(w, len, i, &is_op, &nx)) return 0u;                    \
        if (is_op && l_is_op_success(c)) return 1u;                         \
        i = nx;                                                             \
    }

W32INLINE uint32_t l_scan_finds_success(uint32_t len, uint32_t w) {
    uint32_t i = 0;
    W32_L_SCAN_STEP();
    W32_L_SCAN_STEP();
    W32_L_SCAN_STEP();
    W32_L_SCAN_STEP();
    return 0u;
}

W32INLINE uint64_t l_prescan_tail(uint32_t found, uint32_t discourage_op_success,
                                  uint32_t too_many, uint32_t oversize,
                                  uint64_t later_rc) {
    if (found) {
        if (discourage_op_success) return w32_pack(0, 36);
        return w32_pack(1, 0);
    }
    if (too_many) return w32_pack(0, 8);
    if (oversize) return w32_pack(0, 6);
    return later_rc;
}

// Harness entry: four symbolic script bytes (little-endian packing is cell
// harness, identical on both legs).  Bytes at or past `len` are don't-care.
extern "C" uint64_t cell_scan_finds_success(uint32_t len, uint8_t b0, uint8_t b1,
                                            uint8_t b2, uint8_t b3) {
    if (len > W32_MAX_SCAN_LEN) return w32_bad_domain();
    const uint32_t bytes = (uint32_t)b0 | ((uint32_t)b1 << 8) |
                           ((uint32_t)b2 << 16) | ((uint32_t)b3 << 24);
    return (uint64_t)l_scan_finds_success(len, bytes);
}

extern "C" uint64_t cell_prescan_tail(uint32_t found, uint32_t discourage,
                                      uint32_t too_many, uint32_t oversize,
                                      uint64_t later_rc) {
    return l_prescan_tail(found, discourage, too_many, oversize, later_rc);
}
