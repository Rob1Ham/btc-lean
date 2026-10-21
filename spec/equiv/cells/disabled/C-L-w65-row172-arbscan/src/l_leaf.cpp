// L leg: literal transcription of the Lean model at this repository's BASE.
//
// Source of record:
//   spec/core/Bitcoin/Script/Parser/Defs.lean:206-229   getOpAux / getOp
//   spec/core/Bitcoin/Interpreter/Defs.lean:455-459     disabledWire
//   spec/core/Bitcoin/Interpreter/Defs.lean:463-468     isOpSuccessWire
//   spec/core/Bitcoin/Interpreter/Defs.lean:479-492     opSuccessScanFrom
//   spec/core/Bitcoin/Interpreter/Defs.lean:817-840     stepBody (disabled gate)
//   spec/core/Bitcoin/Interpreter/Defs.lean:1211-1233   executeWitnessScript
//
// The decode walk keeps Lean's push-vs-op distinction: `0x00` is OP_0,
// `0x01..0x4b` direct pushes, `0x4c/4d/4e` PUSHDATA1/2/4, `0x4f` OP_1NEGATE,
// `0x50` OP_RESERVED (an `.op`, not a push), `0x51..0x60` OP_1..OP_16, and
// `0x61..0xff` `.op`.  `opSuccessScanFrom` tests `isOpSuccessWire` only on
// `.op c`; the base disabled gate tests `disabledWire op.wire`, the raw byte,
// for every node.  The interval facts (success starts at 0x50 and 0x50 is an
// op; the only push wire `>= 0x50` is `0x51..0x60`, outside the success set)
// are exactly what the SAW cross-lemmas check against the C leg.
//
// `cell_tail` is the ordering in `executeWitnessScript`
// (Defs.lean:1214-1223): the scan gate first, then MAX_STACK_SIZE, then the
// 520-byte item check, and only then `evalScriptBytes`, whose `parseWire`
// failure is `.badOpcode` (16).  Core reaches the same failure earlier and
// returns 16 before the size checks; the cell records that difference as an
// expected non-equivalence, not as a green equivalence.
#include "common.h"

W65INLINE bool l_is_op(uint32_t c) { return c == 0x50u || c >= 0x61u; }

template <uint32_t POS>
W65INLINE void l_iter(uint32_t len, w65_reg_t reg, uint32_t* skip,
                      uint32_t* bstat, uint32_t* tstat) {
    const uint32_t c = (uint32_t)(reg & 0xffu);
    if ((*bstat == 0u || *tstat == 0u) && POS < len) {
        if (*skip != 0u) {
            *skip -= 1u;
        } else {
            // Lean getOpAux order, branchless PUSHDATA header decode (see
            // c_leaf.cpp for why the if-chain is avoided).
            uint32_t k = 0u;
            uint32_t hdr = 0u;
            if (c == 0u) {
                // OP_0: one-byte push of the empty item.
            } else if (c <= 0x4bu) {
                k = c;
            } else if (c <= 0x4eu) {
                const uint32_t t = c - 0x4bu;  // 1, 2, 3
                hdr = (t == 3u) ? 4u : t;
                k = w65_peek(reg, 8);
                if (hdr >= 2u) k |= w65_peek(reg, 16) << 8;
                if (hdr >= 4u) {
                    k |= (w65_peek(reg, 24) << 16) | (w65_peek(reg, 32) << 24);
                }
            }
            // 0x4f, 0x51..0x60 are push-num nodes; everything else is an
            // `.op`.  `l_is_op` mirrors getOpAux's AST discrimination.
            // Lean's Nat sum is unbounded; uint64 is exact for every reachable
            // term (POS <= 8, k < 2^32), so the comparison is the same test as
            // `sliceOpt`/`readLE` failing.
            if ((uint64_t)POS + 1u + (uint64_t)hdr + (uint64_t)k >
                (uint64_t)len) {
                if (*bstat == 0u) *bstat = 2u;
                if (*tstat == 0u) *tstat = 2u;
            } else {
                if (*bstat == 0u && w65_is_disabled(c)) *bstat = 1u;
                if (*tstat == 0u && l_is_op(c) && w65_is_success(c)) *tstat = 1u;
                *skip = hdr + k;
            }
        }
    }
}

template <uint32_t POS, uint32_t N>
W65INLINE void l_scan(uint32_t len, w65_reg_t reg, uint32_t* skip,
                      uint32_t* bstat, uint32_t* tstat) {
    if constexpr (POS < N) {
        l_iter<POS>(len, reg, skip, bstat, tstat);
        l_scan<POS + 1u, N>(len, reg >> 8, skip, bstat, tstat);
    }
}

extern "C" uint64_t cell_flip(uint32_t len, uint8_t b0, uint8_t b1, uint8_t b2,
                              uint8_t b3, uint8_t b4, uint8_t b5, uint8_t b6,
                              uint8_t b7, uint32_t discourage) {
    if (len > W65_MAX_SCAN_LEN) return W65_BAD_DOMAIN;
    const w65_reg_t reg = ((w65_reg_t)b0 << 0) | ((w65_reg_t)b1 << 8) |
                          ((w65_reg_t)b2 << 16) | ((w65_reg_t)b3 << 24) |
                          ((w65_reg_t)b4 << 32) | ((w65_reg_t)b5 << 40) |
                          ((w65_reg_t)b6 << 48) | ((w65_reg_t)b7 << 56);
    uint32_t skip = 0u;
    uint32_t bstat = 0u;
    uint32_t tstat = 0u;
    l_scan<0u, W65_MAX_SCAN_LEN>(len, reg, &skip, &bstat, &tstat);
    const uint32_t base = (bstat == 1u) ? 17u : (bstat == 2u) ? 16u : 66u;
    const uint32_t tap = (tstat == 1u) ? ((discourage != 0u) ? 36u : 0u)
                        : (tstat == 2u) ? 16u
                                        : 66u;
    return w65_pack(base, tap);
}

// Lean ordering: found -> success; then >1000 items -> STACK_SIZE; then any
// item >520 bytes -> PUSH_SIZE; then parse failure -> BAD_OPCODE; else tail.
extern "C" uint64_t cell_tail(uint32_t found, uint32_t decode_fail,
                                   uint32_t discourage, uint32_t too_many,
                                   uint32_t oversize) {
    if (found != 0u) return (discourage != 0u) ? 36u : 0u;
    if (too_many != 0u) return 8u;
    if (oversize != 0u) return 6u;
    if (decode_fail != 0u) return 16u;
    return 66u;
}
