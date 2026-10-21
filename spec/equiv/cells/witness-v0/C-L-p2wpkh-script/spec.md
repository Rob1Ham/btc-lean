---
# Cell witness-v0/C-L-p2wpkh-script
cell: C-L-p2wpkh-script
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (25-byte implied-script construction; execution abstracted)
precondition: |
  - witversion = 0 and program.size() = 20 (P2WPKH).  The caller has already
    accepted stack.size() = 2 (SCR-135, sibling dispatch cell); the arity check
    is outside this cell.
  - The 20 program bytes are symbolic and arrive as three u64 words:
      p0 = bytes 0..7, p1 = bytes 8..15, p2 = bytes 16..19 in its low 32 bits
    (little-endian byte i of a word is bits 8i..8i+7).  This is a bijection
    from 20-byte programs to (p0, p1, p2 mod 2^32); p2's high 32 bits are
    unobservable.  The encoding is adopted only because Alive2 v20 rejects
    pointer parameters carrying `nocapture`/`noalias` and runs out of memory on
    a 20-byte symbolic memory input.
  - No flags are consulted.  ExecuteWitnessScript (interpreter.cpp:1953) is not
    run: this cell ends at the exec_script bytes.
postcondition: |
  The 25-byte exec_script is reconstructed exactly (zero-padded to 32 bytes):
    s[0]  = 0x76  OP_DUP
    s[1]  = 0xa9  OP_HASH160
    s[2]  = 0x14  push 20 bytes
    s[3..22] = program[0..19]
    s[23] = 0x88  OP_EQUALVERIFY
    s[24] = 0xac  OP_CHECKSIG
    s[25..31] = 0
  Four functions each return one 64-bit little-endian word of the padded
  buffer: w0 = s[0..7], w1 = s[8..15], w2 = s[16..23], w3 = s[24..31].
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-136
scr_row_coverage: |
  partial.  The row's script bytes are fully reconstructed and proved for
  every symbolic program: DUP HASH160 <20-byte program> EQUALVERIFY CHECKSIG.
  What is missing is the row's second half, `ExecuteWitnessScript` on those
  bytes (interpreter.cpp:1953): the EvalScript loop, push parsing, HASH160 and
  ECDSA/CHECKSIG are not modelled.  SCR-136 therefore stays partial and is not
  promoted to full.
patches: none
source_citations:
  - interpreter.cpp:1952 (exec_script << OP_DUP << OP_HASH160 << program
    << OP_EQUALVERIFY << OP_CHECKSIG; CScript::operator<< emits the minimal
    0x14 push for a 20-byte vector)
  - interpreter.cpp:1953 (ExecuteWitnessScript; not modelled)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1271-1278
    (Bitcoin.Interpreter.verifyWitnessProgram P2WPKH arm, inline exec bytes)
  - spec/core/Bitcoin/SigHash/Digest.lean:325-326
    (Bitcoin.SigHash.p2wpkhScriptCodeL, the same five-part byte string)
  - spec/equiv/README.md §7 (same-crypto premise for the unmodelled checker)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at the
  pin, not the whole VerifyWitnessProgram.  L is a REVIEWED TRANSLITERATION of
  the verified Lean byte construction, not generated from twin/ops_ir.py.  The
  two legs deliberately store bytes in different orders (C prefix-first, L
  suffix-first); clang normalized both to the same IR, so Alive2 reports
  syntactic equality, which is the strongest possible outcome.  The four-word
  little-endian output is an exact view of the 32-byte buffer
  (a bijection), not a weakening.  No crypto, hash or script-execution claim is
  made; both tools prove exactly the construction.  No Core patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2; four functions, both legs)
  - saw/result.txt (SAW 1.6, solver abc; eight proofs)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Not executed here.  A useful mutant is `s[2] = 0x15` (wrong push length) or a
  swap of `OP_EQUALVERIFY`/`OP_CHECKSIG`; either must fail at w0/w3 with a
  parseable counterexample, since the comparison is over the whole padded
  buffer.  The word-wise split means a mutant confined to s[25..31] must fail
  at w3.
---
# witness-v0/C-L-p2wpkh-script

SCR-136 is the implied P2WPKH script.  Core does not take it from the witness;
it synthesises `OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG`
(interpreter.cpp:1952) and hands it to `ExecuteWitnessScript`.  This cell
isolates the construction, which is the pure half of the row.

## Encoding and why it is not a weakening

The real Core expression consumes `std::vector<unsigned char> program` and a
`CScript`, i.e. pointers plus memory.  Alive2 v20 cannot take the resulting
symbolic memory parameter here: clang emits `nocapture`/`noalias` on the
pointers and Alive2 rejects those attributes, and a 20-byte symbolic memory
input makes the solver run out of memory.  The cell therefore exposes the same
information as scalar words:

- three little-endian u64 words for the 20 program bytes (bijection), and
- four little-endian u64 words for the 25-byte script plus 7 zero pad bytes
  (bijection).

Every byte that Core would write is observed exactly once, and the pad bytes
are proved zero.  Nothing is existentially chosen or dropped; `p2`'s high 32
bits are simply not part of the 20-byte program.

## What is proved

| function | observed bytes |
|---|---|
| `cell_p2wpkh_script_w0` | `76 a9 14` + program[0..4] |
| `cell_p2wpkh_script_w1` | program[5..12] |
| `cell_p2wpkh_script_w2` | program[13..19] + `88` |
| `cell_p2wpkh_script_w3` | `ac` + zero padding |

Alive2 compares the C and L IR for all four functions (green, semantic
equality).  SAW verifies both modules against the same Cryptol construction
`script p0 p1 p2`, eight proofs.  The L leg stores the string suffix-first and
the Cryptol leg builds it prefix-first, so the agreement is not a
self-comparison.

## What is not proved

- `ExecuteWitnessScript` / `EvalScript` on the script (SCR-136 second half):
  no interpreter loop, no opcode dispatch.
- `HASH160(pubkey) == program` and `CHECKSIG`: no HASH160, no ECDSA.  Per
  `spec/equiv/README.md` §7 these stay conditional on the same-crypto premise.
- Any stack/witness post-state (SCR-138 is the sibling cleanstack cell).
