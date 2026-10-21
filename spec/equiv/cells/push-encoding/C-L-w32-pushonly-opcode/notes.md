# push-encoding/C-L-w32-pushonly-opcode

SCR-052 at the one-op / symbolic-opcode level.

The cell proves that both legs classify every wire byte the same way for a
script of length 0 or 1, including the named `OP_RESERVED` (0x50) case and
the `OP_16` (0x60) / `OP_17` (0x61) boundary.

Why this is **partial**: `CScript::IsPushOnly` is a loop over the whole
script.  This cell fixes the script to zero or one byte, so a multi-op
script and a successful `PUSHDATA1/2/4` push are not exercised, and the
script-level `all` conjunction is only one step deep.

The bound is a scope decision, not a tool rejection.  A probe with a
symbolic trip count

```c
unsigned f(unsigned n, unsigned x) {
  unsigned s = x;
  for (unsigned i = 0; i < n && i < 10; i++) s = s * 1664525u + 1013904223u;
  return s;
}
```

compiled with the same clang flags and checked with
`alive-tv --smt-to=10000`, reports `1 correct transformations` and a
deliberately mutated twin reports `1 incorrect transformations`; Alive2
handles this loop shape.  What was not attempted is the full symbolic-length
script with the complete `GetOp`/`decode_op` byte-decoding surface and a
bounded script buffer.  The smallest next experiment is a fixed 520-byte
buffer plus symbolic length, with `classify_push_only` unrolled once in the
harness only if the SMT query becomes intractable; a SAW/Cryptol
loop-invariant proof of the fold is the alternative.

The truncated-push cases are included deliberately: for a one-byte script,
`GetOp` fails on every push form and both legs return false.  This cell
observes a Boolean, not an error kind, so F-DIV-001 does not apply.
