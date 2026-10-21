---
# Cell push-encoding/C-L-w32-pushonly-opcode
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: push-encoding/C-L-w32-pushonly-opcode
family: push-encoding
tool_status: both-green (symbolic over all 256 opcode bytes, one-op scripts)
precondition: |
  - the predicate does not read flags, sigversion or policy.
  - the script is empty (cell_po0) or exactly one byte (cell_po1).
  - fully parseable where it decodes; truncated push forms are included and
    both legs return false for them (no error kind is observed).
postcondition: |
  - both legs return the same Boolean:
      empty script        -> true
      one-byte script b   -> b = 0x00 ∨ b ∈ [0x4f,0x60].
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-052
scr_row_coverage: >-
  partial — the cell is symbolic over every wire byte 0x00..0xff in a script
  position, so it exercises the named edge exactly: every opcode <= OP_16
  (0x60) counts as a push, including OP_RESERVED 0x50, and OP_17 0x61 does
  not.  It also covers the one-op truncation cases (direct push 0x01..0x4b
  and PUSHDATA1/2/4 with missing length/data).  It does NOT exercise a
  successful multi-op script, a successful PUSHDATA push whose data is
  present, or the script-level `all` conjunction beyond one opcode.  The
  cell is deliberately bounded to a 0/1-byte script; a full symbolic-length
  loop cell over the complete GetOp/decode_op surface was not built in this
  task.  Alive2 itself was not observed to reject loops (a scalar
  symbolic-trip-count probe verifies), so this is a scope decision, not a
  proved tool impossibility; see notes.md.
patches: none
source_citations:
  - script.cpp:266-286 (CScript::IsPushOnly)
  - script.h GetOp (push/direct/PUSHDATA1/2/4 decode)
  - twin/runtime.inc:296-307 (classify_push_only)
  - twin/runtime.inc:242-280 (decode_op)
  - Defs.lean:495-496 (isPushOnlyWire)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp/script.h
  at the pin: GetOp is specialised to the fixed one-byte script size, with
  the width-selection loop written as three explicit branches.  L calls the
  twin's classify_push_only (and its decode_op) verbatim from runtime.inc as
  rendered by twin/gen.py into build/twin.cpp; the buffer and call are cell
  harness.  The scripts used are fully parseable or fail decode in the same
  way on both legs, so the F-DIV-001 error-kind seam is not engaged (this
  cell observes a Boolean, not an error kind).  No Core or twin patch is
  used.
---
