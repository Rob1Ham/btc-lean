---
# Cell push-encoding/C-L-w32-p2sh-pattern
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: push-encoding/C-L-w32-p2sh-pattern
family: push-encoding
tool_status: both-green (symbolic over the three pattern bytes and the script size)
precondition: |
  - the predicate does not read flags, sigversion or policy.
  - the script has length n; b0, b1 and b22 are its first, second and last
    (index 22) bytes.  All other bytes are unconstrained and unread.
postcondition: |
  - both legs return the same Boolean:
    n = 23 ∧ b0 = 0xa9 ∧ b1 = 0x14 ∧ b22 = 0x87.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-054
scr_row_coverage: >-
  full — the row is exactly the 23-byte HASH160 pattern.  The cell is
  symbolic over all three read bytes and over the script length, so every
  accept/reject edge (size 22/23/24, each byte equal or different) is
  exercised.  No other byte participates in the rule.
patches: none
source_citations:
  - script.cpp:224-231 (CScript::IsPayToScriptHash)
  - twin/runtime.inc:309-311 (is_p2sh)
  - Defs.lean:499-502 (isPayToScriptHash)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp at the
  pin.  L calls the twin's is_p2sh verbatim from runtime.inc as rendered by
  twin/gen.py into build/twin.cpp; the 23-byte buffer and the call are cell
  harness.  No Core or twin patch is used.  This is a predicate cell, not a
  whole-verify proof.
---
