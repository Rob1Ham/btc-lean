---
# Cell exec-verify/C-L-w32-verify-sequential
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: exec-verify/C-L-w32-verify-sequential
family: exec-verify
tool_status: both-green
precondition: |
  - Base sigversion; SIGPUSHONLY off; P2SH, WITNESS, CLEANSTACK off (the
    bare non-P2SH face of SCR-001).
  - scriptSig = the declared seam: its EvalScript outcome is a symbolic
    error ordinal `ss_err` or success leaving stack `(ss_depth, ss_top,
    ss_top_len)`. This is the `hss` hypothesis of the Lean row face
    (PDW90.lean:39-50).
  - scriptPubKey = the single opcode OP_DUP (0x76), taken from
    interpreter.cpp:804-811 plus the loop size check at 1231-1233. It is
    applied to the post-scriptSig stack, not to a fresh stack.
  - Domain guards: `ss_top_len <= 8` (element encoding) and
    `ss_depth <= 1000` (a post-scriptSig stack deeper than MAX_STACK_SIZE is
    unreachable). Outside the guards both legs return UNKNOWN.
postcondition: |
  - result(2) | error_kind(6) << 2 is:
      ss_err != 0                  -> (0, ss_err)   scriptSig failure wins
      ss_err = 0, ss_depth = 0     -> (0, 18)       DUP underflow on the same stack
      ss_err = 0, ss_depth >= 1000 -> (0, 8)        STACK_SIZE after DUP
      otherwise                    -> final stack depth ss_depth+1, top is the
                                      scriptSig top: (1,0) if it casts true,
                                      (0,2) EVAL_FALSE if it casts false
  - In particular the truth decision is a function of the *post-scriptSig*
    stack: the scriptPubKey evaluation consumed and reproduced it, so the two
    evaluations are sequential on one stack.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-001
scr_row_coverage: >-
  partial. Proved: (a) a scriptSig EvalScript error short-circuits before the
  scriptPubKey evaluation; (b) the scriptPubKey evaluation is applied to the
  post-scriptSig stack (depth, top and length are carried in, not reset and
  not concatenated); (c) the OP_DUP underflow and MAX_STACK_SIZE edges on that
  stack; (d) the final decision is taken on the stack the second evaluation
  produced. NOT proved: the CVE-2010-5141 parse-boundary witness (a push in
  scriptSig whose declared length would run into scriptPubKey bytes is
  truncated at the scriptSig end instead of consuming scriptPubKey). That
  needs GetScriptOp/the script-buffer boundary and the EvalScript loop, which
  this cell does not model; it is filed as the exact blocker in the wave-32
  report.
patches: none
source_citations:
  - interpreter.cpp:2026-2028 (comment: sequential, not concatenated; CVE-2010-5141)
  - interpreter.cpp:2029-2031 (EvalScript(scriptSig))
  - interpreter.cpp:2032-2033 (stackCopy save is P2SH-only)
  - interpreter.cpp:2034-2036 (EvalScript(scriptPubKey))
  - interpreter.cpp:2037-2040 (empty/false top)
  - interpreter.cpp:804-811 (OP_DUP handler)
  - interpreter.cpp:1231-1233 (size limit after each opcode; MAX_STACK_SIZE 1000)
  - twin/ops_ir.py OP_DUP (Lean Defs.lean:957-959) and twin/runtime.inc:117-128
    (st_push_copy; `if (s.n >= MAX_STACK_SIZE) return TWIN_STACK_SIZE`)
  - Defs.lean:1376-1383 (verifyScriptFull sequential shape)
  - spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:36-50 (verifyScriptFull_sequential)
trust_note: >
  The C leg is a source-excerpt slice of VerifyScript plus the OP_DUP handler;
  the scriptSig evaluation outcome is an input (row-face hypothesis), and the
  scriptPubKey handler is modelled rather than abstracted. The L leg is a
  reviewed transliteration of the Lean/twin shape, with the twin's
  st_push_copy cap and the Lean castToBool. Alive2 compares the two IR modules
  with --always-verify; SAW verifies each against one Cryptol function. The
  first Alive2 run produced a real counterexample at ss_depth = 2^64-1 (the C
  leg's `n += 1` wraps before the size check while the twin's `n >= 1000`
  does not); the divergence is outside the reachable domain, so the cell now
  guards `ss_depth > 1000` explicitly and records the run in notes.md.
mutant: >
  Proposed, not executed: replace the second evaluation's input stack by an
  empty stack (`ss_depth = 0`, `ss_top = 0`) in the L leg. Expected Alive2
  counterexample for any successful scriptSig, because the truth decision no
  longer depends on the scriptSig stack.
---
