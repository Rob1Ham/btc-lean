#include "limits_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   consensus/tx_verify.cpp:149-168  GetTransactionSigOpCost
//       int64_t nSigOps = GetLegacySigOpCount(tx) * WITNESS_SCALE_FACTOR;
//       if (tx.IsCoinBase()) return nSigOps;
//       if (flags & SCRIPT_VERIFY_P2SH)
//           nSigOps += GetP2SHSigOpCount(tx, inputs) * WITNESS_SCALE_FACTOR;
//       for each input: nSigOps += CountWitnessSigOps(...);   // ×1
//       return nSigOps;
//
//   consensus/consensus.h:21  WITNESS_SCALE_FACTOR = 4
//   consensus/consensus.h:17  MAX_BLOCK_SIGOPS_COST = 80,000
//   policy/policy.h:44        MAX_STANDARD_TX_SIGOPS_COST = MAX_BLOCK_SIGOPS_COST/5
//   validation.cpp:2566-2569  if (nSigOpsCost > MAX_BLOCK_SIGOPS_COST) bad-blk-sigops
//   validation.cpp:939-941    if (nSigOpsCost > MAX_STANDARD_TX_SIGOPS_COST)
//                                 bad-txns-too-many-sigops   (policy)
//
// The component counts are unsigned int / size_t in Core; 32-bit symbols
// here (the real counters are bounded far below 2^32).  The cost is
// accumulated in int64 exactly like Core's local.  The per-input static
// counts and witness counts are other rows (SCR-032..036); this cell is the
// accounting aggregation and the two caps.

constexpr int64_t WITNESS_SCALE_FACTOR = 4;
constexpr int64_t MAX_BLOCK_SIGOPS_COST = 80000;
constexpr int64_t MAX_STANDARD_TX_SIGOPS_COST = MAX_BLOCK_SIGOPS_COST / 5;

LIMITS_INLINE int64_t c_tx_sigop_cost(uint32_t legacy, uint32_t p2sh, uint32_t witness,
                                      uint8_t coinbase, uint8_t p2sh_flag, uint8_t witness_flag) {
    int64_t nSigOps = (int64_t)legacy * WITNESS_SCALE_FACTOR;       // :151
    if (coinbase) return nSigOps;                                    // :153-154
    if (p2sh_flag) nSigOps += (int64_t)p2sh * WITNESS_SCALE_FACTOR;  // :156-158
    if (witness_flag) nSigOps += (int64_t)witness;                   // :160-166 (×1)
    return nSigOps;
}

// ConnectBlock's cumulative gate: 1 = within budget, 0 = bad-blk-sigops.
LIMITS_INLINE uint32_t c_block_sigop_gate(int64_t cumulative) {
    return (cumulative > MAX_BLOCK_SIGOPS_COST) ? 0u : 1u;           // validation.cpp:2566-2569
}

// Mempool standardness gate: 1 = accepted, 0 = bad-txns-too-many-sigops.
LIMITS_INLINE uint32_t c_tx_sigop_policy(int64_t cost) {
    return (cost > MAX_STANDARD_TX_SIGOPS_COST) ? 0u : 1u;           // validation.cpp:939-941
}

extern "C" int64_t cell_tx_sigop_cost(uint32_t legacy, uint32_t p2sh, uint32_t witness,
                                      uint8_t coinbase, uint8_t p2sh_flag, uint8_t witness_flag) {
    return c_tx_sigop_cost(legacy, p2sh, witness, coinbase, p2sh_flag, witness_flag);
}

extern "C" uint32_t cell_block_sigop_gate(int64_t cumulative) {
    return c_block_sigop_gate(cumulative);
}

extern "C" uint32_t cell_tx_sigop_policy(int64_t cost) {
    return c_tx_sigop_policy(cost);
}
