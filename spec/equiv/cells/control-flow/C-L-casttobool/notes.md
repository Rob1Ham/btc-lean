# control-flow/C-L-casttobool

## Status

`both-green` for the symbolic bounded element domain (length 0-2, every byte
value). This is a predicate cell, not a whole-entry proof.

## Design

`CastToBool` (`interpreter.cpp:46-59`) is a loop over the element bytes with a
single special case: a nonzero byte at the last position equal to `0x80` is
negative zero and is false. The C leaf keeps the loop verbatim and exports
three functions with `vch.size()` fixed at compile time (0, 1, 2), so clang
fully unrolls the loop and both tools see a loop-free leaf. The L leaf calls
the twin's bounded `cast_to_bool` helper from `build/twin_ops.h` (emitted
verbatim by `cells/_tools/mk_leaf.py`) at the same three fixed lengths.

The Cell's element domain is exactly the existing twin bounded element domain
(`max_elem = 2`); lengths 3-520 are not enumerated. The three outcomes named by
SCR-057 are each covered, including the negative-zero case at the last byte
(len 1) and at a non-last byte (len 2, first byte `0x80`, which is true).

## Alive2

`alive2/run.sh` builds `src/build.sh` and runs:
`alive-tv build/c_cell_cast_{empty,len1,len2}.ll build/l_cell_cast_{empty,len1,len2}.ll`.
All three pairs report `Transformation seems to be correct!` with
`1 correct transformations`, `0 incorrect`, `0 failed-to-prove`,
`0 Alive2 errors`; `alive2/result.txt` ends in `STATUS=alive2-green`.

## SAW

`saw/run.sh` copies `src/cell.cry`/`src/cell.saw` into `build/` and runs
`(cd build && saw cell.saw)`. Both legs are verified against the same
independent Cryptol predicate for every byte value: 6 `Proof succeeded!`
lines (3 functions x C and L), no `Proof failed`; `saw/result.txt` ends in
`STATUS=saw-green`.

## Limits

- Bounded element length 0-2 (the twin leaf domain). No claim for lengths
  >= 3; the algorithm's remaining behaviour is positional and introduces no
  new outcome, but that is an argument, not a machine proof.
- No flags, sigversion, stack, or consensus path is involved.
- `-O1 -fno-strict-aliasing` matches the other bounded leaves. No Core source
  patch is used.
