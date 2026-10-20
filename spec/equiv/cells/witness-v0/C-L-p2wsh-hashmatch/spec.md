---
# Cell witness-v0/C-L-p2wsh-hashmatch
cell: C-L-p2wsh-hashmatch
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (32-byte digest/program compare; SHA256 abstracted)
precondition: |
  - witversion = 0, program.size() = 32 (P2WSH), witness non-empty.  The
    empty-witness guard (ordinal 39) is the sibling dispatch cell and is a
    precondition here.
  - `d0..d3` are the 32 bytes of SHA256(witnessScript), viewed as four
    little-endian u64 words (bytes 0..7, 8..15, 16..23, 24..31).
  - `p0..p3` are the 32 witness-program bytes in the same encoding.
  - SHA256 itself is NOT modelled.  `digest` is an unconstrained symbolic
    value standing for the hash output: this is the same-hash premise of
    spec/equiv/README.md §7.  The cell proves the comparison and its dispatch,
    not that the digest is the hash of any particular script.
postcondition: |
  Packed observable result(2) | error_ordinal(6) << 2:
    all 32 bytes equal (d0=p0, d1=p1, d2=p2, d3=p3)
        -> (2, 0)  continuation sentinel for ExecuteWitnessScript
    any byte differs
        -> (0, 40) SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH
  The comparison is total over all 2^512 input word tuples.  Result 2 is a
  continuation sentinel, NOT a claim that the witness script succeeds;
  SCR-136 (implied/executed script) and SCR-138 (post-state) are separate.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-133
scr_row_coverage: |
  partial.  The row's stated check is "SHA256(witnessScript) == program".  The
  32-byte equality and the mismatch/continue dispatch are proved completely
  and for every input, but SHA256(witnessScript) is an abstract digest input,
  so the hash computation itself is not proved.  The row stays partial; it is
  not promoted as a hash proof.  Because equality is invariant under any fixed
  byte permutation, the four-word encoding is an exact representation of
  memcmp(digest, program, 32) == 0, not a weakened comparison.
patches: none
source_citations:
  - interpreter.cpp:1939-1940 (SpanPopBack of the witnessScript and
    exec_script construction; precondition)
  - interpreter.cpp:1941-1942 (single CSHA256 over exec_script; abstracted)
  - interpreter.cpp:1943-1944 (memcmp of 32 bytes -> MISMATCH ordinal 40)
  - interpreter.cpp:1945-1946 (match -> ExecuteWitnessScript; continuation
    sentinel 2)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1263-1270
    (verifyWitnessProgram 32-byte v0 arm: hashSha256 script != program ->
    witnessProgramMismatch, else executeWitnessScript)
  - contract/error_enum.md (ordinal 40 SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH)
  - spec/equiv/README.md §7 (same-hash premise)
trust_note: >
  C is a line-cited source-excerpt slice of VerifyWitnessProgram at the pin.
  L is a REVIEWED TRANSLITERATION of the verified Lean v0 32-byte arm, with
  the equality written as a four-way conjunction while C uses XOR/OR, so the
  Alive2 result is semantic.  The digest is a symbolic input, so no SHA256
  implementation, preimage or collision-resistance claim is made; both tools
  prove exactly the 32-byte comparison.  No Core patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2)
  - saw/result.txt (SAW 1.6, solver abc; two proofs)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Not executed here.  A useful mutant is comparing only d0/p0 (dropping
  d1..d3), which must fail at a tuple with d0=p0 but d1!=p1, or inverting the
  branch so a match returns 40.  Both counterexamples are one 64-bit word
  apart, so the encoding does not hide the mutant.
---
# witness-v0/C-L-p2wsh-hashmatch

P2WSH commits to the witnessScript by a single SHA256:
`SHA256(witnessScript)` must equal the 32-byte witness program
(interpreter.cpp:1941-1945).  The row is the match test and its two outcomes.

## What is proved

`cell_p2wsh_hashmatch(d0,d1,d2,d3,p0,p1,p2,p3)`:

| condition | result |
|---|---|
| all four words equal | (2, 0) continue to ExecuteWitnessScript |
| any word differs | (0, 40) WITNESS_PROGRAM_MISMATCH |

Alive2 compares the C XOR/OR form with the L conjunction form for all 2^512
inputs; SAW proves both modules against the Cryptol predicate `hashmatch`,
two proofs.  The sentinel 2 deliberately avoids claiming script success.

## What is not proved

- SHA256 itself: the digest is a symbolic input (same-hash premise,
  `spec/equiv/README.md` §7).  In particular the cell does not prove that
  `SHA256` is computed by Core's `CSHA256` with the right preimage bytes.
- `CScript(script_bytes)` parsing / the popped witness item (a precondition).
- `ExecuteWitnessScript` on a match (SCR-136/138).

That is why SCR-133 stays partial even though the comparison is total.
