---
# Cell stack-ops/C-L-arity
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-arity
family: stack-ops
tool_status: both-green (55-row bounded arity table; 55 Alive2 + 110 SAW)
precondition: |
  - base sigversion (sv = Base), flags = 0, nOpCount = 0, empty altstack and
    saved stack, no witness, no code separator.
  - One row per (opcode, depth) in table.csv.  The main stack is seeded with
    exactly d one-byte elements (d = row depth, 0 <= d <= 6).  Element i is the
    symbolic byte b_i; for PICK/ROLL the top element (i = d-1) is the
    zero-length index 0, so the boundary row reaches the copy/erase path rather
    than the SCR-075 index-range error.
  - bounded leaf: depth <= 6, element length <= 1 byte (mk_leaf --max-depth 6
    --max-elem 1).  No opcode-budget edge (flags = 0, nOpCount = 0).
  - 16 opcodes: 2DROP 2DUP 3DUP 2OVER 2ROT 2SWAP IFDUP DROP DUP NIP OVER PICK
    ROLL ROT SWAP TUCK (0x6d..0x7d, without OP_DEPTH).
postcondition: |
  - Underflow rows (depth d < arity k), 39 of them: packed failure
    (result = 0, error = INVALID_STACK_OPERATION = 18) for every value of the
    six seed bytes.  The C guard never reads an element, so the row is a pure
    depth test.
  - Boundary rows (depth d = k), 16 of them: the guard admits the depth and the
    case body's net stack effect is post_depth in table.csv (e.g. 2DROP k=2 ->
    0, 3DUP k=3 -> 6, PICK k=2 -> 2, ROLL k=2 -> 1).  The observable also
    carries the uniform 0x01 elements, so the row fails if the handler does not
    run or changes the depth by the wrong amount.
  - Both directions per row: Alive2 compares C-vs-L, SAW verifies each leg
    against the packed constant from an independent Cryptol format spec.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-074
scr_row_coverage: >-
  bounded-full — the arity threshold is pinned from both sides for all 16
  opcodes in the row's 2DROP..TUCK band: every insufficient depth 0..k-1
  (39 underflow rows) and the smallest admitted depth k (16 boundary rows),
  55 rows in total.  The previous state of this cell probed only n = 0, which
  left 23 insufficient-depth rows and all 16 boundary rows unexercised and let
  guard-threshold mutants survive (wave16b audit S2-2); mutations/ now shows
  the added rows kill too-weak and too-strict thresholds.  Non-claims: the
  enumeration is bounded (depth <= 6, one-byte elements, uniform seed); depths
  above k other than the boundary, symbolic depth, element semantics and the
  opcode-budget-first ordering are not claimed here.  The Lean side
  (BitcoinProofs.AF.PDW79b.stepBody_*_depth) already quantifies an arbitrary
  st.stack.length < k; this cell is the bounded C/L witness for the same face.
patches: none
source_citations:
  - src/script/interpreter.cpp:705-708 (OP_2DROP guard), 715-718 (OP_2DUP),
    727-730 (OP_3DUP), 741-744 (OP_2OVER), 753-756 (OP_2ROT), 766-769
    (OP_2SWAP), 776-779 (OP_IFDUP), 795-798 (OP_DROP), 804-807 (OP_DUP),
    814-817 (OP_NIP), 823-826 (OP_OVER), 833-838 (OP_PICK/OP_ROLL), 851-856
    (OP_ROT), 863-866 (OP_SWAP), 872-875 (OP_TUCK) at cce32b168
  - src/script/interpreter.cpp:67-72 (popstack) for the error ordinal path
  - spec/equiv/contract/error_kind.h:49 (EQUIV_ERR_INVALID_STACK_OPERATION=18)
  - research/06-script-interpreter.md:550-559 (Appendix B.5, SCR-074 row)
trust_note: >
  C is a line-cited transcription of Core's per-case `if (stack.size() < K)`
  guard, with the case body's documented net depth for the boundary rows.  It
  is a source-excerpt model: element semantics and reordering are deliberately
  not modelled on the C side.  L calls the handler generated verbatim from
  twin/ops_ir.py by cells/_tools/mk_leaf.py; the seed, the assembly of the
  packed observable and the ABI are cell harness and identical on both legs.
  No Core source patch, no whole-EvalScript claim.  Alive2 needs
  --src-unroll/--tgt-unroll 16 for OP_2ROT's four-iteration shift loop (default
  unroll is 0); the flag is recorded in alive2/result.txt and is used for every
  row.  The cell is a bounded closed-witness table, not a symbolic law.
---
