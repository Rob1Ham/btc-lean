#include "limits_common.h"

// L leg: reviewed transliteration of the btc-lean twin's sigop-cost model.
//
//   spec/core/Bitcoin/Block/Sigops.lean:308-317  txSigOpCostWithFlags
//       WITNESS_SCALE_FACTOR * (legacySigOpCountTx tx
//           + if flags.p2sh then p2shSigOpCount u tx else 0)
//       + if flags.witness then witnessSigOps u tx else 0
//
//   spec/core/Bitcoin/Block/Sigops.lean:330-335  txSigOpCostWithFlags_coinbase
//       a coinbase pays 4 * legacySigOpCountTx tx (the P2SH and witness
//       counters are zero: p2shSigOpCount_coinbase_zero /
//       witnessSigOps_coinbase_zero).  Core's early `return nSigOps` is the
//       same statement.
//
//   spec/core/Bitcoin/Interpreter/Rules.lean:337-346
//       MAX_BLOCK_SIGOPS_COST = 80000; blockSigOpsCostOk cost = cost <= 80000
//       MAX_STANDARD_TX_SIGOPS_COST = 16000
//
// The L leg applies the model's caller-supplied zeroing for coinbase; that is
// the Lean composition, not an extra rule.

constexpr int64_t L_WITNESS_SCALE_FACTOR = 4;
constexpr int64_t L_MAX_BLOCK_SIGOPS_COST = 80000;
constexpr int64_t L_MAX_STANDARD_TX_SIGOPS_COST = 16000;

LIMITS_INLINE int64_t l_tx_sigop_cost(uint32_t legacy, uint32_t p2sh, uint32_t witness,
                                      uint8_t coinbase, uint8_t p2sh_flag, uint8_t witness_flag) {
    const uint32_t p2shTerm = (coinbase || (p2sh_flag == 0)) ? 0u : p2sh;
    const uint32_t witTerm = coinbase ? 0u : (witness_flag != 0 ? witness : 0u);
    return L_WITNESS_SCALE_FACTOR * ((int64_t)legacy + (int64_t)p2shTerm) + (int64_t)witTerm;
}

LIMITS_INLINE uint32_t l_block_sigop_gate(int64_t cumulative) {
    return (cumulative <= L_MAX_BLOCK_SIGOPS_COST) ? 1u : 0u;
}

LIMITS_INLINE uint32_t l_tx_sigop_policy(int64_t cost) {
    return (cost <= L_MAX_STANDARD_TX_SIGOPS_COST) ? 1u : 0u;
}

extern "C" int64_t cell_tx_sigop_cost(uint32_t legacy, uint32_t p2sh, uint32_t witness,
                                      uint8_t coinbase, uint8_t p2sh_flag, uint8_t witness_flag) {
    return l_tx_sigop_cost(legacy, p2sh, witness, coinbase, p2sh_flag, witness_flag);
}

extern "C" uint32_t cell_block_sigop_gate(int64_t cumulative) {
    return l_block_sigop_gate(cumulative);
}

extern "C" uint32_t cell_tx_sigop_policy(int64_t cost) {
    return l_tx_sigop_policy(cost);
}
