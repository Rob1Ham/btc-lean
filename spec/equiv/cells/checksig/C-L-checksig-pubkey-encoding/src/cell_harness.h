#ifndef W65_CELL_HARNESS_H
#define W65_CELL_HARNESS_H
// Cell harness for checksig/C-L-checksig-pubkey-encoding (SCR-112).
//
// The observable is the contract ABI v2 packed stack used by the wave-16/32
// CHECKSIG cells: result (2) | error ordinal (6) | depth (3) | top len (2) |
// top value (8).  Error ordinals come from contract/error_kind.h, which is
// compiled into both legs; no ordinal is invented here.
//
// This cell has no loops and no arrays: the only stack shape it needs is the
// one-element result of OP_CHECKSIG (optionally followed by OP_NOT).  The
// pubkey payload bytes are deliberately not an input: Core's
// CPubKey::ValidSize / Set and CheckPubKeyEncoding read only the first byte
// and the length, and the EC verification step is abstracted (same-crypto
// premise, docs/DECISION-lax-ecdsa.md).  The cell's spec.md states this as a
// precondition.
#include <stdint.h>

#include "contract/error_kind.h"

#define W65INLINE static inline __attribute__((always_inline))

struct W65Stack {
    uint32_t n;
    uint32_t len;
    uint32_t val;
};

W65INLINE void w65_clear(W65Stack& s) {
    s.n = 0;
    s.len = 0;
    s.val = 0;
}

// stack.push_back(fSuccess ? vchTrue : vchFalse); vchTrue = {1}, vchFalse = {}.
W65INLINE void w65_push_bool(W65Stack& s, uint32_t v) {
    s.n = 1;
    s.len = v ? 1u : 0u;
    s.val = v ? 1u : 0u;
}

// CastToBool (interpreter.cpp:171-190) on the pushed bool only.
W65INLINE uint32_t w65_truth(uint32_t len, uint32_t val) {
    if (len == 0) return 0;
    if (len == 1) return !(val == 0u || val == 0x80u);
    if (val != 0) return 1;
    return !((val >> 8) == 0u || (val >> 8) == 0x80u);
}

W65INLINE uint64_t w65_pack(uint32_t res, uint32_t err, const W65Stack& s) {
    uint64_t r = (uint64_t)(res & 3u) | ((uint64_t)(err & 0x3fu) << 2)
               | ((uint64_t)(s.n & 7u) << 8);
    if (s.n > 0) {
        r |= (uint64_t)(s.len & 3u) << 11;
        r |= (uint64_t)(s.val & 0xffu) << 13;
    }
    return r;
}

W65INLINE uint64_t w65_fail(uint32_t err) {
    W65Stack s;
    w65_clear(s);
    return w65_pack(0, err, s);
}

// VerifyScript's EVAL_FALSE tail (interpreter.cpp:1876-1880).  The stack is
// retained in the observable, matching the existing invalid-pubkey cell.
W65INLINE uint64_t w65_finish(const W65Stack& s) {
    if (s.n == 0) return w65_pack(0, EQUIV_ERR_EVAL_FALSE, s);
    if (!w65_truth(s.len, s.val)) return w65_pack(0, EQUIV_ERR_EVAL_FALSE, s);
    return w65_pack(1, EQUIV_ERR_OK, s);
}

#endif
