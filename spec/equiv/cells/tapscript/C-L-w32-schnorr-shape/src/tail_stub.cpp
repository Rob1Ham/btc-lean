// SAW-lane stub for the cell's single shared Schnorr tail seam
// (SignatureHashSchnorr + VerifySchnorr, interpreter.cpp:1745-1749).
//
// This is NOT a crypto or sighash implementation and proves nothing about
// secp256k1, BIP340, BIP341 or SHA256.  It pins the abstract tail's verdict
// so that a concrete closed scenario can be verified against the cell's
// packed observable.  Each build defines exactly one verdict:
//   0  -> tail would verify (the shape checks passed)
//   47 -> tail would reject (SCRIPT_ERR_SCHNORR_SIG)
#include <cstdint>

#ifndef BTC_EQUIV_TAIL_RESULT
#define BTC_EQUIV_TAIL_RESULT 0
#endif

extern "C" uint32_t btc_equiv_schnorr_tail(uint64_t body, uint32_t hashtype,
                                           uint32_t sig_len,
                                           uint32_t sigversion) {
  (void)body; (void)hashtype; (void)sig_len; (void)sigversion;
  return (uint32_t)BTC_EQUIV_TAIL_RESULT;
}
