---
cell: C-L-w32-flag-combo
family: exec-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic over all flag combinations)
precondition: |
  - Cell seam: the flag-combination constraint of VerifyScript and nothing
    else.  No script, tx, witness or checker is involved.
  - Inputs are the three flag bits that occur in the constraint:
    P2SH (0x1), WITNESS (0x800), CLEANSTACK (0x100), each a symbolic 64-bit
    value read as a boolean.  All other bits are irrelevant to the row and
    are fixed to zero; the high-bit domain rule (`flags & ~0x1fffff == 0`)
    is tape.md §5.5 and is not this row.
  - Cleanstack is a verify flag in Core and `PolicyFlags.cleanstack` in the
    Lean model; the cell fixes that one-to-one mapping (the twin splits
    flags/policy the same way).
postcondition: |
  Observable = the contract-domain answer:
    0  the flag combination is admissible (all VerifyScript implications hold)
    2  bad input (Core's assert condition is violated)
  Truth table (p2sh, witness, cleanstack):
    000/001 -> allowed only when cleanstack = 0; 001 -> 2
    010      -> 2  (WITNESS without P2SH, :2124)
    011      -> allowed
    100      -> 0
    101      -> 2  (CLEANSTACK without WITNESS, :2114)
    110      -> 2  (WITNESS without P2SH)
    111      -> 0
  Equivalent to Lean `flagsComboOk` (Rules.lean:47-50).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-009
scr_row_coverage: |
  full.  The row's rule is a total predicate on the three flag bits, and the
  cell is symbolic over all of them (2^3 combinations, plus the irrelevant
  bits fixed): every combination that violates CLEANSTACK => P2SH ∧ WITNESS
  is rejected and every admissible combination is accepted.  The second
  implication (WITNESS => P2SH, :2124) is included because the contract
  domain check and `flagsComboOk` both carry it; it is normally SCR-014's
  row, which is not claimed here.
  Note the row's consensus flag is false: CLEANSTACK is policy, and the
  assertions are debug-only in Core.  What is proved is the contract's
  total replacement for them, not a release-build abort.
patches: none
source_citations:
  - interpreter.cpp:2110-2114 (CLEANSTACK arm and its two asserts)
  - interpreter.cpp:2120-2124 (WITNESS arm and its P2SH assert)
  - spec/equiv/shims/core/entry.cpp:93-100 (ABI domain check replacing the asserts)
  - contract/ABI.md §5 rules 5-6, contract/tape.md §5 (flag implications -> 2)
  - spec/core/Bitcoin/Interpreter/Rules.lean:47-50 (flagsComboOk)
  - spec/proofs/BitcoinProofs/AF/PDW33/PDW33.lean:26-45 (row-face theorems)
trust_note: >
  C is a line-cited excerpt of the shim's domain check, which is the contract's
  total version of Core's two `assert`s; the Core lines are cited alongside.
  L is a reviewed transliteration of the Lean `flagsComboOk` predicate.  No
  engine code and no Core patch is involved.  Alive2 compares the C/L IR and
  SAW verifies both against the same Cryptol predicate.
mutant: >
  Proposed, not executed: drop the first conjunct in the C leg (accept
  CLEANSTACK without P2SH or without WITNESS).  Expected Alive2
  counterexample at (p2sh=0, witness=0, cleanstack=1): C = 0, L = 2.
---

# exec-verify/C-L-w32-flag-combo

Bounded symbolic cell for SCR-009, the flag-combination constraint.

## Seam

Core asserts the implications only in debug builds:

```
2110  if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {
2113      assert((flags & SCRIPT_VERIFY_P2SH) != 0);
2114      assert((flags & SCRIPT_VERIFY_WITNESS) != 0);
...
2124      assert((flags & SCRIPT_VERIFY_P2SH) != 0);   // inside `if (flags & WITNESS)`
```

The contract turns both into a total domain rule that returns 2
(`contract/tape.md` §5.6, implemented at `shims/core/entry.cpp:93-100`).  The
Lean model states the same predicate as `flagsComboOk` (`Rules.lean:47-50`):

```
(!pol.cleanstack ∨ (flags.p2sh ∧ flags.witness)) ∧ (!flags.witness ∨ flags.p2sh)
```

## What is proved

`cell_flag_combo_admissible(p2sh, witness, cleanstack)` is symbolic in all
three bits and both legs agree on all eight combinations: `0` when the
combination is admissible, `2` when the contract rejects it.

## What is not proved

- Core's release-build behaviour when the assert is violated (there is none:
  the process would abort in a debug build; the contract deliberately
  rejects the input instead).
- The high-bit mask rule (`flags & ~0x1fffff == 0`), which is tape.md §5.5,
  not this row.
- Whether a given flag set is *activated* at a height (SCR-015/SCR-016).

## Exact commands

From the repository root:

```sh
spec/equiv/cells/exec-verify/C-L-w32-flag-combo/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-combo/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flag-combo/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flag-combo/saw/certificate.sha256
```
