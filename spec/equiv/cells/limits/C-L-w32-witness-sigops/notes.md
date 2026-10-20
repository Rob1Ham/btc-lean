# limits/C-L-w32-witness-sigops — notes

## What the cell takes apart

`WitnessSigOps` reads exactly three things:

1. `witversion` (zero or not);
2. `witprogram.size()` (20, 32, or other);
3. the last witness stack item, and only after checking that the stack is
   non-empty.

It never reads the program bytes or any witness item other than the last.  The
cell therefore passes the program **length** and a symbolic stack size, and
packs only the last item.  This is not a lossy abstraction: the omitted bytes
are unread by the sliced Core function and by `witnessSigOps`.

## Domain

The item is a script counted with the accurate static rule.  Its domain is
four bytes, the same bound as the other limits cells (eight bytes made Alive2
exceed its SMT budget).  Every counting branch is reachable in four bytes:
`ac` = 1, `ae` = 20, `52 ae` = 2, `53 ae` = 3, `52 ae ac` = 3.  A larger item
in the v0-32 arm returns `0xffffffff` from both legs and the spec.

## Residual loops make Alive2 vacuous

A first draft used `for` loops.  Alive2 reported "1 correct transformations"
for a blatant mutation (`return 999u;`) that the same IR executes as 999.  A
residual loop is not a trustworthy Alive2 input.  All walks in this cell are
unrolled with an explicit live flag, the extracted IR has no `llvm.loop`
metadata, and the shared Alive2 runner fails the cell if a loop survives.

## Mutation sanity check

Mutating the L leg's v0-20 arm from `return 1;` to `return 2;` makes Alive2
report a counterexample ("Source value: #x00000001 (1) / Target value:
#x00000002 (2)").  The green result is not vacuous.

## Spot evaluations

| version | prog_len | stack_size | item bytes | count |
|---|---|---|---|---|
| 0 | 20 | 0 | — | 1 |
| 0 | 32 | 1 | `52 ae` | 2 |
| 0 | 32 | 1 | `01 ac` | 0 (push data) |
| 0 | 32 | 1 | `ae` | 20 |
| 0 | 32 | 0 | `52 ae` | 0 |
| 1 | 32 | 1 | `52 ae` | 0 |
| 0 | 21 | 1 | `52 ae` | 0 |
| 0 | 32 | 1 | 9-byte item | 0xffffffff (out of domain) |
