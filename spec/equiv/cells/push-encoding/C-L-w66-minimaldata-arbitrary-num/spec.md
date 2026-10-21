---
# Cell push-encoding/C-L-w66-minimaldata-arbitrary-num
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 8142cff0ed6ea6edd448b609817d2a706ab5e057
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: push-encoding/C-L-w66-minimaldata-arbitrary-num
family: push-encoding
tool_status: both-green (Alive2 bidirectional, 6/6 functions; SAW 12/12 proofs)
precondition: |
  - This is a handler-level slice.  The flags word has already passed the
    ABI/VerifyScript entry validation described in contract/tape.md (bits
    above 20 are a "bad input" result there); the cell reads only the pinned
    bits 6 (MINIMALDATA = 0x40), 9 (CHECKLOCKTIMEVERIFY = 0x200) and 10
    (CHECKSEQUENCEVERIFY = 0x400).  Quantifying over every 64-bit word is
    therefore conservative: the unreachable high bits are ignored.
  - Each decoded operand is a five-byte element packed little-endian into one
    64-bit register word plus a FULL 32-bit length.  `len` is not a truncated
    field: every stack element that can reach these decodes has size <=
    MAX_SCRIPT_ELEMENT_SIZE (520), because EvalScript rejects a larger push at
    interpreter.cpp:457-458 and every other element entered the stack through
    a push.  Both caps are <= 5, so the width guard runs first for len > 5 and
    for len <= 5 only byte indices len-1 and len-2 (<= 4) are consulted;
    the packed word therefore has every byte a legal operand can expose, and
    the model covers 0..520 as well as the unreachable >520 values.
  - The CLTV/CSV activation bits are symbolic.  With the bit absent the opcode
    is a NOP and the operand is never decoded.
  - `depth` and `opcount` are symbolic 16-bit values, so Core's `int`
    arithmetic is exact over a superset of the reachable values (depth <=
    MAX_STACK_SIZE 1000, opcount <= MAX_OPS_PER_SCRIPT 201).  `sigversion` is
    symbolic 8-bit; 0 (BASE), 1 (WITNESS_V0) and 2 (TAPSCRIPT) are the Core
    enum, and other values take the tapscript arm.
  - CHECKMULTISIG's stack contents are represented by their depth only; the
    two decoded count operands are independent symbolic elements, so the
    encoding rule is proved for every possible element at the selected index.
    Signature verification, NULLDUMMY/NULLFAIL and FindAndDelete are after the
    count decode and outside the row.
postcondition: |
  Let md = (flags & SCRIPT_VERIFY_MINIMALDATA) != 0,
      nonminimal(len, b) := len > 0 &&
          (b[len-1] & 0x7f) == 0 &&
          (len <= 1 || (b[len-2] & 0x80) == 0),
      rt(len, b) := serialize(set_vch(b[0..len))) == b[0..len),
      value(len, b) := set_vch(b[0..len))  (64-bit two's complement),
      decOK(cap) := len <= cap && !(md && nonminimal(len, b)).

  Both predicate entry points return the packed 64-bit observable
    accept(1) | width(1) << 1 | nonminimal(1) << 2 | rt(1) << 3 |
    value<0(1) << 4 | value==0(1) << 5 | md(1) << 6 |
    (low 56 bits of value, 0 when rejected) << 8
  where width = (len > cap), accept = !width && !(md && nonminimal), and on
  the width path nonminimal = rt = value<0 = accept = 0 while value==0 is 1
  (the C and L initialisers; this is deliberately part of the observable and
  is exercised by the SAW model and the witness driver).  cap is 5 for
  pred_cap5 (CLTV/CSV) and 4 for pred_cap4 (CHECKMULTISIG counts and
  CHECKSIGADD).

  The round-trip field is the independent characterisation of the minimal
  encoding: it is computed by re-serialising the decoded value and comparing
  bytes, never by the two-byte test.  For len <= 5 the model states
    rt(len, b) <-> !nonminimal(len, b)
  and the witness driver exhaustively checks the two formulations agree for
  every 1- and 2-byte operand and a 20,000-case sample of lengths 3..5.

  Both handler legs return the same packed observable
    result(2) | error_kind(6) << 2
  with the following verdicts (error ordinals from contract/error_kind.h):

    CLTV (cap 5, interpreter.cpp:556)
      !(flags & 0x200)                  -> OK (NOP)
      depth < 1                         -> INVALID_STACK_OPERATION (18)
      !decOK(5)                         -> SCRIPTNUM (4)
      decoded value < 0                 -> NEGATIVE_LOCKTIME (21)
      otherwise                         -> OK

    CSV (cap 5, interpreter.cpp:584)
      !(flags & 0x400)                  -> OK (NOP)
      depth < 1                         -> INVALID_STACK_OPERATION (18)
      !decOK(5)                         -> SCRIPTNUM (4)
      decoded value < 0                 -> NEGATIVE_LOCKTIME (21)
      decoded value & SEQUENCE_LOCKTIME_DISABLE_FLAG
                                        -> OK (NOP)
      otherwise                         -> OK

    CMS (cap 4, interpreter.cpp:1126 and :1140)
      sigversion == TAPSCRIPT          -> TAPSCRIPT_CHECKMULTISIG (50)
      depth < 1                         -> INVALID_STACK_OPERATION (18)
      key !decOK(4)                     -> SCRIPTNUM (4)
      key < 0 or key > 20               -> PUBKEY_COUNT (10)
      opcount + key > 201               -> OP_COUNT (7)
      depth < key + 2                   -> INVALID_STACK_OPERATION (18)
      sig !decOK(4)                     -> SCRIPTNUM (4)
      sig < 0 or key < sig              -> SIG_COUNT (9)
      depth < key + sig + 3             -> INVALID_STACK_OPERATION (18)
      otherwise                         -> OK

    CHECKSIGADD (cap 4, interpreter.cpp:1103)
      sigversion BASE or WITNESS_V0    -> BAD_OPCODE (16)
      depth < 3                         -> INVALID_STACK_OPERATION (18)
      !decOK(4)                         -> SCRIPTNUM (4)
      otherwise                         -> OK
      (the EvalChecksig outcome and the pushed value are not observed)

  Error precedence established by the above:
  - the site gate (activation flag, tapscript rejection, sigversion, or
    stack/depth floor) is evaluated before the decode;
  - inside the constructor the width guard is evaluated before the
    minimality test (both raise SCRIPTNUM, so their relative order is not
    observable in the contract's error kind);
  - a decode SCRIPTNUM wins over the immediately following
    NEGATIVE_LOCKTIME, PUBKEY_COUNT, OP_COUNT, SIG_COUNT and arity errors;
  - the CMS tapscript rejection and the CHECKSIGADD BAD_OPCODE gate are
    consensus edges that also precede the decode; neither is a MINIMALDATA
    effect.

  Policy/consensus face.  MINIMALDATA is a policy flag (SCR-051 is
  `consensus: false`).  The cell proves the conditional statement: for a
  flags word with bit 6 clear, a within-cap operand is never rejected by this
  rule, including negative zero (0x80) and every padded encoding; with bit 6
  set, exactly the non-minimal within-cap operands are rejected with
  SCRIPTNUM, which by the round-trip field is exactly the operands whose
  canonical serialisation differs from their bytes.  It does not claim that
  block validation sets bit 6, that standardness equals acceptance, or any
  consensus relaxation/strengthening; the consensus width cap remains
  INV-058.  The R leg and whole EvalScript/VerifyScript are not claimed.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-051
scr_row_coverage: >-
  full for the row's check ("fRequireMinimal under MINIMALDATA for
  CLTV/CSV/CMS-counts/CHECKSIGADD-num, arbitrary operand length").  All five
  cited lines (556, 584, 1126, 1140, 1103) are modelled as bounded handler
  slices, with fRequireMinimal derived from the pinned flags word rather than
  passed as a free flag.  The exact script.h:255-268 predicate is proved for
  every five-byte operand and a full 32-bit length at both caps, under both
  settings of bit 6, and is proved (SAW) plus exhaustively witnessed to agree
  with the independent canonical round-trip test
  serialize(set_vch(operand)) == operand, together with the policy SCRIPTNUM
  error and the immediately following check that the decode must precede
  (NEGATIVE_LOCKTIME for CLTV/CSV, the CSV disable-flag NOP,
  PUBKEY_COUNT/OP_COUNT/arity/SIG_COUNT for CHECKMULTISIG).  The CMS
  tapscript rejection and the CHECKSIGADD base/witnessV0 rejection are included
  as pre-decode consensus gates, so the error precedence at each cited site is
  complete for the decode step.  Excluded, and owned by other rows:
  CheckLockTime/CheckSequence and their transaction context (SCR-122..SCR-129);
  CHECKMULTISIG signature verification, NULLDUMMY/NULLFAIL and FindAndDelete
  (SCR-114..SCR-121); CHECKSIGADD's EvalChecksig and pushed value (SCR-113 /
  E4 seam); the shared decode predicate as its own row (SCR-050) and its
  sign-extension exception (SCR-084); the width-cap rows (SCR-079..SCR-081).
  The L handler arms are a reviewed transliteration of Defs.lean (README
  section 3 fallback), while the decoder and flag constants are generated twin
  code; this is a labelled trust downgrade, not a coverage gap for this row.
  No generated-twin equivalence is claimed for handlers the shared twin does
  not implement.
patches: none
source_citations:
  - script.h:246-271 (CScriptNum constructor: width guard, minimality test)
  - script.h:342-373 (serialize: canonical LE sign-magnitude)
  - script.h:376-391 (set_vch: LE sign-magnitude, sign bit, negative zero)
  - interpreter.cpp:442 (fRequireMinimal = flags & SCRIPT_VERIFY_MINIMALDATA)
  - interpreter.cpp:534-571 (OP_CHECKLOCKTIMEVERIFY, incl. :556 cap 5)
  - interpreter.cpp:574-602 (OP_CHECKSEQUENCEVERIFY, incl. :584 cap 5)
  - interpreter.cpp:1092-1109 (OP_CHECKSIGADD, incl. :1103 cap 4)
  - interpreter.cpp:1113-1152 (OP_CHECKMULTISIG counts, :1126 and :1140 cap 4)
  - interpreter.cpp:1233-1238 (catch scriptnum_error => SCRIPT_ERR_SCRIPTNUM)
  - interpreter.cpp:1118 (tapscript CHECKMULTISIG rejection, before the decode)
  - interpreter.cpp:1097 (CHECKSIGADD base/witnessV0 rejection, before the decode)
  - interpreter.cpp:457-458 (MAX_SCRIPT_ELEMENT_SIZE push rejection bounds len)
  - interpreter.h:49-153 + script/verify_flags.h:31 (flag bit = 1 << ordinal)
  - contract/tape.md:117-124 (MINIMALDATA 0x40, CLTV 0x200, CSV 0x400)
  - Defs.lean:629-632 (decodeNum), :857-875 (CLTV/CSV), :1069-1090
    (checkMultiSig), :803-811 and :1048-1059 (CHECKSIGADD)
  - Numeric/Interface.lean:45-47 (decodeScriptNum)
  - twin/runtime.inc:139-158 (encode_num), :167-188 (decode_num),
    :348-352 (flag constants)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin: CScriptNum is specialised to a five-byte packed
  operand, the set_vch byte loop is replaced by the equivalent mask/sign
  operations (no memory is read), the throw is the error return that
  EvalScript's catch maps to SCRIPT_ERR_SCRIPTNUM, and `break` is the
  observable OK.  The CMS `.getint()` after each construction is exact for the
  4-byte cap: a 4-byte sign-magnitude value lies in [-(2^31-1), 2^31-1].
  The canonical encoder is the closed form of serialize's magnitude loop
  (|value| < 2^39 on this domain, so at most five magnitude bytes and one
  sign/pad byte).  The round-trip field re-serialises and compares bytes; it
  is not derived from the two-byte test.
  L uses the generated twin decoder body `decode_num` (runtime.inc:167-188)
  with the concrete-length byte loop unrolled, and the generated twin encoder
  body `encode_num` (runtime.inc:139-158) with its magnitude loop bounded at
  five steps; the flag constants come from runtime.inc:348-352.  The L handler
  arms are a reviewed transcription of the pinned Defs.lean equations.  The
  generated twin does not implement the CLTV/CSV decode or a CHECKMULTISIG
  handler (ops_ir.py:42-61 returns TWIN_INVALID_UNSUPPORTED when the activation
  flag is on; gen.py:222-225 lists CHECKMULTISIG unsupported), so the cell
  does not claim equivalence of the shared twin's opcode table for these
  sites.  It claims the Lean model arms agree with Core at the row's decode
  sites, with the L link downgraded to "reviewed transliteration" per
  spec/equiv/README.md section 3.  The Cryptol model in src/cell.cry is the
  third, independent statement of the cited semantics (predicate and
  round-trip from script.h, verdicts and ordinals from interpreter.cpp and the
  contract) and is checked against both legs.  No crypto, hash or signature
  code is reached; the same-crypto premise is not used.  No Core or twin patch
  is used.
evidence:
  - alive2/result.txt (6 comparisons, each 1 correct transformation, 0 Alive2 errors)
  - saw/result.txt (12 llvm_verify proofs against src/cell.cry, one per entry point per leg, plus a pure-Cryptol proof of rt <-> !nonminimal for len <= 5)
  - mutations/result.txt (13 mutant/entry-point pairs, all at their expected verdict; every expected-red pair has a counterexample)
  - witnesses/result.txt (1,178,192 concrete checks: precedence table, policy lane, round-trip law)
  - alive2/certificate.sha256, saw/certificate.sha256, mutations/certificate.sha256, witnesses/certificate.sha256
---
