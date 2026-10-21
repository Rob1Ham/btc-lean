// C leg, cell checksig/C-L-checksig-pubkey-encoding (SCR-112).
//
// A bounded, line-cited slice of Bitcoin Core
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.  This leg computes the
// pubkey-encoding predicate from the raw (header byte, length) pair instead
// of taking a `pk_valid` bit as an input.  That is the missing piece the
// wave64 report named for SCR-112 / F-DIV-004.
//
// Core sources:
//   src/pubkey.h:69-76              CPubKey::GetLen
//   src/pubkey.h:86-88              CPubKey::ValidSize
//   src/pubkey.h:98-105             CPubKey::Set (accept iff ValidSize)
//   src/pubkey.h:194-197            CPubKey::IsValid == size() > 0
//   src/script/interpreter.cpp:74-92    IsCompressedOrUncompressedPubKey
//   src/script/interpreter.cpp:94-99    IsCompressedPubKey
//   src/script/interpreter.cpp:213-238 CheckSignatureEncoding/CheckPubKeyEncoding
//   src/script/interpreter.cpp:331-356 EvalChecksigPreTapscript
//   src/script/interpreter.cpp:1069-1092 OP_CHECKSIG / OP_CHECKSIGVERIFY
//   src/script/interpreter.cpp:1701-1724 CheckECDSASignature
//   src/script/interpreter.cpp:1876-1880 EVAL_FALSE tail
//
// `pk_hdr` is the first pubkey byte, `pk_len` the vector length.  Both are
// exact inputs of every predicate used below; the remaining payload bytes are
// read by neither the encoding check nor `CPubKey::Set`.  EC verification is
// the abstract `crypto_ok` input (same-crypto premise).
#include "cell_harness.h"

// CPubKey::GetLen (pubkey.h:69-76): the length a header byte promises.
W65INLINE uint32_t core_get_len(uint8_t hdr) {
    if (hdr == 0x02u || hdr == 0x03u) return 33u;
    if (hdr == 0x04u || hdr == 0x06u || hdr == 0x07u) return 65u;
    return 0u;
}

// CPubKey::ValidSize (pubkey.h:86-88).  This is exactly the condition under
// which CPubKey::Set (pubkey.h:98-105) copies rather than Invalidate()s, and
// CPubKey::IsValid() is `size() > 0` (:194-197).
W65INLINE uint32_t core_valid_pubkey_size(uint8_t hdr, uint32_t len) {
    return (len > 0u && core_get_len(hdr) == len) ? 1u : 0u;
}

// IsCompressedOrUncompressedPubKey (interpreter.cpp:74-92).
W65INLINE uint32_t core_is_compressed_or_uncompressed(uint8_t hdr,
                                                      uint32_t len) {
    if (len < 33u) return 0u;
    if (hdr == 0x04u) return len == 65u;
    if (hdr == 0x02u || hdr == 0x03u) return len == 33u;
    return 0u;
}

// IsCompressedPubKey (interpreter.cpp:94-99).
W65INLINE uint32_t core_is_compressed(uint8_t hdr, uint32_t len) {
    if (len != 33u) return 0u;
    return (hdr == 0x02u || hdr == 0x03u) ? 1u : 0u;
}

// CheckPubKeyEncoding (interpreter.cpp:228-237) with the two policy bits as
// explicit inputs: SCRIPT_VERIFY_STRICTENC and
// SCRIPT_VERIFY_WITNESS_PUBKEYTYPE.  `sv` is 1 for SigVersion::WITNESS_V0 and
// 0 for SigVersion::BASE.  Returns 0 on pass, else the exact Core ordinal.
W65INLINE uint32_t core_check_pubkey_encoding(uint8_t hdr, uint32_t len,
                                              uint32_t strict_enc,
                                              uint32_t witness_pubkey_type,
                                              uint32_t sv) {
    if (strict_enc != 0u && !core_is_compressed_or_uncompressed(hdr, len))
        return EQUIV_ERR_PUBKEYTYPE;
    if (witness_pubkey_type != 0u && sv == 1u &&
        !core_is_compressed(hdr, len))
        return EQUIV_ERR_WITNESS_PUBKEYTYPE;
    return EQUIV_ERR_OK;
}

// CheckECDSASignature (interpreter.cpp:1701-1724).  The CPubKey gate comes
// first (1704-1706), then the empty-signature reject (1708-1709), then the
// abstract EC verification.  `sig_len` is the full signature length including
// the trailing hashtype byte.
W65INLINE uint32_t core_check_ecdsa_signature(uint8_t hdr, uint32_t len,
                                              uint32_t sig_len,
                                              uint32_t crypto_ok) {
    if (!core_valid_pubkey_size(hdr, len)) return 0u;
    if (sig_len == 0u) return 0u;
    return crypto_ok != 0u;
}

// EvalChecksigPreTapscript + OP_CHECKSIG (+ optional OP_NOT continuation).
// The script signature is assumed to pass CheckSignatureEncoding (empty, or a
// valid DER encoding with a defined hashtype for the active flags), so the
// only gate this slice adds is CheckPubKeyEncoding.  `tail_not` appends one
// OP_NOT to witness that execution continues after the pushed false.
W65INLINE uint64_t core_checksig_path(uint8_t hdr, uint32_t len,
                                      uint32_t strict_enc,
                                      uint32_t witness_pubkey_type,
                                      uint32_t sv, uint32_t sig_len,
                                      uint32_t crypto_ok, uint32_t null_fail,
                                      uint32_t tail_not) {
    const uint32_t enc = core_check_pubkey_encoding(
        hdr, len, strict_enc, witness_pubkey_type, sv);
    if (enc != EQUIV_ERR_OK) return w65_fail(enc);

    const uint32_t f_success =
        core_check_ecdsa_signature(hdr, len, sig_len, crypto_ok);
    if (f_success == 0u && null_fail != 0u && sig_len != 0u)
        return w65_fail(EQUIV_ERR_SIG_NULLFAIL);

    W65Stack s;
    w65_clear(s);
    w65_push_bool(s, f_success);
    if (tail_not != 0u) {
        const uint32_t was = w65_truth(s.len, s.val);
        s.len = 1u;
        s.val = was ? 0u : 1u;
    }
    return w65_finish(s);
}

// 1. The CheckPubKeyEncoding decision alone: 0 = pass, else the abort ordinal.
extern "C" uint64_t cell_pubkey_encoding(uint8_t hdr, uint32_t len,
                                         uint32_t strict_enc,
                                         uint32_t witness_pubkey_type,
                                         uint32_t sv) {
    const uint32_t enc = core_check_pubkey_encoding(
        hdr, len, strict_enc, witness_pubkey_type, sv);
    if (enc != EQUIV_ERR_OK) return w65_fail(enc);
    W65Stack s;
    w65_clear(s);
    return w65_pack(1, EQUIV_ERR_OK, s);
}

// 2. Block/default policy (`strict_enc = witness_pubkey_type = 0` at the call
//    site): invalid key -> checker false -> push false -> EVAL_FALSE.
extern "C" uint64_t cell_pubkey_encoding_checksig(
    uint8_t hdr, uint32_t len, uint32_t strict_enc,
    uint32_t witness_pubkey_type, uint32_t sv, uint32_t sig_len,
    uint32_t crypto_ok, uint32_t null_fail) {
    return core_checksig_path(hdr, len, strict_enc, witness_pubkey_type, sv,
                              sig_len, crypto_ok, null_fail, 0u);
}

// 3. The same CHECKSIG followed by OP_NOT: a false verdict now leaves a true
//    final stack, i.e. the surrounding script continues.
extern "C" uint64_t cell_pubkey_encoding_continue(
    uint8_t hdr, uint32_t len, uint32_t strict_enc,
    uint32_t witness_pubkey_type, uint32_t sv, uint32_t sig_len,
    uint32_t crypto_ok, uint32_t null_fail) {
    return core_checksig_path(hdr, len, strict_enc, witness_pubkey_type, sv,
                              sig_len, crypto_ok, null_fail, 1u);
}
