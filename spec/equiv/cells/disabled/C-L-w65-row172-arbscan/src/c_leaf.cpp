// C leg: line-cited source-excerpt slice of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slices:
//   script.cpp:311-362          GetScriptOp (GetOp) decode / truncation rule
//   script.cpp:365-371          IsOpSuccess
//   interpreter.cpp:472-483     legacy disabled-opcode table (inside EvalScript)
//   interpreter.cpp:1846-1862   TAPSCRIPT OP_SUCCESSx pre-scan (ExecuteWitnessScript)
//   interpreter.cpp:1864-1871   initial stack-size / 520-byte item checks
//
// `cell_flip` is the row's bounded context pair: for every tapscript of length
// <= 8 and every byte value, it reports
//
//   base = 17 (a decoded opcode is legacy-disabled)
//        | 16 (GetOp truncation before any such opcode)
//        | 66 (fully decoded, no disabled opcode -> EvalScript would run)
//   tap  =  0 / 36 (an OP_SUCCESSx opcode is decoded; 36 when `disc != 0`,
//                   the cell's normalised form of the
//                   SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS policy bit)
//        | 16 (GetOp truncation before any OP_SUCCESSx -> Core returns
//              BAD_OPCODE from the pre-scan)
//        | 66 (fully decoded, no OP_SUCCESSx -> EvalScript would run)
//
// packed as (base << 32) | tap.  Within this cell's length bound there can be
// no push payload above 520 bytes and no 201-op preemption, so the two
// classifications are exact for the cited Core lines.
//
// The decode walk is the byte-granular shift-register encoding: eight fixed
// template iterations, one script byte each, push payload bytes carried in
// `skip`.  This is NOT assumed equivalent to Core's variable-`nx` loop: the
// SAW proof checks both legs against the independent jump-form Cryptol spec in
// src/cell.cry, and `cell_flip`'s equivalence with the L leg is checked by
// Alive2 in both directions.
//
// `cell_tail` is Core's post-scan ordering (interpreter.cpp:1846-1871):
// a GetOp failure returns BAD_OPCODE *before* the stack-size and 520-byte item
// checks.  It deliberately differs from the Lean transcription's ordering
// (`cell_tail_lean` in l_leaf.cpp); this cell records that divergence as an
// expected Alive2 counterexample instead of claiming the contexts equivalent.
#include "common.h"

// One decode step.  POS is a compile-time byte index; `reg` holds the script
// bytes from POS onward.  Status: 0 scanning, 1 classified (disabled /
// success), 2 decode failure.
template <uint32_t POS>
W65INLINE void c_iter(uint32_t len, w65_reg_t reg, uint32_t* skip,
                      uint32_t* bstat, uint32_t* tstat) {
    const uint32_t c = (uint32_t)(reg & 0xffu);
    if ((*bstat == 0u || *tstat == 0u) && POS < len) {
        if (*skip != 0u) {
            *skip -= 1u;
        } else {
            // Branchless PUSHDATA header decode: 0x4c/0x4d/0x4e are
            // (1,1),(1,2),(1,4) bytes of length field.  Avoiding the
            // `if (c == 0x4c) ... else if` chain keeps clang from emitting a
            // switch table, so the extracted module is self-contained.
            uint32_t k = 0u;
            uint32_t hdr = 0u;
            if (c <= 0x4bu) {
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
            // GetScriptOp fails when the header or payload runs past `end`.
            // uint64 makes the sum exact for every reachable term (k < 2^32).
            if ((uint64_t)POS + 1u + (uint64_t)hdr + (uint64_t)k >
                (uint64_t)len) {
                if (*bstat == 0u) *bstat = 2u;
                if (*tstat == 0u) *tstat = 2u;
            } else {
                // Core tests the raw decoded opcode byte on both legs:
                // EvalScript's disabled table and IsOpSuccess(opcode).  A push
                // header/payload can never be disabled/success because both
                // sets start at 0x50 and no push-shaped wire is in them.
                if (*bstat == 0u && w65_is_disabled(c)) *bstat = 1u;
                if (*tstat == 0u && w65_is_success(c)) *tstat = 1u;
                *skip = hdr + k;
            }
        }
    }
}

template <uint32_t POS, uint32_t N>
W65INLINE void c_scan(uint32_t len, w65_reg_t reg, uint32_t* skip,
                      uint32_t* bstat, uint32_t* tstat) {
    if constexpr (POS < N) {
        c_iter<POS>(len, reg, skip, bstat, tstat);
        c_scan<POS + 1u, N>(len, reg >> 8, skip, bstat, tstat);
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
    c_scan<0u, W65_MAX_SCAN_LEN>(len, reg, &skip, &bstat, &tstat);
    const uint32_t base = (bstat == 1u) ? 17u : (bstat == 2u) ? 16u : 66u;
    const uint32_t tap = (tstat == 1u) ? ((discourage != 0u) ? 36u : 0u)
                        : (tstat == 2u) ? 16u
                                        : 66u;
    return w65_pack(base, tap);
}

// Core ordering after the pre-scan: found -> success; GetOp failure -> 16;
// then >1000 initial items -> 8; then any item >520 bytes -> 6; else the
// EvalScript/cleanstack tail (abstracted as 66).
extern "C" uint64_t cell_tail(uint32_t found, uint32_t decode_fail,
                                   uint32_t discourage, uint32_t too_many,
                                   uint32_t oversize) {
    if (found != 0u) return (discourage != 0u) ? 36u : 0u;
    if (decode_fail != 0u) return 16u;
    if (too_many != 0u) return 8u;
    if (oversize != 0u) return 6u;
    return 66u;
}
