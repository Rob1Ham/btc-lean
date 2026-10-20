// C leg, cell checksig/C-L-checksig-empty (SCR-108 / SCR-109).
//
// Bounded, line-cited slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/script/interpreter.cpp:211-216 (CheckSignatureEncoding: empty bypass)
//   src/script/interpreter.cpp:226-235 (CheckPubKeyEncoding)
//   src/script/interpreter.cpp:331-369 (EvalChecksigPreTapscript)
//   src/script/interpreter.cpp:1704-1720 (CheckECDSASignature: pubkey validity,
//                                       then `if (vchSig.empty()) return false`)
//   src/script/interpreter.cpp:1069-1092 (OP_CHECKSIG / OP_CHECKSIGVERIFY)
//   src/script/interpreter.cpp:1876-1880 (EVAL_FALSE tail)
//
// The empty-signature verdict is decided before any sighash or ECDSA work:
// CheckECDSASignature returns false when the pubkey is invalid, and returns
// false when vchSig is empty.  Hence the result is false for *every* value of
// the pubkey-validity predicate, and this cell needs no same-crypto premise.
#include "cell_common.h"
#include "cell_stack.h"

// CheckSignatureEncoding for the empty signature: `if (vchSig.size() == 0)
// return true;` -- no DER, LOW_S or STRICTENC gate is consulted.
W16INLINE uint32_t core_empty_sig_encoding(uint32_t n) {
    if (n == 0) return W16_OK;   // 213-216
    return W16_OK;               // the cell only carries the empty witness
}

// CheckPubKeyEncoding (226-235); structural, see cell C-L-checksig-policy.
W16INLINE uint32_t core_pubkey_encoding(uint32_t strictEnc,
                                        uint32_t witnessPubkeyType,
                                        uint32_t sv, uint32_t n,
                                        uint32_t pk0) {
    if (strictEnc != 0) {
        const uint32_t ok =
            (n >= 33 && ((pk0 == 0x04 && n == 65) ||
                         ((pk0 == 0x02 || pk0 == 0x03) && n == 33)));
        if (!ok) return W16_PUBKEYTYPE;
    }
    if (witnessPubkeyType != 0 && sv == 1) {
        const uint32_t ok = (n == 33 && (pk0 == 0x02 || pk0 == 0x03));
        if (!ok) return W16_WITNESS_PUBKEYTYPE;
    }
    return W16_OK;
}

// GenericTransactionSignatureChecker::CheckECDSASignature (1704-1720) for
// vchSigIn.empty():
//   CPubKey pubkey(vchPubKey);
//   if (!pubkey.IsValid()) return false;
//   std::vector<unsigned char> vchSig(vchSigIn);
//   if (vchSig.empty()) return false;   <-- 1709-1710, before sighash/ECDSA
// The pubkey-validity predicate is an unconstrained cell input: both of its
// branches return false here, so no ECDSA or pubkey-parse agreement is used.
W16INLINE uint32_t core_check_ecdsa_empty(uint32_t pk_valid, uint32_t sig_len) {
    if (!pk_valid) return 0;
    if (sig_len == 0) return 0;
    return 0;   // unreachable: this cell only carries sig_len == 0
}

// EvalChecksigPreTapscript (331-369) at flags-free encoding, empty signature.
// There is no FindAndDelete effect on an empty push and no NULLFAIL arm
// (`vchSig.size()` is 0), so the only possible error is the pubkey policy.
W16INLINE uint32_t core_eval_checksig_empty(uint32_t pk_valid,
                                            uint32_t strictEnc,
                                            uint32_t witnessPubkeyType,
                                            uint32_t sv, uint32_t pk_len,
                                            uint32_t pk0, uint32_t& succ) {
    const uint32_t sig_len = 0;
    (void)core_empty_sig_encoding(sig_len);          // 213-216, always ok
    const uint32_t e = core_pubkey_encoding(strictEnc, witnessPubkeyType, sv,
                                            pk_len, pk0);
    if (e != W16_OK) return e;
    succ = core_check_ecdsa_empty(pk_valid, sig_len);
    // NULLFAIL (351-352) cannot fire: `!fSuccess && NULLFAIL && vchSig.size()`
    // is false because vchSig is empty.
    return W16_OK;
}

// OP_CHECKSIG / OP_CHECKSIGVERIFY (1069-1092) with the fixed stack
// [<empty sig>, <pubkey>] (bottom -> top).
W16INLINE uint64_t core_checksig_empty(uint32_t pk_valid, uint32_t strictEnc,
                                       uint32_t witnessPubkeyType, uint32_t sv,
                                       uint32_t pk_len, uint32_t pk0,
                                       uint32_t wire, uint32_t tail_not) {
    W16Stack s; st_clear(s);
    s.len[0] = 0; s.val[0] = 0;             // vchSig, empty
    s.len[1] = 1; s.val[1] = pk0;           // vchPubKey (byte 0)
    s.n = 2;
    uint32_t succ = 1u;
    const uint32_t e = core_eval_checksig_empty(
        pk_valid, strictEnc, witnessPubkeyType, sv, pk_len, pk0, succ);
    if (e != W16_OK) return st_fail(e);
    // popstack x2; push fSuccess ? vchTrue : vchFalse
    s.n -= 2;
    st_push_bool(s, succ);
    if (wire == 0xad) {                      // OP_CHECKSIGVERIFY
        if (succ) s.n -= 1;
        else return st_fail(W16_CHECKSIGVERIFY);   // 1088
    } else if (tail_not != 0) {              // (continuation witness) OP_NOT
        const uint32_t v = s.val[s.n - 1];
        const uint32_t truth = st_truth(s.len[s.n - 1], v) ? 1u : 0u;
        s.val[s.n - 1] = truth ? 0u : 1u;
        s.len[s.n - 1] = 1;
    }
    return st_finish(s);
}

extern "C" uint64_t cell_checksig_empty(uint32_t pk_valid, uint32_t strictEnc,
                                        uint32_t witnessPubkeyType,
                                        uint32_t sv, uint32_t pk_len,
                                        uint32_t pk0) {
    return core_checksig_empty(pk_valid, strictEnc, witnessPubkeyType, sv,
                               pk_len, pk0, 0xac, 0);
}

extern "C" uint64_t cell_checksig_empty_continue(uint32_t pk_valid,
                                                 uint32_t strictEnc,
                                                 uint32_t witnessPubkeyType,
                                                 uint32_t sv, uint32_t pk_len,
                                                 uint32_t pk0) {
    // CHECKSIG leaves false on the stack; OP_NOT turns it into true, which
    // proves execution continued instead of aborting the script.
    return core_checksig_empty(pk_valid, strictEnc, witnessPubkeyType, sv,
                               pk_len, pk0, 0xac, 1);
}

extern "C" uint64_t cell_checksigverify_empty(uint32_t pk_valid,
                                              uint32_t strictEnc,
                                              uint32_t witnessPubkeyType,
                                              uint32_t sv, uint32_t pk_len,
                                              uint32_t pk0) {
    return core_checksig_empty(pk_valid, strictEnc, witnessPubkeyType, sv,
                               pk_len, pk0, 0xad, 0);
}
