# locktime/C-L-locktime-input-index-general — notes

General-vin closure of SCR-132 ("CheckLockTime/Sequence see only input nIn").
This is a *new* cell; the two-input cell
`locktime/C-L-locktime-input-index` is left untouched and its statement is not
relabelled.  Its instance is recovered as a special case by
`checkLockTime_twoInput_is_special_case`.

## Commands

```sh
cd /tmp/opencode/wave66/19-scr-132
bash spec/equiv/cells/locktime/C-L-locktime-input-index-general/alive2/run.sh
bash spec/equiv/cells/locktime/C-L-locktime-input-index-general/saw/run.sh
bash spec/equiv/cells/locktime/C-L-locktime-input-index-general/lean/run.sh
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index-general/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index-general/saw/certificate.sha256
sha256sum -c spec/equiv/cells/locktime/C-L-locktime-input-index-general/lean/certificate.sha256
```

Tools: Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2),
SAW 1.6 (`68eed5f`, `/opt/equiv-tools/saw-1.6`), clang++-20 20.1.2,
Lean 4.35.0 with the pinned model at `4d62a97e`.

## What each leg establishes

### Lean — arbitrary list, the general-length closure

`src/GeneralIndex.lean` imports the pinned model
(`Bitcoin.Interpreter.Rules`, unchanged) and proves, for an arbitrary
`List TxIn` and `nIn : Nat`:

| theorem | statement |
|---|---|
| `vinReads_eq` | the `getD` access trace is `[nIn]` in range and `[]` out of range |
| `vinReads_subset` | no index other than `nIn` can appear in the trace |
| `locktimeEnvOf_txSequence_of_lt` | in range, the env's sequence is `(vin[nIn]).sequence` |
| `locktimeEnvOf_txSequence_default` | out of range, the env's sequence is the `getD` default (`0`) |
| `locktimeEnvOf_eq_of_selected` | same version/locktime and same selected sequence (or both out of range) ⇒ same environment; all other inputs, outputs and witness are unconstrained |
| `checkLockTime_perInput_row`, `checkSequence_perInput_row` | the two verdicts are equal under that relation |
| `checkLockTime_outOfRange`, `checkSequence_outOfRange` | out-of-range corollary: the default input is used on both sides |
| `checkLockTime_twoInput_is_special_case` | `vin.length = 2` is an instance of the general theorem |

`#print axioms` lists only `propext` (and `Quot.sound` where `List.map`
occurs).  There is no `sorryAx`; `lean/result.txt` records the lines and the
run script refuses a result containing `sorryAx`.

### Alive2 — arbitrary length, arbitrary uint32 index

Seven transformations, all with a pointer-to-sequence-fields argument and a
`uint32` index.  Alive2 gives a pointer argument an input block of
nondeterministic size (visible in counterexample models: the size varies with
the constraints), so a proof here quantifies over vins of every length at
every in-range index.

| pair | src | tgt | what it proves |
|---|---|---|---|
| `cltv` | C totalised Core body | Lean `locktimeEnvOf` + `checkLockTimeDef` | C = L including the getD fallback |
| `csv` | C totalised Core body | Lean `locktimeEnvOf` + `checkSequenceDef` | C = L including the getD fallback |
| `cltv_raw` | verbatim `txTo->vin[nIn]` read | Lean environment | the raw Core read is the Lean selection (domain-guarded) |
| `csv_raw` | verbatim `txTo->vin[nIn]` read | Lean environment | same for CSV |
| `cltv_ni` | two arbitrary vins `a,b`, verdict from `a` | verdict from `b` | if `selected(a)=selected(b)` the verdicts agree |
| `csv_ni` | same | same | same for CSV |
| `getd_len` | `getD` at `len1` | `getD` at `len2` | the length matters only through `nIn < len`; all out-of-range lengths select the default |

The result text records, per pair, the command, the IR hashes and the full
Alive2 output.  `STATUS=alive2-green`.

`alive2/size-probe.txt` (produced by `alive2/probe/run.sh`, not part of the
proof) shows the model premise directly: a probe whose source reads `p[100]`
produces a counterexample with `i = 100` and a NON-LOCAL block of size
5242225155463184514 bytes.  The input block size is a constraint variable,
not a fixed bound, which is why the pointer-argument proofs cover every vin
length at an in-range index.

### SAW — independent predicate, 16-slot cross-check

`src/cell.cry` is written from the Core/Lean text and shares no code with
either leg.  It models `(tx.vin.getD nIn default).sequence` as
`if nIn < len then vin @ nIn else def`.  `src/cell.saw` allocates 16 symbolic
slots, a symbolic 4-bit index and a symbolically long length, then proves:

- `cell_cltv_general` on the C and on the L module against `cltv`;
- `cell_csv_general` on the C and on the L module against `csv`;
- `cell_cltv_noninterf_b` / `cell_csv_noninterf_b` on both legs against the
  two-array locality predicate (selected slots equal ⇒ the verdict is the
  predicate on that one slot).

Eight `Proof succeeded!`, no `Proof failed`; `STATUS=saw-green`.

### The disclosed bound

SAW cannot express an unbounded array of symbolic contents (it needs a
concrete allocation shape), so its cross-check uses 16 slots.  That is a
*second-tool* cross-check at a stated bound, not the general argument: the
general length is closed by the Lean induction and by Alive2's
nondeterministic input-block size.  The spec's `scr_row_coverage` says this
explicitly; the SAW bound is not presented as the row's generality.

## Core `assert` and the fallback

Core's `txTo->vin[nIn]` is `std::vector<CTxIn>::operator[]`; the debug build
asserts `nIn < size()`, and consensus callers guarantee it.  The row names the
Lean totalisation (`List.getD`, `Rules.lean:92-95`), which returns the default
input's sequence (`0`) out of range.  The cell materialises the assert as the
same `nIn < len` guard in both legs; `cltv_raw`/`csv_raw` additionally keep
the verbatim unguarded `vin[nIn]` read and compare it with the Lean
environment under a harness domain guard.  The cell therefore does not claim
anything about an out-of-range C read; it proves that the *reachable* C read
is the `nIn`-th slot and that the model's fallback is the default input.

## Elisions and trust

Same trust base as the rest of the workstream: C is a line-cited
source-excerpt slice, L is a reviewed transliteration (the twin has no
transaction context; finding F-LOCKTIME-001), and the slot identity claim is
about `nSequence` slots, not the byte layout of `CTxIn`.  No Core patch is
used.  E5 (whole `VerifyScript`) remains a scoped residual; this cell is the
SCR-132 row, not a whole-engine result.
