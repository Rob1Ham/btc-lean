// C leg, cell checksig/C-L-checksig-nullfail-hashtype (SCR-110 / SCR-111).
//
// Bounded, line-cited slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/script/interpreter.cpp:331-369 (EvalChecksigPreTapscript; NULLFAIL 351-352)
//   src/script/interpreter.cpp:1069-1092 (OP_CHECKSIG / OP_CHECKSIGVERIFY)
//   src/script/interpreter.cpp:1876-1880 (EVAL_FALSE tail)
//   src/script/interpreter.cpp:1712-1713 (int nHashType = vchSig.back())
//   src/script/interpreter.cpp:162-167 (IsDefinedHashtypeSignature mask)
//   spec/core/Bitcoin/SigHash/Digest.lean:125-129 (htAcp, htBase)
#include "cell_common.h"
#include "cell_stack.h"

// EvalChecksigPreTapscript's tail (351-355) and the CHECKSIG handler.
// `fSuccess` is the ECDSA checker's verdict for the (sig, pk, sighash) triple;
// how that verdict is computed is the same-crypto seam of
// docs/DECISION-lax-ecdsa.md and is not modelled here.  Everything the row
// states is a function of (fSuccess, nullFail, sig_len, wire) alone.
W16INLINE uint64_t core_checksig_tail(uint32_t fSuccess, uint32_t nullFail,
                                      uint32_t sig_len, uint32_t wire) {
    W16Stack s; st_clear(s);
    s.len[0] = sig_len != 0 ? 1u : 0u;   // non-empty signature (one-byte stand-in)
    s.val[0] = 0;
    s.len[1] = 1; s.val[1] = 0;          // pubkey (one-byte stand-in)
    s.n = 2;
    // 351-352: `if (!fSuccess && (flags & NULLFAIL) && !vchSig.empty())`.
    if (!fSuccess && nullFail != 0 && sig_len != 0) {
        return st_fail(W16_SIG_NULLFAIL);
    }
    if (wire == 0xad) {                  // OP_CHECKSIGVERIFY
        if (fSuccess) s.n -= 2;
        else return st_fail(W16_CHECKSIGVERIFY);
    } else {                             // OP_CHECKSIG
        s.n -= 2;
        st_push_bool(s, fSuccess);
    }
    return st_finish(s);
}

// interpreter.cpp:1712-1713 with the hashtype classification of
// SigHash/Digest.lean:125-145.  Core reads the signature's final byte as the
// 32-bit nHashType; bit 0x80 is ANYONECANPAY, bits 0..4 are the base class,
// and bits 5..6 are ignored by both masks.  This is the decode/passthrough
// layer only; no digest serialization or hashing is modelled.
W16INLINE uint64_t core_hashtype(uint32_t sig_len, const W16Sig& s) {
    uint32_t ht = 0;
    // Domain of the rows is a non-empty signature of at most 80 bytes (the
    // shared word-packed buffer).  Outside that domain the cell totalizes to
    // 0 without reading, so both legs stay memory-safe.
    if (sig_len != 0 && sig_len <= 80) ht = sigbyte(s, sig_len - 1);
    const uint32_t acp = (ht & 0x80u) != 0;
    const uint32_t base5 = ht & 0x1fu;
    const uint32_t cls = base5 == 0x03u ? 2u : (base5 == 0x02u ? 1u : 0u);
    return (uint64_t)ht | ((uint64_t)acp << 8) | ((uint64_t)base5 << 9) |
           ((uint64_t)cls << 16);
}

extern "C" uint64_t cell_checksig_nullfail(uint32_t fSuccess,
                                           uint32_t nullFail, uint32_t sig_len,
                                           uint32_t wire) {
    return core_checksig_tail(fSuccess, nullFail, sig_len, wire);
}

extern "C" uint64_t cell_hashtype(uint32_t sig_len, uint64_t w0, uint64_t w1,
                                  uint64_t w2, uint64_t w3, uint64_t w4,
                                  uint64_t w5, uint64_t w6, uint64_t w7,
                                  uint64_t w8, uint64_t w9) {
    const W16Sig s = mksig(w0, w1, w2, w3, w4, w5, w6, w7, w8, w9);
    return core_hashtype(sig_len, s);
}
