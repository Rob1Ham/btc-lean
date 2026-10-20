---
# Cell disabled/C-L-w32-disabled-dispatch
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: disabled/C-L-w32-disabled-dispatch
family: disabled-opcodes
tool_status: both-green (symbolic, all 2^8 wires x 2 sigversions x 2^32 opcounts x 2 fExec values)
precondition: |
  - the cell starts at the EvalScript loop head after a successful GetOp with
    an empty push value; `w` is the decoded wire byte (0x00..0xff).
  - `wv0` in {0,1} selects BASE or WITNESS_V0; TAPSCRIPT is outside this
    cell (these bytes are OP_SUCCESSx there; see C-L-w32-opsuccess-scan).
  - `nOpCount` is the pre-op nOpCount (uint32, wrapping addition as in Core).
  - `fExec` is the pre-op vfExec.all_true() bit.
  - no PUSH_SIZE, CODESEPARATOR, minimal-data or stack effects are modelled;
    they are separate rows.
postcondition: |
  - cell_guard: 7 (OP_COUNT) iff wv0 && w > 0x60 && nOpCount+1 > 201;
    else 17 (DISABLED_OPCODE) for the fifteen disabled wires; else 64 when
    fExec is set and 65 when it is clear.  The disabled arm does not read
    fExec: this is the SCR-171 ordering claim.
  - cell_default: the same guards, then Core's :493 switch-entry condition
    (fExec || 0x63<=w<=0x68), then push/push-number arms (64), then explicit
    case labels (64), except 0xba (OP_CHECKSIGADD under BASE/WV0 => 16), and
    otherwise 16 (BAD_OPCODE, interpreter.cpp:1227-1228).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-170, SCR-171, SCR-174
scr_row_coverage: >-
  SCR-170 full for the base/witness-v0 domain: symbolic over all fifteen
  disabled wires, both sigversions, the budget boundary (nOpCount = 200/201)
  and both fExec values. SCR-171 full: op-count precedes disabled, disabled
  precedes fExec, proved by the guard function's exact ordering.
  SCR-174 full for the BASE/WITNESS_V0 switch (the row's core_ref): the wire
  classification is symbolic over every wire byte and both fExec values; the
  L table is generated from twin/ops_ir.py + runtime.inc, so a missing or
  duplicated twin wire fails the build, and the default set is proved equal
  to Core's. In tapscript, every default-set byte except OP_VERIF/OP_VERNOTIF
  is an OP_SUCCESSx (proved by C-L-w32-opsuccess-scan), so 0x65/0x66 are the
  only bytes that can reach this default arm there; that arm is the same
  `default:` and is not separately modelled. Not covered here: tapscript
  OP_SUCCESSx (SCR-172 cell), PUSH_SIZE/BAD_OPCODE-from-GetOp ordering
  (F-DIV-001), OP_CODESEPARATOR and stack effects.
patches: none
source_citations:
  - interpreter.cpp:445 (fExec = vfExec.all_true())
  - interpreter.cpp:455-458 (GetOp failure, push-size guard)
  - interpreter.cpp:459-463 (201-op budget, opcode > OP_16)
  - interpreter.cpp:465-482 (the fifteen disabled opcodes)
  - interpreter.cpp:484-486 (OP_CODESEPARATOR, not modelled)
  - interpreter.cpp:488-493 (push arm and switch-entry condition)
  - interpreter.cpp:1097 (OP_CHECKSIGADD under BASE/WITNESS_V0)
  - interpreter.cpp:1227-1228 (default: SCRIPT_ERR_BAD_OPCODE)
  - script.h (MAX_OPS_PER_SCRIPT = 201, OP_16 = 0x60)
  - twin/runtime.inc:396-407 (disabled_wire), :597-636 (eval_script order)
  - Defs.lean:455-462 (disabledWire), :817-848 (stepBody)
trust_note: >
  C is a line-cited source-excerpt slice of EvalScript, not the whole
  function: it begins after GetOp and models only the guard order and the
  switch/default classification. L is the emitted twin order and the twin
  wire table generated from twin/ops_ir.py + twin/runtime.inc by
  src/gen_wire_table.py; handler bodies are not edited. Alive2 compares the
  two implementations over symbolic inputs. SAW verifies each leg against an
  independent Cryptol predicate. No crypto, hash, tx, or exception path is
  touched. This is a bounded step cell, not a whole-Engine equivalence proof.
  No Core source patch is used.
---
