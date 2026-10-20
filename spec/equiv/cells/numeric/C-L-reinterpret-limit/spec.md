---
# Cell numeric/C-L-reinterpret-limit
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-reinterpret-limit
family: numeric
tool_status: both-green
precondition: |
  - base sigversion; flags = 0, so fRequireMinimal = false (MINIMALDATA off)
    and the CScriptNum minimality guard is statically off.  nMaxNumSize keeps
    its default of 4.  One input; no cleanstack.
  - The bounded leaf starts with exactly one raw stack element whose length is
    `clamp8(l) = min(l & 15, 8)`.  Its content is a symbolic 64-bit word; bytes
    at index >= length are not part of the element.  Element width 8 and depth
    4 are bounded-leaf representation constants, not consensus limits.
  - `cell_push_raw`: the element is pushed by the raw push path and the script
    ends; no CScriptNum is constructed.
  - `cell_reinterpret`: the same raw element is immediately consumed by
    OP_1ADD (wire 0x8b) and the script ends.
  - `cell_add4_observe`: the element has exactly four bytes, then OP_1ADD.
  - `cell_add4_readd`: exactly four bytes, then two OP_1ADD instructions.
  - No other opcode executes; the entry stack is exactly one element.
postcondition: |
  - `cell_push_raw`: for every length 0..8 the raw push succeeds and no
    SCRIPTNUM error is reachable.  VerifyScript's tail then yields result 1 /
    error 0 when CastToBool of the raw element is true, or result 0 / error 2
    (EVAL_FALSE) otherwise.  The observable carries depth 1, the raw length,
    and raw bytes 0..4; this is the "operands are raw bytes" half.
  - `cell_reinterpret`: result 0 / error 4 (SCRIPT_ERR_SCRIPTNUM) exactly when
    the element length is 5..8; for lengths 0..4 it matches OP_1ADD: decode the
    sign-magnitude value, add 1, serialize with CScriptNum::serialize, and let
    the tail observe result 1, or result 0 / error 2 for the zero result.  The
    width limit is therefore enforced at the reinterpretation site, not at the
    push site.
  - `cell_add4_observe`: the four-byte input is decoded, incremented, and
    serialized.  The result length is at most five.  At w = 0x7fffffff the
    decoded value is 2^31, which serializes to the five bytes
    `00 00 00 80 00` and is observed as a raw stack element with result 1 /
    error 0.  This is the "results may exceed 4 bytes on stack" half.
  - `cell_add4_readd`: the second OP_1ADD re-interprets the serialized first
    result.  It returns result 0 / error 4 exactly at w = 0x7fffffff (the only
    four-byte input whose first result needs five bytes); for every other input
    the second add succeeds and the tail observes the new value.  This is the
    "only re-interpretation enforces the limit" half.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-085
scr_row_coverage: >-
  full for the row's distinguishing claim.  The cell proves the exact 4/5
  boundary on both sides: raw pushes of every length 0..8 never produce
  SCRIPTNUM, while numeric reinterpretation (OP_1ADD) produces SCRIPTNUM
  exactly for lengths greater than 4.  It also proves that a four-byte operand
  can produce a five-byte result that remains a legal raw stack element, and
  that a second numeric operation on that same result is rejected.  The
  symbolic domains are 2^64 content words for each fixed length and all 16
  length inputs (0..8 after clamp8); lengths above 8 and contents beyond the
  five observable bytes are not part of this bounded leaf, but the enforced
  predicate is exactly `len > 4`, already exercised at 5.
patches: none
source_citations:
  - 'script.h:227-236 (numeric-op width comment; results may overflow and are valid until used in a subsequent numeric operation)'
  - 'script.h:246-271 (CScriptNum constructor rejects vch.size() > nMaxNumSize as a script number overflow)'
  - 'script.h:337-340 (getvch returns serialize(m_value))'
  - 'script.h:342-373 (CScriptNum::serialize has no width parameter)'
  - 'script.h:376-391 (set_vch sign-magnitude decode)'
  - 'interpreter.cpp:455-458 (raw push guarded only by MAX_SCRIPT_ELEMENT_SIZE = 520)'
  - 'interpreter.cpp:487-492 (raw push path: stack.push_back(vchPushValue))'
  - 'interpreter.cpp:924-953 (case OP_1ADD: CScriptNum decode, add, getvch push)'
  - 'interpreter.cpp:46-59 (CastToBool)'
  - 'interpreter.cpp:1877-1878 (VerifyScript tail, EVAL_FALSE)'
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin, not the whole EvalScript.  The slice fixes flags = 0,
  so the minimality guard is settled false; operand length is a symbolic input
  of the harness, so the width guard is exercised, not assumed.  L uses the
  OP_1ADD handler copied verbatim from twin/ops_ir.py by
  findings/wave16/07-numeric-ops/tools/mk_num_leaf.py; the raw push is the
  twin's st_push (the runtime.inc push path).  Init/push/tail/pack is cell
  harness.  The bounded runtime primitives (decode_num, encode_num,
  cast_to_bool, memcpy, memcmp) are the twin/runtime.inc bodies unrolled to an
  8-byte element; the rewrite of serialize into a constant-indexed
  little-endian word is byte-for-byte equal in output and is documented in the
  wave-16 notes.  Alive2 compares C and L directly; SAW verifies both against
  an independent Cryptol model: the shared tools/num.cry numeric semantics for
  decode/serialize/OP_1ADD plus the cell-local raw-push observable in
  src/cell_extra.cry.  This is a bounded op cell, not a whole-engine
  equivalence proof.  No Core source patch is used.
---
