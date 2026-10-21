#ifndef W16_CHECK_COMMON_H
#define W16_CHECK_COMMON_H
// Wave-16 CHECKSIG policy/encoding cell harness (checksig family).
//
// Shared by the C leg (a line-cited slice of Bitcoin Core at the pin) and the
// L leg (a reviewed transliteration of the Lean model).  This header is cell
// harness, not engine code.
//
// Signature representation
// ------------------------
// A script signature is at most 73 bytes (BIP66) plus the sighash byte, and
// the legacy path can be handed anything the push opcodes allow.  For a
// bounded, loop-free leaf we pass the first 80 bytes as ten 64-bit little-
// endian words.  `sigbyte(w, i)` returns byte i exactly as `sig[i]` on a
// std::vector<unsigned char>: value (w[i/8] >> (8*(i%8))) & 0xff.  Both legs
// use this identical accessor; it is injective over 80 bytes and performs no
// bounds clamping, so every read must be guarded by the source's own length
// checks (the C slices are written in Core's check order for that reason).
//
// Error ordinals are copied from contract/error_kind.h (ABI v3), not invented.
#include <stdint.h>

#define W16INLINE static inline __attribute__((always_inline))

#define W16_OK                 0u
#define W16_EVAL_FALSE         2u
#define W16_OP_COUNT           7u
#define W16_CHECKSIGVERIFY    14u
#define W16_INVALID_STACK     18u
#define W16_SIG_HASHTYPE      23u
#define W16_SIG_DER           24u
#define W16_SIG_HIGH_S        27u
#define W16_PUBKEYTYPE        29u
#define W16_SIG_NULLFAIL      32u
#define W16_WITNESS_PUBKEYTYPE 44u

#define W16_MAX_OPS_PER_SCRIPT 201u

// Ten little-endian 64-bit words = 80 signature bytes.
struct W16Sig { uint64_t w[10]; };

// Byte i of the signature as seen by the sliced source (`sig[i]`).
W16INLINE uint32_t sigbyte(const W16Sig& s, uint32_t i) {
    return (uint32_t)((s.w[i >> 3] >> (8u * (i & 7u))) & 0xffu);
}

W16INLINE W16Sig mksig(uint64_t w0, uint64_t w1, uint64_t w2, uint64_t w3,
                       uint64_t w4, uint64_t w5, uint64_t w6, uint64_t w7,
                       uint64_t w8, uint64_t w9) {
    W16Sig s;
    s.w[0] = w0; s.w[1] = w1; s.w[2] = w2; s.w[3] = w3; s.w[4] = w4;
    s.w[5] = w5; s.w[6] = w6; s.w[7] = w7; s.w[8] = w8; s.w[9] = w9;
    return s;
}

// Packed observable for multi-field decisions: err (8) | verdict (1) | aux.
W16INLINE uint64_t w16_pack(uint32_t err, uint32_t verdict, uint32_t aux) {
    return (uint64_t)(err & 0xffu)
         | ((uint64_t)(verdict & 1u) << 8)
         | ((uint64_t)(aux & 0xffffu) << 16);
}

#endif
