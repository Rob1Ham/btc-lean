// C leg, cell C-L-checksig-der.
//
// Bounded, line-cited slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66,
// src/script/interpreter.cpp:
//   IsValidSignatureEncoding   (118-181)
//   CheckSignatureEncoding     (211-224) -- DERSIG arm only
//
// The only deviation is the signature representation: the pinned code indexes a
// std::vector<unsigned char>; here the first 80 bytes are ten 64-bit words and
// sigbyte() is the same byte read.  All length guards are kept in the source's
// order, so every read is in range exactly when Core's read is.
#include "cell_common.h"

// interpreter.cpp:118-181 (BIP66 strict DER; input includes the sighash byte).
W16INLINE uint32_t core_is_valid_signature_encoding(uint32_t n, const W16Sig& s) {
    // Minimum and maximum size constraints.
    if (n < 9) return 0;
    if (n > 73) return 0;

    // A signature is of type 0x30 (compound).
    if (sigbyte(s, 0) != 0x30) return 0;

    // Make sure the length covers the entire signature.
    if (sigbyte(s, 1) != n - 3) return 0;

    // Extract the length of the R element.
    const uint32_t lenR = sigbyte(s, 3);

    // Make sure the length of the S element is still inside the signature.
    if (5 + lenR >= n) return 0;

    // Extract the length of the S element.
    const uint32_t lenS = sigbyte(s, 5 + lenR);

    // Verify that the length of the signature matches the sum of the lengths.
    if (lenR + lenS + 7 != n) return 0;

    // Check whether the R element is an integer.
    if (sigbyte(s, 2) != 0x02) return 0;

    // Zero-length integers are not allowed for R.
    if (lenR == 0) return 0;

    // Negative numbers are not allowed for R.
    if (sigbyte(s, 4) & 0x80) return 0;

    // Null bytes at the start of R are not allowed, unless R would otherwise
    // be interpreted as a negative number.
    if (lenR > 1 && sigbyte(s, 4) == 0x00 && !(sigbyte(s, 5) & 0x80)) return 0;

    // Check whether the S element is an integer.
    if (sigbyte(s, lenR + 4) != 0x02) return 0;

    // Zero-length integers are not allowed for S.
    if (lenS == 0) return 0;

    // Negative numbers are not allowed for S.
    if (sigbyte(s, lenR + 6) & 0x80) return 0;

    // Null bytes at the start of S are not allowed, unless S would otherwise be
    // interpreted as a negative number.
    if (lenS > 1 && sigbyte(s, lenR + 6) == 0x00 && !(sigbyte(s, lenR + 7) & 0x80)) return 0;

    return 1;
}

// interpreter.cpp:211-224, the strict-DER gate:
//   if (vchSig.size() == 0) return true;                 <-- empty bypass
//   if ((flags & (DERSIG|LOW_S|STRICTENC)) != 0 && !IsValidSignatureEncoding)
//       return set_error(serror, SCRIPT_ERR_SIG_DER);
// The LOW_S/STRICTENC arms are separate rows and are not modelled here; this
// function returns the DERSIG arm's error (24) or 0 (accepted / no DER flag).
W16INLINE uint32_t core_der_gate(uint32_t dersig, uint32_t lowS,
                                 uint32_t strictEnc, uint32_t n,
                                 const W16Sig& s) {
    if (n == 0) return W16_OK;
    if ((dersig | lowS | strictEnc) != 0 &&
        !core_is_valid_signature_encoding(n, s)) {
        return W16_SIG_DER;
    }
    return W16_OK;
}

extern "C" uint64_t cell_der(uint32_t n, uint64_t w0, uint64_t w1, uint64_t w2,
                             uint64_t w3, uint64_t w4, uint64_t w5,
                             uint64_t w6, uint64_t w7, uint64_t w8,
                             uint64_t w9) {
    const W16Sig s = mksig(w0, w1, w2, w3, w4, w5, w6, w7, w8, w9);
    return (uint64_t)core_is_valid_signature_encoding(n, s);
}

extern "C" uint64_t cell_der_gate(uint32_t dersig, uint32_t lowS,
                                  uint32_t strictEnc, uint32_t n, uint64_t w0,
                                  uint64_t w1, uint64_t w2, uint64_t w3,
                                  uint64_t w4, uint64_t w5, uint64_t w6,
                                  uint64_t w7, uint64_t w8, uint64_t w9) {
    const W16Sig s = mksig(w0, w1, w2, w3, w4, w5, w6, w7, w8, w9);
    return (uint64_t)core_der_gate(dersig, lowS, strictEnc, n, s);
}
