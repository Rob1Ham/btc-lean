---
# Cell tapscript/C-L-w32-tap-codesep-pos
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
cell: C-L-w32-tap-codesep-pos
family: tapscript
tool_status: both-green for the bounded counter model; SCR-167 is PARTIAL
precondition: |
  - A fully parseable script of at most four opcodes, supplied PRE-DECODED:
    for each position, kind in {0 = push, 1 = opcode}, the wire byte, the
    push payload length, and fExec at that opcode.  `pend` is the script
    end offset.
  - Parsing (GetScriptOp) and the vfExec stack computation are premises.
    A push is assumed to consume 1 + payload bytes and one opcode slot.
  - No element-size, stack-size, op-count or disabled-opcode failures (the
    script is assumed valid for these checks).
postcondition: |
  - m_codeseparator_pos starts at 0xFFFFFFFF.
  - opcode_pos is the 0-based parsed-opcode index; it increments by exactly
    1 per parsed opcode, independent of the push payload length, and it
    increments for unexecuted opcodes too (parsing is not execution).
  - An executed OP_CODESEPARATOR records the current opcode_pos; an
    unexecuted OP_CODESEPARATOR records nothing; a later executed one
    overwrites an earlier value.
  - Observable: bits 0..31 = final position, bits 32..63 = final
    opcode_pos.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-167
scr_row_coverage: partial — the counter/assignment semantics, the sentinel,
  the push-length independence and the executed/unexecuted distinction are
  proved for every pre-decoded 4-opcode stream; the byte-level parse
  (GetScriptOp), the fExec derivation from vfExec, the loop bound beyond
  four opcodes, and the switch's other branches are not modelled.  The
  Core loop itself is not executed by either tool.
patches: none
source_citations:
  - "interpreter.cpp:444-446 (opcode_pos = 0; for (; pc < pend; ++opcode_pos))"
  - "interpreter.cpp:445 (m_codeseparator_pos = 0xFFFFFFFFUL)"
  - "interpreter.cpp:1060-1066 (OP_CODESEPARATOR records opcode_pos)"
  - "interpreter.cpp:453-482 (GetScriptOp / pre-checks; premise, not modelled)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:603-604 (opcodeIndex, codeSepPos defaults)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1032 (codeSepPos := opcodeIndex)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1149 (opcodeIndex + 1 per parsed op)"
  - "spec/equiv/twin/ops_ir.py OP_CODESEPARATOR; twin/runtime.inc:216-217,644"
trust_note: >
  C is a line-cited but *bounded unrolling* of the EvalScript loop, not the
  loop: the opcode stream is an input, so GetScriptOp and the vfExec stack
  are premises.  L uses the twin's OP_CODESEPARATOR handler generated
  verbatim by mk_leaf.py and the runtime.inc counter increment; the
  dispatch gate is transcribed from runtime.inc:637-645.  The harness code
  (the four unrolled steps, the packed observable) is cell harness.  This
  cell RESTS ON THE PREMISE that the pre-decoded stream faithfully
  represents the script; the parse seam is F-DIV-001/SCR-045 territory and
  is not proved here.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "count a push as 1+len opcode slots, or record the byte offset instead of the opcode index, or record an unexecuted separator; expect both tools to fail"
mutant_site: "src/c_leaf.cpp C_STEP / src/l_leaf.cpp L_STEP"
---

# Cell `tapscript/C-L-w32-tap-codesep-pos`

SCR-167 is the `m_codeseparator_pos` rule: initialised to `0xFFFFFFFF`,
set to the **0-based opcode index** (not the byte offset) of each executed
`OP_CODESEPARATOR`, where the index counts parsed opcodes including
unexecuted ones and multi-byte pushes as one opcode.

The cell models exactly that counter over a bounded, pre-decoded 4-opcode
stream with symbolic `pend`, opcode kinds, wire bytes, push lengths and
`fExec` bits. The C leg is the line-cited unrolling of
`interpreter.cpp:444-446`/`:1060-1066`; the L leg uses the twin's generated
`OP_CODESEPARATOR` handler and the `runtime.inc` increment.

## Why partial

The row says the update "is in the EvalScript loop and depends on
parsed-but-unexecuted opcodes and multi-byte push counting". The cell
proves those dependencies, but it does not execute Core's parse: the
opcode stream is an input. Proving `GetScriptOp`'s byte advance and the
`vfExec` stack for real script bytes is the same seam as
F-DIV-001 / SCR-045, and the loop is not executed by Alive2 or SAW.

Smallest next experiment: replace the pre-decoded stream with a concrete
or symbolic byte string of length ≤ 8, implement `GetScriptOp`'s
advance rule from `script.cpp` at the pin as a bounded leaf, and prove the
counter over that. That would remove the parse premise but still not the
whole-loop claim.
