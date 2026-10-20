---
# Cell e4-witness/C-L-witness-v0-dispatch
cell: C-L-witness-v0-dispatch
family: e4-witness
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic dispatch predicate, crypto/script execution abstracted)
precondition: |
  - Cell seam: the v0 arm of VerifyWitnessProgram only. No tx decoding, no
    EvalScript loop, no ExecuteWitnessScript, no SHA256, no signature checking.
  - witversion = 0 (P2SH wrapping is irrelevant to this arm).
  - Inputs are the two dispatch facts Core consults on this arm:
      program_len  = program.size()   (bytes)
      witness_n    = stack.size()     (witness stack items)
    Both are arbitrary 64-bit values in the proof; the tape domain's byte
    bounds are not needed because the predicate is total.
  - Abstraction (declared, not proved): SHA256(witnessScript) == program
    (interpreter.cpp:1939-1945) and ExecuteWitnessScript
    (interpreter.cpp:1946,1953) are fixed to success. The cell therefore
    proves the length/arity dispatch, not the hash or script run.
  - Flags are not consulted by Core on this arm; none are modelled.
postcondition: |
  - Packed observable result(2) | error_ordinal(6) << 2:
      program_len = 32, witness_n = 0        -> (0, 39) WITNESS_PROGRAM_WITNESS_EMPTY
      program_len = 32, witness_n > 0        -> (1, 0)  (abstracted hash/exec success)
      program_len = 20, witness_n != 2       -> (0, 40) WITNESS_PROGRAM_MISMATCH
      program_len = 20, witness_n = 2        -> (1, 0)  (abstracted implied-script success)
      program_len not in {20, 32}            -> (0, 38) WITNESS_PROGRAM_WRONG_LENGTH
  - Equivalently, for every (program_len, witness_n) the C slice and the L
    transliteration return the same pair; no error precedence is invented.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-134, SCR-135, SCR-137
scr_row_coverage: |
  partial (dispatch predicate only), per row:
  - SCR-134 "empty => WITNESS_PROGRAM_WITNESS_EMPTY": full for the empty
    predicate on the 32-byte program; the non-empty arm's success is the
    declared hash/ExecuteWitnessScript abstraction.
  - SCR-135 "else WITNESS_PROGRAM_MISMATCH" (P2WPKH exactly 2 items): full for
    the arity predicate on the 20-byte program; the 2-item arm's success is
    the declared implied-script/ExecuteWitnessScript abstraction.
  - SCR-137 "else WRONG_LENGTH" (v0 length 20 or 32 only): full; the function
    is total over all other lengths.
  NOT claimed here: SCR-133 (SHA256 program match), SCR-136 (P2WPKH script
  reconstruction/execution), SCR-138 (witness cleanstack), and every
  taproot/tapscript row. Those remain seams, listed in findings/e4/seams.md.
patches: none
source_citations:
  - interpreter.cpp:1927 (VerifyWitnessProgram signature)
  - interpreter.cpp:1933-1938 (v0 / P2WSH 32-byte, empty witness -> 39)
  - interpreter.cpp:1939-1946 (SHA256 match, SpanPopBack, ExecuteWitnessScript; abstracted)
  - interpreter.cpp:1947-1953 (v0 / P2WPKH 20-byte, arity != 2 -> 40, implied script; abstracted)
  - interpreter.cpp:1954-1955 (other v0 lengths -> 38)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1259-1279 (Bitcoin.Interpreter.verifyWitnessProgram v0 arm)
  - contract/error_enum.md:68-70 (ordinals 38, 39, 40)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at the
  pin, not the whole VerifyWitnessProgram and not the whole EvalScript. L is a
  reviewed transliteration of the Verified Lean v0 arm, NOT generated from
  twin/ops_ir.py (the twin has no VerifyWitnessProgram handler); the
  transliteration is manual and reviewable in cells/_tools/e4/l_cell.cpp.
  SHA256 and ExecuteWitnessScript are abstracted to success, so no crypto,
  hash, script-loop or cleanstack claim is made. Both tools prove the same
  symbolic dispatch function: Alive2 compares the C and L IR directly; SAW
  verifies each module against the shared Cryptol function. No Core source
  patch is used.
mutant: >
  Proposed, not executed: change the 20-byte arm's arity guard from
  `witness_n != 2` to `witness_n < 2`. Expected: Alive2 counterexample at
  program_len=20, witness_n=3 (C=40, L=1); SAW proof failure. See
  findings/e4/report.md for the exact proposal.
---
