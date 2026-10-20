---
# Cell limits/C-L-w32-sigop-cost
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: limits/C-L-w32-sigop-cost
family: limits
tool_status: both-green (symbolic over all five 32-bit inputs)
precondition: |
  - pure aggregation function: no transaction, script, witness, or coin
    object.  The three per-input counts are inputs, each a uint32_t:
    `legacy` = GetLegacySigOpCount(tx) (scriptSig + scriptPubKey static
    counts); `p2sh` = GetP2SHSigOpCount(tx, inputs); `witness` =
    Sum CountWitnessSigOps over the inputs.
  - `coinbase` and `p2sh_flag` are the two caller gates observed by
    GetTransactionSigOpCost (tx.IsCoinBase(); SCRIPT_VERIFY_P2SH).  Both are
    symbolic 32-bit values, tested only for zero/non-zero.
  - no overflow: the largest result for uint32_t counts is below 2^36, which
    fits the int64_t return; the cell proves the exact arithmetic, not a
    bounded approximation.
postcondition: |
  - legacy and P2SH sigops are charged WITNESS_SCALE_FACTOR = 4 each; witness
    sigops are charged 1.
  - coinbase => return 4 * legacy (the other terms are skipped by the early
    return).
  - otherwise return 4 * (legacy + (p2sh_flag ? p2sh : 0)) + witness.
  - C and L return the same int64_t for every argument tuple, and both equal
    the independent Cryptol `cost`.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-037
scr_row_coverage: >-
  full — every branch and edge of the weight-unit aggregation is exercised
  symbolically: the legacy term is always scaled by 4; the coinbase early
  return; the P2SH term is included and scaled by 4 only when the P2SH flag is
  set; the witness term is charged 1 in every non-coinbase case.  Composition
  boundary: the cell takes the three counts as inputs; the scripts that
  produce them are proved by C-L-w32-p2sh-scriptsig, C-L-w32-witness-sigops,
  and the existing legacy-counter cells.  This cell does not claim those
  counts; it claims the scaling and gates the row names.
patches: none
source_citations:
  - tx_verify.cpp:149-168 (GetTransactionSigOpCost)
  - tx_verify.cpp:151 (legacy * WITNESS_SCALE_FACTOR)
  - tx_verify.cpp:153-155 (coinbase early return)
  - tx_verify.cpp:157-159 (P2SH term under SCRIPT_VERIFY_P2SH, * factor)
  - tx_verify.cpp:161-166 (witness term, * 1)
  - consensus/consensus.h (WITNESS_SCALE_FACTOR = 4)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:54 (LEGACY_SIGOP_SCALE)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:400-416 (InputSigOps, sigOpCost)
  - spec/core/Bitcoin/TxValidation/SigOpsCost.lean:51-61 (p2shSigOpsTx coinbase gate)
trust_note: >
  C is a line-cited source-excerpt slice of tx_verify.cpp's aggregation, with
  the three count computations replaced by their already-proved outputs.  L is
  a reviewed transliteration of the Lean `sigOpCost` formula (model_rev
  4d62a97e) with the caller's coinbase and P2SH gates applied.  This modular
  composition is the same slicing the family uses elsewhere; the cell does not
  re-prove the counts and does not claim any script/crypto behavior.  The
  arithmetic is done in uint64/int64 and cannot overflow for 32-bit counts.
  No pin, contract, engine source, Lean proof, or crypto premise is changed.
---

# limits/C-L-w32-sigop-cost

Symbolic equivalence of Core's weight-unit sigop aggregation and the Lean
`sigOpCost` formula, against an independent Cryptol specification, over all
five 32-bit inputs.

## Entry point

```c
extern "C" int64_t cell_sigop_cost(uint32_t legacy, uint32_t p2sh,
                                   uint32_t witness, uint32_t coinbase,
                                   uint32_t p2sh_flag);
```

## What each tool proves

- **Alive2** (`alive2/run.sh`): C and L agree for every argument tuple.  The
  runner guards the extracted IR (no `alloca`, no `= external`, no
  `switch.table`, no residual `llvm.loop`) and requires `--always-verify` plus
  the exact summary counts.
- **SAW** (`saw/run.sh`): both modules are verified against
  `cost legacy p2sh witness coinbase p2shFlag` for every argument tuple; two
  proofs, solver `abc`.

## Row

**SCR-037** — cost in weight units: `4 * (legacy + p2sh) + witness`, with the
coinbase and P2SH-flag gates.

See `notes.md` for the composition boundary and the mutation sanity check.
