---
# Cell limits/C-L-opcount
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-opcount
family: limits
tool_status: both-green (symbolic, all opcode bytes, counts, fExec, sigversions)
precondition: |
  - one successfully decoded, fully parsed instruction; no push value, so
    the :457-458 PUSH_SIZE check cannot fire.  `wire` is the opcode byte,
    symbolic over all 2^8 values (OP_NOP 0x61 and every disabled opcode are
    in the domain).
  - `sv` ∈ {BASE=0, WITNESS_V0=1, TAPSCRIPT=2}.
  - incoming `nOpCount` ∈ [0, 202] (uint32 input; values above 202 are out of
    domain → result 2).  This is the whole region in which `++nOpCount` is
    well defined and the 201 boundary is reachable.
  - `fExec` ∈ {0,1}; flags = 0, so the OP_CODESEPARATOR/CONST_SCRIPTCODE
    branch at :484-486 cannot fire.
postcondition: |
  - if sv ∈ {BASE, WITNESS_V0} and wire > 0x60 and (nOpCount+1) > 201:
    result 0, error_kind 7 (EQUIV_ERR_OP_COUNT), payload 0.  This includes
    disabled opcodes at the boundary (the disabled check is later).
  - else if wire is one of the 15 disabled opcodes: result 0,
    error_kind 17 (EQUIV_ERR_DISABLED_OPCODE), payload 0.
  - else: result 1, error_kind 0, payload = charged count (bits 0-11) |
    fExec (bit 12).  `charged` is nOpCount + 1 exactly when
    sv ∈ {BASE, WITNESS_V0} and wire > 0x60, and is independent of fExec.
  - out-of-domain count/sigversion/fExec: result 2, error_kind 1.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: [SCR-022, SCR-023, SCR-024, SCR-025]
scr_row_coverage: >-
  full — the cell models one stepBody step over the complete decision domain.
  SCR-022: the `wire > 0x60` charge and the `> 201` rejection with OP_COUNT,
  including the 201→202 boundary, and OP_COUNT returning before the disabled
  table and before dispatch (the admit branch is the dispatch entry point).
  SCR-023: fExec is a free symbolic input and the charged count is computed
  before it is read, so the count and every verdict are flow-insensitive; the
  payload exposes both the charged count and fExec so the property is not
  hidden.  SCR-024: `wire` ranges over all 256 bytes, so all of 0x00-0x60
  are proved exempt and every 0x61-0xff byte is proved charged.
  SCR-025: for every wire/count pair the OP_COUNT branch is tested first; the
  boundary case (count 201, disabled wire) returns OP_COUNT, not
  DISABLED_OPCODE.  The cell stops at the dispatch entry, which is exactly
  where these four ordering/charging rows end; opcode execution is not part
  of them.
patches: none
source_citations:
  - interpreter.cpp:441 (int nOpCount = 0)
  - interpreter.cpp:460-465 (BASE/WITNESS_V0 budget, wire > OP_16, ++nOpCount)
  - interpreter.cpp:467-482 (disabled table, after the budget check)
  - script.h:32 (MAX_OPS_PER_SCRIPT = 201)
  - spec/core/Bitcoin/Interpreter/Defs.lean:826-833 (stepBody order)
  - spec/core/Bitcoin/Interpreter/Defs.lean:455-457 (disabledWire)
  - spec/equiv/twin/runtime.inc:607-614 (twin budget then disabled)
trust_note: >
  C is a line-cited source-excerpt slice of Core interpreter.cpp at the pin;
  `wire` is a decoded opcode byte and the cell does not model GetOp or
  dispatch (it ends where dispatch begins).  L is a reviewed transliteration
  of Lean stepBody's three ordered steps and disabledWire, matching the
  generated twin's structural code; there is no per-opcode handler for the
  budget.  The disabled set is written independently in each leg (Core's
  switch list vs Lean's `w ∈ [...]`).  Domain guard and packing are shared
  harness.  Alive2 compares the extracted modules over i32/i8 inputs; SAW
  verifies each against an independent Cryptol predicate.  Bounded step
  predicate, not a whole-engine proof.  No Core patch.
evidence:
  alive2: alive2/result.txt (STATUS=alive2-green)
  saw: saw/result.txt (STATUS=saw-green, 2 proofs)
  certificates:
    - alive2/certificate.sha256
    - saw/certificate.sha256
---

# limits/C-L-opcount

C vs L for the 201-op budget and its precedence over the disabled table.

The decisive case is `nOpCount = 201` with a disabled wire (e.g. OP_CAT 0x7e):
Core increments to 202 and returns `OP_COUNT` before it ever reads the
disabled table.  The cell proves that for every disabled wire and every
sigversion, and proves that fExec cannot change the charged count.
