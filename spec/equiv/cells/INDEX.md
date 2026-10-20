# Cell index — all recorded cells

**Snapshot:** `2026-10-20` (post wave 16/32 integration)
Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
Pinned Core: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.

There are **89 valid cell directories**; all have Alive2 and SAW attempts
and replayable certificates. Only cells whose `scr_row_coverage` is `full`
for the named row promote that ledger row; per-row `partial` coverage is
honoured. The current ledger is **95 both-green, 7 unjudged-seam, 81 filed
gap, 0 planned**. See `../results/matrix.md` and
`../findings/coverage/F-E6-GAPS.md` for the authoritative generated view.

The table below is retained as the historical E1/E2/E3/E4 core-cell set; the
wave-16/32 cells are listed in the generated matrix and find gaps.

| Cell | Family | Alive2 | SAW | SCR rows | Row coverage |
|---|---|---|---|---|---|
| `control-flow/C-L-nop-return` | control-flow | green | green | SCR-069/071 | **full** for 069/071; 072 not covered |
| `stack-ops/C-L-arity` | stack-ops | 16/16 | 32/32 | SCR-074 | **partial** (empty-stack only; 074 gap) |
| `stack/C-L-dup-drop-swap` | stack-ops | green | green | SCR-074/076/078 | partial; these rows remain gaps |
| `stack/C-L-altstack` | stack-ops | green | green | SCR-073 | partial |
| `stack/C-L-verify` | control-flow | green | green | SCR-068 | partial |
| `e1-stack/swap-order` | stack-ops | green | green | SCR-074/078 | partial |
| `e1-stack/dup-order` | stack-ops | green | green | SCR-074/078 | partial |
| `e1-stack/rot-direction` | stack-ops | green | green | SCR-074 | partial |
| `e1-stack/depth-count` | stack-ops | green | green | SCR-076 | partial |
| `e1-stack/pick-depth` | stack-ops | green | green | SCR-075 | partial |
| `e1-altstack/roundtrip` | stack-ops | green | green | SCR-073 | partial |
| `e2-numeric/within-boundary` | numeric | green | 2/2 | SCR-089 | partial (one-byte domain) |
| `e2-hash/hash160-vector` | hash-ops | green | 2/2 | SCR-093/094 | partial (concrete vector, opaque hash) |
| `e3-checksig/C-L-checksig-dispatch` | checksig | 3/3 | 12/12 | SCR-112 | partial (shared abstract checker) |
| `e3-cms/C-L-cms-1of1` | checkmultisig | 4/4 | 16/16 | SCR-114/118/119/120 | partial (1-of-1) |
| `checksig/C-L-checksig-empty` | checksig | 2/2 | 4/4 | SCR-109 | partial, narrow fallback |
| `e4-witness/C-L-witness-v0-dispatch` | witness-v0 | green | green | SCR-134/135/137 | partial (dispatch predicates only) |

All 17 are evidence-tier, bounded; none is a whole-engine proof. The E3/E4
cells use reviewed transliterations/abstractions where the generated twin has
no handler; their `spec.md` says so. No R proof cell exists at the pin.

---

# E1-specific index (historical detail)


Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
(recipe in `contract/tape.md` §10).
Pinned Core: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
Repository `HEAD` at cell build: `4d62a97e551082a69b13f495365bff0a903b0c99`.

`both-green` in this index means **the bounded leaf cell** passed Alive2 and
SAW. It is not a green claim for the whole `equiv_entry` function; see
“Whole-entry tool gap” below.

## Gate cells (REDTEAM E1 batch)

| Cell | Family | Witness spk | Alive2 | SAW | Whole-entry behavior | scr_rows (partial) |
|---|---|---|---|---|---|---|
| [`e1-stack/swap-order`](e1-stack/swap-order/spec.md) | stack-ops | `51 52 7c 51 87` | green (1 correct) | green (C,L) | C=(1,0), L=(1,0) | SCR-074, SCR-078 |
| [`e1-stack/dup-order`](e1-stack/dup-order/spec.md) | stack-ops | `51 52 76 52 87` | green (1 correct) | green (C,L) | C=(1,0), L=(1,0) | SCR-074, SCR-078 |
| [`e1-stack/rot-direction`](e1-stack/rot-direction/spec.md) | stack-ops | `51 52 53 7b 51 87` | green (1 correct) | green (C,L) | C=(1,0), L=(1,0) | SCR-074 |
| [`e1-stack/depth-count`](e1-stack/depth-count/spec.md) | stack-ops | `51 51 74 52 87` | green (1 correct) | green (C,L) | C=(1,0), L=(1,0) | SCR-076 |
| [`e1-stack/pick-depth`](e1-stack/pick-depth/spec.md) | stack-ops | `51 52 53 52 79 51 87` | green (1 correct) | green (C,L) | C=(1,0), L=(1,0) | SCR-075 |
| [`e1-altstack/roundtrip`](e1-altstack/roundtrip/spec.md) | stack-ops | `51 52 6b 6c 52 87` | green (1 correct) | green (C,L) | C=(1,0), L=(1,0) | SCR-073 |

Each directory contains:

- `spec.md` — contract, pin, precondition/postcondition, direction, SCR,
  trust note, mutation expectation.
- `notes.md` — raw tool tails, exact commands, behavioral witness, limits.
- `alive2/result.txt`, `alive2/certificate.sha256`.
- `saw/result.txt`, `saw/certificate.sha256`.
- `behavior/result.txt`, `behavior/certificate.sha256` (behavioral only).
- `build/` — generated `twin_ops.h` and the extracted C/L IR that the
  certificates hash.

The six witnesses are the exact bytes in the orchestrator correction. The
earlier PICK witness `51 52 53 52 79 52 87` is **not** used: both real legs
return `(0,2)` for it.

### SCR coverage is partial

The gate cells prove the concrete **success branch** of the named stack-ops
rows. They do not exercise underflow, stack-size, opcode-budget, or
`OP_COUNT` edges, so they do **not** discharge an entire SCR row:

| Cell | Not exercised |
|---|---|
| swap-order | SWAP underflow; popstack path |
| dup-order | DUP underflow; stack-size edge |
| rot-direction | ROT underflow |
| depth-count | DEPTH at 0/1; larger CScriptNum encodings |
| pick-depth | PICK index bounds/underflow; ROLL |
| altstack/roundtrip | empty-main/empty-alt failures; OP_COUNT edge |

This is recorded in each `spec.md` as `scr_row_coverage` and in `notes.md`.

## Whole-entry tool gap (not a green claim)

The whole generated `twin/build/twin.cpp` (`equiv_entry`) was compiled with
clang 20 `-O1 -fno-strict-aliasing` and compared to itself with Alive2. Alive2
could not translate it:

```text
ERROR: Unsupported attribute: noalias
ERROR: Unsupported attribute: nocapture
ERROR: Unsupported attribute: sret(%"struct.twin::Ctx")
ERROR: Could not translate '_ZN4twinL18verify_script_fullERKNS_6TxInfoEPKhjRKNS_3CtxERNS_5StateE' to Alive IR
ERROR: Could not translate '_ZN4twinL11eval_scriptEPKhjRKNS_3CtxERNS_5StateE' to Alive IR
Summary: 5 correct transformations, 48 Alive2 errors
```

Full probe: [`_tools/gate/whole_entry_alive2_probe.txt`](_tools/gate/whole_entry_alive2_probe.txt).
The module also contains tx-decoding loops, `new`/exceptions, and hash
routines. Whole-entry SAW is likewise not claimed: `equiv_entry` needs loop
invariants/overrides, and the cell SAW proofs are for the bounded leaves.

The whole-entry evidence for the six witnesses is behavioral only: real C and
L libraries return `(1,0)` on both legs.

## Bounded-leaf method

- `cells/_tools/mk_leaf.py` copies handler bodies **verbatim** from
  `twin/ops_ir.py` into `build/twin_ops.h`. Only `MAX_STACK_SIZE` (6) and
  `MAX_SCRIPT_ELEMENT_SIZE` (1) are re-bound; `std::memcpy`/`std::memcmp` are
  replaced by exact-for-`len <= 2` loop-free helpers.
- The C leg is a line-cited source slice of Core `interpreter.cpp` at the pin.
- The shared bounded stack, dispatcher, finish/truth, and packed observable
  are cell harness, not engine code.
- Packed observable: result (2 bits), error ordinal (6), depth (3), then the
  top three elements as `(len:2, val:8)`. `pick-depth` has depth 4, so its
  bottom element is not packed; depth still distinguishes it.
- Alive2/SAW ingest the extracted `cell_*` function with
  `llvm-extract --recursive`. Toolchain: LLVM/clang 20.1.2, Alive2 LLVM 20,
  SAW 1.6 with `abc`.

The SAW postcondition is the closed witness's packed constant, not a symbolic
op law. The `-O0` fully-inlined build was attempted but did not finish in the
Alive2 harness timeout; all recorded artifacts are `-O1 -fno-strict-aliasing`.

## Corpus reach (exact)

Source: `corpus/selections/stack.jsonl`; machine-readable result:
[`_tools/gate/corpus_reach.json`](_tools/gate/corpus_reach.json).

- 316 rows; 0 witness-form rows.
- Flags: 200 `P2SH,STRICTENC`, 71 `MINIMALDATA`, 42 no flags, 2
  `CONST_SCRIPTCODE`, 1 `SIGPUSHONLY`.
- 50 rows have an empty scriptSig; 0 rows have **both** empty scriptSig and no
  flags.
- 316/316 parse and 316/316 scriptPubKeys pass the parser walk.
- 31 rows use only the gate opcode subset in the scriptPubKey, but only 1 of
  those also has an empty scriptSig; that row has nonzero flags.
- 0/316 rows match any of the six exact gate witnesses.
- Gate precondition (flags 0, empty scriptSig, exact witness): **0/316**.

The gate batch is witness-level mutation detection, not corpus-row coverage.

## Broader `cells/stack/C-L-*` cells (closed witnesses)

These three cells are now built as **bounded closed witnesses**, including
concrete underflow branches.  They are not the originally planned symbolic
depth/stack-domain cells; no universal op law is claimed.

| Cell | Closed witnesses (spk -> packed) | Alive2 | SAW | Whole-entry behavior | scr_rows (partial) |
|---|---|---|---|---|---|
| [`stack/C-L-verify`](stack/C-L-verify/spec.md) | `51 69 51` -> `0x2901`; `00 69` -> `0x012c`; `69` -> `0x0048` | green 3/3 | green (6 proofs) | 3/3 match | SCR-068 |
| [`stack/C-L-dup-drop-swap`](stack/C-L-dup-drop-swap/spec.md) | `76`, `7c`, `75` -> `0x0048` each; `51 52 76 7c 52 87 75` -> `0x1202a01` | green 4/4 | green (8 proofs) | 4/4 match | SCR-074, SCR-078 |
| [`stack/C-L-altstack`](stack/C-L-altstack/spec.md) | `6c` -> `0x004c`; `6b` -> `0x0048`; `51 52 6b 6c` -> `0x1202a01` | green 3/3 | green (6 proofs) | 3/3 match | SCR-073 |

Details:

- `C-L-verify`: OP_VERIFY true branch pops and a final `1` yields result 1;
  OP_0 OP_VERIFY fails with `VERIFY=11`; bare OP_VERIFY on the empty stack
  fails with `INVALID_STACK_OPERATION=18`.
- `C-L-dup-drop-swap`: empty-stack DUP/SWAP/DROP all fail with 18; the
  success composition is sensitive to the M-E1-002 DUP-second-from-top
  mutant (correct final `[1,2]`, mutant final `[1,1]`).
- `C-L-altstack`: FROMALTSTACK on empty alt fails with
  `INVALID_ALTSTACK_OPERATION=19`; TOALTSTACK on empty main fails with 18;
  the roundtrip ends `[1,2]` with an empty altstack.

Each cell has `alive2/`, `saw/`, and `behavior/` results plus certificates.
The whole-entry behavior is behavioral only.  The remaining gap is a
**symbolic** leaf ABI plus a shared Cryptol stack model to quantify over
depths/values and cover stack-size/OP_COUNT edges; that is the next action.

## Mutation replay

The six gate mutants (M-E1-001/002/003/004/006/007) and a C-slice
M-E1-001 were independently replayed on a disposable copy of `spec/equiv`.
All were killed: mutant Alive2 and SAW were non-green, and each baseline was
green again after restoring the original source.  Records and raw outputs:
[`../findings/cells/mutations/`](../findings/cells/mutations/).

M-E1-005 (push-size limit) has no gate cell in this batch and was not run.
A mutation to only `twin/build/twin.cpp` is not observed by these cells; the
leaf is regenerated from `twin/ops_ir.py`.

## Findings / open edges

- **F-DIV-001** — confirmed by execution on truncated-push tails
  (`69 02 01` C=(0,18) L=(0,16); `7e 02 01` C=(0,17) L=(0,16)). The six gate
  scripts are fully parseable, so F-DIV-001 does not apply to them. Any future
  flow/parse cell with a malformed tail must be `unjudged-seam` with
  F-DIV-001, not green.
- **F-ERR-TWIN-001** — still open for the whole-entry mapping. The gate cells
  exercise only the success path (`EQUIV_ERR_OK`); the broader closed-witness
  cells prove their listed leaf error ordinals and their whole-entry behavior
  agrees, but that is not a whole-entry error-kind proof.
- **Altstack gap** — resolved by twin v2; `e1-altstack/roundtrip` is now
  both-green as a bounded leaf.
- **Whole-entry proof gap** — Alive2 cannot ingest `equiv_entry`; SAW would
  need loop/exception overrides. No cell claims whole-entry green.
- **Mutation site** — the gate leaves are regenerated from
  `twin/ops_ir.py`; a mutation to `twin/build/twin.cpp` alone is not observed.
  REDTEAM should mutate the `ops_ir.py` handler body for these gates.
