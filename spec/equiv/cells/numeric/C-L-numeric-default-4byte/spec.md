---
# Cell numeric/C-L-numeric-default-4byte
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-numeric-default-4byte
family: numeric
tool_status: both-green (Alive2 --bidirectional, 7/7; SAW z3, 14/14)
precondition: |
  - flags = 0, so CScriptNum's fRequireMinimal (MINIMALDATA) is false and the
    minimality guard is statically off.  The cap under test is the constructor
    default, not a passed argument.
  - sigversion = TAPSCRIPT for site 5 only (OP_CHECKSIGADD returns BAD_OPCODE
    under BASE/WITNESS_V0); sites 1-4 and 6-7 are the BASE/WITNESS_V0 code
    paths (OP_CHECKMULTISIG returns TAPSCRIPT_CHECKMULTISIG before its count
    decodes under tapscript).  The decode statement itself is
    sigversion-independent.
  - the cell has one entry point per CScriptNum decode site in EvalScript that
    omits the size argument, i.e. that takes nDefaultMaxNumSize = 4:
      site 1  interpreter.cpp:840        OP_PICK / OP_ROLL depth
      site 2  interpreter.cpp:939        OP_1ADD .. OP_0NOTEQUAL   (6 wires)
      site 3  interpreter.cpp:972-973    OP_ADD .. OP_MAX          (13 wires)
      site 4  interpreter.cpp:1017-1019  OP_WITHIN                (3 operands)
      site 5  interpreter.cpp:1103       OP_CHECKSIGADD (tapscript)
      site 6  interpreter.cpp:1126       OP_CHECKMULTISIG nKeysCount
      site 7  interpreter.cpp:1140       OP_CHECKMULTISIG nSigsCount
  - each decoded operand is a bounded element of length `l & 7` with content
    word `w` symbolic over 2^32: lengths 0..4 are the complete 4-byte
    CScriptNum operand domain, lengths 5..7 are the width-cap reject edge.
  - the site's entry stack is built exactly as the case block expects it
    (depth 1..3, plus the two fillers OP_CHECKSIGADD reads around the operand);
    stack underflow is not in the domain (SCR-078 owns it).
  - site 7 fixes nKeysCount to its one-byte encoding of 0 ({0x00}) so the
    preceding decode, the PUBKEY_COUNT range test and the `stack.size() < i`
    test pass deterministically and `stacktop(-(2+nKeysCount))` is the
    nSigsCount element; site 6 covers the nKeysCount operand itself.
postcondition: |
  - accepted arm (length <= 4): status 1, error 0, and the value field carries
    the int64 that set_vch produces for the operand, i.e. exactly the value the
    site consumes.
  - size-limit/error arm (length 5..7): the constructor's `vch.size() >
    nMaxNumSize` guard fires; status 0 and error 4 (SCRIPT_ERR_SCRIPTNUM), the
    error EvalScript's catch sets for scriptnum_error.
  - for the two-operand and three-operand sites the Core order is preserved
    (bn1 then bn2; x, min, max) and the observable is the last operand decoded;
    any over-long operand yields the same error 4.
  - packed observable (dflt_common.h):
    status(2) | error(6)<<2 | site(4)<<8 | value(33)<<12.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-080
scr_row_coverage: >-
  decode-boundary coverage of every default-4 CScriptNum site in EvalScript:
  all 24 numeric opcodes whose operand decode takes the default (PICK, ROLL,
  1ADD, 1SUB, NEGATE, ABS, NOT, 0NOTEQUAL, ADD, SUB, BOOLAND, BOOLOR,
  NUMEQUAL, NUMEQUALVERIFY, NUMNOTEQUAL, LESSTHAN, GREATERTHAN,
  LESSTHANOREQUAL, GREATERTHANOREQUAL, MIN, MAX, WITHIN, CHECKSIGADD,
  CHECKMULTISIG) are mapped to one of the seven sites, and each site is proved
  for both arms over the full bounded operand domain.  The normal-arm op
  results are NOT re-proved here: they are green in
  cells/numeric/C-L-unary-4byte, C-L-binary-4byte and C-L-within-4byte (which
  also cover lengths 5..7), and the post-decode stack/depth/count/signature
  behaviour is owned by SCR-078, SCR-086, SCR-090 and SCR-114..117.  The
  clamp/range branches after the decode are out of this row.
patches: none
source_citations:
  - script.h:227-271 (CScriptNum; nDefaultMaxNumSize = 4 at :242, the default
    argument at :244-247, the width guard at :247-249, minimality at :250-268)
  - script.h:270 / 376-391 (set_vch sign-magnitude decode)
  - interpreter.cpp:840 (OP_PICK / OP_ROLL)
  - interpreter.cpp:929-953 (unary numeric ops; decode at :939)
  - interpreter.cpp:955-1010 (binary numeric ops; decodes at :972-973)
  - interpreter.cpp:1012-1026 (OP_WITHIN; decodes at :1017-1019)
  - interpreter.cpp:1097-1103 (OP_CHECKSIGADD; decode at :1103)
  - interpreter.cpp:1119-1140 (OP_CHECKMULTISIG; decodes at :1126, :1140)
  - interpreter.cpp:432-437, 1236-1238 (scriptnum_error catch ->
    SCRIPT_ERR_SCRIPTNUM)
  - interpreter.cpp:556, 584 (the two explicit 5-byte sites, excluded: SCR-081)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.h and
  interpreter.cpp at the pin, not the whole of EvalScript.  The constructor's
  signature and default argument are transcribed verbatim; every site calls it
  with two arguments, so the emitted IR passes nMaxNumSize = 4 as a constant.
  The throw is modelled as an error field on the constructor, because an
  `invoke`/landingpad path is not expressible in Alive2; the observed error is
  the same SCRIPT_ERR_SCRIPTNUM that EvalScript's catch sets.  The slice stops
  at the decode boundary: the operand is decoded, no op body is executed, so
  the postcondition is "the site accepts length <= 4 with value v, and rejects
  length > 4", which is exactly the SCR-080 check.  L uses the twin's own
  decode_num at the same seven sites with the same literal cap 4 (the twin has
  no default argument), mapped to Core ordinals by the generated core_ord; the
  handler bodies after the decode are not re-run.  SAW verifies both legs
  against an independent Cryptol model (src/cell.cry) written from script.h,
  interpreter.cpp and the Lean script-number equations.  This is a bounded
  decode cell, not a whole-engine or exhaustiveness proof: the site list is a
  source-reading claim, and the cell proves each listed site, not that the list
  is complete.  No Core source patch is used.
---
