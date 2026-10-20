# limits/C-L-w32-sigop-count — notes

## Domain bound: four script bytes

The cell domain is `LIMITS_MAX_SCRIPT_BYTES = 4`.  Eight bytes was tried first
and made Alive2 exceed its 120 s SMT budget; four bytes completes in 5–11 s
with `--smt-to=60000`.  Four bytes are enough to reach every opcode class and
every branch of SCR-032/SCR-033:

- a sigop opcode at each of the four positions;
- OP_CHECKSIG, OP_CHECKSIGVERIFY, OP_CHECKMULTISIG, OP_CHECKMULTISIGVERIFY;
- every preceding OP_1..OP_16 value, since the preceding byte is symbolic;
- every non-OP_N preceding opcode (direct push, OP_PUSHDATA1/2, OP_0,
  OP_1NEGATE, OP_RESERVED, arbitrary opcodes);
- direct pushes of 0..3 bytes, PUSHDATA1 with 1- and 2-byte fields,
  PUSHDATA2 with 2-byte fields, and the truncated tails of all three
  length-prefixed forms (a PUSHDATA4 payload cannot fit in four bytes, so only
  its truncation arm is reachable — recorded here, not hidden).

`len > 4` returns `0xffffffff` in both legs and in `cell.cry`; both tools prove
that too.  The sentinel is above every in-domain count (at most 80), so it
cannot hide a disagreement inside the domain.

## Harness shape

`src/c_leg.cpp` keeps Core's `GetScriptOp` control flow and length checks and
drops the recovered push payload, which `GetSigOpCount` never inspects.
`src/l_leg.cpp` is the Lean `getOp`/`sigOpStep`/`parseWirePrefix` walk with the
same byte reads.  Both then run the loop body four times (each decoded opcode
consumes at least one byte).

The ABI word is unpacked into eight scalar `uint32_t` fields and every byte
read is an explicit index dispatch (`cells/_tools/limits/limits_common.h`).

### Rejected harness variants

1. **Variable 64-bit shift** `(w >> (8*i))` in the C harness: undefined C++ for
   `i >= 8`; clang's speculative form made Alive2 report spurious poison.
2. **Byte array in an alloca**: Alive2 lost the memory contents and reported a
   vacuous "correct" transformation.  Unacceptable.
3. **Jump tables**: without `-fno-jump-tables`, clang emits
   `@switch.table.* = external ... constant`, which Alive2 treats as
   unconstrained and turns into a false green.  The build always passes
   `-fno-jump-tables`, and the Alive2 runner fails if `switch.table` or
   `= external` appears in the extracted IR.

## Alive2 sanity check

A mutation of the C leg (`20 → 19` in the inaccurate multisig arm) is reported
by Alive2 as a real counterexample ("Source value: #x14 (20) / Target value:
#x13 (19)"), so the green result is not vacuous.  The runner also requires
`--always-verify` and the exact summary counts (1 correct, 0 incorrect,
0 failed-to-prove, 0 Alive2 errors).

## Cryptol / SAW encoding notes

- Numeric literals are width-sensitive in Cryptol 3.6: `0xac` is `[8]`, so all
  [64] constants are written as 16 hex digits.  Decimal constants are
  polymorphic.
- `let ... in` is not accepted in expression position by this Cryptol; the
  helpers use `where` clauses.
- `sbyte` uses constant shifts with an index dispatch instead of a symbolic
  shift amount.  A symbolic shift becomes a 64-bit barrel shifter in every
  round and makes the SAW obligation needlessly hard.
- `count32 = drop` is the lossless [32] projection of the [64] count for the
  uint32_t ABI.

## Spot evaluations

`count` on hand-checked Core cases (script bytes shown in wire order):

| bytes | len | accurate | count |
|---|---|---|---|
| `ae` | 1 | false | 20 |
| `52 ae` | 2 | true | 2 |
| `01 ae` | 2 | true | 0 (the `ae` is push data) |
| `ac` | 1 | true | 1 |
| `4c 01 ae` | 3 | true | 0 (PUSHDATA1 payload) |
| `52 ae 53 ae` | 4 | true | 5 |
| `4d 01 00 ae` | 4 | true | 0 (PUSHDATA2 payload) |
| `ae` | 5 | true | 0xffffffff (out of domain) |
