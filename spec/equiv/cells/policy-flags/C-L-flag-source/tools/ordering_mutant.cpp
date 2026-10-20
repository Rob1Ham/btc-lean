// Negative control for policy-flags/C-L-flag-source: the same excerpt with the
// exception replacement applied AFTER the four buried ORs instead of before
// (validation.cpp:2259-2282).  Alive2 must reject it against the L module.
#include "policy_common.h"
using namespace policy_cell;

static inline __attribute__((always_inline))
uint64_t mutant_flag_source(uint64_t exceptionKind, uint64_t height) {
    const uint64_t h = height % 0x100000000ULL;
    uint64_t flags = P2SH | WITNESS | TAPROOT;
    if (BIP66_HEIGHT  <= h) flags |= DERSIG;
    if (BIP65_HEIGHT  <= h) flags |= CLTV;
    if (CSV_HEIGHT    <= h) flags |= CSV;
    if (SEGWIT_HEIGHT <= h) flags |= NULLDUMMY;
    // WRONG ORDER: replacement must happen first; here it overwrites the ORs.
    if (exceptionKind == EXC_BIP16) flags = 0;
    else if (exceptionKind == EXC_TAPROOT) flags = P2SH | WITNESS;
    return flags;
}

extern "C" uint64_t cell_flag_source(uint64_t exceptionKind, uint64_t height) {
    return mutant_flag_source(exceptionKind, height);
}
