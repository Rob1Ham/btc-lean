// Shared checker stub for the SAW lane.
//
// The same object is linked into BOTH the C and L modules for a given
// scenario, so both legs execute the same concretely-pinned checker return
// (0 or 1).  This is the SAW-side counterpart of the external declaration
// used by Alive2; it makes no crypto claim.  BTC_EQUIV_CHECKER_RESULT is set
// by build_cell.sh.
#include <cstdint>
#include "checker_abi.h"

#ifndef BTC_EQUIV_CHECKER_RESULT
#error "define BTC_EQUIV_CHECKER_RESULT=0 or 1"
#endif

extern "C" uint8_t btc_equiv_check_sig(uint32_t sig, uint32_t pk,
                                       uint32_t script_code, uint32_t sigversion) {
  (void)sig; (void)pk; (void)script_code; (void)sigversion;
  return (uint8_t)BTC_EQUIV_CHECKER_RESULT;
}
