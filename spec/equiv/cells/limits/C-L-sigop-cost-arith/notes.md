# limits/C-L-sigop-cost-arith

SCR-037/038/039: sigop-cost weighting, the 80,000 block cap and the 16,000
mempool policy cap. Both tools green on all three functions.

## Source (pin cce32b168)

- `src/consensus/tx_verify.cpp:149-168` — `GetTransactionSigOpCost`:
  `legacy * 4`; coinbase returns legacy only; `p2sh * 4` under
  SCRIPT_VERIFY_P2SH; witness term at weight 1.
- `src/consensus/consensus.h:17,21` — 80,000; WITNESS_SCALE_FACTOR = 4.
- `src/policy/policy.h:44` — `MAX_STANDARD_TX_SIGOPS_COST = 80000/5 = 16000`.
- `src/validation.cpp:939-941` — policy gate `> 16000`.
- `src/validation.cpp:2566-2569` — block gate `> 80000`.
- `spec/core/Bitcoin/Block/Sigops.lean:300-335` — `txSigOpCost`,
  `txSigOpCostWithFlags`, coinbase zero-counter lemmas.
- `spec/core/Bitcoin/Interpreter/Rules.lean:306-346` — `sigOpCost`,
  `MAX_BLOCK_SIGOPS_COST`, `blockSigOpsCostOk`, `MAX_STANDARD_TX_SIGOPS_COST`.

## Model

Three functions: cost aggregation, block gate, policy gate. Components are
32-bit (Core's `unsigned int`/`size_t` counters, far below 2^32); the cost is
int64 like Core's local. L transliterates the Lean model, with the coinbase
zeroing that the Lean model leaves to its caller lemmas.

## Symbolic claim

- Alive2: three `alive-tv` comparisons (each 1 correct transformation).
- SAW: six proofs (both legs for each function) against `src/cell.cry`.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-sigop-cost-arith/alive2/run.sh
bash spec/equiv/cells/limits/C-L-sigop-cost-arith/saw/run.sh
```

## Limits

- No tx/block decoder: the component counts are inputs, proved by the
  SCR-032..036 cells elsewhere.
- The gates take a non-negative int64 cumulative cost (SAW precondition); the
  negative corner is not a Core state.
- No Core patch.
