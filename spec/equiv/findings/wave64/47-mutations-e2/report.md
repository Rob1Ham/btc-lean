# Wave 64 · `47-mutations-e2` — E2 required mutation set

Branch: `wave64/47-mutations-e2`
Base commit: `5946c024546e39f55775bfd9a077b042e3feeef4`
Scope: `spec/equiv/findings/wave64/47-mutations-e2/**` only. No cell, tool,
twin, ledger, or result file was edited or committed.

## Result

**Required E2 set: 4/4 distinct mutants KILLED.** All four were run for real
against existing flow/numeric/limit cells; each kill was observed by **both**
Alive2 and SAW, and each was reverted with the baseline green again.

| Required? | Mutant | Site | Existing cell used | Expected detection | Actual result | Caught? |
|---|---|---|---|---|---|---|
| yes | **M-E2-001** — `CastToBool` treats negative zero `0x80` as true | `core-slice` (`c_leaf.cpp`) | `cells/control-flow/C-L-casttobool` (SCR-057) | Alive2 C-vs-L mismatch for `cell_cast_len1` at `b0=0x80`; SAW C proof fails against `cast1` | Alive2 `alive2-not-green`, `ERROR: Value mismatch`, `b0=#x80 (128,-128)`; SAW `Proof failed`, counterexample `b0=128` | **yes (both)** |
| yes | **M-E2-002** — `CScriptNum` operand bound `4 -> 5` | `core-slice` (`c_leaf.cpp`) | `cells/numeric/C-L-unary-4byte` (SCR-087) | Alive2 C-vs-L mismatch at operand length 5; SAW C proof fails against `decodeOk L <= 4` | Alive2 `alive2-not-green`, `%lb=#5`; SAW `Proof failed`, `lb=5` (all six unary functions mismatch under Alive2) | **yes (both)** |
| yes | **M-E2-004** — `OP_WITHIN` max boundary inclusive `<=` instead of `<` | `core-slice` (`c_leaf.cpp`) and `model` (`twin/ops_ir.py`) | `cells/e2-numeric/within-boundary` (SCR-089) | Alive2 C-vs-L mismatch on `x == max`; SAW fails against independent `min <= x < max` | core-slice: Alive2 `av=bv=cv=0`; SAW `a=65,b=241,c=65`. model: Alive2 same; SAW `a=99,b=43,c=99`; regenerated `build/twin_ops.h` contains `a <= c` | **yes (both, both sites)** |
| yes | **M-E2-005** — `OP_COUNT` threshold `201 -> 200` (rejects a charged count of 201) | `core-slice` (`c_leaf.cpp`) | `cells/limits/C-L-opcount` (SCR-022..025) | Alive2 C-vs-L mismatch at charged count 201; SAW C proof fails against the 201 budget | Alive2 `opCount=200, wire=0x8e`; SAW `opc=200, wire=192`; both `not-green` | **yes (both)** |

Required-set score: **4/4 = 100%** (no equivalent-adjudication claimed).
M-E2-004 was run twice (C excerpt and model site) as a paired application of
one mutant, not as a fifth distinct mutant.

## Cell-name mapping (important)

The catalogue names four E2 cells that **do not exist** at this base. The task
required runs against *existing* cells, so the closest real cells implementing
the same SCR rows were used. This substitution is a ledger/coverage finding
against `MUTATIONS.md`, not a silent waiver.

| Catalogue ID | Catalogue cell (missing) | Existing cell actually run | Evidence |
|---|---|---|---|
| M-E2-001 | `cells/e2-flow/negzero-if` | `cells/control-flow/C-L-casttobool` | SCR-057, `interpreter.cpp:46-59` |
| M-E2-002 | `cells/e2-numeric/num-4byte-boundary` | `cells/numeric/C-L-unary-4byte` | SCR-087, `script.h:246-271` |
| M-E2-004 | `cells/e2-numeric/within-boundary` | `cells/e2-numeric/within-boundary` | exists (SCR-089) |
| M-E2-005 | `cells/e2-flow/opcount-201` | `cells/limits/C-L-opcount` | SCR-022..025, `script.h:32` |

`cells/e2-flow/` and `cells/e2-numeric/num-4byte-boundary` are absent from the
tree at `5946c02`. A future claim must either add those cells or amend the
catalogue to the real cell ids; this report does not rename the catalogue.

## Method (no shared cell edits)

Harness: `run_mutations.py`. For every run it:

1. materialises a byte-identical `git archive HEAD spec/equiv` copy under
   `.work/spec/equiv` and verifies the target sha256 against
   `git show HEAD:spec/equiv/<target>` before touching anything;
2. runs the existing cell's `alive2/run.sh` and `saw/run.sh` and requires
   `STATUS=alive2-green` / `STATUS=saw-green` with exit code 0;
3. applies **one** exact-text semantic edit (occurrence count exactly 1) to the
   copy, records before/after sha256 and a unified diff;
4. re-runs both cell legs and saves the complete `result.txt`, stdout, and exit
   code;
5. restores the original bytes, verifies the before-sha256, and re-runs both
   baseline legs green;
6. classifies `KILLED` only when a tool reports a real mismatch or proof
   failure with a counterexample, the revert verifies, and the post-revert
   baseline is green. Build errors/timeouts are `INVALID`, never kills.

The working tree's cells were never written to. `.work/` is deleted after the
run; `git status` is clean apart from this findings directory.

Reproduce (from the worktree root):

```sh
python3 spec/equiv/findings/wave64/47-mutations-e2/run_mutations.py --list
python3 spec/equiv/findings/wave64/47-mutations-e2/run_mutations.py --all
```

Each run directory contains `result.md`, `mutant.json`, `target.diff`, and the
raw baseline/mutant/post-revert `result.txt` files. Commands recorded in every
record are the canonical relative commands:

```sh
cd spec/equiv && bash cells/<cell>/alive2/run.sh
cd spec/equiv && bash cells/<cell>/saw/run.sh
```

## Per-run evidence

| Run | Classification | Caught by | Record |
|---|---|---|---|
| `M-E2-001-core-slice` | KILLED | alive2, saw | `runs/M-E2-001-core-slice/result.md` |
| `M-E2-002-core-slice` | KILLED | alive2, saw | `runs/M-E2-002-core-slice/result.md` |
| `M-E2-004-core-slice` | KILLED | alive2, saw | `runs/M-E2-004-core-slice/result.md` |
| `M-E2-004-model` | KILLED | alive2, saw | `runs/M-E2-004-model/result.md` |
| `M-E2-005-core-slice` | KILLED | alive2, saw | `runs/M-E2-005-core-slice/result.md` |

Target hashes (before -> after) and revert verification:

| Run | Target | sha256 before | sha256 after | Revert verified |
|---|---|---|---|---|
| M-E2-001-core-slice | `cells/control-flow/C-L-casttobool/src/c_leaf.cpp` | `f8f2393b7e1e…` | `044034a53806…` | yes |
| M-E2-002-core-slice | `cells/numeric/C-L-unary-4byte/src/c_leaf.cpp` | `40062b873417…` | `c63201531534…` | yes |
| M-E2-004-core-slice | `cells/e2-numeric/within-boundary/src/c_leaf.cpp` | `4e72978fa99a…` | `c17b6c5d4c4a…` | yes |
| M-E2-004-model | `twin/ops_ir.py` | `6f0d5531c7f7…` | `2504b53341f3…` | yes |
| M-E2-005-core-slice | `cells/limits/C-L-opcount/src/c_leaf.cpp` | `8222580d12a6…` | `90d70d419651…` | yes |

Full hashes are in each `mutant.json`.

## Honest limitations

1. **`core-copy` is not a full Core build.** The C-side runs mutate the
   line-cited source-excerpt slice used by each cell (`c_leaf.cpp`), exactly as
   the cell's trust note describes. A detached, rebuilt Core translation unit
   at the pin (PROTOCOL §2.2 rule 2) was not available in this worktree, so the
   strict `core-copy` requirement remains open. The kills prove the C *slice*
   and the C-vs-L pair are sensitive; they do not prove the full Core binary is.
2. **Model-site is covered for E2 by M-E2-004 only.** It mutates
   `twin/ops_ir.py`, the cell regenerates `build/twin_ops.h`, and the generated
   diff is recorded. M-E2-001/002/005 were run at the C-excerpt site; they were
   not paired at the model site.
3. **No hash mutant was run.** M-E2-007 is optional in the required E2 subset
   (the mandatory set is M-E2-001, M-E2-002, M-E2-005 plus one of
   M-E2-003/004/008/009). The hash cell `e2-hash/hash160-vector` remains
   tool-green but unmutated; it is not claimed as mutation coverage here.
4. **Alive2 chose a different concrete witness for M-E2-004.** It reported
   `av=bv=cv=0`; this still satisfies `x == max`. The catalogue's `5 1 5`
   witness also satisfies it. SAW independently chose `a=c` triples
   (`65,241,65` and `99,43,99`). The declared witness was therefore reachable;
   the solver simply found a smaller one.
5. **SAW stops at the first failed proof.** For M-E2-002 the recorded
   `0 succeeded, 1 failed` means SAW failed `cell_1add` before trying the other
   five functions; Alive2 reports all six as mismatches. This is expected
   `saw` script behaviour, not six hidden passes.
6. **GitHub/remote provenance.** All runs were local; no network, no Core
   checkout, no `make equiv`/`gate-ir-pin`. Tool versions: `alive-tv` Ubuntu
   LLVM 20.1.2; SAW 1.6 (`68eed5f`); `clang++-20` 20.1.2.

## Conclusion

The required E2 mutation set is observed at **4/4 killed**, with real
baseline/mutant/post-revert runs and concrete counterexamples, not fabricated
PASS lines. E2 sign-off still needs the open items above (full `core-copy`,
catalogue cell ids, optional hash mutant) before it can claim the strict
PROTOCOL §2.2/§6.3 evidence bundle.
