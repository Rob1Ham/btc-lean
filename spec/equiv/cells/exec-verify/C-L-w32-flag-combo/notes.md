# C-L-w32-flag-combo — notes

## Scope

The row (SCR-009) is "Flag combination constraint", core_ref
`interpreter.cpp:VerifyScript:2113-2114 (assert)`.  The contract makes the two
VerifyScript assertions a total domain rule (`tape.md` §5.6) with result 2,
implemented in `shims/core/entry.cpp:93-100`.  The Lean model states the same
predicate as `flagsComboOk` (`Rules.lean:47-50`), including the
`WITNESS => P2SH` arm at :2124.

The cell proves the C domain check and the Lean predicate agree on all eight
combinations of the three bits.  It does not prove anything about a release
build's behaviour when Core's `assert` is violated (there is no defined
behaviour; the contract rejects the input instead).

## Overlap

The `WITNESS => P2SH` arm is SCR-014's row (a different wave-32 task).  It is
present in the function because both `flagsComboOk` and the shim carry it, but
only SCR-009 is claimed here.  Whoever closes SCR-014 can cite this cell as
corroboration without changing it.

## Tool notes

- Alive2 v20, SAW 1.6 with z3.  Three symbolic bits plus irrelevant high bits
  are discharged immediately.
- The observable is the domain answer (0 admissible / 2 rejected), not a
  script verdict; the spec says so to avoid reading result 2 as a script
  failure.
