---
# Cell tapscript/C-L-w32-op-success-prescan
cell: C-L-w32-op-success-prescan
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (bounded script length 0..4, symbolic bytes)
precondition: |
  - Cell seam: the TAPSCRIPT OP_SUCCESSx pre-scan of ExecuteWitnessScript
    (interpreter.cpp:1846-1862) and the branches it precedes
    (interpreter.cpp:1864-1871).
  - cell_scan_finds_success: the script is any 4-byte value; the length is any
    32-bit value and the cell's domain is len 0..4, so all scripts of length
    <= 4 are covered.  len > 4 returns the harness bad-input marker.
  - cell_prescan_tail: `found` is the scan result; `discourage` is the
    SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS policy bit; `too_many` stands for
    `stack.size() > MAX_STACK_SIZE`; `oversize` stands for "some item size >
    MAX_SCRIPT_ELEMENT_SIZE"; `later_rc` is the uninterpreted packed outcome of
    EvalScript plus the witness cleanstack/CastToBool tail.
  - The script is assumed to be inside the tapscript sigversion (the pre-scan
    only runs there); the initial stack/alt budget inputs are the booleans
    above, not proved here.
  - Malformed tails: the found bit is compared, not the error kind.  Core
    returns BAD_OPCODE from the pre-scan on a truncated push *before* the
    stack-size checks; the Lean model returns false and reaches them.  That
    ordering is outside this cell and is filed separately
    (findings/wave32/27-tapscript-149-155/F-DIV-w32-001).
postcondition: |
  - Packed observable: result(2) | error(6) << 2 | aux << 8.
  - cell_scan_finds_success(len, b0..b3) = 1 iff the pre-scan decodes an
    OP_SUCCESSx before the end of a fully decodable script; 0 on reaching the
    end without one and on a decode failure (the two non-success exits are
    folded, see the precondition note).  Both legs agree for every 4-byte
    script and every len 0..4.
  - cell_prescan_tail(found, disc, too_many, oversize, later):
      found != 0, disc = 0      -> (1, 0)      success, before every later check
      found != 0, disc != 0     -> (0, 36)     DISCOURAGE_OP_SUCCESS (policy)
      found = 0, too_many       -> (0, 8)      STACK_SIZE
      found = 0, oversize       -> (0, 6)      PUSH_SIZE
      found = 0, otherwise      -> later_rc    EvalScript tail, abstracted
  - Both legs return the same packed value for every input, in both directions.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-153, SCR-154
scr_row_coverage: |
  partial for both rows; the bound and the two exclusions are exact:
  - SCR-153 "overrides all later checks (incl. size limits)": partial —
    proved for every script of length <= 4 over all byte values: an OP_SUCCESSx
    returns success before the initial stack-size check, the 520-byte item
    check and EvalScript, and its outcome is independent of those inputs.  Not
    proved: scripts longer than 4 bytes (the scan is straight-line unrolled;
    the 8-byte version was attempted and Alive2 could not discharge it inside
    the 60 s SMT budget), and the BAD_OPCODE-vs-STACK_SIZE ordering on a
    truncated tail (F-DIV-w32-001; the cell compares the found bit only).
  - SCR-154 "pol. flag fails them": partial — same bound: with
    DISCOURAGE_OP_SUCCESS set, every found OP_SUCCESSx in a <= 4-byte script
    yields DISCOURAGE_OP_SUCCESS (36) and not success.  The row is policy
    (consensus=false), and the flag is modelled as a policy input, not as a
    consensus ScriptFlags bit.
  NOT claimed: the EvalScript result for scripts without OP_SUCCESSx
  (`later_rc`), the initial stack-size/item-size preconditions themselves, and
  any script longer than 4 bytes.
patches: none
source_citations:
  - interpreter.cpp:1846-1862 (OP_SUCCESSx pre-scan: GetOp loop, IsOpSuccess, DISCOURAGE_OP_SUCCESS, set_success)
  - interpreter.cpp:1864-1865 (initial stack > MAX_STACK_SIZE -> STACK_SIZE)
  - interpreter.cpp:1868-1871 (item > MAX_SCRIPT_ELEMENT_SIZE -> PUSH_SIZE)
  - interpreter.cpp:1874-1879 (EvalScript, cleanstack, CastToBool)
  - script.cpp:311-362 (GetScriptOp decode/truncation)
  - script.cpp:365-371 (IsOpSuccess)
  - spec/core/Bitcoin/Interpreter/Defs.lean:479-492 (opSuccessScanFrom / opSuccessScan)
  - spec/core/Bitcoin/Interpreter/Defs.lean:463-468 (isOpSuccessWire)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:206-229 (getOpAux / getOp)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1211-1233 (executeWitnessScript pre-scan, size checks, runExec)
  - contract/error_kind.h (BAD_OPCODE 16, PUSH_SIZE 6, STACK_SIZE 8, DISCOURAGE_OP_SUCCESS 36)
trust_note: >
  C is a line-cited source-excerpt slice of ExecuteWitnessScript's pre-scan and
  the three following checks, with the loop unrolled four times so the function
  is loop-free.  L is a reviewed transliteration of the Lean recursive scan and
  Lean's getOp; it keeps Lean's push-vs-op distinction.  The scan is bounded to
  script length <= 4 on both legs (a cell-domain bound, not an engine bound).
  The EvalScript/witness tail is an uninterpreted packed input.  SAW verifies
  each leg against an independent Cryptol fold in src/cell.cry; Alive2 compares
  the -O2 canonical forms of the two IR functions (two-file mode,
  `--always-verify`; see findings/wave32/27-tapscript-149-155 for why the raw
  -O1 form is not used).  No Core source patch is used.  The cell is green for a
  partial row: it does not discharge SCR-153/154 for arbitrary script length.
mutant: >
  Proposed, not executed: move the `if (found)` block below the `too_many`
  check in src/l_leaf.cpp.  Expected Alive2 counterexample at found=1,
  too_many=1 (C=1, L=32), SAW failure on the L leg.
---
