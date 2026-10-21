---
# Cell witness-v0/C-L-witness-v0-dispatch
cell: C-L-witness-v0-dispatch
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (total v0 dispatch predicate; SHA256/ExecuteWitnessScript abstracted)
precondition: |
  - witversion = 0 only (the P2SH wrapper is irrelevant to this arm).
  - Symbolic inputs, all 64-bit:
      program_len   = program.size()      (bytes)
      witness_n     = stack.size()        (witness items, before SpanPopBack on P2WSH)
      hash_match    = (SHA256(exec_script) == program), the 32-byte compare at
                      interpreter.cpp:1939-1945.  This is an ABSTRACTION: the
                      hash primitive is not modelled (SCR-133 is filed by its
                      own bounded compare cell and stays partial).
  - The two ExecuteWitnessScript call sites are represented by the cell
    sentinel 2 ("continuation"); no pass/fail execution claim is made.
  - No flags are consulted on this arm.
postcondition: |
  Packed observable result(2) | error_ordinal(6) << 2:
    program_len = 32, witness_n = 0      -> (0, 39) WITNESS_PROGRAM_WITNESS_EMPTY
    program_len = 32, witness_n > 0,
      hash_match = 0                     -> (0, 40) WITNESS_PROGRAM_MISMATCH
    program_len = 32, witness_n > 0,
      hash_match = 1                     -> (2, 0)  continuation sentinel
    program_len = 20, witness_n != 2     -> (0, 40) WITNESS_PROGRAM_MISMATCH
    program_len = 20, witness_n = 2      -> (2, 0)  continuation sentinel
    program_len not in {20, 32}          -> (0, 38) WITNESS_PROGRAM_WRONG_LENGTH
  The predicate is total over all 2^192 input triples; error precedence is
  Lean's and Core's (empty before hash, arity before execution, length last).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-134, SCR-135, SCR-137
scr_row_coverage: |
  full for the three rows below; SCR-133/136/138 are deliberately not claimed.
  - SCR-134 "empty ⇒ WITNESS_PROGRAM_WITNESS_EMPTY" (P2WSH witness
    non-empty): the whole row is the predicate `program_len = 32 ∧
    witness_n = 0 ⇒ (0,39)`.  Proved for every (program_len, witness_n,
    hash_match); the non-empty arm's later outcome is outside the row.
  - SCR-135 "else WITNESS_PROGRAM_MISMATCH" (P2WPKH exactly 2 items): the whole
    row is `program_len = 20 ∧ witness_n ≠ 2 ⇒ (0,40)`.  Proved for every
    input; the 2-item continuation is the separate SCR-136/138 seam.
  - SCR-137 "else WRONG_LENGTH" (v0 length 20 or 32 only): the whole row is
    `program_len ∉ {20,32} ⇒ (0,38)`, total over all 64-bit lengths.
  The SHA256 comparison input and the ExecuteWitnessScript sentinel are
  abstractions, but they are not part of these three rules; they only keep the
  function faithful for the 32-byte non-empty arm.
patches: none
source_citations:
  - interpreter.cpp:1927 (VerifyWitnessProgram signature)
  - interpreter.cpp:1933-1938 (v0 / P2WSH 32-byte, empty witness -> 39)
  - interpreter.cpp:1939-1945 (single SHA256 and memcmp; abstracted to hash_match)
  - interpreter.cpp:1946 (ExecuteWitnessScript; continuation sentinel)
  - interpreter.cpp:1949-1951 (v0 / P2WPKH 20-byte, arity != 2 -> 40)
  - interpreter.cpp:1953 (ExecuteWitnessScript; continuation sentinel)
  - interpreter.cpp:1954-1956 (other v0 lengths -> 38)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1259-1279
    (Bitcoin.Interpreter.verifyWitnessProgram, version = 0 arm)
  - contract/error_enum.md:68-70 (ordinals 38, 39, 40)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at the
  pin, not the whole VerifyWitnessProgram.  L is a REVIEWED TRANSLITERATION of
  the Verified Lean v0 arm, not generated from twin/ops_ir.py (the twin has no
  VerifyWitnessProgram handler).  SHA256 and ExecuteWitnessScript are inputs /
  a sentinel, so no crypto, hash, script-loop or cleanstack claim is made
  here.  Both tools prove the same total dispatch function: Alive2 compares the
  C and L IR, SAW verifies each module against the shared Cryptol function.
  No Core source patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2)
  - saw/result.txt (SAW 1.6, solver abc)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Not executed here.  A useful mutant is `witness_n <= 0` for the 32-byte empty
  arm or `witness_n < 2` for the 20-byte arity arm; both must fail at
  parseable counterexamples (program_len=32,witness_n=1 / program_len=20,
  witness_n=3).  The E4 orchestration already killed the latter as M-E4-004 on
  the older partial cell.
---
# witness-v0/C-L-witness-v0-dispatch

Strengthened replacement for `e4-witness/C-L-witness-v0-dispatch`.  The E4
cell stopped at the P2WSH empty predicate and the P2WPKH arity predicate and
never modelled the SHA256-mismatch arm; it therefore could not exercise the
full 32-byte non-empty branch.  This cell adds the mismatch arms and makes the
whole v0 dispatch total, while keeping the hash primitive and the
ExecuteWitnessScript call as declared abstractions.

What changed relative to E4:

- `hash_match` is now an explicit symbolic input, so the 32-byte P2WSH arm
  splits into `-> (0,40)` and `-> continuation` exactly as Core and Lean do.
- Successful execution is never asserted: both ExecuteWitnessScript call
  sites return the sentinel `2`, not `1`.
- The three row predicates 134/135/137 are therefore exercised as total
  implications, which is what the rules require.

Still not claimed: SCR-133 (SHA256 itself), SCR-136 (implied script bytes and
execution), SCR-138 (cleanstack/truthy post-state, proved by the sibling cell
`C-L-witness-v0-cleanstack`).
