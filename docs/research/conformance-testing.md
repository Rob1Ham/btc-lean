# Conformance and testing infrastructure

> Research note, 2026-10-16.
> Ground truth cloned: **bitcoin/bitcoin @ `c50817fe2d86076ee71c10f9788c48d44458a263`** (the actual HEAD of the shallow clone at the time; the initial project pin `cce32b16…` had moved. All file/line references below are to this commit.)
> bips repo cloned: **bitcoin/bips @ `927b6de9915c9262615a6399de51b200f81e5aa4`**.

---

## Exec summary (≤15 lines)

1. **Bitcoin Core's conformance corpus is excellent and machine-readable.** `src/test/data/` holds the JSON vectors that matter (1,317 script cases, 255+201 tx valid/invalid, 501 sighash cases, BIP341 wallet vectors, base58/key-io), and the bips repo adds BIP-0340 CSV + BIP-0341 wallet JSON. These are the L0/L1 backbone — VERIFIED by direct inspection.
2. **Lean 4 core ships a real JSON parser** (`Lean.Json.parse`, `getArr?`, `getObjVal?`, `getStr?`) — VERIFIED: a 40-line `lake exe` runner ingested all 255 tx_valid entries + all 1,318 script_tests lines in **0.03 s** compiled. No external dependency needed for vector I/O.
3. **`decide` does not scale to real conformance workloads** (recursion-depth blowout at n=10⁵ in a trivial loop probe) but is fine for small compiled-in examples; **`native_decide` is fast (10⁷ ops in ~1.5 s) but adds the `native_decide.ax` axiom**. Recommendation: kernel-checked `decide` codegen for a curated subset; `lake exe` runner (compiled, axiom-free) for the full corpus in CI.
4. **Codegen is viable but must be rationed**: ~15 ms per trivial `decide`-example; 2,000 examples ≈ 31 s wall (parallelizes to ~50 s user across cores). Budget: keep ≤ ~1–2 k compiled-in vector theorems, in a leaf module so CI rebuilds stay incremental.
5. **The harness should be a `lake exe` conformance runner** reading Core's JSON directly from a vendored copy, emitting a machine-readable (JSON) results file per layer — not unit-test-in-source. Source vectors in-tree so CI is hermetic.
6. **L2 differential testing needs no Core changes**: `bitcoind -regtest` + `testmempoolaccept`/`submitblock` RPC already returns consensus verdicts and Core's reject-reason strings (`bad-txns-*`, `mandatory-script-verify-flag-failed`, …); a ~200-line Python RPC wrapper suffices.
7. **L3 fuzz-equivalence is feasible but expensive**: Core has 192 `FUZZ_TARGET` harnesses; the consensus-relevant ones (`eval_script`, `script_interpreter`, `script_flags`, `deserialize`, `decode_tx`, `connect_block`, `pow`, `merkle`, `coins_view`, **`utxo_total_supply`**) take raw byte buffers via `FuzzedDataProvider`. The qa-assets corpus (`bitcoin-core/qa-assets`) is the input source. Mitigate by having a Python shim translate buffers → structured JSON so Lean re-parses, rather than reimplementing FuzzedDataProvider.
8. **L4 mainnet replay on a curated anchor slice** (genesis + BIP30-dup blocks 91842/91880 + overflow block 74638 + BIP34/66 activations + SegWit 481824 + Taproot 709632 + halvings) is the right golden-vector set; pin hex + expected verdicts in-repo.
9. **CI**: `leanprover/lean-action@v1` (elan + `lake build` + mathlib cache auto-detect + `.lake` GitHub cache) is the community standard — VERIFIED via action README/mathlib wiki; consensus layers need an extra `bitcoind` service step. Budget: full CI ≈ 10–25 min/job with caching.
10. **Coverage metric**: per-rule (Core inventory–SegWit and Taproot rule-ID) × vector coverage — % of rule rows with ≥1 passing vector at each layer, plus differential-fuzz pass rate. A generated `coverage.json` + a tiny report in CI artifacts. The traceability matrix (the roadmap) is the natural join key.

---

## Key findings (with citations)

- **`Lean.Json.parse : String → Except String Json`** exists in Lean 4 core (probed, `probes1.lean`); accessors `getArr? : Json → Except String (Array Json)`, `getObjVal?`, `getStr?`. Note: array access is `getArr?` (the old `getArr!` no longer exists at 4.34.1) — [probe output, Appendix B].
- **Vector corpora in Core** (counts VERIFIED by parsing): `tx_valid.json` 255 cases; `tx_invalid.json` 201; `script_tests.json` 1,317 vector entries (+1 format-descriptor); `sighash.json` 501; `base58_encode_decode.json` 21; `key_io_valid/invalid.json` 70/70; `blockfilters.json` 11 groups; `bip341_wallet_vectors.json` (keyPathSpending + scriptPubKey sections). These live in `src/test/data/` and are embedded into unit tests via `read_json` (`src/test/transaction_tests.cpp:170`, `src/test/script_tests.cpp`).
- **Unit tests with data tables** (not JSON, but rule-encoding): `transaction_tests.cpp` (16 test cases incl. tx_no_inputs, tx_oversized — size/weight limits), `script_p2sh_tests.cpp`, `script_segwit_tests.cpp`, `scriptnum_tests.cpp` (BIP62 minimal-push number encoding), `pow_tests.cpp` (difficulty arithmetic), `merkle_tests.cpp`, `coins_tests.cpp`, `key_tests.cpp`, `hash_tests.cpp`, `serialize_tests.cpp`. Several are *tables of programmatic cases* — these must be transcribed, not parsed.
- **Functional tests encoding consensus** (grep-VERIFIED): `feature_block.py` (the deepest: BIP30/34/50 replay, invalid blocks), `feature_bip68_sequence.py`, `feature_taproot.py`, `p2p_segwit.py`, `mempool_accept.py` (uses `testmempoolaccept`), `p2p_invalid_tx.py`, `p2p_invalid_block.py`. The rest of the ~294 files are p2p/wallet/policy/rpc — out of conformance scope, but the framework (`test/functional/test_framework/`) is reusable for our L2 harness.
- **Fuzz surface**: 192 `FUZZ_TARGET` declarations across 138 harness files (VERIFIED by grep). Consensus-critical invariants embedded in them: `utxo_total_supply.cpp` (money-supply ≤ 21 M — directly matches our theorem portfolio), `connect_block.cpp` (block connects without crash/invariant), `eval_script.cpp` (script evals for both SigVersions without UB), `pow.cpp`, `merkle.cpp`. Corpus: external repo `bitcoin-core/qa-assets` (referenced by `test/fuzz/test_runner.py` which runs targets over a corpus dir).
- **bips vectors** (VERIFIED present): `bip-0340/test-vectors.csv` (20 rows: Schnorr sign/verify/fail), `bip-0341/wallet-test-vectors.json`, BIP-0143/BIP-0342 vectors are inline in the `.mediawiki` (need extraction), BIP-0322 (generic SPK sigs) has JSON vectors, BIP-0118/0352/0374 etc. for later forks.
- **`decide` vs `native_decide`** (probed): `decide` on a 10⁴-iteration Nat loop: 0.53 s, **axiom-free**; at 10⁵ iterations it hits `maximum recursion depth` even with `set_option maxRecDepth 100000`. `native_decide` on the same at 10⁷: 1.5 s, `#print axioms` shows `[heavy._native.native_decide.ax_1_1]`. **`decide` = kernel-trusted, slow, depth-limited; `native_decide` = compiled C, one axiom, fast.** Compiled `lake exe` evaluation: axiom-free (it's just running the definition) but result is not a theorem.
- **Compiled-vector extraction speed**: the probe runner parsed + walked 224 KB of script_tests JSON in 0.03 s — JSON I/O is a non-issue; the cost center is crypto (SHA-256/secp256k1) inside the spec, which is crypto tower's problem.

---

## Detailed analysis

### (a) Test-vector source inventory

See **Appendix B** for the full table. Structure of the key formats:

- **tx_valid/tx_invalid.json**: array of entries; each is either a comment string, or `[ [ [prevoutHash, prevoutN, prevoutScriptPubKey, amount?], … ], rawTxHex, flags ]`. The harness must synthesize the prevout map exactly like `transaction_tests.cpp:163-252` does. Flags are scriptVerify flag names (`P2SH`, `WITNESS`, `TAPROOT`, …) — need a flag-name→Lean-bitmask decoder mirroring Core's `mapFlagNames`.
- **script_tests.json**: `[format?]`, then `[ [witness…]?, amount?, scriptSigHex, scriptPubKeyHex, flags, expected_scriptError, …comments ]`. `expected_scriptError` strings (`OK`, `EVAL_FALSE`, `SCRIPT_ERR_*`) are the **error-code vocabulary** our L1 compare semantics should reuse (see (c) compare semantics).
- **sighash.json**: 501 cases of (txHex, scriptCode, value, hashType, sigVersion, expectedSigHash) — perfect for L0-level hashing conformance of BIP143/BIP341.
- **bip341_wallet_vectors.json**: keyed by `scriptPubKey` / `keyPathSpending` — input construction + sighash midstates for Taproot.
- **bip-0340/test-vectors.csv**: 20 rows: index, seckey, pubkey, aux, msg, sig, result, comment — directly drives a BIP340 `decide`-runner.
- **What is NOT in JSON and must be transcribed/generated**: scriptnum edge cases, `CheckTransaction`/`CheckBlock` size limits (tx_oversized tests), PoW retarget arithmetic (`pow_tests.cpp`), merkle edge cases (`merkle_tests.cpp`), activation-state machine transitions (no vectors exist anywhere for BIP9 timeouts — L2/L4 only).

**Mainnet anchor curation (PROPOSED)** — pin a directory `vectors/mainnet/<height>.(hex|json)` with block hex + expected acceptance + per-tx verdicts, all fetched via one script (`contrib/` of our repo) against any synced node so results are reproducible:
| Height | Why |
|---|---|
| 0 | genesis (state root, subsidy, no txs) |
| 1 | first spend of coinbase, first fee |
| 74,638 | 184.467B-BTC value overflow (CVE-2010-5139) — output-value arithmetic edge |
| 91,842 / 91,880 | BIP30 duplicate-coinbase blocks — `CCoinsView` uniqueness rule |
| 173,805 | BIP16 P2SH activation |
| 210,000 | first halving — subsidy arithmetic |
| 227,931 | BIP34 activation — coinbase height-in-script rule |
| 322,56→? | (optional) earliest non-trivial retargets for PoW chain verification |
| 363,725 | BIP66 activation (DER sigs) |
| 419,328 | BIP112/CSV activation |
| 481,824 | SegWit activation — first witness txs & first block with witness commitment |
| 709,632 | Taproot activation — first keypath spends |
| 840,000 | fourth halving + a modern block (taproot-heavy, large witness) |

Sizes: the 74xxx–227931 blocks are ~1–250 KB; total anchor slice well under 10 MB. Fine to vendor.

### (b) The execution story in Lean 4 (probed)

| Route | Mechanism | Trust | Speed | Verdict |
|---|---|---|---|---|
| 1. `#eval` / `decide` in source | kernel-checked | axiom-free | slow beyond ~10⁴-ops (probe: recursion-depth failure at 10⁵) | for small, *proved* conformance theorems |
| 2. `native_decide` | compiled + axiomatized comparison | adds `native_decide.ax` axiom | 10⁷ ops ≈ 1.5 s (probe) | good for crypto-vector conformance (BIP340, SHA-256) where the *expected* value is ground truth anyway |
| 3. `lake exe` runner | compiled binary, `IO.FS.readFile` + `Lean.Json` | axiom-free (no theorem, a test) | 0.03 s for 1.3 k vectors (probe) | **primary harness** |
| 4. codegen → `decide` | python emits `example : spec(input) = expected := by decide` | kernel-checked | ~15 ms/example, 2 k examples ≈ 31 s wall (probe; parallelizes) | cap at curated subset in a leaf module |

JSON in core Lean: VERIFIED (`Lean.Json.parse`, `getArr?`, `getObjVal?`, `getStr?`; `Except`-monad error handling; array iteration with `for x in arr`). Caveat found while probing: `Except`-vs-`Option` monad mixing in `do` blocks needs explicit `.toOption`/`match` plumbing — write small helper combinators once.

`decide` vs `native_decide` in CI — the tradeoff (trust accounting will care):
- The vector's expected value comes from Core, which is ground truth *by assumption*. `decide` proving `spec(input) = CoreExpected` inside the kernel adds essentially no trust gain over a compiled check — the *input/output pair* is the trusted artifact either way. What `decide` buys: the theorem lives in the environment, `#print axioms` stays clean, and it can be referenced by later proofs (e.g., "this script does not overflow the stack").
- Recommendation: **CI runs the `lake exe` runner over the full corpus (fast, no axioms) AND compiles a codegen'd subset (≤2 k cases) as `decide` theorems in a `Conformance/Compiled.lean` leaf module**. `native_decide` reserved for the crypto tower (crypto tower) where kernel-evaluating SHA-256/secp is impractical; its axiom is pre-approved in the trust accounting budget.

### (c) The layered conformance harness (DESIGN)

```
vectors/                     # vendored, pinned-by-hash copies
  core/                      # src/test/data/*.json at pinned Core commit
  bips/                      # bip-0340 csv, bip-0341 json
  mainnet/                   # curated anchor blocks (see (a))
  fuzz/                      # qa-assets slice for L3
Conformance/
  Flags.lean                 # scriptVerify flag-name ↔ bitmask
  Error.lean                 # ScriptError enum = Core's SCRIPT_ERR vocabulary
  Runner.lean                # lake exe: read JSON → run spec → emit results.json
  Compiled.lean              # codegen'd decide-theorems (leaf, incremental-friendly)
scripts/
  codegen.py                 # JSON → Lean source
  anchors.py                 # fetch/refresh mainnet anchors via RPC
  diff_test.py               # L2: regtest bitcoind wrapper + diff
  report.py                  # results.json → coverage.json → dashboard
```

**L0 — pure-function unit vectors.** sha256/ripemd160/base58/sighash/scriptnum/flag decoding. Inputs: Core JSON + BIP CSV. Output: per-case `pass/fail` + compiled `decide` subset. Compare: **exact equality of output bytes/int** (hashes: 64-hex equality; scriptnum: int equality). Failure triage: case id → minimal hex reproduction → `#eval` single case.

**L1 — tx/block validation vectors.** tx_valid (255) + tx_invalid (201) + script_tests (1,317) + sighash (501). Input: full JSON as Core's unit tests consume it (harness must rebuild Core's prevout-map logic). Output: `(accept?, Option ScriptError)` per case. **Compare semantics: acceptance bit must match exactly AND, on Core's error vocabulary, error code equality is the goal — but staged:** phase 1 compare accept-bit only (binary); phase 2 require error-code equality (`EVAL_FALSE` vs `UNKNOWN_ERROR` etc.) since script_tests.json encodes the expected error string. For tx_valid/invalid there is no error code in the JSON — accept-bit only. Block-level: `feature_block.py` cases transcribed into JSON by us (BIP30 dups, BIP34 coinbase) — PROPOSED "core-derived, self-authored" vectors with Core-commit citations in each file header.

**L2 — differential testing vs real `bitcoind -regtest`.** PROPOSED protocol:
1. Wrapper starts `bitcoind -regtest` (or `bitcoind -chain=regtest` with `-testnet` kernel), mines ≥110 blocks (`generatetoaddress`).
2. Generator (Python) emits a structured "scenario" (JSON: UTXO set delta + candidate tx/block hex). The *same* JSON is consumed by the Lean runner — this is the **shared input format**, so both sides see identical state + candidate.
3. Core verdict via `testmempoolaccept` (returns `allowed` + `reject-reason` strings like `bad-txns-inputs-missingorspent`, `bad-txns-fee-exceeds-max`, `mandatory-script-verify-flag-failed (…)`); block verdicts via `submitblock` (returns `duplicate`, `invalid`, `bad-*` strings) — no Core patch needed.
4. Diff: accept-bit must match; reject-reason string is *mapped to rule ID* (Core inventory's rule database) and compared, with a documented allow-list of reason strings that are policy-not-consensus (excluded).
5. Generator corpus: mutations of valid spends (bad amounts, bad scriptsigs, witness malleation, sighash-type fuzzing, weight-boundary) — seeded, so failures reproduce.
Caveat to document: `testmempoolaccept` applies *policy* too; to isolate consensus use `-acceptnonstdtxn=1` on regtest and keep scenarios standard-shaped, or diff against `submitblock` which is consensus-only.

**L3 — fuzz-equivalence.** Core harnesses (`FUZZ_TARGET`) take a raw byte buffer; invariants are "no crash + assert X" (`utxo_total_supply.cpp`: total supply invariant; `deserialize`: every buffer parses or fails cleanly). Feasibility: run qa-assets corpus slice → for consensus-relevant targets, a Python shim decodes FuzzedDataProvider consumption order (VERIFIED in `FuzzedDataProvider.h`: integral-from-front/bytes-from-back — 30 lines to emulate) into structured JSON for the Lean runner; verdict = (crashes?, invariant holds?) both sides. Effort: one shim per *consumption convention*, not per target (~4 conventions cover most). Status: feasible, defer until L0–L2 green; highest-value targets first: `deserialize`, `decode_tx`, `eval_script`, `script_interpreter`, `utxo_total_supply`, `connect_block`, `pow`.

**L4 — mainnet replay on curated slice.** Input: `vectors/mainnet/<height>.hex` + prev-block UTXO snapshot (for ≥ block 1 anchors, ship a minimal `utxos.json` for each anchor's parents; genesis needs none). Runner builds state by *streaming* from height 0 for anchors ≤ 227931 (cheap: few hundred blocks) — actually blocks 0–1 only for the early anchors; for 481824/709632 ship a 40–80 MB UTXO snapshot JSON extracted once by `anchors.py` via `gettxoutsetinfo` + `scantxoutset`-style export, or replay-chain-from-0 with a fast compiled SHA-256. Compare: per-block accept-bit + block hash equality + per-tx accept; on failure, dump first divergent tx + rule mapping. Budget: compiled Lean with fast SHA-256 should target ≥ 5 k blocks/min for early-era blocks; measure when crypto tower lands crypto.

### (d) CI design (GitHub Actions)

Community-standard skeleton (VERIFIED: `leanprover/lean-action@v1` README + mathlib4 wiki + LeanProject's build-project.yml):

```yaml
name: ci
on: {push: {branches: [main]}, pull_request: {}}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: leanprover/lean-action@v1          # elan, lake build, mathlib cache auto-detect
        with: {build-args: "--wfail", test: true}
      - run: lake exe btc-lean-conformance --layers L0,L1 --junit junit.xml
      - uses: actions/upload-artifact@v4
        with: {name: conformance-report, path: out/}
  axioms:                                        # trust accounting's budget audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: leanprover/lean-action@v1
      - run: lake exe axiom-audit                 # #print axioms on every public theorem; fail on un-budgeted axioms
  differential:                                  # nightly, needs bitcoind
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |   # pinned Core binary (release download, no compile)
          wget https://bitcoincore.org/bin/bitcoin-core-XX/bitcoin-XX-x86_64-linux-gnu.tar.gz && tar xf …
      - run: python3 scripts/diff_test.py --seed 2026 --cases 2000
  replay:                                        # weekly: L4 anchors
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps: [- checkout, leanprover/lean-action@v1, - run: lake exe btc-lean-conformance --layers L4]
```

Notes: (1) `.lake` caching is built into lean-action (`actions/cache` under the hood); for mathlib use its `use-mathlib-cache: auto` — never commit `.lake`. (2) `lake exe cache get` only caches *upstream* (mathlib) oleans, not our build. (3) `LEAN_NUM_THREADS` cap needed if we ever hit the GitHub-hosted-runner memory ceiling with mathlib (documented in lean-action README). (4) codegen'd `Compiled.lean` lives in a leaf module so `lake build` stays incremental; gate the codegen step with a drift check (`scripts/codegen.py --check`). (5) Toolchain pinned by `lean-toolchain` = hermetic.

### (e) Measurement / coverage metric

- **Rule coverage** = for each Core inventory–SegWit and Taproot rule-ID row (the traceability matrix from the roadmap), boolean flags `covered@L0`, `covered@L1`, `covered@L2`, `covered@L4` — a rule counts covered at layer X if ≥1 passing vector at that layer exercises it. Join key: vector JSON gains a `"rules": ["R-TX-012", …]` field (self-authored for our vectors; inferred for Core's via rule-ID DB).
- **Headline metrics**: (1) `% rules with ≥1 passing vector` (target trajectory: L0 100% by M2, L1 100% by M3, L2 ≥80% by M4, L4 100% of anchors by M2); (2) differential-fuzz pass rate = passing inputs / total corpus inputs per target (target ≥ 99.9% before calling a module conformant); (3) vector totals executed per CI run.
- **Dashboard (PROPOSED)**: `scripts/report.py` merges per-layer `results.json` + rule DB → `coverage.json` → a single static `index.html` (bar chart per layer, table per rule, last-run timestamps) uploaded as CI artifact + a `COVERAGE.md` badge table in-repo generated on the same run. No infra beyond artifacts.

---

## Implications for other areas

- **the Core inventory**: the rule-ID database must be born with reject-reason strings attached (L2 needs `bad-txns-*` → rule-ID mapping; this is the join).
- **the interpreter**: `script_tests.json`'s expected-error vocabulary should define our `ScriptError` enum names verbatim — decide this *once*, early.
- **the model architecture**: the spec's module boundary must expose (a) a pure `validateTx(ctx, tx, flags) : Option ScriptError` and (b) a pure `connectBlock(state, block)` — the harness drives *only* these two entry points; keep everything else internal.
- **the crypto layer**: conformance will consume crypto tower's SHA-256/ECDSA/Schnorr; the L0/BIP-0340 CSV runner is crypto tower's acceptance test. Perf of compiled crypto directly gates L4 scope.
- **trust accounting**: `native_decide` axiom usage confirmed as a real, countable cost (probe shows the exact axiom name); the budget table should include a "conformance-compiled subset = decide (0 axioms) / native_decide (n axioms)" line.
- **the roadmap**: vector-rule tagging adds a column to the traceability matrix; make it required from row one.

## Open questions & risks

1. **UTXO snapshot weight for L4** (replay-from-genesis vs snapshot import) depends on compiled SHA-256 throughput — unmeasured until crypto tower lands. Risk: medium. Fallback: anchor-era replay only (pre-2015 blocks are cheap).
2. **`testmempoolaccept` policy bleed** in L2 — mitigations above; a Core-side "consensus-only verdict dump" would be cleaner but is an upstream PR (out of scope; note as future work).
3. **FuzzedDataProvider emulation drift** (L3): if our shim's consumption order diverges from Core's, we compare different inputs. Mitigation: port the header literally; add a few hand-checked vectors per convention.
4. **script_tests.json growth**: Core adds vectors over time; pinning by commit + a refresh script keeps deltas reviewable.
5. **BIP342 has no standalone JSON** — vectors are inline mediawiki + BIP340 CSV; extraction script needed (small, one-off).
6. **`decide` recursion limits** on deep recursion (probe): any codegen'd theorem whose evaluation recurses >~10⁴ deep needs restructuring (tail-accumulating defs) — a coding guideline for the spec, not just the harness.
7. qa-assets corpus size (~GBs) — use a committed slice with per-target caps (e.g. 1 k inputs/target), full corpus only in nightly.

## Recommendations (priority order)

1. **Build the `lake exe` conformance runner first** (L0+L1): it's ~300 lines given the verified JSON path, unblocks everything, and gives CI signal from week one.
2. **Vendor `src/test/data/*.json` + BIP CSVs at pinned hashes** with a manifest (`vectors/MANIFEST.sha256`).
3. **Define `ScriptError` + flag names to match Core's vocabulary verbatim** (the interpreter and architecture alignment).
4. **Codegen a curated ≤2 k-case `decide` subset** in a leaf module for the "kernel-checked conformance" claim; keep the rest runner-only.
5. **L2 wrapper second** (~200 lines Python against `testmempoolaccept`/`submitblock`); start the rule-ID ↔ reject-reason mapping table with Core inventory immediately.
6. **Curate mainnet anchors** via `anchors.py` early — the data is the long-lead item, not the code.
7. **Defer L3** until L0–L2 are green; then `deserialize`/`decode_tx`/`utxo_total_supply` first.
8. **Adopt `leanprover/lean-action@v1`** + nightly differential + weekly replay jobs as sketched; add axiom-audit from trust accounting as a required check.

---

## Appendix A — Sources

VERIFIED (cloned/probed in this session):
- bitcoin/bitcoin @ `c50817fe2d86076ee71c10f9788c48d44458a263`
  - `src/test/data/` (all JSON corpora, counts parsed), `src/test/transaction_tests.cpp` (tx_valid/invalid JSON format, lines ~163–252), `src/test/script_tests.cpp` (`DoTest`, error vocabulary), `src/test/fuzz/*` (192 FUZZ_TARGETs; `deserialize.cpp`, `eval_script.cpp`, `connect_block.cpp`, `utxo_total_supply.cpp`), `test/fuzz/test_runner.py` (corpus-dir runner), `test/functional/` (294 files; consensus subset grep-verified), `test/functional/data/mainnet_alt.json` (header timestamps for assumeutxo alt-chain), `test/functional/data/invalid_txs.py`.
- bitcoin/bips @ `927b6de9915c9262615a6399de51b200f81e5aa4`
  - `bip-0340/test-vectors.csv` (20 rows), `bip-0341/wallet-test-vectors.json`, `bip-0143.mediawiki` (inline vectors), `bip-0322/*-test-vectors.json`.
- Toolchain: Lean 4.34.1, Lake 5.0.0 (installed).
- Web: leanprover/lean-action README (v1, inputs incl. `use-mathlib-cache`, `use-github-cache`, `LEAN_NUM_THREADS` note), mathlib4 wiki "Using mathlib4 as a dependency" (`lake exe cache get` semantics), leanprover-community/LeanProject `build-project.yml` (production CI example).

PROPOSED (not yet built): everything in (c) L2–L4 protocol details, anchor curation list, coverage dashboard, CI yml beyond the lean-action skeleton, rule-ID↔reject-reason mapping.

## Appendix B — Test-vector inventory table

| File (Core @ c50817f) | What it tests | Format | Count | Usability for Lean conformance |
|---|---|---|---|---|
| `src/test/data/tx_valid.json` | full tx acceptance (stateless + contextual, all flag combos) | JSON: comment / [prevouts], txHex, flags | 255 cases | **Excellent** — L1 backbone; prevout-map rebuild needed |
| `src/test/data/tx_invalid.json` | tx rejection w/ expected nothing (accept-bit only) | same | 201 | **Excellent** — L1; no error codes in JSON |
| `src/test/data/script_tests.json` | script interpreter: per-script pass/fail + expected error | JSON: [witness]?, amount?, sigHex, spkHex, flags, SCRIPT_ERR | 1,317 | **Excellent** — L1; error vocabulary defines our `ScriptError` |
| `src/test/data/sighash.json` | legacy/witness/taproot sighash computation | JSON: txHex, scriptCode, value, hashType, sigVersion, sigHash | 501 | **Excellent** — L0 hash conformance (BIP143/341) |
| `src/test/data/bip341_wallet_vectors.json` | BIP341 input construction + sighash midstates | JSON (scriptPubKey/keyPathSpending sections) | ~dozens | **Good** — L0 Taproot |
| `src/test/data/base58_encode_decode.json` | base58 encoding | JSON pairs | 21 | Good — L0 |
| `src/test/data/key_io_valid.json` / `key_io_invalid.json` | address/key serialization (bech32/base58 checksums, networks) | JSON | 70 / 70 | Good — L0 (encoding layer, partially out of consensus core) |
| `src/test/data/blockfilters.json` | compact block filters (BIP158) | JSON, 11 groups | 11 groups | Marginal (blockfilters out of v1 core consensus) |
| `src/test/transaction_tests.cpp` | size/weight limits, oversize, no-inputs, big witness | C++ programmatic tables | ~16 cases | Transcribe — some encode rules with **no JSON vectors anywhere** |
| `src/test/scriptnum_tests.cpp` | CScriptNum arithmetic/minimal encoding (BIP62) | C++ table | ~100+ | Transcribe (L0) |
| `src/test/pow_tests.cpp` | difficulty retarget arithmetic | C++ programmatic | ~10 | Transcribe (L1 block layer) |
| `src/test/merkle_tests.cpp` | merkle root computation/duplication rules | C++ programmatic | ~20 | Transcribe |
| `src/test/coins_tests.cpp` | CCoinsView/overlay/cache semantics | C++ (invariant tests) | many | Design reference for model architecture's UTXO model, not vectors |
| `test/functional/feature_block.py` | BIP30/34/50, invalid blocks, chain reorg acceptance | Python builds raw blocks | ~40 scenarios | **Gold for L1-block/L4** — transcribe scenario JSON |
| `test/functional/feature_taproot.py`, `feature_bip68_sequence.py`, `p2p_segwit.py` | consensus features end-to-end | Python/RPC | many | L2 scenario inspiration; framework reusable |
| `test/functional/data/mainnet_alt.json` | mainnet header timestamps (assumeutxo alt data) | JSON | 2000 entries | Marginal — header-chain spot data |
| `test/fuzz/*` (192 FUZZ_TARGETs) | deserialize/decode_tx/eval_script/script_interpreter/script_flags/connect_block/pow/merkle/coins_view/utxo_total_supply | raw byte buffers | corpus in qa-assets (external) | L3 via FuzzedDataProvider shim |
| `bips/bip-0340/test-vectors.csv` | Schnorr sign/verify/fail | CSV | 20 rows | **Excellent** — L0 (crypto tower acceptance test) |
| `bips/bip-0341/wallet-test-vectors.json` | Taproot construction/sighash | JSON | ~20 | Good — L0 |
| `bips/bip-0143.mediawiki` (inline) | BIP143 sighash examples | mediawiki text | ~4 examples | Good — needs extraction |
| `bips/bip-0342.mediawiki` (inline) | Tapscript script/sighash edge cases | mediawiki text | ~15 | Good — needs extraction |
| `bips/bip-0322/*-test-vectors.json` | generic signature message hash | JSON | ~20 | Later (BIP322 not v1 consensus) |

### JSON / `decide` probe results (Appendix interpreter)

| Probe | Result |
|---|---|
| `Lean.Json.parse` in core 4.34.1 | ✅ `String → Except String Json` |
| `getArr!` | ❌ gone; `getArr? : Json → Except String (Array Json)` ✅ |
| `getObjVal?` / `getStr?` | ✅ (`Except String _`) |
| Parse+walk tx_valid.json (255 entries), interpreted via `lake exe` | ✅ correct, whole job incl. build 4.1 s; runtime-only ~0.03 s |
| Same for script_tests.json (1,318 entries) | ✅ 0.03 s |
| `decide`, 10⁴-iteration Nat loop | ✅ 0.53 s, axiom-free (`#print axioms` clean) |
| `decide`, 10⁵ iterations | ❌ `maximum recursion depth` (even with `maxRecDepth 100000`) |
| `native_decide`, 10⁷ iterations | ✅ 1.5 s; axiom `…native_decide.ax_1_1` |
| Codegen 200 `decide`-examples | 3.5 s wall (≈15 ms/example) |
| Codegen 2,000 examples | 31 s wall / 50 s user (parallelizes) |
| Gotcha | `Except`↔`Option` monad mixing in `do` needs explicit `.toOption`; `Json` object constructor is `Json.str` etc. |
