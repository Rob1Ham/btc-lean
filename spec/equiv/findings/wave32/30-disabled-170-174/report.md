# Wave 32 / task 30 — disabled-opcodes SCR-170..174

Commit: this commit on `wave32/30-disabled-170-174` (report is part of it).
Branch: `wave32/30-disabled-170-174`, cut from PR #29 head
`805c8042f92d3bed909ca40219a4d21fc9150cc1` (pin `cce32b168`).
Worktree: `/tmp/opencode/wave32/30-disabled-170-174`.
Additive only: no ledger, `results/**`, `docs/STATE.md`, contract, pins, Lean,
or existing cell was edited. No push.

## Result summary

| SCR | status | cell(s) | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| SCR-170 | **full** | `disabled/C-L-w32-disabled-dispatch` | The fifteen disabled wires return `DISABLED_OPCODE` (17) in BASE and WITNESS_V0 regardless of `fExec`, after the 201-op budget arm; symbolic over all 256 wires × 2 sigversions × 2^32 opcounts. | Tapscript's OP_SUCCESSx route is SCR-172; not part of this row's base/wv0 step. | none |
| SCR-171 | **full** | `disabled/C-L-w32-disabled-dispatch` | Exact guard order: budget (`OP_COUNT`) precedes the disabled arm, which precedes the `fExec` gate. Both legs and the independent Cryptol predicate agree for every input. | none | none |
| SCR-172 | **partial** | `disabled/C-L-w32-opsuccess-scan` | (a) `IsOpSuccess`/`isOpSuccessWire` proved equal over all 256 bytes: the fifteen disabled bytes are OP_SUCCESS126..153. (b) The tapscript pre-scan over two non-push opcodes returns success at the first success byte (either position), with the `DISCOURAGE_OP_SUCCESS` policy arm (36). | Arbitrary-length script induction (the scan is a fold of the same predicate); push-payload decode ordering; the rest of `ExecuteWitnessScript` (item/stack limits, annex, control block). | No blocker for the row's mapping/pre-scan core. The remaining edges are the SCR-153/157/168 seams and F-DIV-001; no fake green is claimed. |
| SCR-173 | **full** | `disabled/C-L-w32-opname-table` | Complete `GetOpName` table: every one of the 256 bytes compared against the Lean `opNameWire` table; 113 named bytes, 143 `OP_UNKNOWN`, including the direct-push gap 0x01..0x4b and 0xbb..0xfe, and named 0xff. | Spelling beyond the two transcription data files (a shared misreading is the known limit of a table cell). | none |
| SCR-174 | **full** (BASE/WITNESS_V0) | `disabled/C-L-w32-disabled-dispatch` | The switch/default classification is symbolic over every wire and both `fExec` values; default set proved equal to `{0x50,0x62,0x65,0x66,0x89,0x8a} ∪ [0xbb,0xff]`, with 0xba (CHECKSIGADD under base/wv0) returning BAD_OPCODE. In tapscript every default byte except 0x65/0x66 is OP_SUCCESSx (proved by the SCR-172 cell). | The tapscript default arm itself (only 0x65/0x66 can reach it) is the same `default:` and not separately modelled. | none |

Rows closed: **4 full** (SCR-170, 171, 173, 174). Partial: **1**
(SCR-172). No row was left un-attempted and no row was relabelled.

## Cells

| cell | functions | Alive2 | SAW |
|---|---|---|---|
| `spec/equiv/cells/disabled/C-L-w32-disabled-dispatch/` | `cell_guard`, `cell_default` | 2/2 correct | 4/4 `Proof succeeded!` |
| `spec/equiv/cells/disabled/C-L-w32-opsuccess-scan/` | `cell_isopsuccess`, `cell_scan` | 2/2 correct | 4/4 `Proof succeeded!` |
| `spec/equiv/cells/disabled/C-L-w32-opname-table/` | `cell_opname` | 1/1 correct | 2/2 `Proof succeeded!` |

Every cell has `spec.md`, `notes.md`, `src/`, `alive2/{run.sh,result.txt,certificate.sha256}`,
`saw/{run.sh,result.txt,certificate.sha256}`.

## Exact commands and raw outcomes

Run from the repository root of the worktree:

```sh
spec/equiv/cells/disabled/C-L-w32-disabled-dispatch/alive2/run.sh
spec/equiv/cells/disabled/C-L-w32-disabled-dispatch/saw/run.sh
spec/equiv/cells/disabled/C-L-w32-opsuccess-scan/alive2/run.sh
spec/equiv/cells/disabled/C-L-w32-opsuccess-scan/saw/run.sh
spec/equiv/cells/disabled/C-L-w32-opname-table/alive2/run.sh
spec/equiv/cells/disabled/C-L-w32-opname-table/saw/run.sh
```

Raw tails:

```
C-L-w32-disabled-dispatch alive2:
  # command: alive-tv build/c_cell_guard.ll build/l_cell_guard.ll
  Transformation seems to be correct!
    1 correct transformations / 0 incorrect / 0 failed-to-prove
  # command: alive-tv build/c_cell_default.ll build/l_cell_default.ll
  Transformation seems to be correct!
    1 correct transformations / 0 incorrect / 0 failed-to-prove
  STATUS=alive2-green
C-L-w32-disabled-dispatch saw:
  Proof succeeded! cell_guard        (C)
  Proof succeeded! cell_guard        (L)
  Proof succeeded! cell_default      (C)
  Proof succeeded! cell_default      (L)
  STATUS=saw-green

C-L-w32-opsuccess-scan alive2:
  Transformation seems to be correct!
  Transformation seems to be correct! (syntactically equal)
  2 x (1 correct / 0 incorrect / 0 failed-to-prove)
  STATUS=alive2-green
C-L-w32-opsuccess-scan saw:
  Proof succeeded! cell_isopsuccess  (C, L)
  Proof succeeded! cell_scan         (C, L)
  STATUS=saw-green

C-L-w32-opname-table alive2:
  Transformation seems to be correct! (syntactically equal)
  1 correct / 0 incorrect / 0 failed-to-prove
  STATUS=alive2-green
C-L-w32-opname-table saw:
  Proof succeeded! cell_opname       (C, L)
  STATUS=saw-green
```

Certificate check from the repository root (all three cells, both runs):

```sh
sha256sum -c spec/equiv/cells/disabled/C-L-w32-disabled-dispatch/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/disabled/C-L-w32-disabled-dispatch/saw/certificate.sha256
# ... same for opsuccess-scan and opname-table
```

All six checks exit 0. The run was repeated after `rm -rf build/` and the
certificates still verify, i.e. the tables/IR are reproducible from the pinned
sources.

Tool versions (recorded in every `result.txt`):

- `alive-tv`: Ubuntu LLVM version 20.1.2
- clang++ 20.1.2, llvm-extract/llvm-as 20.1.2
- SAW 1.6 (68eed5f release-1.6), solver `abc`

## Independent table check (not proof evidence)

A separate script fetched the pinned `script.h`, `script.cpp` and
`interpreter.cpp` and compared them with the cell data:

- disabled list = the exact fifteen bytes `7e,7f,80,81,83,84,85,86,8d,8e,95,96,97,98,99`;
- `IsOpSuccess` expression matches `script.cpp:365-371` verbatim;
- `core_names.txt` = the 113 `GetOpName` cases with zero extra/missing names;
- the EvalScript `case`-label set equals `core_case_label` exactly (0x8d/0x8e
  are deliberately excluded: they are disabled, not case labels);
- the derived default set is `{0x50,0x62,0x65,0x66,0x89,0x8a} ∪ [0xbb,0xff]`,
  equal to the generated twin `W32_BAD` set (`0xba` added separately because
  the twin's OP_CHECKSIGADD_BASE handler returns BAD_OPCODE under base/wv0).

## Tool / infrastructure notes

1. **`llvm-extract` and constant globals.** With `--func=... --recursive`,
   LLVM 20.1.2 turned referenced internal constant arrays/switch tables into
   `external` declarations. Alive2 then reports `UB triggered` on a poison
   load and SAW fails with "Error during memory load" — it is a harness
   limitation, not a cell failure. Two fixes are recorded in the cells:
   - `C-L-w32-disabled-dispatch`: `gen_wire_table.py` emits predicate
     expressions instead of arrays (no globals at all);
   - `C-L-w32-opname-table`: the leaf module defines only `cell_opname`, so
     extraction is skipped (`llvm-as` only) and the private switch table keeps
     its initializer.
2. **SAW/Cryptol syntax.** Cryptol 3 (SAW 1.6) needs explicit parentheses
   around chained comparisons and `~` (not `!`/`not`) for boolean negation.
   Recorded here only so the next wave does not re-discover it.
3. No timeout, OOM, or missing-tool event occurred in the final runs. (One
   earlier SAW crash was the parse error above, fixed in-source; the final
   `result.txt` is green and certificate-covered.)

## Smallest next experiments

- SCR-172 full: extend `cell_scan` to a recursive/fold scan over a symbolic
  list of opcodes (Alive2 cannot quantify over list length; SAW/Cryptol can
  state `scan(ws) = any isOpSuccess ws` over a symbolic sequence, then prove
  the two-opcode step as the base case). The current cell already supplies
  the per-byte predicate and the first-success ordering.
- SCR-174 tapscript arm: add `0x65/0x66` to a tapscript-domain `cell_default`
  variant. It is a two-byte predicate addition; the reason it is not done
  here is that the twin's `stepBody` disabled arm is unreachable on the
  pre-scanned tapscript path, so the comparison needs a pre-scan-aware model
  rather than the base step.
- SCR-170/171: no further work; the step cell is complete for the row as
  written (base/witness-v0).

## Files

New only:

```
spec/equiv/cells/disabled/C-L-w32-disabled-dispatch/**
spec/equiv/cells/disabled/C-L-w32-opsuccess-scan/**
spec/equiv/cells/disabled/C-L-w32-opname-table/**
spec/equiv/findings/wave32/30-disabled-170-174/report.md
```

Nothing under `results/`, `spec/db/`, `contract/`, `docs/`, `PINS.lock`, or
the Lean tree was modified.
