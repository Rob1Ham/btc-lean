# e4-witness/C-L-w32-witness-hash-compare

Bounded, symbolic proof of the **32-byte digest/program comparison and
mismatch branch** at `interpreter.cpp:1939-1945`.  The digest is a symbolic
input; SHA256 itself is the SCR-133 seam and is not modelled.

## Seam and citations

Core:

```cpp
uint256 hash_exec_script;
CSHA256().Write(exec_script.data(), exec_script.size())
         .Finalize(hash_exec_script.begin());
if (memcmp(hash_exec_script.begin(), program.data(), 32)) {
    return set_error(serror, SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH);
}
```

- `interpreter.cpp:1939-1945` — hash, 32-byte memcmp, mismatch -> 40.
- `interpreter.cpp:1946` — `ExecuteWitnessScript`, symbolic pair.
- Lean `Defs.lean:1269` — `hashSha256 script != program` on `ByteArray`s.
- `Hashes.lean:125` — `hashSha256`; **not** modelled here.

## Proof shape

The digest `h0..h3` and program `p0..p3` are four little-endian u64 words
each (a 256-bit bijection).  The C leg compares four words (the `memcmp`
predicate); the L leg compares the same 32 bytes one at a time (the Lean
`ByteArray` inequality).  Both are proved equal, in both directions, to an
independent Cryptol `hashCompare`, so the comparison is exact over all 2^256
pairs: a mismatch in any byte returns `(0,40)`; a full match passes through
the `ExecuteWitnessScript` pair.

This rules out, for example, a 24-byte prefix comparison, an OR-of-equality
bug, or byte-order confusion, which a one-bit `hash_ok` abstraction cannot.

## What is not proved

- `CSHA256().Write(...).Finalize(...)` (SCR-133's hash claim).  There is no
  SHA256 model at the leaf seam: the twin emits an opaque external
  `sha256(p, l, out)` (`twin/ops_ir.py:853-887`), the Lean `hashSha256`
  (`Hashes.lean:125`) is a list-based model with no proved link to Core's
  `CSHA256`, and no same-hash floor cell exists.  SCR-133 therefore remains
  partial/open.  The same-hash premise stays explicit and conditional on
  `docs/DECISION-lax-ecdsa.md`.
- Any script execution or crypto internals.
- No claim that SHA256(x) equals any particular value for any x.

## Exact commands

```sh
spec/equiv/cells/e4-witness/C-L-w32-witness-hash-compare/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-witness-hash-compare/saw/run.sh
```

## Raw results (2026-10-20)

Alive2:

```
Transformation seems to be correct!
These functions seem to be equivalent!
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW: two `Proof succeeded!` lines (C and L against the same spec),
`STATUS=saw-green`.

## Negative control (not committed)

A copy of the L leg that dropped the fourth word (`h3`/`p3`) from the compare
was built in `/tmp/opencode/w32-probe`.  `alive-tv --bidirectional` reported
`Transformation doesn't verify!`, `ERROR: Value mismatch`, C = 160 (0,40) vs
L = 0.  This is exactly the prefix-comparison class the signed cell excludes.

## Smallest next experiment for SCR-133

A standalone bounded **single-block SHA256 floor** cell: C leg = a slice of
`src/crypto/sha256.cpp` `sha256::Transform` specialized to one 64-byte block
(the 64 rounds are already fully unrolled in the pinned source; only the
`blocks` loop must be removed), L leg = a reviewed transliteration of
`sha256Compress`/`sha256Schedule` from `Hashes.lean:99-131`, with a FIPS
180-4 Cryptol spec for SAW.  It needs an 8×u32 state marshalling (eight
scalar witnesses or an aggregate) and a 16×u32 block marshalling, so it is a
separate cell, not a tweak of this one.  It would still only cover length ≤ 55
bytes (single block) and would not discharge the whole SCR-133 row, whose
witnessScript is arbitrary-length; the full row additionally needs the
multi-block `mdPad`/length loop and the same-hash premise.
