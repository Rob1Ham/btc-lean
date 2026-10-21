# E1 report — bounded stack/altstack gate batch

Status: **6/6 gate cells and 3/3 broader closed-witness cells both-green on
bounded leaves**, each with matching whole-entry behavioral evidence.  No
whole-entry proof is claimed.

- Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
  (full `sha256sum` line: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6  -`)
- Pinned Core: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- Repository `HEAD`: `4d62a97e551082a69b13f495365bff0a903b0c99`
- Index: `spec/equiv/cells/INDEX.md`
- Cell tooling: `spec/equiv/cells/_tools/README.md`

## 1. What was delivered

Six REDTEAM gate cells, at the exact paths/bytes from the orchestrator
correction:

| Cell | Witness spk | Alive2 | SAW | Whole-entry behavior |
|---|---|---|---|---|
| `cells/e1-stack/swap-order` | `51 52 7c 51 87` | green | green | C=(1,0), L=(1,0) |
| `cells/e1-stack/dup-order` | `51 52 76 52 87` | green | green | C=(1,0), L=(1,0) |
| `cells/e1-stack/rot-direction` | `51 52 53 7b 51 87` | green | green | C=(1,0), L=(1,0) |
| `cells/e1-altstack/roundtrip` | `51 52 6b 6c 52 87` | green | green | C=(1,0), L=(1,0) |
| `cells/e1-stack/depth-count` | `51 51 74 52 87` | green | green | C=(1,0), L=(1,0) |
| `cells/e1-stack/pick-depth` | `51 52 53 52 79 51 87` | green | green | C=(1,0), L=(1,0) |

Each cell has:

- `spec.md` — contract, repo head, pin, legs, exact precondition,
  postcondition, directions, tool status, SCR rows **with a partial-coverage
  note**, trust note, mutant.
- `notes.md` — raw Alive2/SAW tails, exact commands, behavioral output,
  blockers, mutation caveat.
- `alive2/result.txt`, `alive2/certificate.sha256`.
- `saw/result.txt`, `saw/certificate.sha256`.
- `behavior/result.txt`, `behavior/certificate.sha256` (behavioral only).
- `build/twin_ops.h`, extracted C/L `.ll`/`.bc` hashed by the certificates.

The wrong PICK witness `51 52 53 52 79 52 87` is not used anywhere; both real
legs return `(0,2)` for it.

Three broader `cells/stack/C-L-*` cells are also delivered as bounded closed
witnesses (including concrete underflow branches): `C-L-verify`,
`C-L-dup-drop-swap`, and `C-L-altstack`.  See §5 for their evidence and the
remaining symbolic-domain gap.

### Packed observables (closed leaf)

Layout: result (2 bits), error ordinal (6), depth (3), then the top three
elements as `(len:2, val:8)` each.

| Cell | Packed constant | Decode |
|---|---|---|
| swap-order | `0x0000000000a04a01` | result 1, err 0, n=2, `[2,1]` |
| dup-order | `0x0000000281202b01` | result 1, err 0, n=3, `[1,2,1]` |
| rot-direction | `0x0000000281a04b01` | result 1, err 0, n=3, `[2,3,1]` |
| roundtrip | `0x0000000000a02a01` | result 1, err 0, n=2, `[1,1]`; altstack empty |
| depth-count | `0x0000000280a02b01` | result 1, err 0, n=3, `[1,1,1]` |
| pick-depth | `0x0000000281a04c01` | result 1, err 0, n=4, top3 `[2,3,1]` (bottom `1` not packed) |

All six SAW proofs verify the C and L extracted modules against the cell's
declared constant, so the constant is tool-checked on both legs.

## 2. Method and provenance

### Bounded leaf, not whole `equiv_entry`

A whole-entry comparison is not tool-ingestible today:

- Alive2 on `twin/build/twin.cpp` at `-O1 -fno-strict-aliasing` reports
  `Unsupported attribute: noalias` / `nocapture` /
  `sret(%"struct.twin::Ctx")` and cannot translate
  `verify_script_full`, `eval_script`, or `classify_push_only`.  Summary:
  `5 correct transformations, 48 Alive2 errors`.
- The module also contains tx-decoding loops, `new`/exceptions, and hash
  routines.  Whole-entry SAW would need loop/exception overrides and is not
  claimed.

The cells therefore prove a **bounded handler/script-sequence leaf** for the
exact closed witness, and separately record the whole-entry behavioral
witness.  The distinction is explicit in every `spec.md` and `notes.md`.

### L leg

`cells/_tools/mk_leaf.py` loads `twin/ops_ir.py` read-only and copies the
selected handler bodies **verbatim** into `build/twin_ops.h`.  It only:

- re-binds `MAX_STACK_SIZE = 6` and `MAX_SCRIPT_ELEMENT_SIZE = 1`;
- replaces `std::memcpy`/`std::memcmp` with loop-free helpers exact for
  `len <= 2`;
- adds bounded `st_push`/`st_push_copy`/`st_push_num`/`decode_num`.

The generated header records the SHA-256 of `twin/ops_ir.py`,
`twin/gen.py`, and `contract/error_kind.h`.  The cell dispatcher,
stack initialization, finish/truth, and pack are harness code, not twin
engine code.

### C leg

`cells/_tools/gate/c_leaf.cpp` is a line-cited slice of Bitcoin Core
`src/script/interpreter.cpp` at the pin:

- pushes (`OP_1`..`OP_16`) ~500–529
- TOALTSTACK/FROMALTSTACK 687–703
- DUP 804–811
- PICK 833–849, ROT 851–861, SWAP 863–869
- EQUAL 897–910
- EVAL_FALSE tail ~1876–1880

OP_VERIFY 663–674 and DROP 795–802 are used by the broader closed-witness
cells, not by the six gate scripts.

It is not the whole `EvalScript` and not the whole `VerifyScript`.

### Toolchain

- clang/clang++ 20.1.2
- LLVM 20.1.2 (`llvm-extract`, `llvm-dis`, `llvm-as`)
- Alive2 (LLVM 20 build, `/usr/local/bin/alive-tv`)
- SAW 1.6 (`68eed5f release-1.6`), solver `abc`
- SAW postcondition: closed packed constant, **not** a symbolic op law.

### Build mode

Recorded artifacts use `-O1 -fno-strict-aliasing` IR.  A scratch fully-inlined
`-O0` build did not finish in the 120 s Alive2 harness timeout; no `-O0`
proof or artifact is claimed.  `-g` was avoided (Alive2 metadata rejection);
`-O1` without `-fno-strict-aliasing` rejects TBAA metadata.

## 3. Tool results

For every **gate** cell:

- Alive2: `Transformation seems to be correct!`, summary
  `1 correct transformations, 0 incorrect transformations, 0 failed-to-prove
  transformations, 0 Alive2 errors`.
- SAW: two `Proof succeeded! <cell_fn>` lines (C module and L module), no
  `Proof failed`.
- Behavioral: `C=(1,0)`, `L=(1,0)`, `STATUS=behavior-match`.

For the broader **closed-witness** cells:

- Alive2: 3/3 correct for `C-L-verify`, 4/4 for `C-L-dup-drop-swap`, 3/3 for
  `C-L-altstack`; no incorrect/failed-to-prove/errors.
- SAW: 6, 8, and 6 `Proof succeeded!` lines respectively (C and L for each
  function).
- Behavioral: every listed witness matches, including the non-OK ordinals
  (`VERIFY=11`, `INVALID_STACK_OPERATION=18`,
  `INVALID_ALTSTACK_OPERATION=19`).

The behavioral call is against the real C and L libraries:

- C: `/tmp/opencode/cbuild/libequiv-core.so`,
  sha256 `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5`
- L: `spec/equiv/twin/build/libtwin.so`,
  sha256 `b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b`

Tape: one input, prevout `(0x00…,0)`, empty scriptSig, sequence
`0xffffffff`, amount 0, input 0, flags 0, no witness record.  This is
behavioral evidence, not proof.

## 4. Corpus reach (exact)

From `corpus/selections/stack.jsonl` (machine-readable copy:
`cells/_tools/gate/corpus_reach.json`):

- 316 rows; 0 witness-form rows.
- Flags: 200 `P2SH,STRICTENC`, 71 `MINIMALDATA`, 42 no flags, 2
  `CONST_SCRIPTCODE`, 1 `SIGPUSHONLY`.
- Empty scriptSig: 50 rows.  Empty scriptSig **and** no flags: 0 rows.
- Parse: 316/316.  ScriptPubKey parser walk: 316/316.
- Gate opcode subset in scriptPubKey: 31 rows; 1 of those also has an empty
  scriptSig; that one has nonzero flags.
- Exact match to any of the six gate witnesses: 0/316.
- Gate precondition (flags 0, empty scriptSig, exact witness): **0/316**.

So this batch is witness-level mutation detection; it does not claim corpus
row coverage.

## 5. Findings and open edges

### F-DIV-001 (confirmed, not applicable to these six)

Truncated-push tails diverge by execution:

```text
spk 69 02 01   C=(0,18)  L=(0,16)
spk 7e 02 01   C=(0,17)  L=(0,16)
```

The six gate scripts are fully parseable, so F-DIV-001 does not apply.  Any
future flow/parse cell with a malformed tail must be `unjudged-seam` with
F-DIV-001, not green.

### F-ERR-TWIN-001 (open for whole-entry mapping)

The gate cells exercise only the success path and observe only
`EQUIV_ERR_OK`.  The broader closed-witness cells prove their listed leaf
error ordinals (`INVALID_STACK_OPERATION=18`,
`INVALID_ALTSTACK_OPERATION=19`, `VERIFY=11`) and their whole-entry behavior
agrees for those samples.  This does **not** discharge F-ERR-TWIN-001: the
whole-entry non-OK error-kind mapping is not proved.

### SCR rows are partial

The gate witnesses prove the success branch of the named stack-ops rows, not
the underflow/limit/budget edges:

- swap/dup: SCR-074/078 success only.
- rot: SCR-074 success only.
- depth: SCR-076 with the single minimal encoding 2 only.
- pick: SCR-075 success with index 2 at depth 4 only; no ROLL/underflow.
- altstack: SCR-073 success roundtrip only; no empty-alt/empty-main/OP_COUNT
  edges.

Every `spec.md` carries `scr_row_coverage: partial …`; no SCR row is claimed
as fully discharged.

### Altstack

The former altstack gap is resolved by twin v2.  `e1-altstack/roundtrip` is
both-green on the bounded leaf.

### Broader `cells/stack/C-L-*` cells (closed witnesses)

The three broader cells are built as **bounded closed witnesses**, including
concrete underflow branches.  They are not symbolic depth/value-domain proofs;
no universal op law is claimed.

| Cell | Closed witnesses | Alive2 | SAW | Whole-entry behavior | scr_rows (partial) |
|---|---|---|---|---|---|
| `stack/C-L-verify` | `51 69 51` -> `0x2901`; `00 69` -> `0x012c`; `69` -> `0x0048` | 3/3 correct | 6 proofs | 3/3 match | SCR-068 |
| `stack/C-L-dup-drop-swap` | `76`, `7c`, `75` -> `0x0048` each; `51 52 76 7c 52 87 75` -> `0x1202a01` | 4/4 correct | 8 proofs | 4/4 match | SCR-074, SCR-078 |
| `stack/C-L-altstack` | `6c` -> `0x004c`; `6b` -> `0x0048`; `51 52 6b 6c` -> `0x1202a01` | 3/3 correct | 6 proofs | 3/3 match | SCR-073 |

Evidence is under each cell’s `alive2/`, `saw/`, and `behavior/` directories,
with certificates.  The success composition in `C-L-dup-drop-swap` is
deliberately sensitive to the M-E1-002 DUP-second-from-top mutant: the correct
leaf ends `[1,2]` (`0x1202a01`), while the mutant ends `[1,1]` and fails
Alive2.  The remaining gap is a **symbolic** initial-stack ABI and a shared
Cryptol stack model to quantify over depths/values and cover stack-size /
OP_COUNT edges.

### Independent mutation checks

All six gate mutations were replayed independently on a disposable copy of
`spec/equiv` (`/tmp/opencode/cells-work/mut-repo`).  The real
`spec/equiv/twin/ops_ir.py` was never modified.  After each mutant, the copy
was restored from the original file and the baseline was rerun green.

| Mutant | Cell | Mutant Alive2 | Mutant SAW | Baseline after revert |
|---|---|---|---|---|
| M-E1-001 | `e1-stack/swap-order` | `alive2-not-green` | `saw-not-green` | green / green |
| M-E1-002 | `e1-stack/dup-order` | `alive2-not-green` | `saw-not-green` | green / green |
| M-E1-003 | `e1-stack/rot-direction` | `alive2-not-green` | `saw-not-green` | green / green |
| M-E1-004 | `e1-altstack/roundtrip` | `alive2-not-green` | `saw-not-green` | green / green |
| M-E1-006 | `e1-stack/depth-count` | `alive2-not-green` | `saw-not-green` | green / green |
| M-E1-007 | `e1-stack/pick-depth` | `alive2-not-green` | `saw-not-green` | green / green |
| M-E1-001 core-slice | `e1-stack/swap-order` (C leaf) | `alive2-not-green` | `saw-not-green` | green / green |

Records and raw outputs: `findings/cells/mutations/`.  For M-E1-001/002/003/
006/007 the mutant Alive2 output contains `Transformation doesn't verify!`
with `Value mismatch`.  M-E1-004's mutant Alive2 reports
`Target is more poisonous than source`; its mutant SAW fails during symbolic
execution with `Error during memory load` (non-green, not a counterexample
proof).  The core-slice M-E1-001 changes the C leaf, so both tools fail
against the untouched L leaf.

The broader `C-L-dup-drop-swap` cell was also checked against M-E1-002: the
success composition detects it, with Alive2 reporting 3/4 functions correct
and one value mismatch (raw:
`findings/cells/mutations/raw/M-E1-002-broader-alive2.txt`).

M-E1-005 (push-size limit) has no gate cell in this batch and was not run; the
`e1-push/size-boundary` cell remains future work.  A mutation to only
`twin/build/twin.cpp` is **not** observed by these cells, because the leaf is
regenerated from `twin/ops_ir.py`; use the `ops_ir.py` site for these gates.

## 6. What is not claimed

- No unconditional Lean model == Core claim.
- No whole-`VerifyScript` or whole-`equiv_entry` proof.
- No symbolic op law from SAW; its postcondition is the closed packed
  constant.
- No full SCR row discharge from the success-only gate witnesses or the
  broader closed-witness cells.
- No coverage of the 316-row corpus by these exact witnesses.
- No symbolic universal proof for the broader `cells/stack/C-L-*` cells; they
  are closed edge witnesses only.
- No claim that the C shim library or the L build is the whole engine; the
  leaf C source is a line-cited Core slice, and the L leaf uses verbatim
  handler bodies.

## 7. Reproduce

```sh
cd spec/equiv
for d in cells/e1-stack/swap-order \
         cells/e1-stack/dup-order \
         cells/e1-stack/rot-direction \
         cells/e1-stack/depth-count \
         cells/e1-stack/pick-depth \
         cells/e1-altstack/roundtrip; do
  "$d/alive2/run.sh"
  "$d/saw/run.sh"
  "$d/behavior/run.sh"
done
for d in cells/stack/C-L-verify \
         cells/stack/C-L-dup-drop-swap \
         cells/stack/C-L-altstack; do
  "$d/alive2/run.sh"
  "$d/saw/run.sh"
  "$d/behavior/run.sh"
done
```

Every runner regenerates `build/twin_ops.h` from `twin/ops_ir.py`, rebuilds
the extracted C/L IR, reruns the tool, writes the raw result, and rewrites
the certificate.  Exit status is non-zero on a red result.  `alive-tv` itself
always exits 0, so the runner parses the output text.

## 8. Next actions

1. Upgrade the three closed-witness `cells/stack/C-L-*` cells to symbolic
   cells with a shared packed input ABI and a shared Cryptol reference model;
   retain the current underflow witnesses as concrete regression cases.
2. Attempt a whole-entry Alive2 artifact by extracting a loop-free slice of
   `eval_script` / `verify_script_full` with hash routines overridden and
   contexts modeled; do not call it whole-entry until the tx/verify shell is
   covered.
3. Close F-ERR-TWIN-001 with a whole-entry proof-level error-ordinal mapping,
   not just closed-witness leaves or sampled execution.
4. The independent mutation replay is complete for the six gate cells
   (including a C-slice M-E1-001); remaining mutation work is M-E1-005
   `e1-push/size-boundary`, whose cell does not exist yet.
5. Recompute corpus reach after the symbolic cells exist; current gate
   precondition reach is 0/316 by construction.

---

## Post-E6 addendum — current ledger and later mutations

The six gate cells and three broader stack cells remain raw-green. The current
E6 ledger promotes only **SCR-074** from the stack family (via
`stack-ops/C-L-arity` 16/16 Alive2 + 32/32 SAW, corroborated by the gate
cells). SCR-069/071/072 are green from `control-flow/C-L-nop-return`, not from
this batch.

Later orchestrator runs added:

- **M-E1-008** (twin `OP_2DROP` arity) — killed by both tools on
  `stack-ops/C-L-arity`; reverted, baseline green. See
  `cells/_redteam/runs/`.
- **M-E2-010**, **M-E3-008**, **M-E4-004** — cross-family mutation tests,
  also killed by both tools.

The current total is 8 mutation runs / 7 distinct IDs, all killed. The E1
report's earlier "six gate mutations" count is the E1 batch only; it is not the
E6 total.
