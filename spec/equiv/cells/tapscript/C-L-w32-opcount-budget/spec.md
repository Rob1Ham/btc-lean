---
# Cell tapscript/C-L-w32-opcount-budget
cell: C-L-w32-opcount-budget
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (total symbolic guard + one-OP_NOP witness path)
precondition: |
  - Cell seam: the MAX_OPS guard of EvalScript (interpreter.cpp:460-464) and
    its absence on the tapscript path, plus one concrete opcode (OP_NOP) whose
    handler is a no-op.
  - Inputs: SigVersion 0=BASE, 1=WITNESS_V0, 2=TAPSCRIPT (other values are the
    harness bad-input marker); nOpCount 0..10000 (a script is at most 10000
    bytes and nOpCount grows at most once per opcode plus at most 20 per
    CHECKMULTISIG key, so larger values are unreachable); any wire byte
    0x00..0xff; CastToBool(top) arbitrary for the OP_NOP function.
  - For cell_nop_overbudget only: script is exactly {OP_NOP}; the initial stack
    is exactly one item of at most 520 bytes; the initial main+alt stack is at
    most 1000 items; the witness validation weight is available.  Those are
    preconditions, not proved here (SCR-021, SCR-031, SCR-040).
  - The script in cell_nop_overbudget must also pass the tapscript OP_SUCCESSx
    pre-scan (no OP_SUCCESSx byte), which {OP_NOP} does; see SCR-153/154.
postcondition: |
  - Packed observable: result(2) | error(6) << 2 | nOpCount(32) << 8.
  - cell_opcount_guard(sv, wire, oc), every input in the domain:
      sv in {BASE, WITNESS_V0}, wire > 0x60, oc + 1 > 201
                                    -> (0, 7)  OP_COUNT,  aux = oc + 1
      sv in {BASE, WITNESS_V0}, wire > 0x60, oc + 1 <= 201
                                    -> (1, 0),  aux = oc + 1
      sv in {BASE, WITNESS_V0}, wire <= 0x60
                                    -> (1, 0),  aux = oc
      sv = TAPSCRIPT, any wire      -> (1, 0),  aux = oc
    i.e. the budget is consulted iff (BASE or WITNESS_V0) and wire > OP_16;
    on the tapscript path nOpCount is never incremented and never compared.
  - cell_nop_overbudget(sv, oc, top_true), every input in the domain:
      sv in {BASE, WITNESS_V0}, oc >= 201
                                    -> (0, 7)  OP_COUNT,  aux = oc + 1
      sv in {BASE, WITNESS_V0}, oc < 201, top_true = 0
                                    -> (0, 2)  EVAL_FALSE, aux = oc + 1
      sv in {BASE, WITNESS_V0}, oc < 201, top_true != 0
                                    -> (1, 0),  aux = oc + 1
      sv = TAPSCRIPT, top_true = 0  -> (0, 2)  EVAL_FALSE, aux = oc
      sv = TAPSCRIPT, top_true != 0 -> (1, 0),  aux = oc
  - Both legs return the same packed value for every input, in both directions.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-155
scr_row_coverage: |
  full for the row as stated.  The row has two halves:
  (1) "the MAX_OPS budget is not consulted on the tapscript path: an
      already-over-budget tapscript OP_NOP still succeeds and leaves opCount
      untouched" — cell_opcount_guard proves no OP_COUNT for every wire byte and
      every nOpCount when sv = TAPSCRIPT, with aux = oc; cell_nop_overbudget
      proves the concrete OP_NOP outcome is success for a truthy one-item stack
      and still EVAL_FALSE (not OP_COUNT) for a false one, with aux = oc.
  (2) "on BASE/WITNESS_V0 an over-budget counting opcode instead returns
      OP_COUNT" — both functions prove OP_COUNT for wire > 0x60 / OP_NOP with
      oc + 1 > 201, and the exact increment otherwise.
  Note the reachability caveat: in a real tapscript evaluation nOpCount starts
  at 0 and is never incremented, so oc > 201 is not reachable *within* one
  tapscript EvalScript; the row's statement is counterfactual over the state,
  and the cell proves exactly that (arbitrary oc).  The cell does not claim
  that a script can reach such a state.
patches: none
source_citations:
  - interpreter.cpp:455-458 (nOpCount declaration)
  - interpreter.cpp:459-464 (BASE/WITNESS_V0 guard, opcode > OP_16, ++nOpCount > MAX_OPS_PER_SCRIPT)
  - interpreter.cpp:529-530 (case OP_NOP: break;)
  - interpreter.cpp:1846-1865 (tapscript pre-scan and initial stack-size check precede EvalScript)
  - interpreter.cpp:1870-1879 (EvalScript result, cleanstack, CastToBool)
  - script.h:32 (MAX_OPS_PER_SCRIPT = 201)
  - spec/core/Bitcoin/Interpreter/Defs.lean:816-836 (stepBody guard)
  - spec/core/Bitcoin/Interpreter/Defs.lean:856 (OP_NOP)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1238-1239 (cleanstack / castToBool)
  - contract/error_kind.h (EVAL_FALSE 2, OP_COUNT 7)
trust_note: >
  C is a line-cited source-excerpt slice of interpreter.cpp/EvalScript at the
  pin, not the whole EvalScript; the static/stack/alt traversal, script parse
  and every other opcode are outside the cell.  L is a reviewed transliteration
  of the Lean stepBody guard written in Lean's form (0x60 < w, opCount + 1).
  The generated twin has no whole-step entry, so mk_leaf.py emits nothing for
  this guard.  SigVersion ids, the nOpCount <= 10000 domain bound and the
  packed observable are cell harness, stated in src/ and spec.md.  SAW verifies
  each leg against the independent Cryptol function in src/cell.cry; Alive2
  compares the -O2 canonical forms of the two IR functions directly (two-file
  mode, `--always-verify`).  No Core source patch is used.
mutant: >
  Proposed, not executed: delete the `sv == 0 || sv == 1` condition in
  src/l_leaf.cpp so the guard also applies to TAPSCRIPT.  Expected Alive2
  counterexample at sv=2, wire=0x61, oc=201 (C=1, L=0/OP_COUNT); SAW failure on
  the L leg.
---
