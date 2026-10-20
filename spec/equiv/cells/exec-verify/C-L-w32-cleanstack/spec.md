---
cell: C-L-w32-cleanstack
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green for the flag/policy face; the witness-implicit arm is a recorded divergence (not green)
precondition: |
  - Cell seam: the terminal CLEANSTACK check of VerifyScript
    (interpreter.cpp:2110-2118) and nothing else.
  - `final_len` is the cleanstack-relevant stack length after all evaluation
    (after the P2SH arm, if any, and after the witness resize when a witness
    program was verified).  It is a symbolic 64-bit input.
  - `cs` is one bit: Core's `SCRIPT_VERIFY_CLEANSTACK` on the C leg, the
    Lean model's `PolicyFlags.cleanstack` on the L leg.  That mapping is the
    declared model correspondence for this cell; the other 20 flag bits are
    irrelevant to the row.
  - The domain constraint CLEANSTACK => P2SH and WITNESS
    (interpreter.cpp:2113-2114) is SCR-009's cell and is a precondition
    here; the contract rejects a violating combination as bad input before
    VerifyScript runs.
  - No EvalScript, no tx, no witness data, no signatures.
postcondition: |
  Observable = packed (result, error): result(2) | error(6) << 2.
    cs = 0                  -> (1, 0)   check not performed
    cs != 0, final_len = 1  -> (1, 0)
    cs != 0, final_len != 1 -> (0, 30)  SCRIPT_ERR_CLEANSTACK
  Symbolic in final_len (all 2^64 values) and in cs.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-008
scr_row_coverage: |
  partial.  Covered by this cell (both tools green):
  - the `flag` face: SCRIPT_VERIFY_CLEANSTACK on/off and the exact
    `stack.size() != 1` test (interpreter.cpp:2110-2118),
  - the `pol.` face: the Lean model's `pol.cleanstack` reads the same bit
    and reaches the same `cleanstack` error.
  NOT covered / blocked: the `implicit in witness` face.  Core resizes the
  stack to one element after a successful witness program, at
  :2057 (bare) and :2102 (P2SH-wrapped), so the check at :2115 cannot fire
  for those spends.  The Lean model only reproduces the bare case:
  `verifyScriptFull` computes
      finalLen := if flags.witness ∧ (isWitnessProgram spk).isSome then 1
                  else <re-evaluate the redeem script and take its length>
  and `isWitnessProgram spk` is false for a P2SH scriptPubKey, so the
  P2SH-wrapped witness spend keeps the inner length instead of 1.  The
  concrete Lean evaluation and the Alive2 counterexample are in
  `divergence/` (wave-32 finding F-DIV-W32-01, proposed global id
  F-DIV-003).  SCR-008 stays partial until that is fixed or the row is
  re-scoped.
patches: none
source_citations:
  - interpreter.cpp:2046-2057 (bare witness program, `stack.resize(1)`)
  - interpreter.cpp:2090-2103 (P2SH-wrapped witness program, `stack.resize(1)`)
  - interpreter.cpp:2107-2118 (terminal CLEANSTACK check, asserts :2113-2114)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1395-1418 (finalLen model)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1418-1420 (cleanstack failure)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1442-1443 (bare-face cleanstack)
  - spec/core/Bitcoin/Interpreter/Defs.lean:193 (PolicyFlags.cleanstack)
  - contract/error_enum.md:65 (CLEANSTACK = 30)
trust_note: >
  C is a line-excerpt slice of Bitcoin Core at the pin.  L is a reviewed
  transliteration of the Lean `verifyScriptFull` cleanstack tail.  The
  witness-implicit arm is NOT proved: the Lean model diverges from Core for
  P2SH-wrapped witness spends, and the divergence is preserved verbatim in
  `divergence/` rather than hidden.  Both tools prove the same symbolic
  function for the flag/policy face; Alive2 compares the C/L IR directly and
  SAW verifies each module against `spec_cell_cleanstack_flag`.
mutant: >
  Proposed, not executed: replace `stack.size() != 1` with `stack.size() > 1`
  in the C leg.  Expected Alive2 counterexample at final_len = 0,
  cs != 0 (C = cleanstack, L = ok); SAW proof failure.
---

# exec-verify/C-L-w32-cleanstack

Bounded symbolic cell for the terminal CLEANSTACK check (SCR-008), plus the
evidence that the witness-implicit arm does **not** hold in the Lean model.

## Seam

```
2110  if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {
2113      assert((flags & SCRIPT_VERIFY_P2SH) != 0);
2114      assert((flags & SCRIPT_VERIFY_WITNESS) != 0);
2115      if (stack.size() != 1) {
2116          return set_error(serror, SCRIPT_ERR_CLEANSTACK);
2117      }
2118  }
```

and the two stack resizes that run before it:

```
2055      // Bypass the cleanstack check at the end. ...
2057      stack.resize(1);
...
2100      // Bypass the cleanstack check at the end. ...
2102      stack.resize(1);
```

## What is proved (green)

`cell_cleanstack_flag(final_len, cs)` is symbolic in both arguments and both
legs return `(0, 30)` exactly when `cs` is set and `final_len != 1`.

## What is not proved (blocked)

The `implicit in witness` face.  A concrete Lean evaluation on a
P2SH-wrapped P2WPKH spend under CLEANSTACK returns `.fail .cleanstack`
(reproduced in `divergence/lean-eval.txt`), while Core returns success
because it resized the stack at :2102.  The Alive2 probe pairs Core's
`resize(1)` behaviour with the Lean `finalLen` rule and produces the
counterexample (source 1 = ok, target 120 = CLEANSTACK).  See
`divergence/`.

## Exact commands

From the repository root:

```sh
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-cleanstack/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-cleanstack/saw/certificate.sha256

# divergence probe (expected: counterexample / proof failure)
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/divergence/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/divergence/saw/run.sh
```
