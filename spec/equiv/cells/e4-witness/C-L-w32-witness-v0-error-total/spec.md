---
# Cell e4-witness/C-L-w32-witness-v0-error-total
cell: C-L-w32-witness-v0-error-total
family: e4-witness
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (total v0 dispatch/error function, hash and script execution symbolic inputs)
precondition: |
  - Cell seam: the v0 arm of VerifyWitnessProgram only (interpreter.cpp:1933-1956).
    No tx decoding, no P2SH wrapping, no EvalScript loop, no
    ExecuteWitnessScript, no SHA256.
  - witversion = 0.
  - Symbolic inputs: program_len (program.size()), witness_n (stack.size()),
    hash_ok = (memcmp(SHA256(witnessScript), program, 32) == 0), and the
    (exec_res, exec_err) pair returned by ExecuteWitnessScript.
  - exec pair domain: exec_res in {0,1}; on exec_res = 1 the ABI requires
    exec_err = OK, which w32_exec applies (result 1 => error 0).  On
    exec_res = 0, exec_err is any 6-bit ordinal.
  - hash_ok is an input, not a computed value: SHA256 is the SCR-133 seam and
    is not modelled in this cell.
postcondition: |
  - Packed observable result(2) | error_ordinal(6) << 2.  For every input:
      program_len = 32, witness_n = 0        -> (0, 39) WITNESS_PROGRAM_WITNESS_EMPTY
      program_len = 32, witness_n > 0,
        hash_ok = 0                           -> (0, 40) WITNESS_PROGRAM_MISMATCH
      program_len = 32, witness_n > 0,
        hash_ok != 0                          -> the ExecuteWitnessScript pair
      program_len = 20, witness_n != 2        -> (0, 40) WITNESS_PROGRAM_MISMATCH
      program_len = 20, witness_n = 2         -> the ExecuteWitnessScript pair
      program_len not in {20, 32}             -> (0, 38) WITNESS_PROGRAM_WRONG_LENGTH
    Converse forms are included: 39 is returned iff (32,0); 38 iff the length
    is not 20 or 32; 40 iff the P2WSH hash mismatches or the P2WPKH arity is
    not 2.  No success arm is asserted: when ExecuteWitnessScript is reached,
    the returned pair is exactly the symbolic input pair.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-134, SCR-135, SCR-137
scr_row_coverage: |
  full for SCR-134, SCR-135, SCR-137 at this seam; partial (branch only) for
  SCR-133.
  - SCR-134 "empty => WITNESS_PROGRAM_WITNESS_EMPTY": full.  The cell is total
    over all inputs and proves both that program_len=32 with witness_n=0 returns
    39 and that no other input returns 39.  The hash input is irrelevant on
    that edge.
  - SCR-135 "else WITNESS_PROGRAM_MISMATCH" (P2WPKH arity): full.  Proves that
    program_len=20 with witness_n != 2 returns 40, and that a 2-item witness
    proceeds to ExecuteWitnessScript.  The execution outcome is not part of
    this row.
  - SCR-137 "else WRONG_LENGTH": full.  Proves error 38 for every program_len
    outside {20, 32} and that no other input returns 38.
  - SCR-133 "SHA256(witnessScript) == program": PARTIAL, branch only.  The
    mismatch => 40 and match => proceed edges are proved for a symbolic
    hash_ok; the SHA256 computation itself is not modelled.  See
    e4-witness/C-L-w32-witness-hash-compare for the 32-byte comparison and the
    report for the hash-floor blocker.
  NOT claimed here: SCR-136 implied-script reconstruction (separate cell),
  SCR-138 witness cleanstack, every taproot/tapscript row.
patches: none
source_citations:
  - interpreter.cpp:1927 (VerifyWitnessProgram signature)
  - interpreter.cpp:1933-1938 (v0 32-byte arm, empty witness -> 39)
  - interpreter.cpp:1939-1946 (SHA256 match -> 40 on mismatch; ExecuteWitnessScript; hash input symbolic)
  - interpreter.cpp:1947-1953 (v0 20-byte arm, arity != 2 -> 40; ExecuteWitnessScript)
  - interpreter.cpp:1954-1955 (other v0 lengths -> 38)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1259-1280 (Lean verifyWitnessProgram v0 arm)
  - contract/error_enum.md:68-70 (ordinals 38, 39, 40)
  - contract/ABI.md:34-45 (result/error consistency)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at the
  pin, not the whole VerifyWitnessProgram and not the whole EvalScript.  L is a
  reviewed manual transliteration of the Verified Lean v0 arm
  (cells/_tools/e4w32/l_cells.cpp); the twin has no VerifyWitnessProgram
  handler, so there is no generated body and no mk_leaf instance.  SHA256 and
  ExecuteWitnessScript are symbolic inputs, so no crypto, hash, script-loop or
  cleanstack claim is made.  Alive2 compares the C and L IR in both directions;
  SAW verifies each module against the same independent Cryptol function.  No
  Core source patch is used.
mutant: >
  Proposed, not executed: change the 20-byte arm guard from `wn != 2` to
  `wn < 2`.  Expected Alive2 counterexample at program_len=20, witness_n=3
  (C=40, L=pass-through) and a SAW proof failure.
---
