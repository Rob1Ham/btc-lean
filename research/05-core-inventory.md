# 05 — Bitcoin Core consensus-critical source inventory (B1, report ID 05)

> Pinned ground-truth commit: **`cce32b1686874e85e8a00cfa1a2190f0b6f4dcaf66`**
> (merge bitcoin/bitcoin#36379, "fuzz: fix stale comments in http_request").
> Commit date: **2026-10-15 17:15:30 +0900** (`git log -1 --date=iso`).
> Version string: **32.99.0** — `CMakeLists.txt`: `CLIENT_VERSION_MAJOR 32`, `CLIENT_VERSION_MINOR 99`, `CLIENT_VERSION_BUILD 0`.
> Sources: `bitcoin/bitcoin` and `bitcoin/bips`, checked out at the pins below.
> Every `file:line` below is at the pinned commit unless marked **INFERRED**.

---

## Executive summary

- The full acceptance path is a small, traceable spine: **`net_processing.cpp::PeerManagerImpl::ProcessBlock` → `validation.cpp::ChainstateManager::ProcessNewBlock` → `AcceptBlock` → (`CheckBlock`, `ContextualCheckBlock`) → `Chainstate::ActivateBestChain` → `ConnectTip` → `Chainstate::ConnectBlock`**, with per-tx work delegated to `consensus/tx_check.cpp::CheckTransaction`, `consensus/tx_verify.cpp::CheckTxInputs`/`SequenceLocks`/sigop counters, and `script/interpreter.cpp::VerifyScript`/`EvalScript`/`VerifyWitnessProgram`, plus `pow.cpp::CheckProofOfWork` and `consensus/merkle.cpp::BlockMerkleRoot`.
- **Checkpoints are gone.** PR #31649 "consensus: Remove checkpoints (take 2)", merged 2025-03-14 (v30.0); only a hidden `-checkpoints` arg stub remains (`src/init.cpp:666`). The remaining trust shortcuts are **assumevalid** (`ConnectBlock` script-skip, validation.cpp:2345–2382), **nMinimumChainWork** (anti-DoS, validation.cpp:4353), and **assumeutxo** (validation.cpp:5606–6050). None change consensus rules; a spec should document them as out-of-scope trust options.
- The consensus constants inventory is compact: `MAX_MONEY`, `MAX_BLOCK_WEIGHT` 4M, `MAX_BLOCK_SIGOPS_COST` 80k, `COINBASE_MATURITY` 100, `WITNESS_SCALE_FACTOR` 4, `LOCKTIME_THRESHOLD` 500M, `MAX_FUTURE_BLOCK_TIME` 2h, `MAX_TIMEWARP` 600s (BIP94), sequence constants, script limits — all in 5 small headers.
- Consensus vs policy is cleanly stratified in code: consensus lives in `src/consensus/` + `validation.cpp` + `script/interpreter.cpp` + `pow.cpp` + `coins.*`; `src/policy/` (11 modules) is 100% non-consensus. The subtle boundary cases (tx finality is consensus; *when* you check it for mempool is policy; `GetBlockScriptFlags` is consensus; `STANDARD_SCRIPT_VERIFY_FLAGS` is policy) are documented below.
- The CVE→rule map is directly verifiable **in source comments**: CVE-2010-5137 (disabled opcodes, interpreter.cpp:482), CVE-2010-5139 (output value range, tx_check.cpp:31), CVE-2010-5141 (script eval order, interpreter.cpp:2027), CVE-2012-1909/BIP30 (validation.cpp:2396), CVE-2012-2459 (merkle, merkle.cpp:19, validation.cpp:3858), CVE-2018-17144 (duplicate inputs, tx_check.cpp:44), CVE-2017-12842 (65-byte tx relay floor, validation.cpp:809), CVE-2012-3789 (orphan DoS, txorphanage.cpp:350).
- Appendix B contains **176 rule rows** (INV-001…INV-176) covering the whole acceptance path — the seed of the traceability database. Roughly 78% are pure functions of small algebraic types (ideal for Lean); the impurity hotspots are the coins cache, the block index, and the clocks.

---

## Key findings (VERIFIED unless noted)

1. **Acceptance entry chain (net → validation).** `PeerManagerImpl::ProcessBlock` (`net_processing.cpp:3682–3697`) calls `ChainstateManager::ProcessNewBlock` (`validation.cpp:4413–4461`) which runs `CheckBlock` (4431) → `AcceptBlock` (4434) → `ActivateBestChain` (4448). Headers path: `PeerManagerImpl::ProcessHeadersMessage` (`net_processing.cpp:3218`) → `ProcessNewBlockHeaders` (`validation.cpp:4250–4278`) → `AcceptBlockHeader` (`validation.cpp:4194–4247`).
2. **Two-phase block validation.** `CheckBlock` (context-free, validation.cpp:3926–3991) is deliberately re-run inside `ConnectBlock` (validation.cpp:2319) because "if we add a new consensus rule that is enforced in [ContextualCheck*], then we may have let in a block that violates the rule prior to updating the software" — a property our Lean spec can make explicit (monotone re-validation).
3. **Genesis special case in `ConnectBlock`** (validation.cpp:2336–2342): block connection is skipped; the genesis coinbase is unspendable — genesis must be modeled as a distinguished state.
4. **BIP30 is still enforced, conditionally, in 2026 code** (validation.cpp:2391–2475): explicit no-overwrite check unless (a) the two historical exception blocks at heights 91722/91812, or (b) BIP34 hash precondition holds and height < 1,983,702 (`BIP34_IMPLIES_BIP30_LIMIT`, validation.cpp:2429). Any formalization of the UTXO transition must include these carve-outs.
5. **Script flags are a function of (block, chain params, deployments)**: `GetBlockScriptFlags` (validation.cpp:2249–2288) = base {P2SH, WITNESS, TAPROOT} + per-block hash exceptions from `Consensus::Params::script_flag_exceptions` (kernel/chainparams.cpp:105–108, the BIP16 and Taproot exception blocks) + deployment-gated DERSIG/CLTV/CSV/NULLDUMMY.
6. **BIP9 machinery is compact and fully cached**: `ThresholdState` FSM `DEFINED→STARTED→LOCKED_IN→ACTIVE/FAILED` in `versionbits_impl.h:17–23`; state machine `versionbits.cpp:26–117`; deployment params `consensus/params.h:49–83` (period 2016, threshold 1916 default / 1815 testdummy); only `DEPLOYMENT_TESTDUMMY` remains a live BIP9 deployment on mainnet (deploymentinfo.cpp:12–16) — everything else is *buried* (height-hardcoded, `consensus/params.h:26–36`).
7. **Mainnet buried heights** (kernel/chainparams.cpp:114–142): BIP34 227,931 (with `BIP34Hash`), BIP65 388,381, BIP66 363,725, CSV 419,328, SegWit 481,824, MinBIP9WarningHeight 711,648; `nPowTargetTimespan` 14d, `nPowTargetSpacing` 600s, `powLimit` 0x00000000ffff…, `nMinimumChainWork`, `defaultAssumeValid` @966,143.
8. **The 21M cap is not a constant** — it *emerges* from `GetBlockSubsidy` (validation.cpp:1833–1844): `50·COIN >> halvings`, `0` when `halvings ≥ 64` (BIP42). `MAX_MONEY = 21_000_000·COIN` (consensus/amount.h:26) is a sanity bound, explicitly documented as "not the total money supply" (amount.h:17–25).
9. **UTXO model** (`coins.h`): `Coin = {CTxOut out; bool fCoinBase:1; uint32_t nHeight:31}` (coins.h:45–101); spent ⇔ `out.IsNull()` (coins.h:94); height bit-packed `(nHeight<<1)|coinbase` for serialization (coins.h:77). Cache layer `CCoinsViewCache` with DIRTY/FRESH flags (coins.h:120–220), `SpendCoin`/`AddCoin`/`BatchWrite`/`Flush`/`Sync` (coins.cpp:80–330). `MEMPOOL_HEIGHT = 0x7FFFFFFF` sentinel (txmempool.h:51). The old "negative-height coinbase marker" is historical: today coinbase-ness is one explicit bit, and height is 31 bits.
10. **Assumevalid plumbing** is a single decision inside `ConnectBlock` (validation.cpp:2345–2393): a `script_check_reason` string; `nullptr` ⇒ skip per-input script checks but *all other checks still run* (merkle, amounts, sigops, maturity, BIP68). That's the cleanest statement that assumevalid only removes the script-verification sub-check.
11. **CheckProofOfWork** (pow.cpp:140–171) = decode nBits via `DeriveTarget` (146–159: reject negative/zero/overflow/target > powLimit) then `hash ≤ target`. `GetNextWorkRequired`/`CalculateNextWorkRequired` (pow.cpp:14–85) and `PermittedDifficultyTransition` (pow.cpp:89–136) complete the difficulty rules.
12. **Policy inventory** (`src/policy/`): policy.{h,cpp}, feerate, fees (estimator), packages, rbf, ephemeral_policy, truc_policy, settings — none of it is consensus. Inside validation.cpp, the `MemPoolAccept` family (PreChecks :779, ReplacementChecks :981, PackageRBFChecks :1032, PolicyScriptChecks :1129, ConsensusScriptChecks :1152, SubmitPackage :1236) is where consensus checks (ConsensusScriptChecks) are interleaved with policy (PreChecks/PolicyScriptChecks); `AcceptToMemoryPool` (decl validation.h:273) is the entry.
13. **BIPs 341/342/323 note**: Taproot is enforced from the flags constant itself (`GetBlockScriptFlags` always sets TAPROOT post-activation because SegWit is buried ⇒ always active), with one historical exception block hash carrying only P2SH|WITNESS (kernel/chainparams.cpp:107–108).

---

## Detailed analysis

### (a) The acceptance call chain

**INFERRED formatting note**: call edges are VERIFIED by grep across the pinned tree; line numbers are exact.

```
P2P: net_processing.cpp
  PeerManagerImpl::ProcessHeadersMessage            net_processing.cpp:3218
    └─ ChainstateManager::ProcessNewBlockHeaders    validation.cpp:4250
         └─ ChainstateManager::AcceptBlockHeader    validation.cpp:4194
              ├─ CheckBlockHeader (PoW)             validation.cpp:3836
              │    └─ pow.cpp::CheckProofOfWork     pow.cpp:140  → CheckProofOfWorkImpl pow.cpp:161 (DeriveTarget :146)
              ├─ (duplicate / failed-parent checks) validation.cpp:4198–4231
              └─ ContextualCheckBlockHeader         validation.cpp:4088
                   ├─ GetNextWorkRequired           pow.cpp:14 → CalculateNextWorkRequired pow.cpp:50
                   ├─ MTP/timewarp/future-time      validation.cpp:4100–4118
                   └─ version gates (BIP34/66/65)   validation.cpp:4121–4126
  PeerManagerImpl::ProcessBlock                     net_processing.cpp:3682
    └─ ChainstateManager::ProcessNewBlock           validation.cpp:4413
         ├─ CheckBlock                              validation.cpp:3926
         │    ├─ CheckBlockHeader                   validation.cpp:3836
         │    ├─ CheckSignetBlockSolution           signet.cpp (params-gated) validation.cpp:3939
         │    ├─ CheckMerkleRoot                    validation.cpp:3845
         │    │    └─ consensus/merkle.cpp::BlockMerkleRoot → ComputeMerkleRoot  merkle.cpp:76, 51
         │    ├─ size limits / coinbase position    validation.cpp:3955–3963
         │    ├─ CheckTransaction (per tx)          consensus/tx_check.cpp:19   ← CVE-2018-17144 duplicate-input check :49–53
         │    └─ legacy sigop ceiling               validation.cpp:3979–3985
         ├─ ChainstateManager::AcceptBlock          validation.cpp:4306
         │    ├─ AcceptBlockHeader                  validation.cpp:4194
         │    ├─ ContextualCheckBlock               validation.cpp:4137
         │    │    ├─ BIP113 MTP cutoff + IsFinalTx validation.cpp:4141–4157 (IsFinalTx: consensus/tx_verify.cpp:23)
         │    │    ├─ BIP34 coinbase height         validation.cpp:4159–4167
         │    │    ├─ CheckWitnessMalleation        validation.cpp:3878 (witness commitment, reserved value)
         │    │    └─ block weight ≤ 4M             validation.cpp:4187
         │    └─ WriteBlock / ReceivedBlockTransactions  node/blockstorage, validation.cpp:4373–4387
         └─ Chainstate::ActivateBestChain           validation.cpp:3331
              └─ ActivateBestChainStep              validation.cpp:3199
                   ├─ (reorg side: DisconnectTip :2936 → DisconnectBlock :2178 → ApplyTxInUndo :2148)
                   └─ ConnectTip                    validation.cpp:3012
                        └─ Chainstate::ConnectBlock validation.cpp:2294
                             ├─ CheckBlock (again)            validation.cpp:2319
                             ├─ BIP30 no-overwrite            validation.cpp:2401–2475 (IsBIP30Repeat :6207)
                             ├─ BIP68 flag gate               validation.cpp:2477–2481
                             ├─ GetBlockScriptFlags           validation.cpp:2249
                             ├─ per-tx loop                   validation.cpp:2522–2599
                             │    ├─ Consensus::CheckTxInputs consensus/tx_verify.cpp:170
                             │    │    ├─ HaveInputs          coins.cpp:322
                             │    │    ├─ coinbase maturity   consensus/tx_verify.cpp:185
                             │    │    ├─ MoneyRange in/sum   consensus/tx_verify.cpp:190–194
                             │    │    └─ in ≥ out, fee range consensus/tx_verify.cpp:201–216
                             │    ├─ SequenceLocks (BIP68)    consensus/tx_verify.cpp:113 → CalculateSequenceLocks :45 → EvaluateSequenceLocks :103
                             │    ├─ GetTransactionSigOpCost  consensus/tx_verify.cpp:149 (MAX_BLOCK_SIGOPS_COST check :2567)
                             │    ├─ CheckInputScripts        validation.cpp:2060 → CScriptCheck validation.cpp:2013
                             │    │    └─ script/interpreter.cpp::VerifyScript :2012
                             │    │         ├─ EvalScript (legacy) :417 (legacy wrapper :1251)
                             │    │         ├─ VerifyWitnessProgram :1927 → ExecuteWitnessScript :1842 (v0 P2WPKH/P2WSH)
                             │    │         │                                → VerifyTaprootCommitment :1913 (v1, BIP341/342)
                             │    │         └─ EvalChecksig family :331/357/402
                             │    └─ UpdateCoins              validation.cpp:1998 → coins.cpp::AddCoins :133 / SpendCoin :144
                             ├─ script checks complete (parallel CCheckQueue) validation.cpp:2613–2618
                             ├─ coinbase value ≤ subsidy+fees validation.cpp:2608–2612 (GetBlockSubsidy :1833)
                             └─ WriteBlockUndo / SetBestBlock validation.cpp:2635–2652
Mempool path (policy interleaving, for the boundary map):
  ChainstateManager::ProcessTransaction             validation.cpp:4463
    └─ AcceptToMemoryPool                           validation.h:273
         └─ MemPoolAccept::AcceptSingleTransactionInternal :591
              ├─ PreChecks               :779   (policy + calls CheckTransaction, CheckTxInputs)
              ├─ ReplacementChecks       :981   (RBF policy)
              ├─ PolicyScriptChecks      :1129  (STANDARD_SCRIPT_VERIFY_FLAGS)
              ├─ ConsensusScriptChecks   :1152  (block-equivalent flags)
              └─ SubmitPackage           :1236
```

### (b) Consensus constants inventory

| Name | Value | file:line | Origin / why |
|---|---|---|---|
| `MAX_BLOCK_SERIALIZED_SIZE` | 4,000,000 B | consensus/consensus.h:13 | Buffer limit (SegWit era); not directly a validity check (weight is) |
| `MAX_BLOCK_WEIGHT` | 4,000,000 WU | consensus/consensus.h:15 | BIP141; preserves ~1MB-block DoS economics |
| `MAX_BLOCK_SIGOPS_COST` | 80,000 | consensus/consensus.h:17 | BIP141 sigop cost limit (legacy rule ×4) |
| `COINBASE_MATURITY` | 100 | consensus/consensus.h:19 | Original Satoshi anti-rollover/protection rule |
| `WITNESS_SCALE_FACTOR` | 4 | consensus/consensus.h:21 | BIP141 weight = base·3 + total |
| `MIN_TRANSACTION_WEIGHT` | 240 WU (60 B base) | consensus/consensus.h:23 | Lower bound for a serialized CTransaction |
| `MIN_SERIALIZABLE_TRANSACTION_WEIGHT` | 40 WU (10 B base) | consensus/consensus.h:24 | Lower bound for serialization sanity |
| `MAX_TIMEWARP` | 600 s | consensus/consensus.h:35 | BIP94 timewarp mitigation |
| `MAX_FUTURE_BLOCK_TIME` | 2 h = 7200 s | chain.h:29 | Standard 2-hour future timestamp rule (Satoshi) |
| `TIMESTAMP_WINDOW` | = 2h | chain.h:37 | Derived window used by header sync/IBD logic |
| `LOCKTIME_THRESHOLD` | 500,000,000 | script/script.h:48 | Tue Nov 5 1985 UTC; height-vs-time domain split |
| `SEQUENCE_FINAL` | 0xffffffff | primitives/transaction.h:77 | Satoshi finality sentinel |
| `MAX_SEQUENCE_NONFINAL` | 0xfffffffe | primitives/transaction.h:83 | |
| `SEQUENCE_LOCKTIME_DISABLE_FLAG` | 1<<31 | primitives/transaction.h:94 | BIP68 disable bit |
| `SEQUENCE_LOCKTIME_TYPE_FLAG` | 1<<22 | primitives/transaction.h:100 | BIP68 time-vs-height selector |
| `SEQUENCE_LOCKTIME_MASK` | 0x0000ffff | primitives/transaction.h:105 | BIP68 value field |
| `SEQUENCE_LOCKTIME_GRANULARITY` | 9 (512 s units) | primitives/transaction.h:115 | BIP68 |
| `LOCKTIME_VERIFY_SEQUENCE` | 1<<0 | consensus/consensus.h:28 | BIP68 enable flag (locktime flags) |
| `COIN` | 100,000,000 sat | consensus/amount.h:15 | Satoshi unit |
| `CAmount` | int64_t | consensus/amount.h:12 | Signed; range checks below |
| `MAX_MONEY` | 21,000,000·COIN | consensus/amount.h:26 | Sanity bound ≈ 21M cap; consensus-critical value |
| `MoneyRange(v)` | 0 ≤ v ≤ MAX_MONEY | consensus/amount.h:27 | CVE-2010-5139 family |
| `nSubsidyHalvingInterval` (mainnet) | 210,000 | kernel/chainparams.cpp:114 | Satoshi schedule |
| `GetBlockSubsidy` | 50·COIN >> halvings; 0 if halvings ≥ 64 | validation.cpp:1833–1844 | BIP42 (fixes post-13.44M subsidy resurrection) |
| `powLimit` (mainnet) | 0x00000000ffff…ffff | kernel/chainparams.cpp:126 | Difficulty floor |
| `nPowTargetTimespan` | 14·24·60·60 s | kernel/chainparams.cpp:127 | 2016-block retarget window |
| `nPowTargetSpacing` | 600 s | kernel/chainparams.cpp:128 | 10-min target |
| `DifficultyAdjustmentInterval()` | timespan/spacing = 2016 | consensus/params.h:130 | |
| Timespan clamp | /4 … ×4 | pow.cpp:57–60 | Satoshi anti-instability |
| `nMinimumChainWork` (mainnet) | 0x…145ec036acc5ba740052af1a0 | kernel/chainparams.cpp:141 | Anti-DoS (NOT consensus; see (f)) |
| `defaultAssumeValid` | hash @ height 966,143 | kernel/chainparams.cpp:142 | Trust shortcut (see (f)) |
| Buried heights | BIP34 227931; BIP65 388381; BIP66 363725; CSV 419328; SegWit 481824 | kernel/chainparams.cpp:119–124 | BIP90-style hardcoding |
| `MinBIP9WarningHeight` | 711,648 | kernel/chainparams.cpp:125 | Warning machinery only |
| BIP9 defaults | period 2016, threshold 1916 (95%) | consensus/params.h:62–68 | BIP9 |
| `VERSIONBITS_TOP_BITS`/`TOP_MASK`/`NUM_BITS` | 0x20000000 / 0xE0000000 / 5 | versionbits.h:21–25 | BIP9; BIP323 limits meaningful bits to 0–4 |
| `VERSIONBITS_LAST_OLD_BLOCK_VERSION` | 4 | versionbits.h:19 | Pre-versionbits max |
| `MAX_SCRIPT_ELEMENT_SIZE` | 520 | script/script.h:29 | BIP141/BIP62 heritage; Satoshi |
| `MAX_SCRIPT_SIZE` | 10,000 | script/script.h:41 | Satoshi |
| `MAX_OPS_PER_SCRIPT` | 201 | script/script.h:32 | Satoshi |
| `MAX_PUBKEYS_PER_MULTISIG` | 20 | script/script.h:35 | Satoshi |
| `MAX_STACK_SIZE` | 1000 | script/script.h:44 | Satoshi |
| `MINIMUM_WITNESS_COMMITMENT` | 38 B | consensus/validation.h:25 | BIP141 commitment shape |
| `MEMPOOL_HEIGHT` | 0x7FFFFFFF | txmempool.h:51 | Sentinel height for mempool coins (impl detail) |
| `SIGHASH_ALL/NONE/SINGLE/ANYONECANPAY/DEFAULT` | 1/2/3/0x80/0 | script/interpreter.h:30–40 | Satoshi; BIP341 DEFAULT |
| script flag exceptions (mainnet) | 2 block hashes | kernel/chainparams.cpp:105–108 | BIP16 retroactive exception; Taproot exception |
| `BIP34_IMPLIES_BIP30_LIMIT` | 1,983,702 | validation.cpp:2429 | BIP30 optimization horizon (see (e)) |
| `MAX_BLOCK_COINSDB_USAGE_BYTES` | 10 MiB | validation.cpp:520 (inline in `LargeCoinsCacheThreshold`) | Flush heuristics — NOT consensus |

**21M cap structure**: no single constant caps supply. The cap = Σ_h (50·COIN >> ⌊h/210000⌋) with the `halvings ≥ 64 ⇒ 0` rule; `MAX_MONEY` is an independent sanity clamp. A Lean spec should define the subsidy function and prove `Σ < MAX_MONEY` (a nice first theorem; see C4 liaison).

### (c) Consensus vs policy boundary

**`src/policy/` inventory** (all NOT consensus):

| Module | Contents | Why not consensus |
|---|---|---|
| policy.{h,cpp} | `IsStandard` (:80), `IsStandardTx` (:100), `IsWitnessStandard` (:265), `AreInputsStandard`, dust (`GetDustThreshold`), `MANDATORY/STANDARD_SCRIPT_VERIFY_FLAGS` (policy.h:104–134), relay fee defaults | Standardness gates relay/mining; a block containing "non-standard" txs is still valid |
| feerate.{h,cpp} | `CFeeRate` arithmetic | Fee accounting |
| fees/* | Fee estimator | Purely local |
| packages.{h,cpp} | `IsPackageWellformed`, package limits (25 anc / 25 desc, cluster limits policy.h:72–78) | Mempool topology policy |
| rbf.{h,cpp} | BIP125 replace-by-fee | Policy ( signaled opt-in; not enforced in blocks) |
| ephemeral_policy.{h,cpp} | Ephemeral dust package policy | v3/TRUC-adjacent policy |
| truc_policy.{h,cpp} | BIP431 TRUC topological restrictions | Standardness for nVersion=3 txs |
| settings.{h,cpp} | `-mempool*` config plumbing | Local config |

**Inside validation.cpp, the consensus/policy split by check** (VERIFIED by reading `MemPoolAccept::PreChecks` :779 and `ConnectBlock` :2294):

- Consensus (enforced identically in `ConnectBlock`): everything in §(b), `CheckTransaction`, `CheckTxInputs`, `SequenceLocks`, `GetTransactionSigOpCost`, block-contextual checks, `GetBlockScriptFlags` script execution.
- Policy-only (never block-invalidating): fee floor/`-minrelaytxfee`, dust, size > `MAX_STANDARD_TX_WEIGHT` (400k), `<65 non-witness bytes` (CVE-2017-12842 mitigation, validation.cpp:809), nVersion standardness, OP_RETURN datacarrier ≤ 80 B, bare multisig permit, RBF, package/cluster limits, TRUC/P2A/ephemeral standardness, `STANDARD_SCRIPT_VERIFY_FLAGS` extras (STRICTENC, MINIMALDATA, LOW_S, CLEANSTACK, MINIMALIF, NULLFAIL, WITNESS_PUBKEYTYPE, CONST_SCRIPTCODE, DISCOURAGE_*), sigop-denominator policy (20 B/sigop), coinbase-additional-sigops template rule (policy.h:29).
- **Borderline catalogued**: (i) `IsFinalTx` is consensus but "reject non-final from mempool" is policy (PreChecks); (ii) sigop *counting* is consensus, the *65/78 limit application* in mempool is policy; (iii) `fPowAllowMinDifficultyBlocks` and `enforce_BIP94` are consensus *params* that differ per network; (iv) script/sig caches (`ValidationCache`, validation.h:369) never change acceptance outcomes (same flag set ⇒ same result) — performance only; (v) `mempool.check()` sanity (validation.cpp:4473) is an internal assertion, not a rule.

### (d) Softfork activation machinery

- **BIP9 engine**: `versionbits_impl.h` `ThresholdState` enum (:17–23) + `AbstractThresholdConditionChecker::GetStateFor` (versionbits.cpp:26–117): state computed per period via `GetAncestor(nHeight − ((nHeight+1) % period))`, cached in `ThresholdConditionCache` keyed by period-start parent. Transitions: DEFINED→STARTED at `MTP ≥ nStartTime` (:77–81); STARTED→LOCKED_IN when `count ≥ threshold` over the period (:83–98); STARTED→FAILED at `MTP ≥ nTimeout`; LOCKED_IN→ACTIVE when `pindexPrev.nHeight + 1 ≥ min_activation_height` (:100–105). Condition = `(nVersion & TOP_MASK) == TOP_BITS && bit set` (versionbits_impl.h:79–82).
- **Deployment table (real names)**: `Consensus::DeploymentPos` = {`DEPLOYMENT_TESTDUMMY`} (consensus/params.h:38–43); `Consensus::BuriedDeployment` = {`DEPLOYMENT_HEIGHTINCB`, `DEPLOYMENT_CLTV`, `DEPLOYMENT_DERSIG`, `DEPLOYMENT_CSV`, `DEPLOYMENT_SEGWIT`} (:26–35). Names in `deploymentinfo.cpp:20–39`. BIP324/341-era Taproot was BIP9-activated then buried; its deployment struct has since been removed from `DeploymentPos` (only TESTDUMMY remains) — **INFERRED** from deploymentinfo.cpp:12–16 + doc/bips.md (activation v24 "always active", PR 23536).
- **Buried (height) activations** — `DeploymentHeight()` (consensus/params.h:143–158) maps them to `BIP34Height/BIP65Height/BIP66Height/CSVHeight/SegwitHeight`; BIP90 (PR #8391) is the meta-rule that allows this hardcoding.
- **Flag plumbing**: `ContextualCheckBlockHeader` uses buried heights for version≥2/3/4 (validation.cpp:4121–4126); `ContextualCheckBlock` gates BIP113 MTP cutoff on `DEPLOYMENT_CSV` (:4141–4150) and BIP34 coinbase-height on `DEPLOYMENT_HEIGHTINCB` (:4159–4167); `ConnectBlock` gates `LOCKTIME_VERIFY_SEQUENCE` on CSV (:2477–2481) and computes flags via `GetBlockScriptFlags` (:2249–2288: DERSIG, CHECKLOCKTIMEVERIFY, CHECKSEQUENCEVERIFY, NULLDUMMY per deployment; P2SH+WITNESS+TAPROOT always on except the two exception blocks); `IsBlockMutated`/`CheckWitnessMalleation` gate witness-commitment checks on `DEPLOYMENT_SEGWIT` (validation.cpp:4177).
- **BIP94** (testnet4/regtest): `MAX_TIMEWARP` check in `ContextualCheckBlockHeader` (validation.cpp:4105–4113) and first-block-of-period base in `CalculateNextWorkRequired` (pow.cpp:67–76); mainnet `enforce_BIP94=false` (kernel/chainparams.cpp:130).
- **Warning bits (not consensus)**: `WarningBitsConditionChecker` (versionbits.cpp:299–331) + `MinBIP9WarningHeight`.

### (e) CVE → rule map

| CVE / event | Bug | Fix (commit/PR) | Today's check (rule row) |
|---|---|---|---|
| **CVE-2010-5139** (2010-08, 184.467B BTC, block 74638) | Output values overflowed int64; sum of negative+positive passed naive check | Satoshi 0.3.6 series fix; superseded by money-range refactor (pre-GitHub history — **INFERRED** for exact hash) | `CheckTransaction` per-output `nValue < 0` / `> MAX_MONEY` / running-sum `MoneyRange` (tx_check.cpp:31–42) → INV-006/007/008; plus input-side ranges in `CheckTxInputs` (tx_verify.cpp:190–194) → INV-046/047 |
| **CVE-2010-5137** | Crash via disabled script opcodes (OP_LSHIFT et al.) with huge shifts / stack abuse | 2010 disable-opcodes patch (Satoshi; pre-GitHub **INFERRED**) | `EvalScript` disabled-opcode branch (interpreter.cpp:482) → INV-063 |
| **CVE-2010-5141** | scriptSig+scriptPubKey *concatenated* before eval; an OP_RETURN in scriptSig truncated the combined script → fake spends | Satoshi fix (pre-GitHub **INFERRED**) | Sequential evaluation of scriptSig then scriptPubKey (interpreter.cpp:2027) → INV-087 |
| **2010 opcode removals** (OP_CAT, OP_SUBSTR, OP_LEFT/RIGHT, OP_MUL/DIV/MOD, OP_LSHIFT/RSHIFT, OP_BOOLAND/OR, OP_NUMEQUALVERIFY, OP_NOP2/3) | Multiple crash/inflation vectors | Satoshi, Aug–Sep 2010 (**INFERRED**) | `case` fall-through to SCRIPT_ERR_DISABLED_OPCODE (interpreter.cpp:472–483) → INV-062 |
| **CVE-2012-1909 / BIP30** | Duplicate coinbase txids overwrite UTXO entries (heights 91842/91880 collisions) | PR #915 "Do not allow overwriting unspent transactions", merge `ae6616bc` (2012-03-03, VERIFIED via GitHub API) | BIP30 no-overwrite check in `ConnectBlock` (validation.cpp:2401–2475) → INV-080; exceptions `IsBIP30Repeat`/`IsBIP30Unspendable` (:6207–6217) → INV-081/082 |
| **CVE-2012-2459** | Merkle-tree duplication malleability (odd-level leaf duplication ⇒ same root, different tx list) | Fix "merkle: detect duplicate hash pairs" era (2012; PR search inconclusive — **INFERRED**), plus the v0.8 2013 fork fallout | `ComputeMerkleRoot(..., &mutated)` pair-equality detection (merkle.cpp:51–73) + `CheckMerkleRoot` "bad-txns-duplicate" (validation.cpp:3858–3866) → INV-072; note `ProcessNewBlock` deliberately does NOT cache CheckBlock failures for this class (validation.cpp:4426–4431) → INV-084 |
| **BIP50 (2013-03 BDB lock-limit fork)** | Level-DB fork at height 225,430 due to BDB `MaxLocks` → 0.7/0.8 chain split; resolved by mining a specific tx with low fee (b6a2668f…) | 0.8.1 handling + BIP50 advisory; the special-case tx constant lived in old chainparams, no longer in master (grep found nothing — **INFERRED** that it was removed with BIP90-era cleanup) | No live rule; catalogued as historical-chain exception. The durable lesson: *database-layer nondeterminism must not enter validation* (cf. CCoinsViewErrorCatcher, coins.h:806–823) → INV-169 |
| **CVE-2017-12842** | Merkle-proof forgery for 64-byte txs (txid leaf ambiguity) | PR #11558-era relay floor (VERIFIED in-code comment validation.cpp:809) | Policy 65-byte relay floor (NOT consensus) → INV-166; plus `IsBlockMutated` 64-byte-tx mutation heuristic (validation.cpp:4043–4056) → INV-073 |
| **CVE-2018-17144** | Duplicate inputs in a tx: crash (nodes) / inflation (patched DBs) | PR #14247 "Fix crash bug with duplicate inputs within a transaction", merge `9b4a36ef` (2018-09-17, VERIFIED via GitHub API) | `CheckTransaction` duplicate-prevout set check (tx_check.cpp:49–53) → INV-009; re-checked in `CheckBlock` loop (validation.cpp:3966–3976) |
| **CVE-2012-3789** | Orphanage DoS | Limit on orphan size/count (txorphanage.cpp:350,381 comment VERIFIED) | p2p/DoS layer only → INV-167 |
| **Malleability era (2014–2015, motivating SegWit)** | Third-party malleation of txid via sig DER/dummy/push tweaks broke downstream locktimes/dependent txs | BIP62 family (v0.10) + BIP141 SegWit (PR #8149, merge `f8528134` 2016-06-24, VERIFIED via API) | Witness hashing (`GetWitnessHash`, block witness merkle), `WITNESS_MALLEATED` scriptSig-empty rule (interpreter.cpp:2051–2053) → INV-090, `WITNESS_MALLEATED_P2SH` (:2097–2100) → INV-091 |
| **Header-spam DoS 2024 disclosure** (not a CVE) | Unbounded block-index growth pre-v0.15 | Historical; modern mitigations = `nMinimumChainWork` gate in `AcceptBlock` (validation.cpp:4349–4353) + headerssync | DoS layer, out of consensus scope → INV-168 |

### (f) Trust shortcuts (out-of-scope for the spec, must be documented)

1. **Checkpoints — REMOVED.** `src/init.cpp:666` ("Checkpoints were removed…") + PR #31649 (merge `1b251f6b`, 2025-03-14, v30.0; VERIFIED via GitHub API). The spec need not model them; keep one line of history.
2. **assumevalid** (`Consensus::Params::defaultAssumeValid`, param `-assumevalid`): skips *script checks only* for blocks under the assumed-valid ancestor meeting the 2-week-equivalent-time and minimum-chainwork guards (`ConnectBlock`, validation.cpp:2345–2393). Everything else (PoW, merkle, amounts, UTXO, maturity, sigops) is still enforced. Argument it doesn't change consensus: the skipped checks are exactly those whose result is committed to by the block hash (merkle root) — assuming validity of one ancestor never changes which *chains* are valid, only verification cost.
3. **nMinimumChainWork** (kernel/chainparams.cpp:141, used validation.cpp:2888-ish `ReportHeadersPresync` :4288 and `AcceptBlock` :4353): an anti-DoS gate on *unrequested* blocks/headers. A chain with less work is still valid data; this only controls processing priority. NOT a consensus rule.
4. **assumeutxo** (`m_assumeutxo_data`, kernel/chainparams.cpp:190–203; `ActivateSnapshot` validation.cpp:5606; `PopulateAndValidateSnapshot` :5772; `MaybeValidateSnapshot` :5985; `Assumeutxo` enum validation.h:526–533): trusts a UTXO-set hash at a snapshot height until background validation recomputes `hash_serialized` (MuHash3072, kernel/coinstats.cpp:59–112). Consensus output is only accepted *after* the hash match; before that the snapshot chainstate is `UNVALIDATED`. Spec treatment: model as an optional bootstrap; the *rule set* is unchanged.
5. **Caches that must never change results** (worth a spec-side lemma): script-execution cache (cuckoocache, keyed by wtxid+flags, validation.cpp:2077–2083), signature cache (`script/sigcache.h`), `CBlock::fChecked` (validation.cpp:3930, 3987), `m_checked_merkle_root`/`m_checked_witness_commitment` (validation.cpp:3847, 3881).

### (g) The UTXO model (`coins.{h,cpp}`)

- **Data model** (consensus-relevant): `Coin{CTxOut out; fCoinBase:1; nHeight:31}` (coins.h:45–101). Spent ⇔ null out (:94). Serialized `(nHeight<<1)|coinbase` VARINT (:77). A Coin is a *pure value*; the consensus state is exactly: (outpoint ↦ Coin) map + best-block hash.
- **Views**: `CCoinsView` (abstract, coins.h:355–388) → `CCoinsViewBacked` → `CCoinsViewCache` (in-memory overlay with DIRTY/FRESH, :436–592) → `CoinsViews` stack in `Chainstate` (validation.h:478–506: CCoinsViewDB ⊂ CCoinsViewErrorCatcher ⊂ CCoinsViewCache) + `CoinsViewOverlay` parallel prefetcher (coins.h:655–783).
- **Consensus-relevant operations**: `AddCoin` (coins.cpp:80; refuses unspendable scriptPubKeys — OP_RETURN outputs never enter the UTXO set, :83); `AddCoins` (coins.cpp:133; coinbase overwrite allowed for pre-BIP30 duplicates, :136–137); `SpendCoin` (coins.cpp:144); `HaveInputs` (coins.cpp:322 — all non-coinbase prevouts present); `AccessCoin`; height used for maturity (`CheckTxInputs` tx_verify.cpp:185) and BIP68 prevheights (validation.cpp:2551–2553).
- **Flush semantics** (implementation detail, but bounded-state relevant): `BatchWrite` (coins.cpp:201), `Flush`/`Sync` (:272/:284), FRESH-erase optimization (:144–168), `SanityCheck` (:344). Failure to mark DIRTY/FRESH correctly = consensus failure by the code's own comment (coins.h:160–174) — a Lean spec replaces this mutable-flag dance with a pure `Map OutPoint Coin` + explicit transition functions.
- **Undo records**: `CTxUndo`/`ApplyTxInUndo` (validation.cpp:2148–2174) — reorg support; `DISCONNECT_UNCLEAN` marks inconsistent undo data. Consensus-wise: reorg = reverse transition functions; undo data is a cache, not a rule.
- **Snapshot path**: `EmplaceCoinInternalDANGER` (coins.cpp:123) — assumeutxo-only.

---

## Implications for btc-lean

1. **The consensus core is small.** ~6,400 lines of validation.cpp contain everything consensus-relevant in <2,500 of those lines; consensus/{consensus,amount,params,tx_check,tx_verify,merkle}.h/.cpp ≈ 900 lines total. A Lean `Consensus` namespace mirroring these files is feasible with a 1:1 file mapping (C1 liaison).
2. **The right Lean decomposition**: (i) pure check functions (`CheckTransaction`, `CheckTxInputs`, `IsFinalTx`, `SequenceLocks`, `EvalScript` as a pure `State → Script → Option State` step function, `CheckProofOfWork`, `BlockMerkleRoot`); (ii) a context record (`Consensus::Params`, block index as a pure `Nat → BlockHeader` map + MTP function); (iii) the UTXO transition as a pure `Map OutPoint Coin → Block → Result (Map OutPoint Coin)` — the DIRTY/FRESH machinery is pure optimization and can be *proved* semantically equivalent.
3. **Clocks and MTP** are consensus inputs (`GetMedianTimePast` over 11 blocks, `MAX_FUTURE_BLOCK_TIME` vs wall clock). Wall-clock comparisons (`time-too-new`) make validation non-deterministic in the strict sense; the spec should model `now` as an explicit environment parameter and note that the check is advisory-persisting (blocks in the future become valid later — there is no permanence).
4. **Carve-outs are part of consensus**: BIP30 exceptions, the two script-flag exception blocks, BIP16 activation-before-segwit subtleties, `BIP34_IMPLIES_BIP30_LIMIT`. These are exactly the "dark corners" a faithfulness theorem must cover.
5. **Difficulty**: `arith_uint256` 256-bit arithmetic + `SetCompact`/`GetCompact` (lossy 3-byte mantissa + 5-bit exponent with 0x00800000 sign bit) is a self-contained, highly testable Lean module (difficulty 3).
6. **Rule-ID database**: Appendix B is directly machine-ingestible (one row per rule; Core anchor = `file:function:lines@cce32b168`).

## Open questions & risks

- **R1 — BIP9 deployment erosion**: `DeploymentPos` now contains only TESTDUMMY; Taproot's BIP9 entry was deleted (INFERRED from code). If we model BIP9 generically we must decide whether historical deployments live in the spec's params or as frozen height constants. Recommend: model both (`BuriedDeployment` heights + a BIP9 engine proven correct on TESTDUMMY).
- **R2 — non-determinism seams**: `NodeClock::now()` (time-too-new), `FastRandomContext` in flush logic, threading in `CheckQueue`. All excludable from the pure core; flag in spec as environment.
- **R3 — BIP50 / pre-BIP34 historical exceptions**: exact byte-level faithfulness for blocks < 481,824 requires the exception tables; we have them (script_flag_exceptions, IsBIP30Repeat/Unspendable) but must sweep for others (e.g., the 64-byte-tx issue and BIP16 exception handling interact).
- **R4 — `Assume(...)` vs `Assert(...)`**: several comments in ConnectBlock assert unreachability of `bad-txns-fee-outofrange` (tx_verify.cpp:207–216). A Lean spec can *prove* these unreachability lemmas — cheap wins for the theorem portfolio (C4).
- **R5 — version string**: 32.99.0 means master is post-31; line numbers will drift. All row records must cite `@cce32b16868`; the pin is frozen repository-wide.
- **R6 — TestBlockValidity vs AcceptBlock divergence**: `TestBlockValidity` (validation.cpp:4478–4549) intentionally skips `AcceptBlockHeader`; mining RPC path. Ensure the spec's entry-point semantics match `ProcessNewBlock`, not TestBlockValidity.

## Recommendations

1. Adopt **INV-xxx IDs from Appendix B verbatim** as the traceability DB seed (D1); columns already match charter §1.3.
2. Formalization order by ROI: money/amount invariants + subsidy (INV-020–024, 100–102) → tx-level stateless checks (INV-001–010) → merkle+PoW (INV-066–075, 108–117) → locktime/BIP68 (INV-011–019) → UTXO transition + BIP30 (INV-043–058) → script interpreter (INV-060–095; B2 owns) → activation FSM (INV-118–126).
3. Encode **CVE reproducers** as `example` test cases in Lean (block 74638-style overflow, duplicate-coinbase, merkle dup pairs, CVE-2018-17144 tx) — each CVE becomes both a rule row and a negative conformance test.
4. Write the **"NOT consensus" list (§c + INV-160…176) into the charter appendix** so policy never sneaks into the spec.
5. Ask B3 to re-derive rows INV-001–058 independently (cross-check), B2 to own/extend INV-060–095, B4 to own INV-096–147, B5 the witness rows — dedupe at merge time.
6. Pin the BTC repo at `cce32b168` in every machine-readable anchor (CI can grep-verify anchors against a vendored shallow clone).

---

## Appendix A — Sources

**Primary (VERIFIED, at commit `cce32b1686874e85e8a00cfa1a2190f0b6f4dcaf66`, bitcoin/bitcoin, clone bitcoin/bitcoin):**
- src/consensus/consensus.h, amount.h, params.h, tx_check.{h,cpp}, tx_verify.{h,cpp}, merkle.{h,cpp}, validation.h
- src/validation.{h,cpp} (functions cited individually above)
- src/pow.{h,cpp}; src/chain.h; src/coins.{h,cpp}; src/txmempool.h; src/versionbits.{h,cpp}, versionbits_impl.h; src/deploymentinfo.{h,cpp}
- src/script/interpreter.{h,cpp}, script/script.h, script/verify_flags.h, script/script_error.h
- src/kernel/chainparams.{h,cpp}, kernel/coinstats.{h,cpp}, kernel/checks.cpp
- src/net_processing.cpp (entry points only); src/node/txorphanage.cpp (CVE-2012-3789 comment); src/init.cpp:666 (checkpoints removed)
- doc/bips.md (BIP→PR↔version table, in-tree)

**Secondary (GitHub API, VERIFIED):** PR #14247 (CVE-2018-17144 fix, merge 9b4a36ef, 2018-09-17); PR #915 (BIP30, merge ae6616bc, 2012-03-03); PR #8149 (SegWit, merge f8528134, 2016-06-24); PR #31649 (checkpoints removed, merge 1b251f6b, 2025-03-14, v30.0).

**INFERRED (not directly pinned):** pre-GitHub Satoshi-era fix commits for CVE-2010-5137/5139/5141 and the 2010 opcode removals; the exact 2012 CVE-2012-2459 fix PR; removal history of the BIP50 special-case constant from chainparams; Taproot BIP9 deployment-struct deletion history.

**BIP corpus:** bitcoin/bips (bitcoin/bips master, 2026-10-16).

---

## Appendix B — THE RULE INVENTORY TABLE

Legend: Difficulty (Lean) 1 = trivial decidable check, 5 = deep semantics. "P" = pure function candidate. All `@cce32b168`. Location format `file:function:lines`.

### B.1 Transaction stateless checks — `consensus/tx_check.cpp::CheckTransaction:19–68`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-001 | vin non-empty | tx_check.cpp:CheckTransaction:22–23 | `∀tx. tx.vin ≠ ∅` | Satoshi | `tx.inputs ≠ []`; d=1; P |
| INV-002 | vout non-empty | tx_check.cpp:24–25 | `tx.outputs ≠ ∅` | Satoshi | d=1; P |
| INV-003 | tx base-serialized weight ≤ MAX_BLOCK_WEIGHT | tx_check.cpp:27–29 | `weight(noWitness tx) ≤ 4_000_000` | SegWit BIP141 | weight = 4·len; d=1; P |
| INV-004 | every output value ≥ 0 | tx_check.cpp:35–36 | `∀o ∈ outs. 0 ≤ o.value` | CVE-2010-5139 | CAmount=ℤ; d=1; P |
| INV-005 | every output value ≤ MAX_MONEY | tx_check.cpp:37–38 | `o.value ≤ 21e6·COIN` | CVE-2010-5139 | d=1; P |
| INV-006 | running output sum in MoneyRange | tx_check.cpp:39–41 | `foldl (+) 0 values ≤ MAX_MONEY` (checked incrementally ⇒ prefix sums) | CVE-2010-5139 | incremental ⇒ equivalent to total-sum check; prove equiv; d=2; P |
| INV-007 | no duplicate inputs | tx_check.cpp:49–53 | prevout list is duplicate-free | CVE-2018-17144 | `Nodup`; d=2; P |
| INV-008 | coinbase scriptSig length ∈ [2,100] | tx_check.cpp:55–58 | `2 ≤ len(cb.scriptSig) ≤ 100` | Satoshi | d=1; P |
| INV-009 | non-coinbase: no null prevout | tx_check.cpp:62–64 | `∀i ∈ inputs. i.prevout ≠ null` | Satoshi | d=1; P |
| INV-010 | coinbase predicate (exactly one input, null prevout) | primitives/transaction.h:IsCoinBase | classification rule underlying INV-008/009 | Satoshi | d=1; P |

### B.2 Finality & locktime — `consensus/tx_verify.cpp::IsFinalTx:23–43`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-011 | nLockTime = 0 ⇒ final | tx_verify.cpp:IsFinalTx:25–26 | `lt=0 → final` | Satoshi | d=1; P |
| INV-012 | height-domain: nLockTime < block height | tx_verify.cpp:27 | when `lt < 500M`, compare with height | Satoshi | d=2; P |
| INV-013 | time-domain: nLockTime < block time | tx_verify.cpp:27 | when `lt ≥ 500M` (`LOCKTIME_THRESHOLD` script.h:48), compare with (BIP113-corrected) time | BIP113 | domain split via 500M; d=2; P |
| INV-014 | SEQUENCE_FINAL override | tx_verify.cpp:38–41 | `∀i. i.seq = 0xffffffff → final regardless` | Satoshi | d=1; P |
| INV-015 | BIP113: cutoff = prev-block MTP when CSV active | validation.cpp:ContextualCheckBlock:4141–4150 | time comparisons use MTP of prev 11 blocks | BIP113 | MTP = median of 11 (chain.h:231–244); d=2; P |
| INV-016 | all block txs final (block context) | validation.cpp:ContextualCheckBlock:4152–4157 | block-level quantifier over INV-011..14 | — | d=2; P |
| INV-017 | BIP68 enabled only for tx version ≥ 2 | tx_verify.cpp:CalculateSequenceLocks:57 | `fEnforceBIP68 = version≥2 ∧ flag` | BIP68 | d=1; P |
| INV-018 | sequence disable flag (bit 31) ⇒ no lock | tx_verify.cpp:71–75 | mask semantics | BIP68 | bitvec ops; d=2; P |
| INV-019 | sequence type flag (bit 22) ⇒ time-based, 512s granularity | tx_verify.cpp:79–94 | `MTP(prev of coinHeight) + (seq & 0xffff)·512 − 1` | BIP68 | d=3; P |
| INV-020 | height-based sequence lock | tx_verify.cpp:96 | `coinHeight + (seq & 0xffff) − 1` | BIP68 | d=2; P |
| INV-021 | sequence-lock evaluation vs block | tx_verify.cpp:EvaluateSequenceLocks:103–111 | `minH < blockHeight ∧ minT < MTP(block.prev)` | BIP68 | d=2; P |
| INV-022 | OP_CHECKLOCKTIMEVERIFY semantics | interpreter.cpp:OP_CLTV:556–567 + CheckLockTime:1755–1788 | script-level finality lock (5-byte CScriptNum; both tx-level finality AND lock satisfied) | BIP65 | needs tx context in checker; d=3; P |
| INV-023 | OP_CHECKSEQUENCEVERIFY semantics | interpreter.cpp:OP_CSV:584–599 + CheckSequence:1792–1836 | script-level relative lock | BIP112 | d=3; P |

### B.3 Money & fees — `consensus/amount.h`, `tx_verify.cpp::CheckTxInputs:170–220`, `validation.cpp`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-024 | MoneyRange definition | amount.h:27 | `0 ≤ v ≤ MAX_MONEY` | CVE-2010-5139 | predicate; d=1; P |
| INV-025 | input coin value in MoneyRange | tx_verify.cpp:CheckTxInputs:190–194 | per-input | CVE-2010-5139 | d=1; P |
| INV-026 | running input sum in MoneyRange | tx_verify.cpp:191–194 | prefix sums again | CVE-2010-5139 | d=2; P |
| INV-027 | inputs available (not spent/missing) | tx_verify.cpp:173–176 via coins.cpp:HaveInputs:322 | `∀i. prevout ∈ UTXO` | Satoshi | needs state; d=2; P |
| INV-028 | coinbase maturity: spend height − coin height ≥ 100 | tx_verify.cpp:185–188 | `h − coin.nHeight ≥ COINBASE_MATURITY` | Satoshi | d=1; P |
| INV-029 | value in ≥ value out | tx_verify.cpp:201–205 | `nValueIn ≥ GetValueOut` | Satoshi/conservation | conservation core; d=2; P |
| INV-030 | fee in MoneyRange | tx_verify.cpp:208–216 | `0 ≤ fee ≤ MAX_MONEY` (provably unreachable given INV-004..006,025–029 — prove it) | — | good lemma; d=3; P |
| INV-031 | block accumulated fee in MoneyRange | validation.cpp:ConnectBlock:2540–2545 | sum of per-tx fees | — | d=2; P |
| INV-032 | coinbase pays ≤ subsidy + fees | validation.cpp:ConnectBlock:2608–2612 | `cb.GetValueOut ≤ GetBlockSubsidy(h) + Σfees` | Satoshi / 51% inflation | **THE no-inflation rule**; d=3; P |
| INV-033 | subsidy = 50·COIN >> ⌊h/210000⌋, 0 when halvings ≥ 64 | validation.cpp:GetBlockSubsidy:1833–1844 | halving schedule | BIP42 | d=2; P; Σ < MAX_MONEY theorem |
| INV-034 | COIN = 10⁸; MAX_MONEY = 21·10⁶·COIN | amount.h:15,26 | constants | Satoshi | d=1 |

### B.4 Sigop accounting — `consensus/tx_verify.cpp`, `validation.cpp`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-035 | legacy sigop count = OP_CHECKSIG(≈1) + OP_CHECKMULTISIG(k) counts, no accurate parse | tx_verify.cpp:GetLegacySigOpCount:118–130 | sum over scriptSig+scriptPubKey with `fAccurate=false` | Satoshi | d=2; P |
| INV-036 | P2SH sigop count (accurate, from redeem script) | tx_verify.cpp:GetP2SHSigOpCount:132–147 | only when P2SH flag & prevout IsPayToScriptHash | BIP16 | d=2; P |
| INV-037 | witness sigop cost | tx_verify.cpp:GetTransactionSigOpCost:149–168 via interpreter.cpp:CountWitnessSigOps:2139–2160 | v0: 1 for P2WPKH, redeem-based for P2WSH; v1: validation-weight based | BIP141/342 | d=3; P |
| INV-038 | legacy count × 4 in cost | tx_verify.cpp:151 | `legacy·WITNESS_SCALE_FACTOR` | BIP141 | d=1; P |
| INV-039 | block sigop cost ≤ 80,000 (exact, ConnectBlock) | validation.cpp:ConnectBlock:2566–2570 | running cost check | BIP141 | d=2; P |
| INV-040 | block legacy sigops × 4 ≤ 80,000 (coarse, CheckBlock) | validation.cpp:CheckBlock:3979–3985 | pre-check before context | — | d=2; P |

### B.5 Script interpreter (entry + global limits) — `script/interpreter.cpp` (B2 owns details)

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-041 | script size ≤ 10,000 (BASE/WITNESS_V0 only) | interpreter.cpp:EvalScript:437–439 | `len(script) ≤ 10000` | Satoshi | d=1; P |
| INV-042 | push size ≤ 520 | interpreter.cpp:457–458 | `MAX_SCRIPT_ELEMENT_SIZE` | BIP141/BIP62 | d=1; P |
| INV-043 | op count ≤ 201 (incl. multisig k) | interpreter.cpp:461–463,1126–1131 | `nOpCount` | Satoshi | d=2; P |
| INV-044 | stack+altstack ≤ 1000 | interpreter.cpp:1232 | `MAX_STACK_SIZE` | Satoshi | d=1; P |
| INV-045 | disabled opcodes fail | interpreter.cpp:472–483 | OP_CAT..OP_NOP10 subset fail | CVE-2010-5137 | d=1; P |
| INV-046 | minimal push (MINIMALDATA) | interpreter.cpp:489–491 + CheckMinimalPush | BIP62 rule 3/4 | BIP62 | flag-gated (consensus only when flag set); d=2; P |
| INV-047 | if/else/endif nesting validity | interpreter.cpp:vfExec logic | balanced conditionals | Satoshi | d=2; P |
| INV-048 | success criterion: last stack elem truthy | interpreter.cpp:EvalScript epilogue + CastToBool:46 | |top| = true | Satoshi | d=1; P |
| INV-049 | OP_CHECKMULTISIG: nKeys ≤ 20, dummy element popped | interpreter.cpp:1103–1215 | multisig semantics + off-by-one dummy | Satoshi | d=4; P |
| INV-050 | NULLDUMMY: dummy must be empty | interpreter.cpp:1211–1213 | when flag | BIP147 | d=1; P |
| INV-051 | NULLFAIL: failed checksig ⇒ sig must be empty | interpreter.cpp:351–352,1196–1198 | when flag | BIP146 | d=1; P |
| INV-052 | signature DER encoding check | interpreter.cpp:CheckSignatureEncoding(~449) + IsValidSignatureEncoding | when DERSIG/STRICTENC | BIP66 | d=3; P |
| INV-053 | LOW_S check | interpreter.cpp:CheckSignatureEncoding path | s ≤ order/2 | BIP62 rule 5 | policy unless flag; d=2; P |
| INV-054 | pubkey encoding check (STRICTENC / tapscript x-only) | interpreter.cpp:CheckPubKeyEncoding | | BIP62/342 | d=2; P |
| INV-055 | sighash type valid (ALL/NONE/SINGLE/ANYONECANPAY) | interpreter.cpp:OP_CHECKSIG:1167–1171 | hashtype ∈ defined set | Satoshi | d=2; P |
| INV-056 | FindAndDelete of matching sig in scriptCode | interpreter.cpp:FindAndDelete:239,340,1156 | legacy checksig quirk | Satoshi | notoriously subtle; d=4; P |
| INV-057 | OP_CODESEPARATOR positions in sighash scriptCode | interpreter.cpp:1281–1290,1058–1061 | codeseparator-pos commit | Satoshi/CONST_SCRIPTCODE | d=3; P |
| INV-058 | CScriptNum ≤ 4-byte (5 for CLTV/CSV) minimal encoding | interpreter.cpp:CScriptNum class | numeric encoding rule | BIP62 rule 4 | d=2; P |
| INV-059 | MINIMALIF (witness v0, flag) / mandatory in tapscript | interpreter.cpp:620–639 | IF argument minimal | BIP141/BIP342 | d=2; P |
| INV-060 | tapscript: OP_CHECKSIGADD semantics | interpreter.cpp (tapscript branch) | c-hanged multisig replacement | BIP342 | d=2; P |
| INV-061 | tapscript: 80-byte? no—stack item limits & OP_SUCCESSx | interpreter.cpp:eval loop; script.h:MAX_OPCODE | future-version escapes | BIP342 | d=3; P |
| INV-062 | OP_CHECKMULTISIG unavailable in tapscript | interpreter.cpp (TAPSCRIPT branch) | validation failure | BIP342 | d=1; P |
| INV-063 | disabled opcodes (canonical list) | interpreter.cpp:482 | see INV-045; cross-ref | CVE-2010-5137 | dup ok |

### B.6 VerifyScript / witness dispatch — `script/interpreter.cpp:2012–2111, 1842–2010`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-064 | scriptSig evaluated, then scriptPubKey, sequentially | interpreter.cpp:VerifyScript:2027–2040 | no concatenation | CVE-2010-5141 | d=2; P |
| INV-065 | SIGPUSHONLY (policy-flag) scriptSig pushes only | interpreter.cpp:2021–2023 | | BIP62 rule 2 | d=1; P |
| INV-066 | P2SH: redeemScript = last scriptSig element, evaluated | interpreter.cpp:2062–2090 | | BIP16 | d=3; P |
| INV-067 | witness program detection (v0 20/32B; v1 32B) | interpreter.cpp:2036–2047 + script.h:IsWitnessProgram | program shapes | BIP141 | d=2; P |
| INV-068 | native witness: scriptSig must be empty | interpreter.cpp:2049–2053 | SCRIPT_ERR_WITNESS_MALLEATED | BIP141 | d=1; P |
| INV-069 | P2SH-wrapped witness: scriptSig = single push of redeem | interpreter.cpp:2097–2100 | WITNESS_MALLEATED_P2SH | BIP141 | d=2; P |
| INV-070 | witness v0: P2WPKH (20B) vs P2WSH (32B) paths | interpreter.cpp:VerifyWitnessProgram:1940–1955 | dispatch | BIP141/143 | d=3; P |
| INV-071 | BIP143 sighash for v0 | interpreter.cpp:SignatureHash(WITNESS_V0) + PrecomputedTransactionData (interpreter.h:164–199) | 3-hash preimage | BIP143 | d=4; P |
| INV-072 | taproot keypath: 64/65-byte witness, schnorr | interpreter.cpp:VerifyWitnessProgram:1957–1980 | key path spend | BIP340/341 | d=4; P |
| INV-073 | taproot scriptpath: control block, tapleaf hash, taptree proof | interpreter.cpp:VerifyTaprootCommitment:1913–1926 | leaf commitment | BIP341 | d=4; P |
| INV-074 | tapscript leaf version 0xc0; unknown versions discouraged | interpreter.cpp:1962–1972 | | BIP342 | d=2; P |
| INV-075 | annex parsing + hash into sighash | interpreter.cpp:ScriptExecutionData annex fields | | BIP341 | d=3; P |
| INV-076 | CLEANSTACK (policy-flag; implicit in witness) | interpreter.cpp:2101–2108 | | BIP62 rule 6 | d=1; P |
| INV-077 | WITNESS implies P2SH; unexpected witness data fails | interpreter.cpp:2113–2119 | | BIP141 | d=1; P |
| INV-078 | legacy sighash (SigVersion::BASE) incl. ONE|SINGLE bug compat | interpreter.cpp:SignatureHash(BASE) | CTransactionSignatureSerializer | Satoshi | d=4; P |

### B.7 Block structure — `validation.cpp::CheckBlockHeader:3836`, `CheckBlock:3926–3991`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-079 | PoW: hash ≤ target from nBits | validation.cpp:CheckBlockHeader:3839 → pow.cpp:CheckProofOfWorkImpl:161–171 | | Satoshi | d=2; P |
| INV-080 | nBits decodes to valid target (non-neg, non-zero, non-overflow, ≤ powLimit) | pow.cpp:DeriveTarget:146–159 | compact encoding sanity | Satoshi | d=3; P |
| INV-081 | merkle root matches tx list | validation.cpp:CheckMerkleRoot:3845–3870 via merkle.cpp:BlockMerkleRoot:76–84 | | Satoshi | d=3; P |
| INV-082 | merkle mutation detection (dup pairs at every level) | merkle.cpp:ComputeMerkleRoot:53–70 + validation.cpp:3861–3866 | | CVE-2012-2459 | d=3; P |
| INV-083 | block has ≥ 1 tx; count·4 ≤ 4M; serialized·4 ≤ 4M | validation.cpp:CheckBlock:3955–3956 | size limits | BIP141 | d=1; P |
| INV-084 | first tx is coinbase; no other | validation.cpp:3959–3963 | | Satoshi | d=1; P |
| INV-085 | CheckTransaction for every tx (incl. INV-007 dup inputs) | validation.cpp:3967–3976 | | CVE-2018-17144 | d=2; P |
| INV-086 | signet solution check (param-gated) | validation.cpp:3939 → signet.cpp | | BIP325 | d=3; P |
| INV-087 | merkle mutation ⇒ block rejected not cached-invalid (design rule in ProcessNewBlock) | validation.cpp:4426–4431 | defensive | CVE-2012-2459 | meta-rule; d=2 |
| INV-088 | witness commitment output present/consistent (when segwit active & commitment exists) | validation.cpp:CheckWitnessMalleation:3878–3911 | 36-byte OP_RETURN, last matching output | BIP141 | d=3; P |
| INV-089 | witness reserved value = 32 bytes | validation.cpp:3888–3893 | | BIP141 | d=1; P |
| INV-090 | witness merkle root ⊕ reserved value matches commitment | validation.cpp:3898–3906 | | BIP141 | d=3; P |
| INV-091 | no witness data in blocks without commitment | validation.cpp:3913–3921 | | BIP141 | d=1; P |
| INV-092 | witness merkle: coinbase leaf = 0 | merkle.cpp:BlockWitnessMerkleRoot:86–95 | | BIP141 | d=2; P |
| INV-093 | block weight (3·base + total) ≤ 4M, checked after coinbase witness | validation.cpp:ContextualCheckBlock:4187 | GetBlockWeight consensus/validation.h:143–146 | BIP141 | d=2; P |

### B.8 Block context — `ContextualCheckBlockHeader:4088–4129`, `ContextualCheckBlock:4137–4192`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-094 | nBits = GetNextWorkRequired(prev) | validation.cpp:4096–4097 | difficulty continuity | Satoshi | d=4; P |
| INV-095 | retarget only at interval boundaries | pow.cpp:GetNextWorkRequired:20–39 | | Satoshi | d=2; P |
| INV-096 | timespan clamp [T/4, T·4] | pow.cpp:57–60 | | Satoshi | d=1; P |
| INV-097 | new target = old·actual/T, capped by powLimit | pow.cpp:63–84 | | Satoshi | 256-bit arith; d=3; P |
| INV-098 | PermittedDifficultyTransition bounds | pow.cpp:89–136 | audit check (VerifyDB level) | — | d=3; P |
| INV-099 | block time > MTP(prev 11) | validation.cpp:4100–4101 | time-too-old | Satoshi | d=2; P |
| INV-100 | BIP94 timewarp: first-block-of-period time ≥ prev − 600 | validation.cpp:4105–4113; consensus.h:35 | testnet4/regtest (mainnet off) | BIP94 | d=2; P |
| INV-101 | block time ≤ now + 2h | validation.cpp:4116–4118 | time-too-new; env-clock param | Satoshi | d=1; impure(env) |
| INV-102 | block version ≥ 4 (post-CLTV), ≥3 (post-DERSIG), ≥2 (post-HEIGHTINCB) | validation.cpp:4121–4126 | version gates | BIP34/66/65, BIP90 | d=2; P |
| INV-103 | BIP34: coinbase scriptSig begins with CScriptNum(height) | validation.cpp:4159–4167 | | BIP34 | d=2; P |
| INV-104 | BIP30: no overwriting existing UTXO (conditional) | validation.cpp:2401–2475 | | BIP30, CVE-2012-1909 | d=3; P (state) |
| INV-105 | BIP30 exception blocks (91722/91812 hashes) | validation.cpp:6207–6217, 2200–2201 | historical carve-out | BIP30 | constants; d=1 |
| INV-106 | BIP30-vs-BIP34 precondition (`BIP34Hash` at `BIP34Height`) + limit 1,983,702 | validation.cpp:2429,2458–2466 | optimization with proof caveats in comments | BIP34 | subtle; d=4; P |
| INV-107 | genesis block special case (no tx connection) | validation.cpp:2336–2342 | | — | d=1 |
| INV-108 | BIP68 enabled in-block when CSV active | validation.cpp:2477–2481 | flag gate | BIP68 | d=1; P |
| INV-109 | prev-block-hash linkage (`hashPrevBlock` = prev index hash) | validation.cpp:AcceptBlockHeader:4221–4231; ConnectBlock:2331–2332 | chain structure | Satoshi | d=1; P |

### B.9 UTXO transition — `validation.cpp::UpdateCoins:1998`, `coins.cpp`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-110 | spend all inputs (exactly once, coinbase exempt) | validation.cpp:UpdateCoins:2001–2008 | deletion from UTXO | Satoshi | d=2; P(state fn) |
| INV-111 | add all outputs with height & coinbase flag | validation.cpp:2010 → coins.cpp:AddCoins:133–141 | insertion | Satoshi | d=2; P |
| INV-112 | unspendable (OP_RETURN / >10k script) outputs never added | coins.cpp:AddCoin:83–84; script.h:IsUnspendable:566 | | Satoshi | d=2; P |
| INV-113 | coinbase overwrite allowed (pre-BIP30 duplicates) | coins.cpp:AddCoins:136–137 | | BIP30 | d=3 |
| INV-114 | Coin = (out, coinbase?, height), spent ⇔ null out | coins.h:45–101 | data model | — | d=1; P |
| INV-115 | height encoding 31 bits, coinbase 1 bit | coins.h:77–89 | serialization invariant | — | d=1; P |
| INV-116 | undo records restore inputs on disconnect | validation.cpp:ApplyTxInUndo:2148–2174 | reorg correctness | — | d=3 |
| INV-117 | DisconnectBlock consistency (outputs match, BIP30 exceptions) | validation.cpp:DisconnectBlock:2178–2247 | reverse transition | BIP30 | d=3 |
| INV-118 | MEMPOOL_HEIGHT sentinel ≠ real height | txmempool.h:51; validation.cpp:198–200 | impl sentinel | — | d=1 |
| INV-119 | UTXO-set hash (MuHash3072) for assumeutxo | kernel/coinstats.cpp:59–112 | snapshot equality predicate | — | d=4; P |
| INV-120 | best-block pointer tracks coins state | coins.cpp:SetBestBlock:196; ConnectBlock:2652 | statefulness | — | d=1 |

### B.10 Activation machinery — `versionbits*`, `consensus/params.h`, `deploymentinfo.cpp`

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-121 | BIP9 FSM states & transitions | versionbits_impl.h:17–23; versionbits.cpp:GetStateFor:26–117 | DEFINED→STARTED→LOCKED_IN→ACTIVE / FAILED | BIP9 | inductive; d=4; P |
| INV-122 | signalling condition: top bits = 001 & bit set | versionbits_impl.h:79–82; versionbits.h:21–25 | | BIP9/BIP323 | d=1; P |
| INV-123 | STARTED→LOCKED_IN at threshold within period | versionbits.cpp:83–98 | count over 2016 | BIP9 | d=3; P |
| INV-124 | STARTED→FAILED at timeout (MTP) | versionbits.cpp:95–97 | | BIP9 | d=2; P |
| INV-125 | LOCKED_IN→ACTIVE at min_activation_height | versionbits.cpp:100–105 | | BIP9 | d=2; P |
| INV-126 | period alignment via GetAncestor((h+1)%period) | versionbits.cpp:44–47 | state cache semantics | BIP9 | d=3; P |
| INV-127 | Buried deployment heights (mainnet values) | kernel/chainparams.cpp:119–124; params.h:143–158 | BIP34 227931; BIP65 388381; BIP66 363725; CSV 419328; segwit 481824 | BIP90 | constants; d=1 |
| INV-128 | DERSIG flag gate | validation.cpp:GetBlockScriptFlags:2267–2270 | | BIP66 | d=1; P |
| INV-129 | CLTV flag gate | validation.cpp:2272–2275 | | BIP65 | d=1; P |
| INV-130 | CSV flag gate | validation.cpp:2277–2280 | | BIP112 | d=1; P |
| INV-131 | NULLDUMMY flag gate (with segwit) | validation.cpp:2282–2285 | | BIP147 | d=1; P |
| INV-132 | base flags P2SH+WITNESS+TAPROOT always on | validation.cpp:2261 | post-activation simplification | BIP16/141/341 | d=1; P |
| INV-133 | script_flag_exceptions (BIP16 & taproot exception blocks) | validation.cpp:2262–2265; kernel/chainparams.cpp:105–108 | historical carve-outs | BIP16 | d=2; P |
| INV-134 | BIP113 MTP gate on CSV deployment | validation.cpp:4141–4150 | | BIP113 | d=1; P |
| INV-135 | BIP34 gate via DEPLOYMENT_HEIGHTINCB | validation.cpp:4159–4167 | | BIP34/90 | d=1; P |
| INV-136 | segwit commitment validation gate | validation.cpp:4177 | | BIP141 | d=1; P |
| INV-137 | MinBIP9WarningHeight / unknown-version warnings | kernel/chainparams.cpp:125; versionbits.cpp:299–345 | warnings, NOT enforcement | BIP9 | non-consensus; d=1 |
| INV-138 | DeploymentEnabled/ActiveAt helpers | validation.h:1399–1416; deploymentstatus.h | API surface | BIP9 | d=1; P |
| INV-139 | BIP94 retarget base (first block of period) | pow.cpp:67–76 | testnet4 | BIP94 | d=2; P |

### B.11 Chain selection & reorg (spec-level rules, impl-flavored)

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-140 | best chain = most accumulated work | validation.cpp:ActivateBestChainStep:3199; chain.h:GetBlockProof:305 | work comparison | Satoshi | total work = Σ GetBlockProof; d=2; P |
| INV-141 | GetBlockProof from nBits compact | chain.h:305–308 → chain.cpp:GetBitsProof | work function | Satoshi | d=3; P |
| INV-142 | GetBlockProofEquivalentTime (for assumevalid 2wk check) | chain.h:311; validation.cpp:2363 | | — | d=2; P |
| INV-143 | invalid-block marking: descendants of invalid are invalid | validation.cpp:SetBlockFailureFlags:810; InvalidBlockFound:871 | failure propagation | — | d=3 |
| INV-144 | cached-invalid headers rejected | validation.cpp:AcceptBlockHeader:4207–4211 | | — | d=1 |
| INV-145 | header must connect to known, non-failed prev | validation.cpp:4221–4231 | prev-blk-not-found / bad-prevblk | — | d=1 |
| INV-146 | unrequested blocks: more-or-same-work, not-too-far-ahead, ≥ min chain work | validation.cpp:AcceptBlock:4326–4353 | anti-DoS, NOT consensus | — | d=2 |
| INV-147 | min_pow_checked gate for header persistence | validation.cpp:4237–4240 | anti-DoS, NOT consensus | — | d=1 |

### B.12 Trust shortcuts & caches (documented, out-of-scope)

| Rule ID | Check | Core location | Spec summary | BIP/CVE | Lean note |
|---|---|---|---|---|---|
| INV-148 | assumevalid: skip script checks under conditions (chain membership, best-header ancestry, chainwork ≥ min, 2wk eq-time) | validation.cpp:ConnectBlock:2345–2393 | trust option; other checks still enforced | — | d=2 |
| INV-149 | nMinimumChainWork (param) | kernel/chainparams.cpp:141; validation.cpp:4353,4288 | anti-DoS only | — | d=1 |
| INV-150 | assumeutxo snapshot: hash_serialized check before VALIDATED | validation.cpp:5985–6050; validation.h:526–533; kernel/chainparams.cpp:190–203 | bootstrap trust | — | d=3 |
| INV-151 | checkpoints: REMOVED (v30.0) | init.cpp:666–667 | historical note | — | d=1 |
| INV-152 | script execution cache must not alter acceptance | validation.cpp:CheckInputScripts:2077–2083 | cache-equivalence lemma | — | d=2 |
| INV-153 | signature cache must not alter acceptance | script/sigcache.h | cache-equivalence lemma | — | d=2 |
| INV-154 | CBlock::fChecked / m_checked_merkle_root memoization | validation.cpp:3930,3847,3881 | memoization-equivalence lemma | — | d=2 |
| INV-155 | fCacheResults=false when actually connecting (no stale-cache pollution) | validation.cpp:2574 | impl detail | — | d=1 |

### B.13 NOT consensus — policy & DoS catalogued (NOT formalized; boundary list)

| Rule ID | Check | Core location | Why excluded |
|---|---|---|---|
| INV-156 | IsStandard script types (P2PKH, P2SH, P2WPKH, P2WSH, P2TR, multisig, nulldata…) | policy/policy.cpp:80 | standardness: blocks with other types valid |
| INV-157 | IsStandardTx (version ≤ MAX_STANDARD_VERSION, size, bare multisig permit, nulldata ≤ 80 B) | policy/policy.cpp:100–263 | relay/mining policy |
| INV-158 | IsWitnessStandard (v0 stack ≤100 items ≤80 B; tapscript ≤ 80 B; annex rules; unknown-version discourage) | policy/policy.cpp:265–341; policy.h:54–60 | standardness |
| INV-159 | dust threshold (GetDustThreshold; 3 sat/vB default) | policy/policy.cpp (dust), policy.h:68 | standardness |
| INV-160 | min relay fee / incremental fee / RBF BIP125 | policy/rbf.cpp; policy.h:48,70 | mempool policy |
| INV-161 | package/cluster limits (25 anc/desc, cluster 64, 101 kvB) | policy/packages.cpp; policy.h:72–78 | mempool policy |
| INV-162 | MAX_STANDARD_TX_WEIGHT 400k; MIN_STANDARD_TX_NONWITNESS_SIZE 65 (CVE-2017-12842) | policy.h:38,40; validation.cpp:809 | standardness/DoS |
| INV-163 | TRUC (BIP431) topological restrictions | policy/truc_policy.cpp | standardness (nVersion=3) |
| INV-164 | P2A ephemeral anchors / ephemeral dust policy | policy/ephemeral_policy.cpp; BIP433 | standardness |
| INV-165 | sigop policy denominators (20 B/sigop; 2500 legacy cap) | policy.h:46,50 | standardness |
| INV-166 | coinbase additional sigops cap for templates (400) | policy.h:29 | mining template rule |
| INV-167 | orphanage limits (CVE-2012-3789) | node/txorphanage.cpp:350,381 | p2p DoS |
| INV-168 | header-sync anti-DoS (headerssync.cpp, 2h window consts) | headerssync.cpp:43–47 | p2p DoS |
| INV-169 | CCoinsViewErrorCatcher leveldb-error shutdown | coins.h:806–823 | availability, not rules (BIP50 lesson) |
| INV-170 | mempool.check() internal consistency assertions | validation.cpp:4473; txmempool.cpp | debug invariant |
| INV-171 | mempool expiry (336h default), trimming | validation.cpp:LimitMempoolSize:273–287 | policy |
| INV-172 | fee estimation freshness (3h tip age) | validation.cpp:101,289–301 | policy |
| INV-173 | pruning (MIN_BLOCKS_TO_KEEP 288, prune locks) | validation.h:76; validation.cpp:2718–2758 | storage |
| INV-174 | TestBlockValidity RPC/mining path (skips header index update) | validation.cpp:4478–4549 | alternate entry, same rules |
| INV-175 | bloom filter CVE-2013-5700 divide-by-zero | common/bloom.cpp:51,70 | p2p service |
| INV-176 | -checkpoints hidden arg no-op | init.cpp:666–667,953–956 | legacy CLI |

**Row count: 176** (INV-001…INV-176). Of these, INV-001…INV-159 + part of B.11 (~150 rows) are consensus / spec-relevant; INV-156…INV-176 (21 rows) are the explicit *not-consensus* catalogue.

---

*Report ends. All citations are against the pinned sources above.*
