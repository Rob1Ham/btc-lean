---
# Cell e4-witness/C-L-w32-witness-hash-compare
cell: C-L-w32-witness-hash-compare
family: e4-witness
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (exact 256-bit digest/program comparison, SHA256 computation symbolic)
precondition: |
  - Cell seam: the 32-byte comparison and mismatch branch at
    interpreter.cpp:1939-1945 only, reached in the v0 32-byte-program arm
    after the empty-witness guard.  No EvalScript, no ExecuteWitnessScript,
    no tx context.
  - h is the 32-byte `hash_exec_script` digest, carried as four little-endian
    u64 words h0..h3.  program is the 32-byte witness program, carried the
    same way as p0..p3.  Both are fully symbolic (2^256 pairs).
  - SHA256(exec_script) itself is NOT computed: h is the SCR-133 hash-floor
    seam as an input.  No claim is made about SHA256.
postcondition: |
  - If any of the four words differs, the result is (0, 40)
    WITNESS_PROGRAM_MISMATCH, in both legs.
  - If all four words are equal, both legs pass through the
    ExecuteWitnessScript (exec_res, exec_err) pair, with the ABI invariant
    result 1 => error 0.
  - Equivalently, the C `memcmp(hash_exec_script.begin(), program.data(), 32)`
    predicate and the Lean `hashSha256 script != program` byte-array
    inequality are the same 256-bit predicate for every input.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-133
scr_row_coverage: |
  partial for SCR-133.  The comparison half is full: for all 2^256
  (digest, program) pairs the cell proves that a mismatch in any of the 32
  bytes yields WITNESS_PROGRAM_MISMATCH and that a full 32-byte match
  proceeds, against an independent Cryptol equality on the same marshalling.
  The other half -- `CSHA256().Write(exec_script).Finalize(hash_exec_script)`
  at interpreter.cpp:1940-1941 -- is not modelled.  SCR-133 is therefore not
  closed: no SHA256 model exists at the leaf seam (see the task report for the
  exact blocker and the smallest next experiment).
patches: none
source_citations:
  - interpreter.cpp:1939-1945 (CSHA256 Write/Finalize then memcmp 32 bytes; mismatch -> 40)
  - interpreter.cpp:1946 (ExecuteWitnessScript)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1266-1270 (hashSha256 script != program)
  - spec/core/Bitcoin/Interpreter/Hashes.lean:125 (hashSha256, not modelled)
  - contract/error_enum.md:70 (ordinal 40)
trust_note: >
  C is a line-cited model of the memcmp and branch; the digest is an input.
  L is a reviewed transliteration of the Lean ByteArray inequality, comparing
  the 32 bytes one at a time (cells/_tools/e4w32/l_cells.cpp).  The u64 word
  marshalling is a bijection between 256-bit byte strings and four words, is
  identical on both legs and in the Cryptol spec, and is cell harness rather
  than engine semantics.  No SHA256, hash, or crypto claim is made; the
  same-crypto premise is unchanged and cited to docs/DECISION-lax-ecdsa.md.
  No Core source patch is used.
mutant: >
  Proposed, not executed: compare only three of the four words (drop the h3/p3
  word).  Expected Alive2 counterexample with h3 != p3 and a SAW failure; this
  is exactly the class of prefix-comparison mutants the cell rules out.
---
