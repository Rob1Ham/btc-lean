# control-flow/C-L-casttobool-full

## Status

`both-green` for the complete consensus element domain: every length
`n` in `0..520`, every byte value.  This closes the domain gap that demoted
SCR-057 in the wave65 snapshot audit (F3): the older cell
`control-flow/C-L-casttobool` fixed `vch.size()` at 0, 1 and 2, so lengths
3..520 were a stated gap.  This cell does not fix the length.

## What changed relative to the bounded cell

The bounded cell compiled three wrappers with `vch.size()` fixed at 0, 1 and
2, which let clang unroll the loop away.  Here the exported function is

```c
uint32_t cell_cast_arb(const uint8_t* vch, uint32_t n) {
  __builtin_assume(n <= 520u);   // consensus element bound
  return core_cast_to_bool(vch, n) ? 1u : 0u;
}
```

where `core_cast_to_bool` is the verbatim `interpreter.cpp:46-59` loop.  The
built IR still contains `!llvm.loop` (recorded as `loop_present_c=1` and
`loop_present_l=1` in `build/build.txt`), so neither tool is proving a
per-length unrolled instance.  The L leg is the twin's real loop, extracted
verbatim from `twin/runtime.inc`; `src/extract_twin.py` pins the SHA-256 of
the exact function text and fails the build on drift.

## The proved statement

For every `n` in `[0,520]` and every `b : [n][8]`:

* `n = 0` -> false.
* If some `b[i] != 0` with `i < n-1`: true.  The scan stops there, so the
  negative-zero test (`i == n-1`) cannot apply; in particular `0x80` before
  the last position is true.
* Otherwise every pre-last byte is zero, so the last byte decides:
  `b[n-1] = 0x00` -> false, `b[n-1] = 0x80` -> false (negative zero),
  any other nonzero byte -> true.

This is exactly the three named outcomes of SCR-057 plus the positional
scan/no-scan rule.  Both legs are proved equal to this predicate.

## Alive2

`alive2/run.sh` builds the two leaves and runs (exact command in
`alive2/result.txt`):

```sh
alive-tv --bidirectional --smt-to=60000 \
  build/c_cell_cast_arb.ll build/l_cell_cast_arb.ll
```

The length is a symbolic 32-bit argument constrained by `llvm.assume(n <= 520)`
in both leaves.  `--bidirectional` checks both refinement directions of the
single C/L pair; the report says "These functions seem to be equivalent!" and
contains one correct transformation, zero incorrect, zero failed-to-prove,
zero Alive2 errors, and ends in `STATUS=alive2-green`.  Alive2 reasons about
the loop directly; no `--src-unroll`/`--tgt-unroll` factor is used.

## SAW

`saw/run.sh` verifies C and L against the same independent Cryptol predicate in
`src/cell.cry`:

```sh
(cd build && saw cell.saw)
```

The script allocates a fully symbolic 520-byte array, fixes no length, and
preconditions only `n <= 520`.  Both `llvm_verify` calls print
`Proof succeeded!` (2 proofs), no `Proof failed`, and the result ends in
`STATUS=saw-green`.  The predicate is the scan/no-scan abstraction above; the
`0x80` rule is applied only at `n-1`.

## Domain completeness

The domain is finite in length: Core never creates a script element larger
than 520 bytes (`MAX_SCRIPT_ELEMENT_SIZE`).  The symbolic proof covers all
521 lengths simultaneously, so this is a complete finite abstraction rather
than a sampled domain.  There is no `partial` coverage bullet for SCR-057 in
this cell and no "lengths 3..520 are a gap" statement.

## Limits

* Predicate cell only: no flags, sigversion, stack, or whole-`VerifyScript`
  path is involved.
* The domain assumption `n <= 520` is the consensus element bound, not an
  extra semantic restriction.  A caller that passes a longer `valtype` is
  outside Core's script-element invariant.
* The C leaf is a source-excerpt slice, not the whole Core translation unit.
* `-O1 -fno-strict-aliasing` matches the other bounded leaves.  No Core source
  patch and no twin edit is used.
