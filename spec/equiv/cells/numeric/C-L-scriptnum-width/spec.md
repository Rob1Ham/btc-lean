---
# Cell numeric/C-L-scriptnum-width
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-scriptnum-width
family: numeric
tool_status: both-green
precondition: |
  - base sigversion; flags = 0 (fRequireMinimal / MINIMALDATA false); one
    input; no cleanstack.  nMaxNumSize keeps CScriptNum's default of 4
    (script.h:242,244), so the width guard is `vch.size() > 4`.
  - the operand is one bounded element of length `num_len8(l)`: the harness
    exposes a 4-bit length `l` and folds 9..15 to 8, so every representable
    length 0..8 occurs.  Its content is a symbolic 64-bit word (2^64 byte
    patterns).  Element width 8 and depth 4 are bounded-leaf representation
    constants, not consensus limits.
  - `cell_scriptnum` exercises the CScriptNum constructor alone; on success
    it pushes `bn.getvch()` and applies the VerifyScript tail.
  - `cell_1add` has entry stack exactly [x] and closed dispatch to wire 0x8b
    (OP_1ADD); no other opcode executes.
postcondition: |
  - width reject, i.e. length in 5..8 (`vch.size() > 4`, script.h:247-249):
    the constructor fails, EvalScript's catch sets SCRIPT_ERR_SCRIPTNUM, so
    the packed observable is result 0, error 4, no stack: 0x10.  This is the
    exact error ordinal (4), not merely "some error".
  - accept, i.e. length in 0..4: the decoded sign-magnitude value is
    canonicalised by `bn.getvch()`.  If it is nonzero the tail observes
    result 1, error 0, depth 1, len = encLen(v), bytes = the encoding; if it
    is 0 (including the negative-zero wires) the empty top trips EVAL_FALSE,
    result 0, error 2, depth 1, len 0.
  - `cell_1add`: the same reject observable on 5..8; on 0..4 the pushed value
    is v+1 before the tail.  In particular a 5-byte operand yields
    SCRIPT_ERR_SCRIPTNUM *before* any arithmetic.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-079
scr_row_coverage: >-
  full for the constructor row and its first opcode consumer.  The executable
  obligations are exact over the whole bounded leaf domain: every length
  0..8 times every one of the 2^64 content words, for both entry points.
  Lengths 0..4 are the accept region (no SCRIPTNUM error is ever produced);
  lengths 5..8 are the reject region and all four map to ordinal 4.  The
  guard is a single `len > 4` comparison (script.h:247-249) and so is
  monotone in length: lengths 9..MAX_SCRIPT_ELEMENT_SIZE (520) are rejected
  by the same predicate.  The any-length statement `b.size > k ⇒
  decodeNum pol b k = .error .scriptNum` is proved in Lean
  (Bitcoin/Numeric/Interface.lean:`scriptNum_width_rule`,
  `scriptNum_four_byte_rule_any`; Bitcoin/Numeric/RowFaces.lean:
  `decodeNum_overflow_error`), so the cell plus that theorem closes the row.
  Not this row: stack underflow (SCR-078), the nMaxNumSize=5 CLTV/CSV sites
  (SCR-081), the minimality guard (SCR-083/084, off here because flags = 0),
  and "every numeric opcode decodes at 4" (SCR-080).
patches: none
source_citations:
  - script.h:242,244 (nMaxNumSize default 4)
  - script.h:246-271 (CScriptNum ctor; width guard at 247-249 precedes the
    minimality guard at 250-268)
  - script.h:376-391 (set_vch sign-magnitude decode)
  - script.h:337-340,342-373 (getvch / serialize)
  - interpreter.cpp:432-437 (catch (scriptnum_error) -> SCRIPT_ERR_SCRIPTNUM)
  - interpreter.cpp:1120-1122 (case OP_1ADD)
  - interpreter.cpp:1877-1878 (VerifyScript tail, EVAL_FALSE)
  - twin/runtime.inc:167-193 (twin decode_num, scriptnum_error mapping)
  - twin/ops_ir.py OP_1ADD (wires 0x8b, Defs.lean:1003-1007)
  - Defs.lean:626-633 (decodeNum -> Except.error .scriptNum)
  - Numeric/Interface.lean:128-158 (scriptNum_width_rule and
    scriptNum_four_byte_rule_any)
  - Numeric/RowFaces.lean:36-64 (decodeNum_overflow_error, ordinals)
  - Theorems/Exhaust/ScriptNumBoundary4.lean:298-320 (width-gate rows,
    including the 5-byte only -2^31 encoding)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.h and
  interpreter.cpp at the pin, using num_core.h.  The two model deviations are
  inherited from that shared excerpt and apply identically to every numeric
  cell: the std::vector is a bounded (value,len) element and the
  scriptnum_error throw is an error return carrying EQUIV_ERR_SCRIPTNUM, the
  value EvalScript's catch sets.  L is the twin's own decode_num and
  st_push_num from twin/runtime.inc, re-bound to an 8-byte element by
  mk_num_leaf.py, plus op_OP_1ADD verbatim from twin/ops_ir.py.  Alive2
  compares C and L directly for every 64-bit word and 32-bit length input;
  SAW verifies each leg against the independent Cryptol model num.cry
  (`decodeOk`/`decode`/`obs`/`errObs`, and `pUnary` for OP_1ADD).  This is a
  bounded constructor/op cell, not a whole-engine equivalence proof, and no
  Core patch is used.
---
