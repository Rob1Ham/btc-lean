---
# Cell limits/C-L-sigop-cost-arith
cell: C-L-sigop-cost-arith
family: limits
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (three symbolic functions, both directions)
precondition: |
  - The cell is the sigop-cost aggregation and the two caps, not the
    per-input counters (SCR-032..036) and not tx/block decoding.
  - `legacy`, `p2sh`, `witness` are the component counts Core computes:
    GetLegacySigOpCount / GetP2SHSigOpCount return unsigned int, and
    CountWitnessSigOps returns size_t. They are 32-bit symbols here; the real
    counters are far below 2^32, so this is the full reachable domain.
  - `coinbase`, `p2sh_flag`, `witness_flag` are Core booleans (0/1 in the
    domain). P2SH gating is `flags & SCRIPT_VERIFY_P2SH`; witness gating is
    the WITNESS flag check inside CountWitnessSigOps (interpreter.cpp:2160).
  - The block gate takes the cumulative `nSigOpsCost` of ConnectBlock, which
    is a non-negative int64; the SAW precondition is 0 <= c < 2^63 (the
    int64 domain with no signed-overflow corner). The policy gate takes the
    per-tx cost in the same domain.
  - The cost is accumulated in int64, exactly like Core's local; with 32-bit
    component counts the maximum is below 2^35, so no overflow is reachable.
postcondition: |
  - `cell_tx_sigop_cost`:
      n = 4 * legacy
      coinbase                        -> n
      else n += 4 * p2sh (if p2sh_flag)
           n += witness   (if witness_flag, weight 1)
  - `cell_block_sigop_gate`: 1 iff cumulative <= 80,000; 0 above
    (Core rejects with "bad-blk-sigops" when the running cost is > 80,000).
  - `cell_tx_sigop_policy`: 1 iff cost <= 16,000; 0 above
    (Core rejects with "bad-txns-too-many-sigops"; policy, consensus=false).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-037, SCR-038, SCR-039
scr_row_coverage: |
  full for all three rows:
  - SCR-037 (cost in weight units): full. The 4x legacy, 4x P2SH and 1x
    witness weighting, the P2SH/WITNESS flag gates and the coinbase
    legacy-only early return are proved for every component value in the
    32-bit domain. Component counting is other rows.
  - SCR-038 (cumulative block sigop cost <= MAX_BLOCK_SIGOPS_COST (80,000)):
    full. The exact `> 80,000` gate is proved for every non-negative int64
    cumulative cost, matching validation.cpp:2566-2569.
  - SCR-039 (mempool policy per-tx limit): full. MAX_STANDARD_TX_SIGOPS_COST
    = MAX_BLOCK_SIGOPS_COST/5 = 16,000 and the exact `>` test are proved for
    every non-negative int64 cost. This row is policy (consensus=false).
  Out of scope: transaction/block decoding, the P2SH and witness counters'
  per-input derivation, and the error-string/state plumbing.
patches: none
source_citations:
  - consensus/tx_verify.cpp:149-168 (GetTransactionSigOpCost: 4x legacy, coinbase early return, 4x P2SH under the flag, witness at 1x)
  - consensus/consensus.h:17,21 (MAX_BLOCK_SIGOPS_COST = 80,000; WITNESS_SCALE_FACTOR = 4)
  - policy/policy.h:44 (MAX_STANDARD_TX_SIGOPS_COST = MAX_BLOCK_SIGOPS_COST/5)
  - validation.cpp:939-941 (bad-txns-too-many-sigops policy gate)
  - validation.cpp:2566-2569 (bad-blk-sigops cumulative gate)
  - spec/core/Bitcoin/Block/Sigops.lean:300-335 (txSigOpCost, txSigOpCostWithFlags, coinbase)
  - spec/core/Bitcoin/Interpreter/Rules.lean:306-346 (sigOpCost, MAX_BLOCK_SIGOPS_COST, blockSigOpsCostOk, MAX_STANDARD_TX_SIGOPS_COST)
trust_note: >
  C is a line-cited source-excerpt slice of tx_verify.cpp/consensus.h/
  policy.h/validation.cpp at the pin. L is a reviewed transliteration of the
  Lean Block/Sigops.lean txSigOpCostWithFlags model; Core's coinbase early
  return is the Lean model's caller-supplied zero counters
  (p2shSigOpCount_coinbase_zero / witnessSigOps_coinbase_zero) and is
  transliterated explicitly. Alive2 compares the C and L IR for all three
  functions; SAW verifies both legs against independent Cryptol predicates.
  No Core patch is used. This is cost arithmetic, not a tx or block decoder.
mutant: >
  Proposed, not executed: charge the witness term at 4x (the classic BIP141
  error). Expected: Alive2 counterexample at witness = 1 with the WITNESS
  flag set (C = legacy*4 + 1, L = legacy*4 + 4); SAW failure of the cost
  predicate.
---
