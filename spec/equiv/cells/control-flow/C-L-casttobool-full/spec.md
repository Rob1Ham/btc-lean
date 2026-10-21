---
# Cell control-flow/C-L-casttobool-full
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 8142cff0ed6ea6edd448b609817d2a706ab5e057
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-casttobool-full
family: control-flow
tool_status: both-green (symbolic length, all lengths 0-520, all byte values)
precondition: |
  - no engine flags, scriptSig, or sigversion input: CastToBool is a pure
    predicate on one element.
  - the element is (vch, n) with a symbolic 32-bit length n constrained to
    0 <= n <= 520 (Core's MAX_SCRIPT_ELEMENT_SIZE).
  - all 520 bytes are symbolic; the loop is not specialised per length.
postcondition: |
  For every n in [0,520] and every byte vector b of length n:

    C(b) = L(b) = 1  iff  n > 0 and either
        (i) some byte b[i] with i < n-1 is nonzero, or
        (ii) b[n-1] is neither 0x00 nor 0x80;

    C(b) = L(b) = 0  otherwise (including n = 0, all-zero vectors, and the
    lone last byte 0x80, the negative zero).

  Equivalently: the scan stops at the first nonzero byte before the last
  position and returns true; if no such byte exists, only the last byte
  decides, and 0x80 is the unique nonzero byte that casts to false.  A 0x80
  byte before the last position is an ordinary nonzero byte and is true.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-057
scr_row_coverage: >-
  full — all element lengths 0..520, every byte value.  The new cell keeps
  Core's scan loop verbatim and gives it a symbolic 32-bit length under the
  consensus bound n <= 520; it is not specialised to compile-time lengths.
  SAW verifies both legs against the same independent Cryptol scan/no-scan
  predicate with symbolic n <= 520 and a fully symbolic 520-byte array, so
  all 521 lengths and all 2^(8n) byte vectors per length are covered in one
  check per leg.  Alive2 compares the two loops directly at the same symbolic
  length.  This supersedes the older bounded cell
  control-flow/C-L-casttobool, whose 0..2 domain is stated there and is not
  used for this row's coverage claim.
patches: none
source_citations:
  - interpreter.cpp:46-59 (bool CastToBool(const valtype& vch))
  - spec/equiv/twin/runtime.inc:130-139 (twin cast_to_bool, extracted verbatim)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the CastToBool loop is verbatim and only the exported wrapper adds
  `__builtin_assume(n <= 520)` for the consensus element domain.  L is the
  twin's real `cast_to_bool`, extracted verbatim from twin/runtime.inc by
  src/extract_twin.py with a pinned SHA-256 over the function text (a twin
  change fails the build).  SAW checks both legs against an independent
  Cryptol predicate; Alive2 checks C against L without using that predicate.
  The cell is a pure predicate cell, not whole-engine equivalence.  No Core
  source patch, no shared proof edit, no twin edit is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell; non-vacuity probe recorded in the finding)
---
