// C leg, cell C-L-checksig-policy.
//
// Bounded, line-cited slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/script/interpreter.cpp:200-209 (IsDefinedHashtypeSignature)
//   src/script/interpreter.cpp:74-106  (IsCompressedOrUncompressedPubKey /
//                                       IsCompressedPubKey)
//   src/script/interpreter.cpp:226-235 (CheckPubKeyEncoding)
//   src/script/interpreter.cpp:183-198 (IsLowDERSignature: LOW_S arm)
//
// The signature's last byte is passed directly (Core reads
// `vchSig[vchSig.size() - 1]`); extracting "the last byte" is vector indexing,
// not part of the rule.  The S value is passed as four little-endian 64-bit
// limbs for the LOW_S comparison.
#include "cell_common.h"

// interpreter.cpp:200-209.
W16INLINE uint32_t core_is_defined_hashtype(uint32_t last, uint32_t n) {
    if (n == 0) return 0;
    // `vchSig[...]` is an unsigned char: the byte domain is [0,255].  Core's
    // `& ~SIGHASH_ANYONECANPAY` then assigns to `unsigned char nHashType`.
    const uint32_t b = last & 0xffu;
    const uint32_t nHashType = b & (~0x80u);
    if (nHashType < 1u || nHashType > 3u) return 0;
    return 1;
}

// interpreter.cpp:211-224, STRICTENC arm:
//   else if ((flags & STRICTENC) != 0 && !IsDefinedHashtypeSignature(vchSig))
//       return set_error(serror, SCRIPT_ERR_SIG_HASHTYPE);
W16INLINE uint32_t core_hashtype_gate(uint32_t strictEnc, uint32_t last,
                                      uint32_t n) {
    if (strictEnc != 0 && !core_is_defined_hashtype(last, n)) {
        return W16_SIG_HASHTYPE;
    }
    return W16_OK;
}

// interpreter.cpp:74-92 (IsCompressedOrUncompressedPubKey).
W16INLINE uint32_t core_is_compressed_or_uncompressed(uint32_t n,
                                                      uint32_t pk0) {
    if (n < 33) return 0;
    if (pk0 == 0x04) {
        if (n != 65) return 0;
    } else if (pk0 == 0x02 || pk0 == 0x03) {
        if (n != 33) return 0;
    } else {
        return 0;
    }
    return 1;
}

// interpreter.cpp:94-106 (IsCompressedPubKey).
W16INLINE uint32_t core_is_compressed(uint32_t n, uint32_t pk0) {
    if (n != 33) return 0;
    if (pk0 != 0x02 && pk0 != 0x03) return 0;
    return 1;
}

// interpreter.cpp:226-235 (CheckPubKeyEncoding).
W16INLINE uint32_t core_check_pubkey_encoding(uint32_t strictEnc,
                                              uint32_t witnessPubkeyType,
                                              uint32_t sv, uint32_t n,
                                              uint32_t pk0) {
    if (strictEnc != 0 && !core_is_compressed_or_uncompressed(n, pk0)) {
        return W16_PUBKEYTYPE;
    }
    // Only compressed keys are accepted in segwit (SigVersion::WITNESS_V0).
    if (witnessPubkeyType != 0 && sv == 1 &&
        !core_is_compressed(n, pk0)) {
        return W16_WITNESS_PUBKEYTYPE;
    }
    return W16_OK;
}

// secp256k1 scalar n / 2 (floor), little-endian 64-bit limbs.
// n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
static const uint64_t HALF_N0 = 0xdfe92f46681b20a0ull;
static const uint64_t HALF_N1 = 0x5d576e7357a4501dull;
static const uint64_t HALF_N2 = 0xffffffffffffffffull;
static const uint64_t HALF_N3 = 0x7fffffffffffffffull;

// 256-bit unsigned compare s <= floor(n/2), most-significant limb first.
W16INLINE uint32_t core_le_half_n(uint64_t s0, uint64_t s1, uint64_t s2,
                                  uint64_t s3) {
    if (s3 != HALF_N3) return s3 < HALF_N3;
    if (s2 != HALF_N2) return s2 < HALF_N2;
    if (s1 != HALF_N1) return s1 < HALF_N1;
    return s0 <= HALF_N0;
}

// interpreter.cpp:183-198 (IsLowDERSignature) after DER validity:
//   if (!CPubKey::CheckLowS(vchSigCopy)) return SCRIPT_ERR_SIG_HIGH_S;
// CPubKey::CheckLowS (pubkey.cpp:393-399) parses the DER part and returns
// `!secp256k1_ecdsa_signature_normalize(...)`, i.e. s <= n/2.  Domain of this
// cell: s is already the canonical scalar (s < n); the s >= n overflow window
// of the lax parser is excluded and recorded as not covered.
W16INLINE uint32_t core_low_s_gate(uint32_t lowS, uint64_t s0, uint64_t s1,
                                   uint64_t s2, uint64_t s3) {
    if (lowS == 0) return W16_OK;
    if (core_le_half_n(s0, s1, s2, s3)) return W16_OK;
    return W16_SIG_HIGH_S;
}

extern "C" uint64_t cell_hashtype_gate(uint32_t strictEnc, uint32_t last,
                                       uint32_t n) {
    return (uint64_t)core_hashtype_gate(strictEnc, last, n);
}

extern "C" uint64_t cell_is_defined_hashtype(uint32_t last, uint32_t n) {
    return (uint64_t)core_is_defined_hashtype(last, n);
}

extern "C" uint64_t cell_pubkey_encoding(uint32_t strictEnc,
                                         uint32_t witnessPubkeyType,
                                         uint32_t sv, uint32_t n,
                                         uint32_t pk0) {
    return (uint64_t)core_check_pubkey_encoding(strictEnc, witnessPubkeyType,
                                                sv, n, pk0);
}

extern "C" uint64_t cell_pubkey_predicates(uint32_t n, uint32_t pk0) {
    const uint32_t cu = core_is_compressed_or_uncompressed(n, pk0);
    const uint32_t c = core_is_compressed(n, pk0);
    return (uint64_t)(cu | (c << 1));
}

extern "C" uint64_t cell_lows_gate(uint32_t lowS, uint64_t s0, uint64_t s1,
                                   uint64_t s2, uint64_t s3) {
    return (uint64_t)core_low_s_gate(lowS, s0, s1, s2, s3);
}
