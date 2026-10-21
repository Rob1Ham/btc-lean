# e4-witness/C-L-w32-witness-v0-error-total

Bounded, symbolic proof of the **total** v0 `VerifyWitnessProgram` dispatch and
error function.  Unlike `e4-witness/C-L-witness-v0-dispatch`, the two
operations the dispatch calls are kept as symbolic inputs instead of being
fixed to success:

- `hash_ok` — `memcmp(SHA256(witnessScript), program, 32) == 0`
  (`interpreter.cpp:1943`), the SCR-133 predicate;
- `(exec_res, exec_err)` — the pair `ExecuteWitnessScript` returns
  (`interpreter.cpp:1946`, `1953`).

So nothing outside the v0 dispatch is asserted.  The cell is total over
`(plen, wn, hash_ok, exec_res, exec_err)` and proves the exact `(result,
error)` pair, including the converses ("no other input yields 39/38/40").

## Seam and citations

Core (`/tmp/opencode/core-pin/src/script/interpreter.cpp`, pin `cce32b168`):

- `1933-1938` — 32-byte v0 program; `stack.size() == 0` returns 39.
- `1939-1945` — SHA256/memcmp; mismatch returns 40.  `hash_ok` is symbolic.
- `1946` — `ExecuteWitnessScript`.  Its result pair is symbolic.
- `1947-1951` — 20-byte v0 program; `stack.size() != 2` returns 40.
- `1952-1953` — implied P2WPKH script, then `ExecuteWitnessScript`.
- `1954-1955` — every other v0 length returns 38.

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean:1259-1280`) has the same branch
order.  The L leg is a reviewed transliteration (the twin has no
`VerifyWitnessProgram` handler, so there is no generated body).

## What is proved

| plen | wn | hash_ok | result, error |
|---:|---:|---:|---|
| 32 | 0 | any | (0, 39) |
| 32 | > 0 | 0 | (0, 40) |
| 32 | > 0 | != 0 | (exec_res, exec_err) with `1 => 0` |
| 20 | != 2 | any | (0, 40) |
| 20 | 2 | any | (exec_res, exec_err) with `1 => 0` |
| other | any | any | (0, 38) |

Alive2: `--bidirectional`, one combined summary, "These functions seem to be
equivalent!"  SAW: both modules verified against the same independent Cryptol
function `v0_error_total`.

## What is not proved

- `SHA256(witnessScript) == program` (SCR-133): `hash_ok` is an input.
- `ExecuteWitnessScript`: EvalScript loop, HASH160/RIPEMD160, ECDSA/Schnorr
  CHECKSIG, cleanstack, EVAL_FALSE (SCR-136/138 and later rows).
- Any taproot/tapscript branch, P2SH wrapping, tx decoding, flags, sigops or
  witness weight.
- No hash or crypto internals; the same-hash premise is untouched.

## Exact commands

```sh
spec/equiv/cells/e4-witness/C-L-w32-witness-v0-error-total/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-witness-v0-error-total/saw/run.sh
```

## Raw results (2026-10-20)

Alive2 tail:

```
These functions seem to be equivalent!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW tail:

```
Verifying cell_v0_error_total...
...
Proof succeeded! cell_v0_error_total
Verifying cell_v0_error_total...
...
Proof succeeded! cell_v0_error_total
STATUS=saw-green
```

## Negative control (not committed)

A copy of the L leg with the 20-byte guard changed from `wn != 2` to
`wn < 2` was built in `/tmp/opencode/w32-probe` and checked with the same
`alive-tv --bidirectional` command.  Result: `Transformation doesn't verify!`,
`ERROR: Value mismatch`, C = 160 (0,40) vs L = 0 at `plen=20`, `wn=3`.
This confirms the signed cell is not vacuous.

## Proposed mutation (not executed)

Not needed beyond the negative control above; a permanent mutation record
belongs to the gate/redteam workstream.
