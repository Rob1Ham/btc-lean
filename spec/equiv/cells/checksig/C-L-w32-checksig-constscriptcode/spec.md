---
# Cell checksig/C-L-w32-checksig-constscriptcode
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: the pinned rbitcoin render/error path is documented non-proof (F-HARNESS-002, F-TOOL-001)"
cell: C-L-w32-checksig-constscriptcode
family: checksig
tool_status: both-green (bounded symbolic source slice + closed scenarios)
precondition: |
  - The scriptCode range starts at the last code separator; this cell fixes
    that start at offset 0 (the boundary itself is C-L-w32-checksig-codesep).
  - Three function pairs cover the serialized signature push of needle length
    1/2/3, i.e. sig length 0/1/2: cell_fadpol_pl1/pl2/pl3.
  - Script length is exactly 6 bytes; every script and needle byte is
    symbolic.  SigVersion is BASE (sv=0) or WITNESS_V0 (sv=1); constsc is the
    SCRIPT_VERIFY_CONST_SCRIPTCODE bit.
  - The slice stops at the FindAndDelete policy result.  DERSIG, LOW_S,
    STRICTENC, NULLFAIL and the ECDSA checker are outside this cell; no
    crypto routine is called.
postcondition: |
  - BASE: FindAndDelete runs.  If found > 0 and constsc is set, the call fails
    with SCRIPT_ERR_SIG_FINDANDDELETE = 54 before any encoding check, and only
    the error ordinal is observable.  Otherwise err = 0 and (found, out) are
    the FindAndDelete result.
  - WITNESS_V0: FindAndDelete is not run at all (BIP143).  err = 0, found = 0
    and out is the original scriptCode.
  - Both legs agree on (err, found, out) for every input in the domain.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-099
scr_row_coverage: full — the policy implication found>0 ⇒ SIG_FINDANDDELETE is
  exercised with constsc on and off; found=0 with constsc on and off; one and
  two matches; BASE and WITNESS_V0; and needle lengths 1/2/3.  The only exit
  paths of the row (error-before-return and no-error) are covered.  Bounded to
  six-byte scripts with sig length ≤ 2; every branch/edge named by SCR-099 is
  present.
coverage: full
patches: none
source_citations:
  - "interpreter.cpp:336-343 (scriptCode, BASE-only FindAndDelete, found>0 + CONST_SCRIPTCODE => SIG_FINDANDDELETE)"
  - "interpreter.cpp:239-265 (FindAndDelete)"
  - "interpreter.cpp:484-486 (the separate unexecuted-CODESEPARATOR policy check; see codesep cell)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:720-733 (evalChecksigPreTapscript: findAndDelete, found>0 and constScriptCode => sigFindAndDelete)"
  - "spec/core/Bitcoin/SigHash/Ops.lean:90-124 (matchAtL/findAndDeleteL)"
  - "contract/error_kind.h:97 (SIG_FINDANDDELETE=54)"
trust_note: >
  C is a line-cited source slice of EvalChecksigPreTapscript, not the whole
  EvalScript.  L is a reviewed transliteration of evalChecksigPreTapscript's
  scriptCode/policy prologue.  The scalar GetOp/byte-select, Out sink and
  packing are cell harness.  The signature is uninterpreted; the only error
  under test is the constant-scriptcode find-and-delete policy, not DER or
  ECDSA.  No Core source patch is used and no crypto/hash claim is made.
---
