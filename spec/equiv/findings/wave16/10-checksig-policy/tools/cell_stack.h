#ifndef W16_CELL_STACK_H
#define W16_CELL_STACK_H
// Bounded stack + packed observable for the wave-16 CHECKSIG handler cells.
//
// ABI v2 observable (contract/ABI.md): result (2) | error ordinal (6) |
// depth (3) | up to three top elements (len 2 bits, value 8 bits each).
// On failure only (result, error_kind) is observable, so the failure pack
// carries an empty stack -- Core mutates its stack before returning false and
// the Lean `Except` error carries no state.  Layout matches
// cells/_tools/e3/cellsig/e3_common.h so results are directly comparable.
#include "cell_common.h"

struct W16Stack { uint32_t n; uint32_t len[4]; uint32_t val[4]; };

W16INLINE void st_clear(W16Stack& s) {
    s.n = 0;
    for (int i = 0; i < 4; ++i) { s.len[i] = 0; s.val[i] = 0; }
}

// Push vchTrue = {1} / vchFalse = {} (Core's static valtype constants).
W16INLINE void st_push_bool(W16Stack& s, uint32_t v) {
    s.len[s.n] = v ? 1u : 0u;
    s.val[s.n] = v ? 1u : 0u;
    s.n += 1;
}

W16INLINE bool st_truth(uint32_t len, uint32_t val) {
    if (len == 0) return false;
    if (len == 1) return !(val == 0 || val == 0x80);
    if (val != 0) return true;
    return !((val >> 8) == 0 || (val >> 8) == 0x80);
}

W16INLINE uint64_t st_pack(uint32_t res, uint32_t err, const W16Stack& s) {
    uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2)
               | ((uint64_t)(s.n & 7u) << 8);
    if (s.n > 0) { r |= (uint64_t)(s.len[0] & 3u) << 11; r |= (uint64_t)(s.val[0] & 0xffu) << 13; }
    if (s.n > 1) { r |= (uint64_t)(s.len[1] & 3u) << 21; r |= (uint64_t)(s.val[1] & 0xffu) << 23; }
    if (s.n > 2) { r |= (uint64_t)(s.len[2] & 3u) << 31; r |= (uint64_t)(s.val[2] & 0xffu) << 33; }
    return r;
}

W16INLINE uint64_t st_fail(uint32_t err) {
    W16Stack s; st_clear(s);
    return st_pack(0, err, s);
}

// VerifyScript's EVAL_FALSE tail (interpreter.cpp:1876-1880) on the cell's
// bounded stack.
W16INLINE uint64_t st_finish(const W16Stack& s) {
    if (s.n == 0) return st_pack(0, W16_EVAL_FALSE, s);
    if (!st_truth(s.len[s.n - 1], s.val[s.n - 1])) {
        return st_pack(0, W16_EVAL_FALSE, s);
    }
    return st_pack(1, 0, s);
}

#endif
