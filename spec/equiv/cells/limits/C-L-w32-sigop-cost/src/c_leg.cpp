// C leg — source-excerpt slice of Bitcoin Core at pin cce32b168.
//
//   src/consensus/tx_verify.cpp:149-168  GetTransactionSigOpCost
//   src/consensus/tx_verify.cpp:120-130  GetLegacySigOpCount (caller)
//   src/consensus/tx_verify.cpp:132-147  GetP2SHSigOpCount (caller)
//   src/script/interpreter.cpp:2160-2182 CountWitnessSigOps (caller)
//
// SCR-037: cost in weight units.  Legacy and P2SH sigops are charged
// WITNESS_SCALE_FACTOR = 4 each; witness sigops are charged 1.  Coinbase
// transactions return the legacy term only.  The P2SH term is present only
// when SCRIPT_VERIFY_P2SH is set.
//
// The three counts are inputs: they are the outputs of the legacy/P2SH/witness
// cells (C-L-w32-p2sh-scriptsig, C-L-w32-witness-sigops, and the legacy
// counter).  This cell proves the aggregation arithmetic and its gates.
#include "limits_common.h"

namespace {

static const int64_t WITNESS_SCALE_FACTOR = 4;

CLINLINE int64_t core_sigop_cost(uint32_t legacy, uint32_t p2sh,
                                 uint32_t witness, uint32_t coinbase,
                                 uint32_t p2sh_flag) {
  int64_t n_sigops = static_cast<int64_t>(legacy) * WITNESS_SCALE_FACTOR;

  if (coinbase) return n_sigops;

  if (p2sh_flag) {
    n_sigops += static_cast<int64_t>(p2sh) * WITNESS_SCALE_FACTOR;
  }

  n_sigops += static_cast<int64_t>(witness);
  return n_sigops;
}

}  // namespace

extern "C" int64_t cell_sigop_cost(uint32_t legacy, uint32_t p2sh,
                                   uint32_t witness, uint32_t coinbase,
                                   uint32_t p2sh_flag) {
  return core_sigop_cost(legacy, p2sh, witness, coinbase, p2sh_flag);
}
