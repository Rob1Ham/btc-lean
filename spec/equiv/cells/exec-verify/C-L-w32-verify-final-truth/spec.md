---
# Cell exec-verify/C-L-w32-verify-final-truth
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: exec-verify/C-L-w32-verify-final-truth
family: exec-verify
tool_status: both-green
precondition: |
  - The VerifyScript tail only (interpreter.cpp:2037-2040), base sigversion.
  - The two EvalScript calls are the declared seam: their outcome
    (error ordinal, or success) is a symbolic input, mirroring the Lean row
    face's hypotheses `hss`/`hspk`
    (spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:39-50).
  - Inputs in the proof: `ss_err`, `spk_err` arbitrary 64-bit ScriptError
    ordinals (0 = success); post-scriptPubKey stack depth `n` arbitrary
    64-bit; the top element is a 0..8-byte little-endian word `top` of
    length `top_len`.
  - The cell's stack encoding carries at most 8 bytes per element. `top_len >
    8` is outside the encoding and both legs return the declared UNKNOWN
    guard; no claim is made there. Elements of 9..520 bytes follow the same
    Core rule (first nonzero byte decides, lone wire-last 0x80 is negative
    zero); the encoding bound, not the rule, is the limitation.
postcondition: |
  - result(2) | error_kind(6) << 2 is:
      ss_err != 0                  -> (0, ss_err)     first failure wins
      ss_err = 0, spk_err != 0     -> (0, spk_err)
      both ok, n = 0               -> (0, 2)          EVAL_FALSE (empty stack)
      both ok, top casts false     -> (0, 2)          EVAL_FALSE
      both ok, top casts true      -> (1, 0)          success
  - CastToBool agrees with interpreter.cpp:46-59 including the negative-zero
    corner (single 0x80 element casts false).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-002
scr_row_coverage: >-
  full for the row's edges: empty stack, non-empty stack with a false top
  (0x00, 0x80 negative zero, and multi-byte elements that are all zero), and
  non-empty stack with a true top (nonzero at any position, including 0x80
  when it is not the wire-last byte). Error precedence (scriptSig before
  scriptPubKey) is exercised symbolically. Bounded element width (<= 8
  bytes) is a cell-encoding limit, not a missing branch of the row.
  NOT claimed: that EvalScript actually produces those outcomes, nor the
  witness/P2SH/cleanstack tails.
patches: none
source_citations:
  - interpreter.cpp:2029-2031 (EvalScript(scriptSig) error returned)
  - interpreter.cpp:2034-2036 (EvalScript(scriptPubKey) error returned)
  - interpreter.cpp:2037-2038 (stack.empty() -> SCRIPT_ERR_EVAL_FALSE)
  - interpreter.cpp:2039-2040 (CastToBool(stack.back()) false -> EVAL_FALSE)
  - interpreter.cpp:46-59 (CastToBool; negative-zero rule)
  - Numeric/Interface.lean:64 and Numeric/ScriptNum.lean:648 (Lean castToBool
    on the reversed byte list)
  - spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:39-50
    (verifyScriptFull_sequential / verifyScriptFull_ok_base_stack face)
  - contract/error_enum.md:37 (ordinal 2 EVAL_FALSE)
trust_note: >
  C is a line-cited source-excerpt slice of VerifyScript at the pin, with the
  EvalScript calls replaced by symbolic outcome inputs (the row face's
  hypotheses). L is a reviewed transliteration of the Lean `verifyScriptFull`
  tail, not generated from twin/ops_ir.py; its CastToBool follows the Lean
  reversed-list definition, while the C leg uses Core's first-nonzero loop,
  so Alive2 has to reconcile two genuinely different programs. No Core patch,
  no solver axiom beyond the tool trust base. SAW verifies both legs against
  one Cryptol function; Alive2 compares the two IR modules with
  `--always-verify`.
mutant: >
  Proposed, not executed: drop the `stack.empty()` check in the L leg (make
  it read the top of an empty stack). Expected Alive2 counterexample at
  n = 0 (C = EVAL_FALSE vs L = UNKNOWN/garbage) and a SAW proof failure.
---
