# Wave 16 / 12-locktime — SCR-122..132 closed with Alive2 + SAW

Worktree `/tmp/opencode/wave16/12-locktime`, branch `wave16/12-locktime`,
cut from PR head `805c804`.  Pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
Cells commit: **`e50139f`**.

## Outcome

| row | summary | cell | Alive2 | SAW | coverage |
|---|---|---|---|---|---|
| SCR-122 | CLTV negative operand rejected | `locktime/C-L-cltv-op` | green | green | full |
| SCR-123 | CLTV type agreement at 500000000 | `locktime/C-L-cltv-op` | green | green | full |
| SCR-124 | CLTV `operand <= tx nLockTime` | `locktime/C-L-cltv-op` | green | green | full |
| SCR-125 | CLTV final-input rejection | `locktime/C-L-cltv-op` | green | green | full |
| SCR-126 | CSV negative operand rejected | `locktime/C-L-csv-op` | green | green | full |
| SCR-127 | CSV operand bit 31 ⇒ NOP | `locktime/C-L-csv-op` | green | green | full |
| SCR-128 | CSV tx version < 2 ⇒ fail | `locktime/C-L-csv-op` | green | green | full |
| SCR-129 | CSV tx disable flag ⇒ fail | `locktime/C-L-csv-op` | green | green | full |
| SCR-130 | CSV mask 0x0040ffff | `locktime/C-L-csv-op` | green | green | full |
| SCR-131 | CSV raw masked compare / granularity in SequenceLocks | `locktime/C-L-csv-granularity` | green | green | full |
| SCR-132 | CLTV/CSV see only input `nIn` | `locktime/C-L-locktime-input-index` | green | green | full |

Ledger derivation (`update_ledger.py --check`, not written — shared file):
21 cells scanned, 21 valid, 0 malformed; `SCR-122..132: gap -> both-green`;
green rows 15, blocked 0.

All 11 rows were `gap` before this task.  No row in the family is left
partial or blocked.

## Evidence

Each cell has a real run of both tools and a certificate that verifies:

| cell | Alive2 comparisons | SAW proofs |
|---|---|---|
| `C-L-cltv-op` | 1 (`Transformation seems to be correct!`) | 2 (C and L legs) |
| `C-L-csv-op` | 1 | 2 |
| `C-L-csv-granularity` | 4 (masked, mask-probe, granularity, time-lane) | 8 (4 claims x 2 legs) |
| `C-L-locktime-input-index` | 2 (CLTV, CSV) | 4 (2 checkers x 2 legs) |

Raw logs: `<cell>/alive2/result.txt`, `<cell>/saw/result.txt`.  Certificates:
`<cell>/alive2/certificate.sha256`, `<cell>/saw/certificate.sha256`, hashing
the spec, the runners, both source legs, `contract/error_kind.h`, the emitted
IR and the raw result.  All `patches: none`; no Core/Lean/ledger/STATE edits.

Reproduce:

```sh
cd /tmp/opencode/wave16/12-locktime
for c in C-L-cltv-op C-L-csv-op C-L-csv-granularity C-L-locktime-input-index; do
  bash spec/equiv/cells/locktime/$c/alive2/run.sh
  bash spec/equiv/cells/locktime/$c/saw/run.sh
  sha256sum -c spec/equiv/cells/locktime/$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/locktime/$c/saw/certificate.sha256
done
```

Tools: Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang++-20 20.1.2,
`llvm-extract`/`llvm-dis` 20.1.2.  Cells are built with `-std=c++20 -O1`
(`CScriptNum::operator<=>` needs C++20).

## Design (same shape for all four cells)

- **C leg** is a line-cited source excerpt of the pinned Core:
  `interpreter.cpp` (CLTV opcode `:532-568`, CLTV checker `:1754-1788`, CSV
  opcode `:571-603`, CSV checker `:1791-1836`), `script.h` (`CScriptNum`),
  `primitives/transaction.h` (BIP68 constants, `CTransaction` fields) and
  `consensus/tx_verify.cpp:74-111` (SequenceLocks time lane).
- **L leg** is a reviewed transliteration of the Lean model
  (`Defs.lean:235-297,857-875`, `DataLaws/Laws.lean:240-444`,
  `Interpreter/Rules.lean:89-129`), **not** the generated twin — see
  F-LOCKTIME-001 below.
- **Independent Cryptol predicate** per cell; SAW verifies each leg against it,
  Alive2 verifies C = L directly.
- Observables: ScriptError ordinals (`0` OK, `21` NEGATIVE_LOCKTIME,
  `22` UNSATISFIED_LOCKTIME) for the two opcode cells; boolean/arithmetic
  results for the granularity cell; the checker's verdict (`1`/`0`) for the
  per-input cell.

Notable fidelity points (all stated in the per-cell `spec.md`):

- `CTransaction::version` is `uint32_t` at the pin, so `version < 2` is
  unsigned; the cells model it as `uint32_t`.
- The CLTV/CSV opcode dispatch, flag checks, stack guards and 5-byte
  `CScriptNum` decode are elided and attributed to SCR-051/052 and the
  activation rules; the cells prove strictly more input values than the decode
  can produce.
- SCR-131: the script-level comparison deliberately stays in the raw masked
  domain (no 512 scaling); `(seq & MASK) << 9` is proved equal to
  `seqRelative * 512`, and `EvaluateSequenceLocks`' last-invalid
  `nMinTime = coin + rel*512 - 1`, `nMinTime >= blockTime -> false` is proved
  to be exactly Lean's `seqTimeOk` (`block >= coin + rel*512`) — no
  off-by-one.  MTPs are modelled as uint32, which is exactly the reachable
  MTP domain (`chain.h:233`: median of uint32 header times).
- SCR-132: two-input instance; `nIn` is symbolic over both indices and the
  unselected slot is symbolic.  The L side never names the unselected slot, so
  the C = L equality is input locality.  The general-`n` induction is the Lean
  theorem (`checkLockTime_perInput_row` / `checkSequence_perInput_row`), not
  re-proved by the cell; this is stated under `scr_row_coverage`.

## Finding F-LOCKTIME-001 — twin has no transaction context

`spec/equiv/twin/ops_ir.py:44-58` (CLTV) and `:53-58` (CSV) return
`TWIN_INVALID_UNSUPPORTED` for the flag-on paths.  The twin `Ctx` carries no
`txTo`/`nIn`/`version`/`nLockTime`, so the generator cannot emit a handler for
`CheckLockTime`/`CheckSequence`.  Consequence: the L legs in this family are
reviewed transliterations of the Lean equations, with the mapping recorded in
each cell's `src/lean_excerpt.md`.  This is the same convention already used by
the committed three-leg workstream for context-dependent checkers; no twin
file was changed.  Next action if the twin is ever extended: add
`(version, locktime, vin[nIn].sequence)` to `Ctx` and regenerate; the cells
would then be re-pointed at the twin without changing the C legs or the
Cryptol predicates.

## Remaining gaps in this family

None.  SCR-122..132 are all both-tool green with `scr_row_coverage: full`.
The following adjacent claims are deliberately outside these rows and remain
owned elsewhere: operand decoding (SCR-051/052), activation/flag combos
(SCR-009 area), `IsFinalTx` and the height-domain sequence lock (TXV-034..038),
and whole-engine composition — none is claimed here.

## Validation performed

- `alive2/run.sh` and `saw/run.sh` for all four cells: exit 0.
- `sha256sum -c` for all eight certificates from the repo root: all OK.
- `python3 spec/equiv/results/scripts/update_ledger.py --check`: 21/21 cells
  valid, SCR-122..132 promoted to `both-green`, 0 blocked rows.  (Check mode
  only; the shared ledger was not modified.)
- `git status --short` clean after commit `e50139f`; no push.
