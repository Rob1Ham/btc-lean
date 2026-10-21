---
# Cell numeric/C-L-w64-negzero
cell: C-L-w64-negzero
family: numeric
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c02
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic predicate over the declared domain)
consensus: true
precondition: |
  - Base sigversion, flags 0. The numeric operand path constructs
    CScriptNum(vch, fRequireMinimal, 4); fRequireMinimal = false here (the
    minimality rule is SCR-084, not this row).
  - One stack element as the little-endian byte vector b0..b3 with a
    symbolic uint32 length. The in-domain lengths are 0..4, the default
    nMaxNumSize (script.h:244,246-249). len > 4 is the constructor's
    width-guard failure, represented by SCRIPT_ERR_SCRIPTNUM = 4
    (contract/error_kind.h; the error EvalScript's catch sets at
    interpreter.cpp:432-437).
  - The decode is asked for its int64 value and CastToBool is asked for the
    same raw bytes. No opcode executes and no serialization is modelled.
postcondition: |
  - Packed observable: err(8) | decoded value(32) at bit 8 | CastToBool(1)
    at bit 40.
  - len > 4 -> 4 (err = SCRIPT_ERR_SCRIPTNUM, value 0, cast 0).
  - len == 0 -> 0: set_vch of the empty vector is 0 and CastToBool is false.
  - otherwise value is the sign-magnitude set_vch result (script.h:376-391)
    and cast is the interpreter.cpp:46-61 predicate on the same bytes.
  - Negative zero: every encoding 0x00...0x80 with 0x80 in the
    most-significant (wire-last) position and zeros below, for lengths
    1..4, decodes to 0 and casts to false. A 0x80 that is *not* in the
    top position, or whose lower bytes are not all zero, is an ordinary
    positive magnitude.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-083
scr_row_coverage: >-
  full for the default four-byte CScriptNum operand domain. The cell proves
  both halves of the row universally over every wire vector b0..b3 and every
  length 0..4: 0x80 (and the longer negative-zero encodings 00 80,
  00 00 80, 00 00 00 80) decodes to 0, and CastToBool is false for the lone
  0x80 and for every all-zero vector, while a non-top 0x80 or a nonzero
  lower byte is true. Bound: elements longer than four bytes are not in the
  domain. That excludes the five-byte CLTV/CSV operand (SCR-081) and
  multi-byte results produced on the stack (SCR-085); CastToBool for those
  lengths is not claimed here and is not part of this row's named vector.
coverage: full (bounded four-byte operand domain)
patches: none
evidence:
  - alive2/result.txt, alive2/certificate.sha256 (raw alive-tv v20 output, both directions)
  - saw/result.txt, saw/certificate.sha256 (raw SAW 1.6 output, both legs)
  - ir/ (c_leaf.ll, l_leaf.ll, c_cell_negzero.ll, l_cell_negzero.ll,
    build.txt; tracked, so the certificates hash exactly the modules
    presented to alive-tv and SAW)
  - concrete_check.out (C and L agree on 13 corner vectors; driver in
    _tools/concrete_check.cpp)
source_citations:
  - "script.h:376-391 (set_vch; the negative-zero arm is 387-390)"
  - "script.h:244,246-271 (CScriptNum default nMaxNumSize = 4 and width guard)"
  - "interpreter.cpp:46-61 (CastToBool; the 0x80 top-byte exception)"
  - "interpreter.cpp:423-425 (vchTrue/vchFalse statics, context only)"
  - "interpreter.cpp:432-437 (scriptnum_error -> SCRIPT_ERR_SCRIPTNUM)"
  - "contract/error_kind.h (EQUIV_ERR_SCRIPTNUM = 4)"
  - "spec/core/Bitcoin/Numeric/ScriptNum.lean:449-458 (setVchBE), 648-652 (castToBoolList)"
trust_note: |
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin, not the whole EvalScript. The set_vch byte loop and
  the CastToBool loop are fully unrolled to the constant four-byte element
  bound with an `i < n` guard; this changes no semantics and keeps the leaf
  loop-free. The width guard is preserved and is the only error path.
  L is a reviewed transliteration of the pinned Lean equations setVchBE and
  castToBoolList, written from the equations, not generated from the twin
  and not copied from the C leg. SAW verifies both legs against an
  independent Cryptol model of the two source functions for all 2^32
  wire vectors and every uint32 length; Alive2 checks both refinement
  directions. The packed observable is harness and identical by
  construction. No Core patch,
  pin change, twin change, ledger edit or shared-tool edit is used.
---
