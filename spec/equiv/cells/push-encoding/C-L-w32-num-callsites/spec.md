---
# Cell push-encoding/C-L-w32-num-callsites
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: push-encoding/C-L-w32-num-callsites
family: push-encoding
tool_status: both-green (Alive2 bidirectional, 4/4 functions; SAW 8/8 proofs)
precondition: |
  - the handler has been reached: OP_CHECKSIGADD's BAD_OPCODE and
    stack-underflow gates are part of the cell; the EvalScript `fExec` gate,
    the 201-op budget and the size/disabled-opcode checks are outside it, as
    in every handler-level cell of this family.
  - each decoded operand is a five-byte buffer plus a length byte whose low
    three bits are the operand length 0..7.  Lengths 3, 4 and 5 are the
    widths where the two caps differ (4 for the CHECKMULTISIG counts and the
    CHECKSIGADD number, 5 for CLTV/CSV); 6 and 7 exercise the width rejection.
  - fRequireMinimal is the MINIMALDATA policy bit (symbolic, both values).
  - stack depth and the opcode budget counter are symbolic 32-bit values; the
    transaction context (nLockTime, nVersion, input nSequence) is symbolic
    32-bit and is the only environment the handlers read.
  - the activation flag (CLTV or CSV) is symbolic: with the flag absent the
    opcode is a NOP and the operand is never decoded.
postcondition: |
  - both legs return the same packed observable
    result(2) | error_kind(6) << 2:
      CLTV : flag off -> OK; depth < 1 -> INVALID_STACK_OPERATION;
             decode(cap 5) error -> SCRIPTNUM; n < 0 -> NEGATIVE_LOCKTIME;
             !CheckLockTime -> UNSATISFIED_LOCKTIME; else OK.
      CSV  : flag off -> OK; depth < 1 -> INVALID_STACK_OPERATION;
             decode(cap 5) error -> SCRIPTNUM; n < 0 -> NEGATIVE_LOCKTIME;
             n & SEQUENCE_LOCKTIME_DISABLE_FLAG -> OK (NOP);
             !CheckSequence -> UNSATISFIED_LOCKTIME; else OK.
      CMS  : depth < 1 -> INVALID_STACK_OPERATION;
             key count decode(cap 4) error -> SCRIPTNUM;
             < 0 or > 20 -> PUBKEY_COUNT; opcount + nKeys > 201 -> OP_COUNT;
             depth < nKeys + 2 -> INVALID_STACK_OPERATION;
             sig count decode(cap 4) error -> SCRIPTNUM;
             < 0 or > nKeys -> SIG_COUNT;
             depth < nKeys + nSigs + 3 -> INVALID_STACK_OPERATION; else OK.
      CHECKSIGADD : base/witnessV0 -> BAD_OPCODE; depth < 3 ->
             INVALID_STACK_OPERATION; number decode(cap 4) error ->
             SCRIPTNUM; else OK (the EvalChecksig outcome does not affect the
             verdict that this cell observes).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-051
scr_row_coverage: >-
  partial (narrowed) — this cell adds the handler-level call sites that the
  decode-law cell did not cover: OP_CHECKLOCKTIMEVERIFY (cap 5, with
  NEGATIVE_LOCKTIME, type match, locktime comparison and final-sequence
  rejection), OP_CHECKSEQUENCEVERIFY (cap 5, with the disable-flag NOP and
  CheckSequence), the two OP_CHECKMULTISIG count decodes (cap 4, with
  PUBKEY_COUNT / OP_COUNT / SIG_COUNT / arity ordering) and OP_CHECKSIGADD's
  number decode (cap 4, with the tapscript-only BAD_OPCODE gate).  All five
  cited lines (556, 584, 1103, 1126, 1140) are exercised.  Still not covered:
  (a) the L leg is a reviewed transcription of the Lean Defs.lean handler
  arms, not generated twin handler code, because twin/ops_ir.py has no CLTV/CSV
  decode and no CHECKMULTISIG handler (see notes.md — the exact blocker);
  (b) CHECKMULTISIG signature verification, NULLDUMMY/NULLFAIL handling and
  FindAndDelete are outside the cell (the count decode precedes them);
  (c) OP_CHECKSIGADD's EvalChecksig is abstracted (same-crypto premise) and the
  pushed result value is not observed.  The MINIMALDATA row itself is a policy
  face; this cell does not claim consensus behaviour of the operands.
patches: none
source_citations:
  - interpreter.cpp:534-571 (OP_CHECKLOCKTIMEVERIFY, incl. :556 cap 5)
  - interpreter.cpp:574-602 (OP_CHECKSEQUENCEVERIFY, incl. :584 cap 5)
  - interpreter.cpp:1755-1788 (GenericTransactionSignatureChecker::CheckLockTime)
  - interpreter.cpp:1791-1844 (GenericTransactionSignatureChecker::CheckSequence)
  - interpreter.cpp:1097-1109 (OP_CHECKSIGADD, incl. :1103 cap 4)
  - interpreter.cpp:1113-1152 (OP_CHECKMULTISIG counts, :1126 and :1140)
  - script.h:246-271 (CScriptNum(vch, fRequireMinimal, nMaxNumSize))
  - script.h:376-391 (set_vch)
  - Defs.lean:272-280 (checkLockTimeDef)
  - Defs.lean:285-296 (checkSequenceDef)
  - Defs.lean:803-811 (checksigAddStep)
  - Defs.lean:857-875 (OP_CLTV/OP_CSV arms)
  - Defs.lean:1048-1059 (OP_CHECKSIGADD arm)
  - Defs.lean:1069-1090 (stepBody.checkMultiSig count decode)
  - twin/runtime.inc:167-188 (decode_num, called by the L leg)
  - twin/ops_ir.py:42-50,55-61 (CLTV/CSV return TWIN_INVALID_UNSUPPORTED)
  - twin/gen.py:222-225 (CHECKMULTISIG listed unsupported)
  - Defs.lean PDW98 (decodeNum_nonminimal, stepBody_{cltv,csv}_nonminimal,
    checkMultiSig_{key,sig}count_nonminimal, stepBody_checksigadd_nonminimal)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin: CScriptNum is specialised to a five-byte operand and
  set_vch is unrolled under the width guard; the handlers keep Core's check
  order and stop where Core continues into work outside the row.  L calls the
  generated twin decode_num (runtime.inc, verbatim) but the handler arms are a
  reviewed transcription of the Defs.lean equations, because the generated
  twin has no CLTV/CSV decode path (ops_ir.py:42-61 returns
  TWIN_INVALID_UNSUPPORTED with the flag on) and no CHECKMULTISIG handler
  (gen.py:222-225 lists it unsupported).  The cell therefore does NOT claim
  equivalence of the generated twin's opcode table for these four sites; it
  claims the Lean model arms agree with Core at the row's call sites.  The
  Cryptol model in src/cell.cry is the third, independent statement of the
  same cited semantics and is checked against both legs.  No Core or twin
  patch is used.  The same-crypto premise covers OP_CHECKSIGADD only.
---
