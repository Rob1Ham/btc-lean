#include <cstdint>

// Shared same-crypto Schnorr stub for the SAW lane.  BTC_EQUIV_SCHNORR_RESULT
// encodes (ok bit) | (error ordinal << 1), matching checker_abi.h.
#ifndef BTC_EQUIV_SCHNORR_RESULT
#define BTC_EQUIV_SCHNORR_RESULT 1u  // success
#endif

extern "C" uint32_t btc_equiv_check_schnorr(uint32_t, uint32_t, uint32_t,
                                            uint32_t) {
  return (uint32_t)BTC_EQUIV_SCHNORR_RESULT;
}
