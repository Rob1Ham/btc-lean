---
# Cell checksig/C-L-w32-checksig-findanddelete
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: the pinned rbitcoin render/error path is documented non-proof (F-HARNESS-002, F-TOOL-001)"
cell: C-L-w32-checksig-findanddelete
family: checksig
tool_status: both-green (bounded symbolic source slice + closed scenarios)
precondition: |
  - FindAndDelete is called at the start of a scriptCode byte range; the
    code-separator boundary is a separate cell (C-L-w32-checksig-codesep).
  - Three function pairs cover the serialized signature push
    CScript() << vchSig, which is length byte + payload and therefore never
    empty: cell_fad_pl1 (needle length 1, sig length 0), cell_fad_pl2
    (needle length 2, sig length 1), cell_fad_pl3 (needle length 3, sig
    length 2).
  - Script length is exactly 4 bytes for pl1/pl2 and 6 bytes for pl3; every
    script byte and every needle byte is symbolic.
  - Scripts may contain malformed push tails.  FindAndDelete is defined on
    those bytes and copies the tail verbatim; this is a superset of the
    fully-parseable scripts reachable from EvalScript.
  - No crypto checker is called by this cell.
postcondition: |
  - found is the number of non-overlapping needle matches consumed at opcode
    boundaries, including consecutive matches (after a match the walk resumes
    at the byte immediately after the needle, before any GetOp step).
  - out is the script with every matched needle removed.  Non-matching spans
    are copied whole: a 0xab inside a push payload is not a match, and the
    needle is never searched inside a payload.
  - A GetOp failure copies the remaining bytes verbatim and ends the walk.
  - Both legs agree on (found, out) for every input in the domain.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-098
scr_row_coverage: full — the cell exercises: no match; a match at offset 0;
  one multi-byte match; two consecutive matches of a 2-byte needle and of a
  3-byte needle; a partial/non-match followed by a GetOp step and continued
  scanning; the same needle bytes appearing inside a push payload (not
  matched); all-0x00 needle repeated to exhaust the script; and a malformed
  push tail.  Needle lengths 1, 2 and 3 cover sig lengths 0, 1 and 2.  Bounded
  to 4/4/6-byte scripts; every branch/edge named by SCR-098 is present.
coverage: full
patches: none
source_citations:
  - "interpreter.cpp:239-265 (FindAndDelete: match-at-boundary loop, then GetOp step; tail copy)"
  - "interpreter.cpp:340 (needle = CScript() << vchSig)"
  - "script.cpp:313-363 (CScript::GetOp)"
  - "spec/core/Bitcoin/SigHash/Ops.lean:50-78 (getOpAt)"
  - "spec/core/Bitcoin/SigHash/Ops.lean:90-124 (matchAtL, findAndDeleteAuxL, findAndDeleteL)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:720-729 (pushBytesWire sig / BASE-only call site)"
trust_note: >
  C is a line-cited source-excerpt slice of FindAndDelete, not the whole
  interpreter.  L is a reviewed transliteration of findAndDeleteAuxL /
  findAndDeleteL and getOpAt.  The scalar byte-select, Out sink and packing are
  cell harness.  The signature bytes are uninterpreted payload here: this cell
  proves the removal algorithm, not DER or ECDSA acceptance.  No Core source
  patch is used and no crypto/hash claim is made.
---
