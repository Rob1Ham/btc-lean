# witness-v0/C-L-p2wsh-hashmatch

The comparison half of SCR-133: `memcmp(SHA256(witnessScript), program, 32)`
(interpreter.cpp:1941-1945), with the hash itself abstracted.

## Design

`cell_p2wsh_hashmatch(d0..d3, p0..p3)` treats the digest and the program as four
little-endian u64 words each and returns

- `(2, 0)` when all four words are equal (continuation sentinel for
  `ExecuteWitnessScript`), and
- `(0, 40)` `SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH` otherwise.

The C leg computes `(d0^p0) | (d1^p1) | (d2^p2) | (d3^p3)`; the L leg uses a
four-way `&&` conjunction, so the Alive2 result is a semantic comparison of two
different spellings.  Equality of 32 bytes is invariant under any fixed byte
permutation, so the word encoding is exact rather than a weakened compare.

`digest` is a symbolic input, not a SHA256 result: the hash primitive is the
same-hash premise (`spec/equiv/README.md` §7).  Result 2 is explicitly a
continuation sentinel, not success.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-p2wsh-hashmatch/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-p2wsh-hashmatch/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-p2wsh-hashmatch/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-p2wsh-hashmatch/saw/certificate.sha256
```

## Versions

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f, solver abc), clang 20.1.2.

## Result

- Alive2: `Transformation seems to be correct!` (semantic; XOR/OR vs
  conjunction), `STATUS=alive2-green`.
- SAW: two `Proof succeeded!` (C and L), `STATUS=saw-green`.

## Limits / blockers

- SHA256(witnessScript) is not computed.  The cell proves the 32-byte compare
  and dispatch only, so SCR-133 remains **partial**.
- A symbolic 32-byte `memcmp` over actual memory was attempted first; Alive2
  rejected the pointer attributes (`nocapture`/`noalias`) and exhausted memory
  on the symbolic buffer.  The word encoding is the information-preserving
  workaround, documented in `spec.md`.
- `CScript` construction from the popped witness item and the subsequent
  `ExecuteWitnessScript` are outside the cell.
