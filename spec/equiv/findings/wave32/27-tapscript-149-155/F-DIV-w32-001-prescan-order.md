# F-DIV-w32-001 — OP_SUCCESSx pre-scan error ordering (C vs Lean)

**Status:** open model divergence, reproduced with SAW and a concrete driver.
**Severity (honest scope):** diagnostic / error-code only. Both implementations
reject the script. This is **not** an accept/reject consensus split, and it is
not a claim about Bitcoin Core itself — it is a divergence between the pinned
Core source and the Lean model in this repository.
**Rows affected:** SCR-153, SCR-154 (the bounded cell excludes this path).

## Summary

On the TAPSCRIPT path, Core scans the whole script for `OP_SUCCESSx` *before*
the initial stack-size and item-size checks. If the scan hits a truncated push,
`GetOp` fails and Core returns `SCRIPT_ERR_BAD_OPCODE` immediately
(`interpreter.cpp:1851-1854`). The Lean `executeWitnessScript`
(`spec/core/Bitcoin/Interpreter/Defs.lean:1211-1233`) first tests
`opSuccessScan`, then `MAX_STACK_SIZE`, then `runExec`'s item-size check, and
only later reaches `parseWire` inside `evalScriptBytes`, which reports
`badOpcode`. So when a script has a truncated push **and** an oversized
initial stack or item, Core reports `BAD_OPCODE` while Lean reports
`STACK_SIZE` / `PUSH_SIZE`.

Both legs return a failure; the divergence is the error ordinal only.

## Reproducer

C leg: `probe/probe_c.cpp` — line-cited Core excerpt order
(`interpreter.cpp:1851-1865`, scan failure first).
L leg: `probe/probe_l.cpp` — reviewed transliteration of
`Defs.lean:1211-1233` (size checks before `parseWire`).

SAW counterexample (`probe/saw/result.txt`):

```
len: 4   b0: 2   b1: 2   b2: 128 (0x80)   b3: 78 (0x4e)
tm: 0    os: 16  di: 2048
C: 64 = BAD_OPCODE (16)        L: 24 = PUSH_SIZE (6)
```

The script bytes are `02 02 80 4e`: a push of two bytes, then `PUSH_DATA4`
(`0x4e`) at offset 3 with a four-byte operand missing — a truncated tail.
Core's scan reports `BAD_OPCODE` before the item-size check; Lean reaches the
size check (`os=16` → `PUSH_SIZE`) first.

Concrete driver (`probe/driver/result.txt`, built by `probe/run_driver.sh`):

```
saw-cex  len=4 bytes=02 02 80 4e tm=0 os=16 di=2048  C=64  L=24  DIVERGE
stack    len=1 bytes=02 00 00 00 tm=1 os=0  di=0     C=64  L=32  DIVERGE
success  len=1 bytes=50 00 00 00 tm=0 os=0  di=0     C=1   L=1   agree
disc     len=1 bytes=50 00 00 00 tm=0 os=0  di=1     C=144 L=144 agree
```

The last two lines show the well-formed paths still agree, so the probe is not
an artefact of the harness.

## Alive2 tool note (recorded, not hidden)

`alive-tv` 20.0 on the raw clang `-O1` IR reports
`Transformation seems to be correct!` for this pair — and also for a copy of
the L leg with a return constant changed, with `--skip-smt`, in ~0.1 s. Alive2
is silently not discharging the query on that IR shape (a tool limitation, not
evidence of equivalence). After `opt -O2` the same pair yields a counterexample
(`probe/alive2/result.txt`, run 2):

```
Example: len=3 bytes=00 00 01 00 tm=1 os=0 di=0
Source value: 64   Target value: 32
```

`probe/run_alive2.sh` records both runs and sets `STATUS=divergence-confirmed`
from the O2 run only. SAW is the primary evidence: it reports a counterexample
against an independently written Cryptol specification. The cell runners also
use the `opt -O2` form with `--always-verify` and are mutation-checked
(`check_alive2_nonvacuous.sh`); the cell SAW runs still verify the raw `-O1`
functions.

## Why the cells are unaffected

`C-L-w32-op-success-prescan` compares only the `found` bit of the scan
(`1` = OP_SUCCESSx seen, `0` = not seen / decode failure folded), not the
error kind. Its postcondition explicitly excludes the malformed-tail error
kind. This finding is the exact reason for that exclusion.

## Smallest next experiment

In the Lean `executeWitnessScript`, make the scan return a three-way result
(`found | none | decodeFailure`) and branch to `badOpcode` **before** the
`MAX_STACK_SIZE` / item-size checks on `decodeFailure`, matching
`interpreter.cpp:1851-1854`. Then rebuild the 8-byte prescan pair and re-run
SAW + Alive2 (`opt -O2`) on the `stack` case above; expected both legs `64`.

## Files

- `probe/probe_c.cpp`, `probe/probe_l.cpp` — the two legs
- `probe/probe.cry`, `probe/probe.saw` — independent Cryptol spec + SAW script
- `probe/driver.cpp`, `probe/run_driver.sh` — concrete driver
- `probe/alive2/result.txt` — raw Alive2 (run 1: unsound "correct"; run 2: cex)
- `probe/saw/result.txt` — SAW (C leg proved, L leg counterexample)
- `probe/driver/result.txt` — concrete values
- `probe/run_alive2.sh`, `probe/run_saw.sh`, `probe/build.sh` — runners

Exact commands, from this directory:

```sh
./run_driver.sh
./run_saw.sh
./run_alive2.sh
```
