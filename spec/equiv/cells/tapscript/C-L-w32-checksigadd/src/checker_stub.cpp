// SAW-lane stub for the cell's single shared Schnorr seam.
//
// This is NOT a crypto implementation and proves nothing about secp256k1,
// BIP340 or SHA256.  It pins the abstract checker's verdict so that a
// concrete closed scenario can be verified against the cell's packed
// observable.  Each build defines exactly one verdict.
#include <cstdint>

#ifndef BTC_EQUIV_CHECKER_RESULT
#define BTC_EQUIV_CHECKER_RESULT 0
#endif

extern "C" uint8_t btc_equiv_check_schnorr(uint64_t sig, uint64_t pk,
                                           uint32_t sigversion) {
  (void)sig; (void)pk; (void)sigversion;
  return (uint8_t)BTC_EQUIV_CHECKER_RESULT;
}
