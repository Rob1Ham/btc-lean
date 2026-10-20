// C leg, cell checksig/C-L-checksig-invalid-pubkey (SCR-112).
//
// Bounded, line-cited slice of Bitcoin Core cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   src/script/interpreter.cpp:1704-1706 (CPubKey pubkey(vchPubKey);
//                                         if (!pubkey.IsValid()) return false;)
//   src/script/interpreter.cpp:331-369 (EvalChecksigPreTapscript; NULLFAIL)
//   src/script/interpreter.cpp:1069-1092 (OP_CHECKSIG / OP_CHECKSIGVERIFY)
//   src/script/interpreter.cpp:1876-1880 (EVAL_FALSE tail)
//
// `CPubKey::IsValid()` is structural (the key object parses only a 33-byte
// 02/03 or 65-byte 04/06/07 encoding), so for an INVALID key the checker
// returns false before any EC operation.  This cell takes the validity flag as
// an input and proves the invalid-key branch is independent of `crypto_ok`,
// the abstract EC-verification result (same-crypto premise,
// docs/DECISION-lax-ecdsa.md).
#include "cell_common.h"
#include "cell_stack.h"

// The checker as seen by EvalChecksigPreTapscript:
//   if (!pubkey.IsValid()) return false;      (1705-1706, before crypto)
//   return crypto_ok;                          (the EC seam)
W16INLINE uint32_t core_checker_result(uint32_t pk_valid, uint32_t crypto_ok) {
    if (!pk_valid) return 0;
    return crypto_ok != 0;
}

// CHECKSIG with a non-empty signature.  With NULLFAIL off the invalid-key
// false is pushed and the script continues; `tail_not` is the continuation
// witness for the following OP_NOT.
W16INLINE uint64_t core_checksig_invalid(uint32_t pk_valid, uint32_t crypto_ok,
                                         uint32_t sig_len, uint32_t nullFail,
                                         uint32_t tail_not) {
    W16Stack s; st_clear(s);
    s.len[0] = sig_len != 0 ? 1u : 0u;
    s.val[0] = 0;
    s.len[1] = 1; s.val[1] = 0;
    s.n = 2;
    const uint32_t fSuccess = core_checker_result(pk_valid, crypto_ok);
    if (!fSuccess && nullFail != 0 && sig_len != 0) {
        return st_fail(W16_SIG_NULLFAIL);
    }
    s.n -= 2;
    st_push_bool(s, fSuccess);
    if (tail_not != 0) {
        const uint32_t truth = st_truth(s.len[s.n - 1], s.val[s.n - 1]) ? 1u : 0u;
        s.len[s.n - 1] = 1;
        s.val[s.n - 1] = truth ? 0u : 1u;
    }
    return st_finish(s);
}

extern "C" uint64_t cell_invalid_pubkey(uint32_t pk_valid, uint32_t crypto_ok,
                                        uint32_t sig_len, uint32_t nullFail) {
    return core_checksig_invalid(pk_valid, crypto_ok, sig_len, nullFail, 0);
}

extern "C" uint64_t cell_invalid_pubkey_continue(uint32_t pk_valid,
                                                 uint32_t crypto_ok,
                                                 uint32_t sig_len,
                                                 uint32_t nullFail) {
    return core_checksig_invalid(pk_valid, crypto_ok, sig_len, nullFail, 1);
}
