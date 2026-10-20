---
cell: C-L-w32-p2sh-stackcopy
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic snapshot/restore relation, EvalScript abstracted)
precondition: |
  - Cell seam: the P2SH arm's snapshot and restore, plus the two
    post-EvalScript checks that sit between the calls.  No tx decoding, no
    EvalScript execution, no redeem-script execution, no witness, no
    signatures.
  - The stack after `EvalScript(stack, scriptSig, ...)` (:2029) and the stack
    after `EvalScript(stack, scriptPubKey, ...)` (:2034) are cell inputs:
    depths in [0,2] and one-byte elements.  The EvalScript loop is the E5
    residual; its stack results are symbolic here by construction.
  - The scriptPubKey is the P2SH template, and the push-only gate at :2065
    is a precondition of this cell (it is SCR-006's cell).  The redeem
    script is one byte wide on this domain; its `EvalScript` at :2080 is
    abstracted to success, and the observable is the argument pair
    (redeemScript byte, stack) that call receives.
  - The unreachable `assert(!stack.empty())` at :2074 is reported as
    UNKNOWN_ERROR for totality; it is outside Core's reachable domain when
    the P2SH scriptPubKey evaluated successfully.
postcondition: |
  Observable = packed
    result(2) | error(6)<<2 | redeem(8)<<8 | sub_n(2)<<16
    | sub_e0(8)<<18 | sub_e1(8)<<26
  with `redeem`/`sub_*` describing the stack handed to
  `EvalScript(stack, pubKey2, ...)` at :2080.
    post-spk stack empty or falsy top  -> (0, 2) EVAL_FALSE  (:2037-2040)
    P2SH flag clear                    -> (1, 0, 0, 0, 0, 0) arm not taken
    P2SH set, post-scriptSig depth 0   -> (0, 1) UNKNOWN_ERROR (assert, out of contract)
    P2SH set, post-scriptSig depth n>0 -> (1, 0, top(sig), n-1, rest(sig))
  The key clause is the last one: the redeem byte and the subscript stack
  are derived from the **post-scriptSig** stack, never from the post-spk
  stack, for every symbolic pair of distinct stacks.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-007
scr_row_coverage: |
  full for the row as stated:
  - the snapshot is taken from the scriptSig result (:2032-2033); the two
    stacks are independent symbolic inputs and the observable proves the
    restore uses the scriptSig one,
  - the restore happens before the subscript evaluation (:2069, :2076-2080)
    and the popped top is the redeemScript byte,
  - the snapshot and restore are inside the P2SH arm (:2062), and the cell
    proves the flag-conditional snapshot changes nothing when the arm is not
    entered.
  Named abstractions: EvalScript results are inputs (E5 residual, B3); the
  redeem-script CPU is not executed.  Those are not branches of SCR-007.
patches: none
source_citations:
  - interpreter.cpp:2029-2031 (EvalScript scriptSig)
  - interpreter.cpp:2032-2033 (`if (flags & SCRIPT_VERIFY_P2SH) stackCopy = stack;`)
  - interpreter.cpp:2034-2036 (EvalScript scriptPubKey)
  - interpreter.cpp:2037-2040 (empty/falsy stack -> EVAL_FALSE)
  - interpreter.cpp:2062 (P2SH arm guard)
  - interpreter.cpp:2068-2069 (`swap(stack, stackCopy)`)
  - interpreter.cpp:2071-2078 (assert, `stack.back()`, `popstack`)
  - interpreter.cpp:2080-2086 (subscript EvalScript, empty/falsy checks)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1372-1374 (`let stackCopy := stack1`)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1335-1340 (`p :: rest` -> eval p on rest)
  - spec/core/Bitcoin/Interpreter/Defs.lean:465-470 (CastToBool)
  - contract/error_enum.md:27,30 (EVAL_FALSE = 2, UNKNOWN_ERROR = 1)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core at the pin.  L is a
  reviewed transliteration of the Verified Lean `verifyScriptFull`/`p2shInner`
  bindings, not generated from the twin.  The EvalScript stack results are
  declared inputs, so this is a proof of the P2SH restore dataflow, not of
  script evaluation.  Both tools prove the same symbolic function: Alive2
  compares the C/L IR, SAW verifies both against `spec_cell_p2sh_stackcopy`.
  No Core patch is used.
mutant: >
  Proposed, not executed: delete the `swap(stack, stackCopy)` restore in the
  C leg (use the post-spk stack).  Expected Alive2 counterexample at
  `sig_e0 != spk_e0` with depth 1: C returns the post-spk byte as the redeem
  script, L returns the scriptSig byte; SAW proof failure.  The observable
  exists precisely to make that mutant visible.
---

# exec-verify/C-L-w32-p2sh-stackcopy

Bounded symbolic cell for SCR-007: `stackCopy` is taken **after** the
scriptSig evaluation and restored **before** the redeem-script evaluation.

## Seam

```
2029  if (!EvalScript(stack, scriptSig, flags, checker, SigVersion::BASE, serror))
2032  if (flags & SCRIPT_VERIFY_P2SH)
2033      stackCopy = stack;
2034  if (!EvalScript(stack, scriptPubKey, flags, checker, SigVersion::BASE, serror))
...
2062  if ((flags & SCRIPT_VERIFY_P2SH) && scriptPubKey.IsPayToScriptHash())
2068      // Restore stack.
2069      swap(stack, stackCopy);
2076      const valtype& pubKeySerialized = stack.back();
2077      CScript pubKey2(...);
2078      popstack(stack);
2080      if (!EvalScript(stack, pubKey2, ...))
```

Lean (`verifyScriptFull`, Defs.lean:1372) binds `stackCopy := stack1` (the
post-scriptSig stack) and `p2shInner` (Defs.lean:1335-1340) destructures it
as `p :: rest`: the redeem script is its head, the subscript stack is its
tail.

## What is proved

For every pair of independent symbolic stacks (post-scriptSig and
post-scriptPubKey), every depth in [0,2] and every element byte, the P2SH arm
evaluates the redeem script from the **post-scriptSig** stack:

- `redeem` = top of the post-scriptSig stack,
- the stack handed to the subscript evaluation = that stack minus its top,
- the post-spk stack contributes only the empty/falsy check at :2037-2040,
- with the P2SH flag clear the arm is not entered.

The C and L legs are equal on the packed observable; Alive2 and SAW are both
green.

## What is not proved

- The two `EvalScript` calls are inputs, not executions (E5 residual).
- The redeem-script execution at :2080 (abstracted to success).
- Witness handling, cleanstack, signatures, tx context.

## Exact commands

From the repository root:

```sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy/saw/certificate.sha256
```
