---
# Cell push-encoding/C-L-w32-witness-program
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: push-encoding/C-L-w32-witness-program
family: push-encoding
tool_status: both-green (symbolic over (version byte, length byte, script size))
precondition: |
  - base sigversion; flags = 0; policy = 0; one input (the predicate does not
    read flags).
  - the script has length n and its first two bytes are v (the version
    opcode slot) and plen (the direct-push length slot).
  - bounded to the predicate: only (v, plen, n) are observed; all other
    script bytes are irrelevant to IsWitnessProgram, which reads at most
    these two bytes before the length test succeeds.
postcondition: |
  - both legs return the same Boolean recognition result:
    n ∈ [4,42] ∧ (v = 0x00 ∨ v ∈ [0x51,0x60]) ∧ plen + 2 = n.
  - the program length is plen, hence 2..40 by the length window.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-053
scr_row_coverage: >-
  full — the row is the IsWitnessProgram template: 4..42-byte script,
  OP_0/OP_N version byte, exact-length direct push, program 2..40.  The cell
  is symbolic in all three inputs that appear in the rule and ranges over all
  2^32 sizes and all 256 version/length bytes, so every edge (sizes 3/4/42/43,
  versions OP_0/OP_1/OP_16/OP_17, plen+2 = n or not) is exercised.  The
  version decoding (SWT-002) and the program-byte extraction are not part of
  this cell's observable; no other byte participates in recognition.
patches: none
source_citations:
  - script.cpp:250-264 (CScript::IsWitnessProgram length/version/push checks)
  - twin/runtime.inc:312-320 (is_witness_program)
  - Defs.lean:510-521 (isWitnessProgram)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp at the
  pin, not the whole function: the two GetOp decodes are reduced to their
  byte reads and the program copy/version decode are omitted because they do
  not affect the Boolean.  L calls the twin's is_witness_program verbatim from
  runtime.inc as rendered by twin/gen.py into build/twin.cpp; the two-byte
  buffer and the call are cell harness.  No Core or twin patch is used.  This
  is a predicate cell, not a whole-verify proof.
---
