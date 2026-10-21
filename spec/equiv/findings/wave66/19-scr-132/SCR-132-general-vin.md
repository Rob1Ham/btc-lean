# Wave 66 / 19 — SCR-132: general-vin closure of the locktime input-index cell

**Branch:** `wave66/19-scr-132`
**Base:** `8142cff0ed6ea6edd448b609817d2a706ab5e057` (`equiv/llvm-three-leg`, PR #29)
**Worktree:** `/tmp/opencode/wave66/19-scr-132`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (Bitcoin Core v32.99)
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Row:** SCR-132 — *CheckLockTime/Sequence see only input nIn*
**Mode:** new cell + new finding. Ledger, matrix, `spec/db/**`, `results/**`,
`contract/**`, `PINS.lock`, `spec/proofs/**`, docs, twin and every existing
cell are untouched.

---

## 1. Verdict

The wave-65 audit (`findings/wave65/32-audit/report.md`, F1) demoted
`locktime/C-L-locktime-input-index` because that cell proves only the
`vin.length = 2` instance while its `scr_row_coverage` field said `full`. The
row quantifies over an arbitrary `vin` list, so the two-input cell cannot
close it.

This finding adds a **separate** cell,
`locktime/C-L-locktime-input-index-general`, that closes the general
statement without relabelling or editing the two-input cell:

| dimension | new cell |
|---|---|
| arbitrary vin length | Lean induction over `List TxIn`, importing the pinned model unchanged |
| arbitrary index | `nIn : Nat` in Lean; fully symbolic `uint32` in Alive2 |
| out-of-range `getD` fallback | part of the statement: `[]` access trace, default sequence, corollary theorems |
| "sees only input nIn" | access-trace equality/subset theorems plus two-vin non-interference in Alive2 and SAW |
| compiled checkers | Alive2 over a pointer argument (nondeterministic input-block size) |
| independent cross-check | SAW against a from-text Cryptol predicate at a **disclosed 16-slot bound** |

The two-input statement is recovered as
`checkLockTime_twoInput_is_special_case`, i.e. an instance of the general
theorem — not a relabelling.

**This commit does not promote the row.** `spec/db/equiv-cells.yaml` still
says `SCR-132: gap`; the ledger and matrix are integrator-owned and were
forbidden for this task. `scripts/update_ledger.py --check` mechanically
derives the transition `SCR-132: gap -> both-green (2 cell(s))` from the new
cell record, and its only reported drift is the unedited ledger itself.
Promotion therefore requires the integrator's one-line ledger/matrix
regeneration, not another proof.

---

## 2. What was actually missing

F1's objection was correct and is answered directly:

| F1 objection | answer in this cell |
|---|---|
| "the vin length (2 inputs instead of an arbitrary list)" | `GeneralIndex.lean` proves the lookup/environment/verdict theorems for `∀ vin : List TxIn`, by structural induction |
| "the general-n induction is not mechanized and is not claimed" | mechanized: `vinReads_eq` is an induction on the list; `vinReads_subset` and both `*_perInput_row` theorems follow |
| "the two-input instance is what the LLVM cell proves" | two-input body is kept as an unreferenced sibling cell; the general theorem has `checkLockTime_twoInput_is_special_case` showing `length = 2` is a corollary |

The mechanism that made the two-input cell look sufficient is the same one
the new cell does not use: a boolean index cannot witness "no other input is
read" for `n > 2`. The new cell never enumerates slots in Lean; it reasons
about the list and its access trace.

---

## 3. Artefacts

Cell root:
`spec/equiv/cells/locktime/C-L-locktime-input-index-general/`

| file | sha256 |
|---|---|
| `spec.md` | `bda74399e2b63cd0e9f07e2ea40d308dc06c792fa31ce212b05f8911bbe86835` |
| `notes.md` | `8f785afd653aea6980de28731a0ae1c5b12eee8b6de150825e4965ffecf24a20` |
| `src/GeneralIndex.lean` | `c4f45e08544c4cea9e5f83672eecf25b8600d82234b990df71967241d1c4e747` |
| `src/c_leaf.cpp` | `e2fde977688a2572101adc36d8b5931af3f8b3665cdc9952a887231db35b496a` |
| `src/l_leaf.cpp` | `851add446de865bd5e0684c4105fce5804fa8c86db61fd5fae255fca14284ed3` |
| `src/cell.cry` | `21b7d71be35093bc74a89f56e2fc3944a4ecb84f219921ef2fb517fb4becb0f0` |
| `src/cell.saw` | `db3da87622ae983da0bf8f0c2825ad62e5c062f4d0443f32a6eac6fd37fc9010` |
| `src/build.sh` | `69c54edddffc44c72ed13b8ef29f830610b039cc23b40702b3c4e5586f13a9bd` |
| `src/lean_excerpt.md` | `aecffddd0b59b96aa5e5a0f9bd747380821b739f4f21c77abbabeb73af4d5342` |
| `alive2/size-probe.txt` | `bbcbcafbbdecc0dc764d179c7c9ee729bd72d828f5c4588c295dc107f7c4b666` |

Full pins, citations, pre/postconditions and the trust note are in `spec.md`;
the bound disclosure, commands and per-leg explanation are in `notes.md`.

---

## 4. Evidence

### 4.1 Lean — the arbitrary-length argument

Command (`lean/run.sh`):

```sh
cd /tmp/opencode/wave66/19-scr-132
bash spec/equiv/cells/locktime/C-L-locktime-input-index-general/lean/run.sh
```

The script builds the pinned `Bitcoin.Interpreter.Rules` at
`4d62a97e551082a69b13f495365bff0a903b0c99` (Lean 4.35.0,
`leanprover/lean4:v4.35.0`) and elaborates `src/GeneralIndex.lean`. Result
(`lean/result.txt`): every theorem prints a `#print axioms` line and the run
script rejects `sorryAx`.

| theorem | axiom list |
|---|---|
| `vinReads_eq` / `vinReads_eq_singleton_iff` | `[propext]` |
| `vinReads_eq_nil_iff` / `vinReads_subset` | `[propext, Quot.sound]` |
| `locktimeEnvOf_txSequence_of_lt` / `_default` | `[propext]` |
| `locktimeEnvOf_eq_of_selected` | `[propext]` |
| `checkLockTime_perInput_row` / `checkSequence_perInput_row` | `[propext]` |
| `checkLockTime_outOfRange` / `checkSequence_outOfRange` | `[propext]` |
| `checkLockTime_twoInput_is_special_case` | `[propext, Quot.sound]` |

`STATUS=lean-green`. The axioms are Lean/Mathlib foundations (`propext`,
`Quot.sound`); no `sorryAx`.

### 4.2 Alive2 — compiled C vs Lean over an arbitrary-length vin pointer

Command (`alive2/run.sh`):

```sh
cd /tmp/opencode/wave66/19-scr-132
bash spec/equiv/cells/locktime/C-L-locktime-input-index-general/alive2/run.sh
```

Built with `clang++-20 20.1.2`, `-O1 -fno-strict-aliasing -S -emit-llvm`; each
function is extracted with LLVM 20.1.2, the `nocapture` hint stripped and the
pair renamed to `f` (an optimisation hint only; see `notes.md`). Alive2 is
`alive-tv-v20.0` with `--smt-to=300000`.

Result (`alive2/result.txt`): 7/7 pairs report
`Transformation seems to be correct!`, `1 correct transformations`,
`0 incorrect`, `0 failed-to-prove`, `0 Alive2 errors`,
`STATUS=alive2-green`. Per-pair IR hashes are recorded in the result file;
the pairing is:

| pair | src | tgt | claim |
|---|---|---|---|
| `cltv` | totalised Core CLTV body | Lean `locktimeEnvOf` + `checkLockTimeDef` | body equality incl. getD fallback |
| `csv` | totalised Core CSV body | Lean `locktimeEnvOf` + `checkSequenceDef` | body equality incl. getD fallback |
| `cltv_raw` | verbatim `txTo->vin[nIn]` read | Lean environment | raw Core read selects the same slot (domain-guarded) |
| `csv_raw` | verbatim `txTo->vin[nIn]` read | Lean environment | same for CSV |
| `cltv_ni` | verdict from arbitrary vin `a` | verdict from arbitrary vin `b` | locality: equal selected slot ⇒ equal verdict |
| `csv_ni` | same | same | same for CSV |
| `getd_len` | `getD` at `len1` | `getD` at `len2` | length matters only via `nIn < len` |

The generality of the Alive2 dimension is a tool-semantics argument: a
pointer argument's input block size is nondeterministic, so the checked
domain is every in-range `nIn` at every vin length. This is not asserted from
the docs; `alive2/probe/run.sh` builds a probe whose source reads `p[100]`
and Alive2 returns a counterexample with `i = 100` and a non-local block of
size `5242225155463184514` bytes (`alive2/size-probe.txt`). The size is a
constraint variable, not a fixed bound.

### 4.3 SAW — independent predicate cross-check at a disclosed bound

Command (`saw/run.sh`):

```sh
cd /tmp/opencode/wave66/19-scr-132
bash spec/equiv/cells/locktime/C-L-locktime-input-index-general/saw/run.sh
```

SAW 1.6 (`68eed5f`, `/opt/equiv-tools/saw-1.6`) proves both compiled legs and
both two-vin non-interference products against `src/cell.cry`, which is written
from the Core/Lean text and shares no code with either leg. Eight proofs
succeed with no `Proof failed`: `cell_cltv_general` (C, L), `cell_csv_general`
(C, L), `cell_cltv_noninterf_b` (C, L), `cell_csv_noninterf_b` (C, L);
`STATUS=saw-green`.

**Disclosed bound:** 16 symbolic vin slots, symbolic 4-bit index, symbolic
64-bit length. SAW cannot allocate an unbounded array of symbolic contents,
so this leg is a second-tool cross-check at a stated bound. It is **not** the
general-length argument; that is §4.1 plus the Alive2 pointer domain in §4.2.
`spec.md` and `notes.md` say this in the same words, so the bound cannot be
mistaken for the row's generality.

### 4.4 Certificates

Each leg's run script writes `certificate.sha256` after the run. Entries are
repo-root-relative; verify from the worktree root (not from the cell dir):

```sh
cd /tmp/opencode/wave66/19-scr-132
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index-general/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index-general/saw/certificate.sha256
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index-general/lean/certificate.sha256
```

All 16 alive2 entries, 12 saw entries and 6 lean entries verify `OK` against
the committed bytes (`spec.md`, `notes.md`, run scripts, sources,
`contract/error_kind.h`, `alive2/size-probe.txt`, and the result files).

Repository gates run at this commit:

| gate | result |
|---|---|
| `make gate-ir-pin` | pass — 165 cells, 347 certificates |
| `make pins` | pass |
| `scripts/update_ledger.py --check` | derives `SCR-132: gap -> both-green (2 cell(s))`; sole drift is the unedited ledger (forbidden here) |

---

## 5. Residuals (explicit)

1. **Ledger/matrix not regenerated.** `spec/db/equiv-cells.yaml` still has
   `SCR-132: gap` and the matrix is not rebuilt. This is deliberate: both are
   integrator-owned. The mechanical derivation is green; the integrator must
   run the ledger and matrix generators after merge.
2. **C is a source-excerpt slice, not the whole engine.** As in every C/L
   locktime cell, the opcode dispatch, flag checks, stack guard and CScriptNum
   decode are outside the cell and named in `spec.md`. `L` is a reviewed
   transliteration of the pinned environment rule, not the generated twin
   (the twin has no transaction context; `F-LOCKTIME-001`).
3. **SAW is bounded at 16 slots.** It is a cross-check, not the generality
   proof (see §4.3). The general length rests on the Lean induction and the
   Alive2 pointer domain.
4. **Out-of-range C read is not claimed.** Core's `vin[nIn]` has a debug
   `assert` and is consensus-unreachable out of range. The cell materialises
   that assert as the same `nIn < len` guard that Lean's `List.getD` uses; the
   `*_raw` pairs keep the verbatim read under a harness domain guard. Nothing
   is claimed about an actual out-of-bounds C read.
5. **E5 residual unchanged.** Whole `VerifyScript`/`EvalScript` remains
   blocked by the dispatch loop/heap/exception edges
   (`findings/e5/E5-RESIDUAL.md`). This finding is the SCR-132 row only.
6. **Slot identity, not byte layout.** The vin model is a run of `nSequence`
   fields; the claim is about slot identity and the sequence value, not the
   `CTxIn` byte layout or `scriptSig`.

---

## 6. Reproduction

```sh
cd /tmp/opencode/wave66/19-scr-132
CELL=spec/equiv/cells/locktime/C-L-locktime-input-index-general
bash "$CELL/lean/run.sh"
bash "$CELL/saw/run.sh"
bash "$CELL/alive2/run.sh"
sha256sum -c "$CELL/lean/certificate.sha256"
sha256sum -c "$CELL/saw/certificate.sha256"
sha256sum -c "$CELL/alive2/certificate.sha256"
make gate-ir-pin
```

Expected markers: `STATUS=lean-green` (no `sorryAx`),
`STATUS=saw-green` (8 `Proof succeeded!`),
`STATUS=alive2-green` (7 correct transformations), and `OK` for every
certificate entry.
