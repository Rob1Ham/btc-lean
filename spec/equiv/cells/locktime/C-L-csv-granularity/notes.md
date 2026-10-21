# locktime/C-L-csv-granularity — notes

BIP68 granularity, row SCR-131, both tools green.

## Commands

```sh
cd /tmp/opencode/wave16/12-locktime
bash spec/equiv/cells/locktime/C-L-csv-granularity/alive2/run.sh
bash spec/equiv/cells/locktime/C-L-csv-granularity/saw/run.sh
sha256sum -c spec/equiv/cells/locktime/C-L-csv-granularity/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/locktime/C-L-csv-granularity/saw/certificate.sha256
```

Tools: Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang++-20 20.1.2.

## What is proved

| function | claim | C source |
|---|---|---|
| `cell_csv_masked` | raw masked verdict (no scaling) | `interpreter.cpp:1812-1833` |
| `cell_csv_mask_probe` | bits outside `0x0040ffff` are irrelevant | same, congruence form |
| `cell_seq_granularity` | `(seq & 0xffff) << 9` = `rel * 512` | `tx_verify.cpp:94` |
| `cell_seq_time_ok` | time lock vs block MTP, height case contributes nothing | `tx_verify.cpp:79-94,103-111` |

Each function is checked twice — once for the C excerpt module and once for
the Lean-transliteration module — against the same independent Cryptol
predicate, so `saw/result.txt` has 8 `Proof succeeded!` lines.  Alive2 runs
one C-vs-L comparison per function, so `alive2/result.txt` has 4
`Transformation seems to be correct!` blocks.

## Why the cells are shaped this way

- **The script-level compare is raw.**  A tempting misreading of "512-second
  granularity" is that `CheckSequence` scales one side by 512.  It does not:
  `interpreter.cpp:1812-1814` masks both sides with
  `TYPE_FLAG|MASK = 0x0040ffff` and compares them directly.  Claim 1 pins the
  raw comparison, and claim 2 proves the congruence that makes the mask sound
  (bits 16..21 and 23..30 cannot matter).
- **The 512 factor appears only when the masked value becomes a time.**
  `tx_verify.cpp:94` computes
  `nCoinTime + (int64_t)((seq & MASK) << 9) - 1`.  Claim 3 proves the shift is
  exactly `seqRelative * 512`; claim 4 composes it with the acceptance test.
- **No off-by-one.**  `EvaluateSequenceLocks` rejects when
  `nMinTime >= nBlockTime`, and `nMinTime` is `coin + rel*512 - 1`, i.e. the
  **last invalid** time.  Rejection means `coin + rel*512 - 1 >= block`, so
  acceptance is `coin + rel*512 <= block`, which is exactly Lean's
  `seqTimeOk` (`Laws.lean:431-434`) and `seqTimeLock_last_invalid`
  (`Laws.lean:440-444`).  The cell states this as one integer inequality; no
  separate off-by-one rule is assumed.
- **Height-based inputs leave the time lane at `-1`.**  With `TYPE_FLAG`
  clear the branch at `tx_verify.cpp:79` does not touch `nMinTime`, which is
  initialised to `-1`; `-1 >= nBlockTime` is false for a non-negative MTP, so
  the time lane always passes.  `seq_time_ok`'s first branch mirrors that.

## Source and elisions

The C leg keeps the cited expressions verbatim.  Elisions, all named in
`spec.md`:

1. The opcode dispatch, stack guard and `CScriptNum` decode — the operand
   arrives decoded (SCR-051/052).
2. The version gate and transaction disable-flag gate — proved in
   `locktime/C-L-csv-op` (SCR-128/129).
3. The multi-input `std::max` fold and `prevHeights` — one input in the
   domain, so the fold is the identity (SCR-132 owns indexing).
4. `GetAncestor`/`GetMedianTimePast` — the coin time is an arbitrary uint32
   MTP, which is exactly the set of reachable MTP values (median of uint32
   header times).
5. `break`/`return false` at the opcode level is spelled as the ScriptError
   ordinal in the sibling cell; here the functions return the boolean verdict
   (`1`/`0`) or the converted value directly, because the row is about the
   arithmetic split, not the error plumbing.

## Domain note (stated, not silently reduced)

The Lean predicates use `Nat` for MTPs.  The cell quantifies over `uint32_t`
MTPs.  That is the reachable domain (`chain.h:233`: the median of uint32
header times is one of them) and it keeps Core's own `int64_t` sum in range.
A `Nat` MTP of `2^32` or more is not reachable from a header chain, so this is
not a weakening of the rule; the branch structure is complete either way.

## Twin status

`twin/ops_ir.py:44-58` (flag-on CLTV/CSV) returns `TWIN_INVALID_UNSUPPORTED`
because the generated twin's `Ctx` has no transaction context.  The L leg is
therefore the reviewed Lean transliteration, matching `locktime/C-L-cltv-op`
and `locktime/C-L-csv-op`; recorded as finding F-LOCKTIME-001 in the wave
report.

## Why the row is full

SCR-131's decision content is the height/time split and the 512 factor.  Both
lanes are present: `cell_seq_granularity`/`cell_seq_time_ok` prove the time
lane and its 512 scaling; `cell_csv_masked` proves that the script-level
comparison stays in the raw masked domain, and the height lane's unscaled
`seqRelative` is the same function (`seq_relative`) that half of
`cell_seq_granularity` and the LP/HP split of the masked compare exercise.
Both `TYPE_FLAG` branches and all masked-compare outcomes are covered, so the
row is marked `full`, not `partial`.
