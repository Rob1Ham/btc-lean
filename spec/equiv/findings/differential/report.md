# Differential harness report — C vs L (twin), with Lean-model cross-check

- **date:** 2026-10-19
- **owner:** DIFFERENTIAL
- **schema:** `btc-lean/equiv-differential/v1`
- **scope:** `spec/equiv/differential/` (harness + results),
  `spec/equiv/findings/differential/` (this report and F-DIV-002)
- **no commits, no writes outside the two directories above**

## 1. Summary

An independent harness replayed all **1258 case-like rows** of the pinned Core
`script_tests.json` through three verdict sources:

1. the **C leg** (`equiv_entry`, ABI v2, Core shim),
2. the **L leg** — the generated C++ twin `spec/equiv/twin/build/libtwin.so`,
3. the **Lean interpreter model** (`spec/data/l2/scr/results/tierC.l2r`), as
   an oracle cross-check, not as L.

**Current recorded run** is against twin `b9ed129b…` / generated
`39ab7c66…`, after the F-DIV-002 fix and the later flow-op extension:
**C vs L_twin 922 agree / 0 disagree / 336 blocked** (result 3 = outside
subset). The first pass (twin `d560a5f6…`, 854/0/404) is archived under
`differential/results/archive-d560/`; it is the run that exposed F-DIV-002.

Recorded outcome:

| Comparison | Agree | Disagree | Blocked |
|---|---:|---:|---:|
| **C vs L_twin (the L leg)** | **922** | **0** | **336** |
| C vs Lean model (oracle) | 1251 | 0 | 7 |
| C vs corpus expected | 1258 | 0 | 0 |
| R | — | — | 1258 |

- Out of contract domain: **0**
- C internal errors: **0**
- Encode failures: **0**
- C / L_twin call failures: **0**
- Determinism (in-process replay, both legs, every tape): **identical**
- Two consecutive runs: **byte-identical result files**
- Harness exit code: **0** (no disagreement, out-of-domain row, or encode
  failure). A disagreement forces exit `1`; none is suppressed.

**No C-L disagreement remains in the recorded run.** During the first pass
the twin build `9d787f1b…` had exactly one, `sc-0365`: it pushed a one-byte
`{0x00}` instead of Core's empty `vchFalse` for a false `EQUAL`. That was
filed as `F-DIV-002` and has since been fixed in the regenerated twin
`d560a5f6…`; a later regeneration `b9ed129b…` retains the fix, adds flow
support, and is the current recorded run. `sc-0365` agrees in both. The counterexample and resolution are kept
in the finding.

A behavioral agreement here is **evidence about these builds on this corpus,
not an LLVM IR proof**.

## 2. What is compared

### 2.1 Legs and identities

The label defect in `F-HARNESS-001` is addressed by recording both lanes:

| Lane key | Artifact | `leg_identity` | Role |
|---|---|---|---|
| `C` | `/tmp/opencode/cbuild/libequiv-core.so` | — | Core shim |
| `L_twin` | `spec/equiv/twin/build/libtwin.so` | `twin-libtwin` | **L leg** |
| `L` | `spec/data/l2/scr/results/tierC.l2r` | `lean-model-not-twin` | oracle |

Only `C vs L_twin` is called C-L. The Lean-model lane is always named
`C-vs-Lean-model`. The primary `status` / `agree` fields in every JSON record
come from the twin lane.

### 2.2 Pins and hashes

| Artifact | sha256 |
|---|---|
| `spec/data/core/script_tests.json` | `7fb93dea245f68b627d214e0d51969c4f29fefaae1ac94ca1eba5fe8322f864c` |
| `spec/data/l2/scr/results/tierC.l2r` | `88624ebfb4c772be5f353feea4ea3972923e7dcca1ed0cc57805d6361d7df1b6` |
| C leg `libequiv-core.so` | `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5` |
| L twin `libtwin.so` (current) | `b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b` |
| L twin `libtwin.so` (first pass, archived) | `d560a5f69a05179c29851aa80cbea330e976ec455c7e6bca32f0b6dfee223801` |
| Twin generated `twin.cpp` (current) | `39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f` |
| Twin IR metadata `twin.ir.json` (current) | `e5fbe72707a43bfc950ad67e4a86eff3c4c3c4314aa17323c2a23b9f3cfd6413` |
| Contract (`ABI.md`+`tape.md`+`error_kind.h`+`corpus_schema.md`) | `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6` |
| `contract/error_kind.h` | `7a5f778f4aed8947a7768da3d3856c99eec2715f5502cb8f59af576c72dca170` |
| `differential/run.py` | `a3c7d7d1c097819a24dfc6df6a203ac47f677a38f5cf34c7ddc0ababb0d2d09d` |
| `differential/probe_fdiv001.py` | `e49e09fe3df0d09d85e88f139b6f51e2968cbff78b2af652665eb9e12774d890` |
| `results/c-l.jsonl` (current) | `764b3a33a3280c5af428bd834b002e4131b9ca4de70aab845ff87c6d8d2b5f95` |
| `results/summary.json` (current) | `64e4abfbd49574fe6e42b4b1412f049845b547f96184f3252d2117a34e72ea97` |
| `results/summary.md` (current) | `87ba8649a2a0c7bcbfe4d5dda3de3e4350a2aa15d50923547e4cafea6586f22e` |
| `results/disagreements.md` (current) | `2b835433e77e8947b61121ed3583c19fc1014dcf10640d3d7448704f3ce044d7` |
| `results/stderr.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` (0 bytes) |

The harness refuses to run on corpus or verdict-file hash drift and aborts on
selection-field, selection-row-hash, selection-count, or family-count drift.

### 2.3 Corpus coverage

`script_tests.json` has 1258 case-like rows. All are replayed. Only 1456
memberships are present in `corpus/selections/*.jsonl`; 170 rows have no
selection and are labelled `unassigned`. They are not dropped.

| Family | Rows | Twin agree | Twin disagree | Twin blocked | Lean agree | Lean disagree | Lean blocked | C~expected agree |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| stack | 316 | 258 | 0 | 58 | 316 | 0 | 0 | 316 |
| flow | 297 | 271 | 0 | 26 | 297 | 0 | 0 | 297 |
| numeric | 335 | 254 | 0 | 81 | 335 | 0 | 0 | 335 |
| hash | 115 | 55 | 0 | 60 | 115 | 0 | 0 | 115 |
| checksig | 90 | 5 | 0 | 85 | 90 | 0 | 0 | 90 |
| cms | 117 | 1 | 0 | 116 | 117 | 0 | 0 | 117 |
| locktime | 21 | 6 | 0 | 15 | 21 | 0 | 0 | 21 |
| disabled | 24 | 24 | 0 | 0 | 24 | 0 | 0 | 24 |
| witness | 134 | 28 | 0 | 106 | 127 | 0 | 7 | 134 |
| taproot | 7 | 0 | 0 | 7 | 0 | 0 | 7 | 7 |
| unassigned | 170 | 170 | 0 | 0 | 170 | 0 | 0 | 170 |

Family counts overlap (a row can be in several selections). `unassigned`
rows are exactly those with no selection.

## 3. Method

### 3.1 Tape encoding

The harness reimplements the pinned Core test framework directly:

- credit transaction = `BuildCreditingTransaction` (version 1, null prevout,
  `OP_0 OP_0` scriptSig, one output);
- spend transaction = `BuildSpendingTransaction` (version 1, one input at
  vout 0, one empty output, locktime 0), serialized `TX_WITH_WITNESS`;
- `prevout.hash = SHA256d(credit_tx)`;
- witness marker/flag and stack are present iff the witness stack length is
  `> 0` (`CScriptWitness::IsNull() == stack.empty()`);
- `CLEANSTACK ⇒ P2SH|WITNESS`, as `DoTest` does before `VerifyScript`;
- JSON `NULLFAIL` → `SIG_NULLFAIL` (the only alias);
- taproot rows: Core's `#SCRIPT#`/`#CONTROLBLOCK#`/`#TAPROOTOUTPUT#`
  generation with internal key `keys.key0` (private key 1, x-only `G.x`),
  one leaf at depth 0, BIP341 tweak.

Correctness of the encoder is supported, not assumed: the C leg reproduces
the corpus's expected verdict **and exact error kind** on all 1258 rows,
including all seven taproot rows.

### 3.2 Verdict comparison

A row agrees only if the pass/fail boolean matches **and** the error-kind
name matches. Three non-verdict outcomes are separated from disagreement:

- **C result 2** — out of contract domain. `domain: "out"`, `status:
  "blocked"`, literal reason recorded. It is never counted as a script
  disagreement. (Recorded run: 0 rows.)
- **C result 3** — internal error. Same treatment. (0 rows.)
- **L_twin result 3** — twin's declared outside-subset boundary. `status:
  "blocked"`, never `disagree`. (404 rows.)
- **Lean model `U`** — unjudged. `lean_model_status: "blocked"`. (7 rows.)

Rows that fail to encode, fail to call, or fail the L join are also kept as
records with their exact `skip_reason`; none are silently dropped.

### 3.3 Lean-model join

`tierC.l2r` has no source-index column. The harness joins by expected ordinal
id **and** requires the file's `want` to equal the vector's `expected`
(under the single `NULLFAIL` alias). Result:

- 1258/1258 ids present;
- 1258/1258 id matches;
- 1258/1258 `want` matches expected;
- 0 join failures.

The join metadata is in `results/summary.json` under `lean_model`.

**Pin trust note.** `tierC.l2r` was produced with the L2-SCR oracle read at
`c50817fe`, while the vendored corpus is pinned at `cce32b168`. The verdicts
were **not re-executed** in this pass. The `want`-vs-expected check makes the
join safe against row misalignment, but the Lean-model column is only a
trust-the-existing-artifact comparison, and is recorded with that caveat in
`summary.json` (`source_pin_note`).

## 4. Results detail

### 4.1 C vs L_twin disagreements (0 in the recorded run)

The recorded run has no C-vs-L_twin disagreement. `sc-0365` now agrees:

| Leg | Result | Kind |
|---|---|---:|
| expected | pass | `OK` |
| C | pass | `OK` |
| Lean model | pass | `OK` |
| L_twin | pass | `OK` |

**History.** The first pass used twin `9d787f1b…` and found one
disagreement on this row:

```json
["0 0 1", "EQUAL EQUAL", "P2SH,STRICTENC", "OK"]
```

The pre-fix twin returned `EVAL_FALSE` because its generated `op_OP_EQUAL`
pushed one byte `{0x00}` for false, where Core and Lean both push the empty
vector (`vchFalse`). In this script the second `EQUAL` therefore compared
`[]` with `{0x00}` instead of `[]` with `[]`.

This was a **twin generator** bug, not a Lean-model divergence: Lean
`pushBoolV false = vchFalse = ByteArray.empty`, and the Lean model returned
`OK`. It was filed as `F-DIV-002`; the twin generator was corrected
(`uint8_t b = 1u; st_push(..., eq ? 1u : 0u)`), `twin.cpp` was regenerated
(`gen.py --check` passes), and the re-run is green. Full evidence, including
the pre-fix record hash, is in
`findings/differential/F-DIV-002-twin-equal-false-encoding.md`.

No patch was applied by DIFFERENTIAL (outside this role's write scope); the
twin lane owner regenerated the artifact.

### 4.2 Blocked rows (explicit)

- **404 C vs L_twin rows**: twin returned result `3` (outside the declared
  E1 subset). Listed verbatim in `results/disagreements.md`. Main groups:
  signature checking (`CHECKSIG*`, `CHECKMULTISIG*`, CMS), remaining
  locktime (`CLTV`/`CSV`), witness/taproot execution, and some hash/flow
  rows. (The count dropped from 412 in the pre-fix run because the twin
  regeneration also expanded the supported subset.)
- **7 C vs Lean-model rows**: `tierC.l2r` returned `U` (unjudged):
  `sc-1237 … sc-1243` (witness/tapscript).
- **1258 R rows**: R leg blocked (see §5).

None of these is counted as agreement or disagreement.

### 4.3 Out-of-corpus probe (F-DIV-001)

The corpus has no malformed-tail script, so the 1258-row replay cannot
exercise the eager-parse seam. `probe_fdiv001.py` builds the two tapes from
`F-DIV-001` and runs the **C side only**:

| scriptPubKey | C `(result, kind)` |
|---|---|
| `690201` (`OP_VERIFY`, truncated `PUSH2`) | `(0, INVALID_STACK_OPERATION / 18)` |
| `7e0201` (disabled `OP_CAT`, truncated `PUSH2`) | `(0, DISABLED_OPCODE / 17)` |

There is **no L verdict** for these tapes in `tierC.l2r`; F-DIV-001's Lean
side remains a code-reading prediction. The probe does not create a new
finding; it confirms the C reference for the existing one.

## 5. R leg — blocked

The R leg was not run. Evidence:

1. `spec/equiv/shims/rust/entry.rs` is a **STUB**: its `equiv_entry` body
   returns `(3, EQUIV_ERR_UNKNOWN_ERROR)`. Direct call against the built
   stub `/tmp/opencode/shim-build/libequiv_rust.so` (sha256
   `245bcb412f8963093207ea636d6c5a6f3ad8b680ce141da1285badd96dc49018`)
   on a valid `OP_1` tape returns `(3, 1)`.
2. `/tmp/opencode/equiv-work/rbitcoin` at
   `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` is dirty:
   `M crates/rbitcoin-consensus/Cargo.toml`, `M .../src/lib.rs`,
   `A .../src/script/ffi.rs`, `M .../src/script/mod.rs`. This is the
   unregistered FFI patch.
3. `/tmp/opencode/equiv-work/rbitcoin-clean` exists, but there is still no
   clean shim that maps a tape to an rbitcoin verdict.

Every one of the 1258 records carries
`R = {"status": "blocked", "reason": "R leg not run: no clean R shim exists ..."}`.
No R claim is made.

## 6. Reproduction and determinism

From `/home/ubuntu/btc-lean-public`:

```sh
python3 spec/equiv/differential/run.py
python3 spec/equiv/differential/probe_fdiv001.py
```

Recorded stdout tail:

```text
differential: rows=1258 attempted=1258 C~L_twin agree=854 disagree=0 blocked=404 \
(twin unsupported=404); C~lean-model agree=1251 disagree=0 blocked=7; \
C~expected agree=1258 disagree=0; out_of_domain=0; determinism=identical
wrote .../results/c-l.jsonl, summary.json, summary.md, disagreements.md, stderr.log
```

Exit code `0`, stderr file 0 bytes.

Determinism was checked two ways:

1. in-process: every tape is replayed on both legs; all `(result, kind)`
   pairs matched (`determinism: "identical"`);
2. cross-run: `sha256sum results/*` before and after a second full invocation
   diffed empty.

## 7. Limits of this evidence

**Supported by this work:**

- C reproduces Core's own expected verdict and error kind on every one of
  the 1258 case-like vectors — a concrete check of the C shim, ABI v2, and
  tape encoding.
- The generated twin returns a verdict on 854 rows and matches C on all of
  them; 404 rows are outside its declared subset. (The pre-fix twin had one
  disagreement, `sc-0365`, now fixed.)
- The Lean interpreter model matches C on 1251 rows, with no disagreement
  and 7 unjudged rows, subject to the `c50817fe` provenance note.
- No row was silently dropped; every skip, block, and failure is in
  `c-l.jsonl` with a reason.

**Not supported:**

- No LLVM IR equivalence, refinement, or compiler-correctness conclusion.
- No universal C = Lean claim, and no claim outside this corpus.
- No twin coverage claim for the 404 result-3 rows.
- No R evidence of any kind.
- No re-execution of the Lean model at the corpus pin.
- No claim that a green row here closes an E1 cell; cell acceptance remains a
  ledger decision.

## 8. Findings and artifacts

| Artifact | Role |
|---|---|
| `differential/README.md` | method, labels, encoding, reproduce |
| `differential/run.py` | harness |
| `differential/probe_fdiv001.py` | out-of-corpus C-side probe |
| `differential/results/c-l.jsonl` | 1258 per-row records |
| `differential/results/summary.json` | machine-readable totals/metadata |
| `differential/results/summary.md` | human-readable totals |
| `differential/results/disagreements.md` | disagreement + blocked lists |
| `differential/results/stderr.log` | captured fd-2 (empty) |
| `differential/results/LEG-IDENTITY.md` | lane-label warning |
| `findings/differential/F-DIV-002-twin-equal-false-encoding.md` | twin bug |
| `findings/differential/report.md` | this report |

Related, pre-existing findings: `F-HARNESS-001` (lane labelling, addressed
here by dual-lane records), `F-DIV-001` (eager parse, out-of-corpus seam).
