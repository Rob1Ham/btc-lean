---
# Cell push-encoding/C-L-w32-pushnum
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-pushnum
family: push-encoding
tool_status: both-green (symbolic over all 18 push-number opcodes and MINIMALDATA)
precondition: |
  - base sigversion; fExec = true; empty input stack.
  - the single executed opcode is selected by sel:
    sel 0 = OP_0 (0x00), sel 1 = OP_1NEGATE (0x4f), sel 2..17 = OP_1..OP_16
    (0x51..0x60).
  - MINIMALDATA policy bit is symbolic (both values covered).
  - no other opcode executes; the final EVAL_FALSE tail is applied to the
    produced stack as VerifyScript does.
postcondition: |
  - the executed opcode leaves exactly one stack element:
    OP_0 -> empty; OP_1NEGATE -> {0x81}; OP_n -> {n as one byte}.
  - packed observable: res=1, err=OK(0), depth=1, len, first byte, and the
    final verdict (0 = EVAL_FALSE for OP_0, 1 otherwise).
  - both legs agree for every sel and every MINIMALDATA value.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-046, SCR-047
scr_row_coverage: >-
  full for both rows under the stated single-opcode domain.  SCR-046:
  OP_0 produces the empty vector and OP_1..OP_16 produce the single bytes
  0x01..0x10, all 17 opcodes covered symbolically.  SCR-047: OP_1NEGATE
  produces 0x81 (CScriptNum(-1).getvch / encodeScriptNum(-1) false) and is
  independent of MINIMALDATA, proved for both policy values.  The cell does
  not cover OP_1..OP_16 in an unexecuted branch (that is SCR-049) or the
  PUSHDATA1/2/4 encodings (SCR-045).
patches: none
source_citations:
  - interpreter.cpp:499-503 (pushdata branch: OP_0's empty vector, MINIMALDATA gate)
  - interpreter.cpp:415-427 (CScriptNum::getvch)
  - interpreter.cpp:527-546 (OP_1NEGATE / OP_1..OP_16 push)
  - interpreter.cpp:1876-1880 (EVAL_FALSE tail)
  - Defs.lean:836-846 (stepBody .pushBytes/.pushNum)
  - Parser/Defs.lean:26-30, 200-221 (OP_0 / OP_1NEGATE / OP_n AST convention)
  - Numeric/Interface.lean:55-56 (encodeScriptNum)
  - twin/runtime.inc:159-163 (st_push_num), 246-258 (decode_op push kinds)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin.  L is the Lean stepBody push semantics transcribed verbatim from
  the generated twin (st_push_num + encode_num), restricted to the reachable
  values -1..16 and a two-element stack.  The CastToBool tail is copied from
  the twin.  The cell is a bounded single-opcode result, not a whole-
  EvalScript equivalence proof.  No Core source patch is used.
---
