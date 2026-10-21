---
# Cell exec-verify/C-L-verify-sequential-boundary
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 8142cff
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: exec-verify/C-L-verify-sequential-boundary
family: exec-verify
tool_status: both-green
precondition: |
  - Base sigversion; SIGPUSHONLY off; P2SH, WITNESS and CLEANSTACK off.
  - The scriptSig is the canonical push of `declared` payload bytes with
    only `after` payload bytes present before the scriptSig buffer end
    (`0 <= after <= declared <= 10000`); scriptPubKey supplies the other
    `declared - after` bytes, so a concatenated parse of
    scriptSig ++ scriptPubKey would see the complete payload.  The
    concatenated buffer is `1 + header_len(declared) + declared` bytes
    (header_len = 0/1/2 for direct/OP_PUSHDATA1/OP_PUSHDATA2); when that
    exceeds MAX_SCRIPT_SIZE = 10000 the family is out of domain (2),
    because EvalScript's pre-check would reject the script before parsing
    (interpreter.cpp:419-421).
  - `truthy` is CastToBool of the pushed element (a Boolean abstraction; the
    byte-level CastToBool rule is SCR-057).
  - `cell_push_boundary` covers every opcode byte 0x00..0xff and every
    declared length (direct, OP_PUSHDATA1/2/4) with
    `after <= MAX_SCRIPT_SIZE = 10000`; outside that bound both legs return
    the out-of-domain sentinel 2, which is unreachable because EvalScript
    rejects `script.size() > 10000` before the parse loop
    (interpreter.cpp:419-421).
  - The stack element encoding of `cell_verify_tail` is the sibling
    exec-verify cells' 0..8-byte word; longer elements are outside the cell.
postcondition: |
  - `cell_push_boundary = 1` exactly when GetScriptOp returns false for the
    push header: the declared payload length exceeds the bytes left before
    the script-buffer end, or the length bytes themselves do not fit.  This
    is proved for every declared length, not by unrolling a parse loop.
  - `cell_split_verdict` returns the (sequential, concatenated) verdict pair:
    sequential = BAD_OPCODE(16) whenever `after < declared` (the scriptSig
    parse is truncated at the scriptSig end); concatenated = the verdict on
    the pushed element (OK if `truthy`, EVAL_FALSE(2) otherwise).  The two
    coincide when the push fits exactly (`after = declared`).
  - `cell_split_diff = 1` iff the sequential and concatenated verdicts
    differ, i.e. iff `after < declared`.  This holds for either truth value:
    sequentially the truncated push is BAD_OPCODE(16); concatenation accepts
    it and then either succeeds (truthy) or yields EVAL_FALSE(2).  This is
    the CVE-2010-5141 distinction: the scriptSig parse is truncated at the
    scriptSig boundary instead of consuming scriptPubKey bytes.
  - `cell_verify_tail`: a scriptSig failure (BAD_OPCODE) wins and the
    scriptPubKey is not evaluated; otherwise the scriptPubKey runs on the
    scriptSig stack (empty scriptPubKey: the decision is CastToBool of the
    scriptSig element; OP_1: the decision is the stack the second evaluation
    produced; OP_0: EVAL_FALSE).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-001
scr_row_coverage: >-
  full for the row's claim, under the row's own EvalScript-outcome premise.
  (1) Script order: VerifyScript evaluates scriptSig first and scriptPubKey
  second on the same stack; a scriptSig error short-circuits and the
  scriptPubKey is never evaluated (cell_verify_tail; the sibling
  exec-verify/C-L-w32-verify-sequential cell proves the same shape with
  OP_DUP and arbitrary post-scriptSig stacks).  (2) No concatenation: the
  scriptPubKey evaluation receives the post-scriptSig stack and the
  scriptPubKey bytes, and the parser is handed the scriptSig buffer end, so a
  push that straddles the boundary is rejected in the sequential model and
  accepted by a concatenated parse (cell_push_boundary, cell_split_verdict,
  cell_split_diff -- complete over every push encoding for every in-domain
  declared length).
  The universal compositional statement for arbitrary scriptPubKey content
  is the already-proven Lean row target
  BitcoinProofs.AF.PDW90.verifyScriptFull_sequential, which is conditional on
  the two EvalScript outcomes exactly as this cell is.  Neither this cell nor
  the row target claims EvalScript's opcode semantics for arbitrary scripts;
  that is the E5 whole-function residual (also SCR-003/SCR-045) and is out of
  this row's claim.  The recorded wave-32 residual for SCR-001 -- the
  CVE-2010-5141 parse-boundary witness -- is discharged here and, for the
  concrete witness, on the pinned Core IR in
  findings/wave66/01-scr-001/.
patches: none
source_citations:
  - interpreter.cpp:2026-2028 (comment: sequential, not concatenated; CVE-2010-5141)
  - interpreter.cpp:2029-2031 (EvalScript(scriptSig) first)
  - interpreter.cpp:2032-2033 (stackCopy save is P2SH-only)
  - interpreter.cpp:2034-2036 (EvalScript(scriptPubKey) second, same stack)
  - interpreter.cpp:2037-2040 (empty/false top -> EVAL_FALSE)
  - interpreter.cpp:419-421 (MAX_SCRIPT_SIZE pre-check before the parse loop)
  - interpreter.cpp:455-456 (GetOp failure -> SCRIPT_ERR_BAD_OPCODE)
  - script.cpp:313-363 (GetScriptOp; push length vs end; OP_PUSHDATA1/2/4)
  - twin/runtime.inc:240-280 (read_le / decode_op boundary)
  - twin/runtime.inc:592-608 (eval_script)
  - twin/runtime.inc:781-805 (verify_script_full, same State across both evals)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:214-227 (getOp boundary)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1363-1390 (verifyScriptFull)
  - spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:36-50
    (verifyScriptFull_sequential)
trust_note: >
  The C leg is a source-excerpt slice of GetScriptOp (script.cpp:313-363),
  EvalScript's GetOp-failure line (interpreter.cpp:455-456) and VerifyScript's
  call order (interpreter.cpp:2026-2040).  The L leg is a reviewed
  transliteration of the generated twin's decode_op / eval_script /
  verify_script_full.  The two legs implement the boundary test differently
  (Core `(unsigned)(end - pc) < nSize` vs twin `k > size - i - prefix`), so
  Alive2 is doing a semantic comparison.  The payload contents and
  CastToBool are abstracted to a Boolean `truthy`; the pushed element's
  byte-level CastToBool is SCR-057, not this row.  The two EvalScript
  *outcomes* for arbitrary scripts are the row-face hypotheses of
  PDW90.verifyScriptFull_sequential; this cell does not prove EvalScript's
  opcode semantics (E5).  The concrete CVE witness is separately proved on
  the pinned Core IR (findings/wave66/01-scr-001/).
mutant: >
  Run in findings/wave66/01-scr-001/mutant: feed the sequential arm the
  concatenated end (replace `hdr + after_op` by `hdr + declared` in
  c_split_pair).  SAW rejects the mutant with the counterexample
  declared = 8334, after = 8191, truthy = 0 (mutant/result.txt), because the
  mutant reports the concatenated verdict where the sequential contract
  reports BAD_OPCODE.  The unmutated cell is green under both tools.
---
