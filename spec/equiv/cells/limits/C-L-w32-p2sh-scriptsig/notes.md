# limits/C-L-w32-p2sh-scriptsig — notes

## Domain: four scriptSig bytes

Same bound and rationale as `C-L-w32-sigop-count`: eight bytes made Alive2
exceed its SMT budget, four bytes completes quickly, and every branch of
SCR-034 is reachable.  The largest redeem data reachable through a four-byte
scriptSig is a direct push of three bytes (`03 52 ae ac`), which is enough for
the accurate lookback and a following opcode.

Reachable examples (scriptSig bytes in wire order):

| scriptSig | len | result | why |
|---|---|---|---|
| `03 52 ae ac` | 4 | 3 | redeem `52 ae ac`: OP_2, CMS = 2, CHECKSIG = 1 |
| `02 52 ae` | 3 | 2 | redeem `52 ae` |
| `01 ac` | 2 | 1 | redeem `ac` |
| `4c 01 ac` | 3 | 1 | PUSHDATA1 last push, redeem `ac` |
| `4d 01 00 ac` | 4 | 1 | PUSHDATA2 last push, redeem `ac` |
| `ac` | 1 | 0 | opcode > OP_16 (non-push-only) |
| `4c` | 1 | 0 | truncated push (malformed scriptSig) |
| `00` | 1 | 0 | empty last data |
| `51` | 1 | 0 | OP_1 clears the data register |
| empty | 0 | 0 | no last push |
| `ae` | 5 | 0xffffffff | out of domain |

The `PUSHDATA4` arms in both parsers are present but only their truncation
branch is reachable in four bytes (a four-byte length field cannot be followed
by a payload); this is the same situation as cell A and is not hidden.

## The two loops are deliberately different

The scriptSig walk is **all-or-nothing** (a malformed push returns 0), while
the redeem-data walk is **prefix-keeping** (a malformed push keeps the count of
the already parsed prefix).  Both cells encode this distinction explicitly;
conflating them would be a real bug on e.g. a scriptSig whose redeem data is
`ac 4c`.

## Hash / jump-table guards

`-fno-jump-tables` is mandatory: without it clang emits
`@switch.table.* = external ... constant`, which Alive2 treats as
unconstrained and turns into a false green.  The Alive2 runner also fails on
`alloca`, `= external`, or `switch.table` in the extracted IR.

## Residual loops make Alive2 vacuous

The first draft of this cell used `for` loops in both legs.  Alive2 reported
"1 correct transformations" even for a blatant mutation (`return 999u;`) that
the same IR executes as 999 for scriptSig `02 52 ae`.  A residual loop is not
a trustworthy Alive2 input.  Both walks are now unrolled with an explicit live
flag (no `llvm.loop` metadata in either extracted module), and
`_tools/limits/run_alive2.sh` fails the cell if `llvm.loop` survives.

## Mutation sanity check

With the unrolled IR, mutating the L leg's `return prev_num;` to
`return 999u;` (accurate multisig) makes Alive2 report a counterexample
("Source value: #x00000008 (8) / Target value: #x000003e7 (999)").  The green
result is therefore not vacuous.
