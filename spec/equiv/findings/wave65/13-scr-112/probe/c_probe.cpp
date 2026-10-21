// Divergence probe, SCR-112 / F-DIV-004.
//
// C side: the exact Core predicate from the pin, identical to the C leg of
// cell checksig/C-L-checksig-pubkey-encoding.
//   src/pubkey.h:69-76,86-88,98-105,194-197
//   src/script/interpreter.cpp:74-99,228-237,331-356,1069-1092,1701-1724
#include "cell_harness.h"

W65INLINE uint32_t p_get_len(uint32_t hdr) {
    if (hdr == 0x02u || hdr == 0x03u) return 33u;
    if (hdr == 0x04u || hdr == 0x06u || hdr == 0x07u) return 65u;
    return 0u;
}

W65INLINE uint32_t p_core_valid_size(uint32_t hdr, uint32_t len) {
    return (len > 0u && p_get_len(hdr) == len) ? 1u : 0u;
}

W65INLINE uint32_t p_icu(uint32_t hdr, uint32_t len) {
    if (len < 33u) return 0u;
    if (hdr == 0x04u) return len == 65u;
    if (hdr == 0x02u || hdr == 0x03u) return len == 33u;
    return 0u;
}

W65INLINE uint32_t p_ic(uint32_t hdr, uint32_t len) {
    if (len != 33u) return 0u;
    return (hdr == 0x02u || hdr == 0x03u) ? 1u : 0u;
}

W65INLINE uint32_t p_check_encoding(uint32_t hdr, uint32_t len,
                                    uint32_t strict_enc,
                                    uint32_t witness_pubkey_type,
                                    uint32_t sv) {
    if (strict_enc != 0u && !p_icu(hdr, len)) return EQUIV_ERR_PUBKEYTYPE;
    if (witness_pubkey_type != 0u && sv == 1u && !p_ic(hdr, len))
        return EQUIV_ERR_WITNESS_PUBKEYTYPE;
    return EQUIV_ERR_OK;
}

extern "C" uint64_t probe_core(uint8_t hdr, uint32_t len, uint32_t strict_enc,
                               uint32_t witness_pubkey_type, uint32_t sv,
                               uint32_t sig_len, uint32_t crypto_ok,
                               uint32_t null_fail) {
    const uint32_t enc = p_check_encoding(hdr, len, strict_enc,
                                          witness_pubkey_type, sv);
    if (enc != EQUIV_ERR_OK) return w65_fail(enc);
    const uint32_t f = (p_core_valid_size(hdr, len) && sig_len != 0u &&
                        crypto_ok != 0u) ? 1u : 0u;
    if (f == 0u && null_fail != 0u && sig_len != 0u)
        return w65_fail(EQUIV_ERR_SIG_NULLFAIL);
    W65Stack s;
    w65_clear(s);
    w65_push_bool(s, f);
    return w65_finish(s);
}
