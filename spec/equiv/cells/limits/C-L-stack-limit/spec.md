---
# Cell limits/C-L-stack-limit
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-stack-limit
family: limits
tool_status: both-green (symbolic, all bounded main/altstack depth pairs)
precondition: |
  - one executed opcode's terminal size guard.  `depth` = stack.size() and
    `alt` = altstack.size() after the opcode, each bounded to [0, 2000] so
    the 32-bit sum is exact and the > 1000 region is fully inside the domain.
  - values above 2000 are out of domain → result 2.
  - the guard is unconditional (no flag, no sigversion input).
postcondition: |
  - if depth + alt > 1000: result 0, error_kind 8 (EQUIV_ERR_STACK_SIZE),
    payload 0.
  - otherwise: result 1, error_kind 0, payload = depth + alt.
  - out-of-domain depth/alt: result 2, error_kind 1.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: [SCR-029, SCR-030]
scr_row_coverage: >-
  full — SCR-029/SCR-030 are the terminal combined guard
  `stack.size() + altstack.size() > MAX_STACK_SIZE ⇒ STACK_SIZE`.  The cell is
  symbolic over every bounded (main, alt) depth pair, so it proves the
  boundary (sum 1000 admits, 1001 rejects), the strict `>` comparison, and
  that the altstack is added rather than ignored (the same main depth admits
  or rejects depending on alt).  "Checked per opcode" is the loop that
  applies this step guard after every executed opcode; the guard itself is
  this predicate and is applied unconditionally, so the single-step model
  covers the row's condition and placement.  Multi-op depth accumulation is
  not modelled (that needs the opcode semantics, not the limit).
patches: none
source_citations:
  - interpreter.cpp:1231-1233 (post-opcode combined size limit)
  - script.h:44 (MAX_STACK_SIZE = 1000)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1131-1136 (stepChecked terminal guard)
  - spec/equiv/twin/runtime.inc:642-643 (twin terminal guard)
trust_note: >
  C is a line-cited source-excerpt slice of Core interpreter.cpp at the pin.
  L is a reviewed transliteration of Lean stepChecked's terminal guard,
  identical to the generated twin's structural check; there is no opcode
  handler for this limit.  Domain guard and packing are shared harness.
  Alive2 compares the extracted modules over i32 inputs; SAW verifies each
  against an independent Cryptol predicate over all bounded pairs.  Bounded
  step predicate, not a whole-engine proof.  No Core patch.
evidence:
  alive2: alive2/result.txt (STATUS=alive2-green)
  saw: saw/result.txt (STATUS=saw-green, 2 proofs)
  certificates:
    - alive2/certificate.sha256
    - saw/certificate.sha256
---

# limits/C-L-stack-limit

C vs L for `stack.size() + altstack.size() > 1000`.

The payload is the combined depth, which makes the altstack contribution
observable: (depth = 900, alt = 101) rejects, (900, 100) admits.
