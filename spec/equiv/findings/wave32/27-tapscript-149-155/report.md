# Wave 32 — task `27-tapscript-149-155`

**Branch:** `wave32/27-tapscript-149-155` (base `805c804`)
**Pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Family:** tapscript
**Rows:** SCR-149 … SCR-155
**Result:** 5 full, 2 partial, 0 blocked; one new C↔L divergence filed
(`F-DIV-w32-001`).

All cells use the new family directory `spec/equiv/cells/tapscript/` and the
shared runner `spec/equiv/cells/_tools/w32/` (own build; Alive2
`--smt-to=60000`). No existing cell, finding, ledger, contract, pin, proof or
result file was edited.

## Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| SCR-149 | **full** | `tapscript/C-L-w32-witness-dispatch-upgradable` | Every `control[0]` byte: mask `0xc0` selects tapscript, all other leaf versions return `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` when the policy flag is set and success otherwise; the tapscript result is an uninterpreted input. | Only the dispatch seam: no control-block commitment, annex, or executed tapscript. The row is a dispatch statement, so this is the row's full content. | none for the row. (The node summary says `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`; code at `interpreter.cpp:1995` and `Defs.lean:1316` uses `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION`. The cell models the code; recorded as a naming discrepancy, not a gap.) |
| SCR-150 | **full** | same cell, `cell_program_tail_dispatch` | v1 + 2-byte program `0x4e73` + not P2SH returns success before the discourage check and without calling `ExecuteWitnessScript`, for both flag states and all other dispatch inputs. | Only the dispatch seam (as above). | none. |
| SCR-151 | **full** | same cell, `cell_program_tail_dispatch` | Every v2..v16, every wrong-size v1, and every P2SH-wrapped v1 (all byte values, both P2SH states, both flag states) succeed when the flag is off / return `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` when it is on. v0 and v1/32/!P2SH are excluded as other rows. | Only the dispatch seam. | none. |
| SCR-152 | **full** | `tapscript/C-L-w32-op-success-set` | The exact `IsOpSuccess` table over **all 256** byte values `{80,98,126-129,131-134,137-138,141-142,149-153,187-254}` and its complement; `OP_RESERVED 0x50` is a member, `0xff` is not. | Nothing for the row (it is a pure membership predicate). Execution consequences are SCR-153/154. | none. |
| SCR-153 | **partial** | `tapscript/C-L-w32-op-success-prescan` | For every script of length ≤ 4 over all byte values: a decoded OP_SUCCESSx returns success / `DISCOURAGE_OP_SUCCESS`, beats the initial stack-size check, the 520-byte item check and the EvalScript tail; push payloads are skipped, a truncated push before any success byte yields "not found", and a success byte before a truncated push still wins. | (1) Scripts longer than 4 bytes. (2) The error *kind* on a malformed tail: Core returns `BAD_OPCODE` from the pre-scan before the size checks; Lean reaches `STACK_SIZE`/`PUSH_SIZE` first (`F-DIV-w32-001`). The cell compares the `found` bit only. | The scan is straight-line unrolled for length ≤ 4. An 8-byte prototype (development-only, not kept in the tree) was built: Alive2 could not discharge it within the 60 s SMT budget (it returned a counterexample at a 120 s budget, exposing and fixing a real 32-bit wrap in the first L draft). SAW is not the obstacle. Next experiment: 8-byte unroll with two 32-bit words and `--smt-to=300000`, or a SAW loop invariant at `MAX_SCAN_LEN=8`. |
| SCR-154 | **partial** | same cell, `cell_prescan_tail` | Same bound: with `DISCOURAGE_OP_SUCCESS` set, every found OP_SUCCESSx in a ≤ 4-byte script yields `DISCOURAGE_OP_SUCCESS` (36), never success; the flag is modelled as the policy input (`consensus=false`). | Same two exclusions as SCR-153 (length bound; malformed-tail error kind). Not claimed: that the flag is a consensus ScriptFlags bit. | Same as SCR-153. |
| SCR-155 | **full** | `tapscript/C-L-w32-opcount-budget` | `cell_opcount_guard`: total over SigVersion ∈ {BASE, WITNESS_V0, TAPSCRIPT}, all 256 wire bytes and `nOpCount ≤ 10000` — the `> OP_16` guard increments and compares only for BASE/WITNESS_V0; TAPSCRIPT never increments and never returns `OP_COUNT`. `cell_nop_overbudget`: a concrete OP_NOP with `oc ≥ 201` succeeds on TAPSCRIPT (truthy stack) and leaves `oc` unchanged (observable in the packed aux), while BASE/WITNESS_V0 returns `OP_COUNT`. | The rest of `EvalScript` (parse, stack/alt, other opcodes) and the initial stack-size/item-size/weight preconditions (SCR-021/031/040). | none for the row as stated. Reachability caveat: a real tapscript evaluation starts at `nOpCount=0` and never increments it, so `oc > 201` is not reachable *within* one tapscript `EvalScript`; the row is counterfactual over the state and the cell proves exactly that. |

## Proof obligations and raw results

Each cell has two independent legs per function: Alive2 (C IR vs L IR) and SAW
(each leg against an independent Cryptol specification in `src/cell.cry`).
There is no `llvm_unsafe_assume_spec` and no handwritten success marker; the
`STATUS=...` line is appended by the runner from parsed tool output.

| cell | functions | Alive2 | SAW |
|---|---|---|---|
| `C-L-w32-witness-dispatch-upgradable` | `cell_leaf_version_dispatch`, `cell_program_tail_dispatch` | 2 correct, 0 incorrect | 4 `Proof succeeded!` |
| `C-L-w32-op-success-set` | `cell_is_op_success` | 1 correct, 0 incorrect | 2 `Proof succeeded!` |
| `C-L-w32-opcount-budget` | `cell_opcount_guard`, `cell_nop_overbudget` | 2 correct, 0 incorrect | 4 `Proof succeeded!` |
| `C-L-w32-op-success-prescan` | `cell_scan_finds_success`, `cell_prescan_tail` | 2 correct, 0 incorrect | 4 `Proof succeeded!` |

Raw files: `alive2/result.txt`, `saw/result.txt` in each cell directory. All
eight certificates (Alive2 + SAW, one of each per cell) verify: every listed
file matches its hash.

```sh
cd /tmp/opencode/wave32/27-tapscript-149-155
for d in spec/equiv/cells/tapscript/*/; do
  sha256sum -c "$d/alive2/certificate.sha256"
  sha256sum -c "$d/saw/certificate.sha256"
done
# all lines: OK
```

### Exact commands

```sh
# one cell (same shape for all four)
spec/equiv/cells/tapscript/C-L-w32-op-success-prescan/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-op-success-prescan/saw/run.sh
```

`run.sh` calls `_tools/w32/run_alive2.sh` / `run_saw.sh`, which rebuild the two
legs (`/usr/bin/clang++-20 -O1 -emit-llvm`), extract each function, run the
tool, write the raw result, and regenerate the certificate. SAW needs
`/opt/equiv-tools/saw-1.6/bin` on `PATH` (the runner sets it); the default PATH
`/usr/local/bin/saw` cannot find `abc`.

### Alive2 non-vacuity check (important)

Alive2 20.0 sometimes reports `Transformation seems to be correct!` for a pair
whose L leg has a changed constant (observed on the large raw `-O1` probe
function, with `--skip-smt`, in ~0.1 s) — i.e. it silently skips the query on
some raw-IR shapes, non-deterministically. The probe exposed this
(`probe/alive2/result.txt`, run 1). Therefore the cell runners verify the
**`opt -O2` canonical form** with `--always-verify`; the raw `-O1` form is still
what SAW verifies. To show the Alive2 runs are real, each cell pair was
re-checked with one mutated constant
(`spec/equiv/findings/wave32/27-tapscript-149-155/check_alive2_nonvacuous.sh`,
output in `alive2-mutation-checks.txt`):

```
cell_prescan_tail              DETECTED
cell_scan_finds_success        DETECTED
cell_is_op_success             DETECTED
cell_opcount_guard             DETECTED
cell_nop_overbudget            DETECTED
cell_leaf_version_dispatch     DETECTED
cell_program_tail_dispatch     DETECTED
```

Three consecutive runs: 7/7 DETECTED each time. This is a sanity check, not
part of the proof; the SAW results do not depend on Alive2.

## Divergence filed: F-DIV-w32-001

`spec/equiv/findings/wave32/27-tapscript-149-155/F-DIV-w32-001-prescan-order.md`

Core's OP_SUCCESSx pre-scan returns `BAD_OPCODE` on a truncated push before the
initial stack-size / item-size checks (`interpreter.cpp:1851-1854`); the Lean
`executeWitnessScript` runs `MAX_STACK_SIZE` and the item-size check before
`parseWire` reports `badOpcode` (`Defs.lean:1211-1233`). Both reject; the error
ordinal differs.

Evidence (independent):

- SAW counterexample: `len=4, b0=2, b1=2, b2=0x80, b3=0x4e, tm=0, os=16` →
  C `BAD_OPCODE` (64), L `PUSH_SIZE` (24).
- Concrete driver: `saw-cex` C=64/L=24, `stack` C=64/L=32; the well-formed
  OP_SUCCESSx cases agree (C=L=1 and C=L=144).
- Alive2 on `opt -O2`: counterexample `len=3, bytes 00 00 01 00, tm=1` →
  C=64, L=32. Alive2 on the raw `-O1` pair says "correct" (the skip above),
  which is recorded, not hidden.

This divergence is exactly why SCR-153/154 are `partial` on the malformed-tail
error kind; the cells' postconditions exclude it explicitly.

## Scope / no-overclaim notes

- No crypto or hash internals are used or claimed: none of these rows needs
  libsecp256k1, Schnorr, SHA256 or RIPEMD. Taproot/tapscript *execution* enters
  the dispatch cell as an uninterpreted packed input; the tx, commitment,
  annex and control-block checks are outside the cells.
- SCR-149/150/151 are dispatch-level rows and are full at that seam. SCR-152 is
  a total predicate over all byte values. SCR-155 is full for the guard as
  stated, with the reachability caveat above.
- The two partial rows are partial only because of the 4-byte unroll bound and
  the malformed-tail error kind; both are stated in the cell `spec.md` and in
  F-DIV-w32-001.

## Tool / infrastructure failures

1. Alive2 20.0 silent skip on some raw `-O1` IR (above). Mitigated by
   `opt -O2` + `--always-verify` and the mutation check; SAW covers the raw IR.
2. Alive2 could not discharge the 8-byte unrolled scan at `--smt-to=60000`
   (OOM/timeout); this is the SCR-153/154 bound. At 120 s it produced a
   counterexample that found a real 32-bit wrap in the L PUSHDATA4 bound check,
   which was fixed before the 4-byte cell was accepted.
3. `saw` on the default PATH lacks `abc`; all runners prepend
   `/opt/equiv-tools/saw-1.6/bin`.

No other failures; no row is blocked.

## Commit contents

New files only:

- `spec/equiv/cells/_tools/w32/{w32_common.h,build.sh,run_alive2.sh,run_saw.sh}`
- `spec/equiv/cells/tapscript/C-L-w32-witness-dispatch-upgradable/`
- `spec/equiv/cells/tapscript/C-L-w32-op-success-set/`
- `spec/equiv/cells/tapscript/C-L-w32-opcount-budget/`
- `spec/equiv/cells/tapscript/C-L-w32-op-success-prescan/`
- `spec/equiv/findings/wave32/27-tapscript-149-155/` (this report,
  F-DIV-w32-001, the probe, and the non-vacuity check)

Build products (`build/`) are generated, git-ignored, and referenced by the
certificates only for reproducibility in the worktree.
