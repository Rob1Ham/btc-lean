---
# Cell limits/C-L-push-size
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-push-size
family: limits
tool_status: both-green (symbolic, all push lengths, kinds, and fExec bits)
precondition: |
  - the instruction decoded successfully (GetOp returned true); the
    truncated-push tail is F-DIV-001 and outside this cell.
  - kind ∈ {0 = byte push, 1 = numeric push OP_1NEGATE..OP_16,
    2 = other opcode}; fExec ∈ {0,1}.
  - `dlen` is the decoded push-value size in bytes, symbolic over all 2^16
    values.  No flags are read by this check; sigversion is irrelevant to it.
  - one instruction, no opcode budget or stack-depth interaction.
postcondition: |
  - if kind = byte push and dlen > 520: result 0, error_kind 6
    (EQUIV_ERR_PUSH_SIZE), payload 0 — for both fExec values.
  - otherwise: result 1, error_kind 0, payload = 1 iff the instruction is a
    push (kind 0 or 1) and fExec = 1, else 0.
  - out-of-domain kind/fExec: result 2, error_kind 1.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: [SCR-020]
scr_row_coverage: >-
  full — SCR-020 is the per-instruction check
  `vchPushValue.size() > MAX_SCRIPT_ELEMENT_SIZE ⇒ PUSH_SIZE`, placed after
  GetOp and before any use of fExec.  The cell is symbolic over the complete
  push-length domain (all 2^16 values, so 520/521 are both exercised), over
  byte and numeric pushes, over non-push opcodes, and over both fExec values,
  so the "even unexecuted" branch is proved rather than witnessed.  The
  payload's post-check push effect also distinguishes executed from
  unexecuted pushes.
patches: none
source_citations:
  - interpreter.cpp:455-458 (GetOp, then vchPushValue size check)
  - interpreter.cpp:488-493 (push only when fExec)
  - script.h:29 (MAX_SCRIPT_ELEMENT_SIZE = 520)
  - spec/core/Bitcoin/Interpreter/Defs.lean:817-826 (stepBody sizeOk)
  - spec/equiv/twin/runtime.inc:603-606 (twin element-size check)
trust_note: >
  C is a line-cited source-excerpt slice of Core interpreter.cpp and
  script.h at the pin; GetOp's decode is represented by the decoded
  instruction class and `dlen`, and the cell precondition states GetOp
  succeeded.  L is a reviewed transliteration of Lean stepBody's `sizeOk`
  (and the identical structural check in the generated twin), not a
  generated handler: the limit lives in the EvalScript step, not in an
  opcode handler.  Domain guard and packing are shared harness.  Alive2
  compares the extracted modules over i16/i8 inputs; SAW verifies each
  against an independent Cryptol predicate over all 2^16 lengths, all kind
  bytes and both fExec values.  Bounded step predicate, not a whole-engine
  proof.  No Core patch.
evidence:
  alive2: alive2/result.txt (STATUS=alive2-green)
  saw: saw/result.txt (STATUS=saw-green, 2 proofs)
  certificates:
    - alive2/certificate.sha256
    - saw/certificate.sha256
---

# limits/C-L-push-size

C vs L for the 520-byte per-instruction push-value limit.

The "even unexecuted" half is the point: the size check is upstream of
`fExec`, so `dlen = 521` returns `PUSH_SIZE` with `fExec = 0` exactly as it
does with `fExec = 1`.  A later `stack.push_back` only happens when executed.
