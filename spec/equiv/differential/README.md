# `differential/` — behavioral differential over the pinned script corpus

This directory is an **independent replay harness**. It feeds every case-like
row of the pinned Core `script_tests.json` through the C leg and the L leg,
and compares the observed `(result, error_kind)` with each other, with the
Lean interpreter model, and with the corpus's own `expected` verdict.

It is deliberately *not* wired into the per-cell / IR machinery. A behavioral
agreement here is evidence about **these builds on this corpus**; it is not an
LLVM IR proof, not a refinement proof, and not a statement that C and Lean are
universally equivalent.

## Leg identities (read this first)

`findings/cross/F-HARNESS-001-lean-verdicts-labelled-L.md` established that
`spec/data/l2/scr/results/tierC.l2r` is produced by `L2ScrRunner.lean`, the
Lean **interpreter model**, and is *not* the generated C++ twin.

The harness therefore records two L-shaped lanes:

| Lane | Artifact | Identity | Role |
|---|---|---|---|
| **C** | `/tmp/opencode/cbuild/libequiv-core.so` | Core shim, ABI v2 | reference replay |
| **L_twin** | `spec/equiv/twin/build/libtwin.so` | `twin-libtwin` | **the actual L leg; primary comparison** |
| `L` | `spec/data/l2/scr/results/tierC.l2r` | `lean-model-not-twin` | oracle cross-check only |
| R | none | — | **blocked**, no clean shim |

Every record in `results/c-l.jsonl` carries `L.leg_identity =
"lean-model-not-twin"` and `L_twin.leg_identity = "twin-libtwin"`. The
primary `status` / `agree` fields are computed from **C vs L_twin**. The
Lean-model comparison is reported separately as `c_vs_lean_model` and
`lean_model_status`.

Only the `C vs L_twin` lane may be called C-L. The Lean-model lane must be
cited as `C-vs-Lean-model`.

## Pins

| Input | Path | sha256 |
|---|---|---|
| Corpus | `spec/data/core/script_tests.json` | `7fb93dea245f68b627d214e0d51969c4f29fefaae1ac94ca1eba5fe8322f864c` |
| Lean-model verdicts | `spec/data/l2/scr/results/tierC.l2r` | `88624ebfb4c772be5f353feea4ea3972923e7dcca1ed0cc57805d6361d7df1b6` |
| C leg | `/tmp/opencode/cbuild/libequiv-core.so` | `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5` |
| L twin | `spec/equiv/twin/build/libtwin.so` | `d560a5f69a05179c29851aa80cbea330e976ec455c7e6bca32f0b6dfee223801` |
| Twin IR metadata | `spec/equiv/twin/build/twin.ir.json` | `8684d4f0bdb5ec9a08006e83e60a1ca3bc14068da8443feb9100dd50bc590693` |
| Contract | `contract/{ABI.md,tape.md,error_kind.h,corpus_schema.md}` | `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6` |

The harness refuses to run if the corpus or verdict-file hash drifts. The
contract hash is recorded in `results/summary.json`.

**Pin mismatch, recorded rather than hidden.** The Lean-model verdicts were
produced with the L2-SCR oracle read at `c50817fe`, while the vendored corpus
is pinned at `cce32b168`. Before joining a verdict, the harness requires the
row id to match its ordinal and the verdict's `want` column to equal the
vector's `expected`; 1258/1258 rows pass both checks. That makes the
`C vs expected` column independent of the verdict file, but it does not
re-execute the Lean model at the corpus pin.

## Corpus coverage

`script_tests.json` contains **1258 case-like rows** (entries with at least
three fields; comment and single-string lines are skipped) out of the raw
file. All 1258 are replayed, not just the 1456 memberships in
`corpus/selections/*.jsonl`:

- 1456 selection memberships across the ten derived families;
- 170 case-like rows belong to no selection and get family `unassigned`.

The selection files are hash-checked, field-checked against the source row,
and row-hash-checked at load time. A mismatch aborts the run. Note that a row
may belong to several families, so per-family row counts overlap and do not
sum to 1258.

| Family | Rows (tally) |
|---|---:|
| stack | 316 |
| flow | 297 |
| numeric | 335 |
| hash | 115 |
| checksig | 90 |
| cms | 117 |
| locktime | 21 |
| disabled | 24 |
| witness | 134 |
| taproot | 7 |
| unassigned (not in any selection) | 170 |

## Encoding rules

The harness reimplements Core's test-framework tape construction directly;
no encoding step is guessed.

- **Crediting transaction** — `BuildCreditingTransaction` (`version 1`, null
  prevout, scriptSig `OP_0 OP_0`, one output of `amount` and `spk`, locktime
  0), serialized without witness.
- **Spending transaction** — `BuildSpendingTransaction` (`version 1`, one
  input spending vout 0 of the credit tx, one empty output, locktime 0),
  serialized as `TX_WITH_WITNESS`.
- **Prevout txid** — `SHA256d(credit_tx)`.
- **Witness presence** — marker/flag and witness stack are serialized iff the
  witness stack length is `> 0` (`CScriptWitness::IsNull() == stack.empty()`),
  not merely when a witness item is non-empty.
- **Flags** — parsed from `contract/tape.md` bit values. `CLEANSTACK` implies
  `P2SH|WITNESS`, exactly as `DoTest` does before `VerifyScript`.
- **Error alias** — JSON `NULLFAIL` maps to `SIG_NULLFAIL`; this is the only
  alias (`script_errors[]` in `src/test/script_tests.cpp`).
- **Taproot** — the seven taproot rows use Core's `#SCRIPT#` /
  `#CONTROLBLOCK#` / `#TAPROOTOUTPUT#` auto-generation: internal key
  `keys.key0` (private key 1, x-only `G.x`), one tapscript leaf at depth 0,
  BIP341 output-key tweak, generated control block. `0x51 0x20
  #TAPROOTOUTPUT#` is replaced with the computed `OP_1 <32-byte output key>`.
  This encoder is validated by the fact that the C leg reproduces all seven
  expected taproot verdicts.
- **Stack operand encoding** — integer pushes use Core `CScriptNum`
  serialization (minimal little-endian, sign bit in the high bit).

`results/c-l.jsonl` records the resulting `script_sig_hex`,
`script_pubkey_hex`, `witness_hex`, `flags`, `amount`, and `tape_sha256` for
every row, so a tape can be rebuilt without trusting the harness's prose.

## L join and trust boundary

`tierC.l2r` has no source-index column. The harness joins it by the ordinal
id it expects (`sc-NNNN` over the case-like row order) **and** verifies that
the file's `want` equals the vector's `expected` under the single `NULLFAIL`
alias. A row that fails either check is not joined and stays blocked; it is
never guessed.

The join result (1258 joined, 1258 id matches, 1258 `want` matches) is stored
under `lean_model` in `results/summary.json`.

## Outputs

| File | Contents |
|---|---|
| `results/c-l.jsonl` | One JSON record per case-like row (1258 lines), including skips and blocked rows |
| `results/summary.json` | Totals, per-family tallies, leg metadata, pins, determinism |
| `results/summary.md` | Human-readable version of the same |
| `results/disagreements.md` | Every disagreement, plus the explicit blocked-row lists |
| `results/stderr.log` | Raw fd-2 output captured for the whole run (0 bytes in the recorded run) |
| `results/LEG-IDENTITY.md` | Short warning about the `L` vs `L_twin` labels |

Each record contains:

- `row_id`, `family` (first family), `families`, `source_index`, `row_sha256`;
- `C` = `{result, kind, name, bool}`;
- `L` = Lean-model verdict with `leg_identity: lean-model-not-twin`;
- `L_twin` = `{result, kind, name, bool, supported, matches_expected}`;
- `expected` = `{text, name, kind, result, verdict}`;
- `c_vs_expected`, `c_vs_lean_model`, `c_vs_l_twin`, `status`,
  `lean_model_status`, `agree`;
- `domain` (`in` / `out` / `internal`), `skip_reason`, `encode_failed`,
  `c_call_failed`, `twin_call_failed`;
- `R = {status: "blocked", reason: ...}` for every row.

Comparison rules:

- A row agrees only when `(result == 1) == (other_result == 1)` **and** the
  error-kind name matches. Error identity is compared, not just accept/reject.
- C result `2` (bad input / out of contract domain) is **not** a script
  disagreement: it is recorded as `domain: out`, `status: blocked`, with the
  literal reason. C result `3` (internal) is treated the same way.
- L_twin result `3` is the twin's declared "outside subset / unjudged"
  boundary (`twin/README.md`), not a verdict. Such rows are `blocked`, never
  `disagree`.
- A missing or unusable Lean-model verdict (e.g. `U`) is blocked, not a
  disagreement.

## Recorded run

Run on 2026-10-19 from the repository root:

```text
rows=1258
attempted (C)=1258
C vs L_twin:      agree=854  disagree=0  blocked=404 (all twin result 3)
C vs Lean model:  agree=1251 disagree=0  blocked=7 (UNJUDGED witness rows)
C vs expected:    agree=1258 disagree=0
out of domain=0   C internal=0   encode failures=0   call failures=0
R rows blocked=1258
determinism=identical (in-process replay of every tape on both legs)
```

Per-family detail is in `results/summary.md`. During the first pass the twin
(`9d787f1b…`) produced one disagreement, `sc-0365`; that was traced to a
twin `EQUAL` false-encoding bug, fixed in the regenerated twin
(`d560a5f6…`). The current run has no C/L_twin disagreement. The historical
counterexample and resolution are recorded in
`findings/differential/F-DIV-002-twin-equal-false-encoding.md`.

A second consecutive invocation produced byte-identical result files
(`sha256sum results/*` diff was empty), in addition to the in-process replay.

## Reproduce

```sh
cd /home/ubuntu/btc-lean-public

# Full replay (writes results/, captures stderr).
python3 spec/equiv/differential/run.py

# Exit codes:
#   0 = ran, no C/L_twin disagreement and no encode failure
#   1 = a disagreement, out-of-domain row, or encode failure (results still written)
#   2 = a library or pinned input is missing/unloadable

# Out-of-corpus probe for the F-DIV-001 malformed-tail seam.
python3 spec/equiv/differential/probe_fdiv001.py
```

The harness needs the C library at `--core-lib` (default
`/tmp/opencode/cbuild/libequiv-core.so`) and the twin at `--twin-lib` (default
`spec/equiv/twin/build/libtwin.so`). It never writes outside `--out-dir`
(default `results/`).

The recorded run exits `0` (no disagreement, no out-of-domain row, no encode
failure). A disagreement would force exit `1`; it is never silently converted
into a green exit.

## R leg — blocked (domain, not a stub)

The R leg was not run in the recorded differential pass:

- The official clean ABI shim is tracked at `shims/rust/entry.rs`
  (source sha256 `1fd706b8…`), built by `shims/rust/build.sh` with rustc
  1.95.0 to a `.so` sha256 `73e3d2d9…`, and is green in E0. It is **not** a
  stub.
- `differential/run.py` uses a public all-inputs entry; that entry accepts one
  input, `input_index = 0`, `flags = 0`, and returns no typed `ScriptError`.
  Multi-input/flags rows and error-kind parity are therefore blocked by
  `F-HARNESS-002` / `R-GAP-01`.
- The earlier recorded `summary.json`/`summary.md` carry the literal
  `R_BLOCK_REASON` from the pre-clean-shim run. That string is superseded by
  this section and by `differential/results/R-NOTE.md`; the recorded
  C-vs-L rows are unchanged.

Every record therefore has `R.status = "blocked"` with the same literal
reason. No R claim is made anywhere in this directory.

## What this does and does not establish

**Established behaviorally, for these builds and this corpus:**

- the C leg reproduces the corpus's own expected verdict on all 1258 rows,
  including exact error kinds — evidence that the C shim, ABI v2, and the
  tape encoder agree with Core's test oracle;
- the twin agrees with C on all 854 rows where it returns a verdict, and 404
  rows are outside its declared subset;
- the Lean interpreter model agrees with C on 1251 rows, disagrees on none,
  and leaves 7 witness/tapscript rows unjudged.

**Not established:**

- no LLVM IR equivalence, refinement, or compiler-correctness claim;
- no claim that C equals Core outside these 1258 vectors;
- no claim that the twin covers the 404 blocked rows;
- no R evidence;
- no claim about the Lean model at the corpus pin (its verdicts were not
  re-executed in this pass; only the `want`-vs-expected join is verified).

## Findings

- `findings/differential/F-DIV-002-twin-equal-false-encoding.md` — historical
  twin bug: `EQUAL` pushed a one-byte `{0x00}` instead of Core's empty
  `vchFalse`; exposed by `sc-0365`, fixed in the regenerated twin, and
  verified green by the current run.
- `findings/differential/report.md` — full report: method, counts, evidence,
  trust notes, blocked legs.
- `findings/cross/F-DIV-001-eager-parse.md` — pre-existing out-of-corpus
  malformed-tail seam; `probe_fdiv001.py` confirms the C side of it.
- `findings/cross/F-HARNESS-001-lean-verdicts-labelled-L.md` — the label
  defect this harness's dual-lane record answers.
