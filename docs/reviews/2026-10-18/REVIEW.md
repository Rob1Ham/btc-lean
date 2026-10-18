# btc lean repository review and remediation plan

Review date: 2026-10-18, America/Chicago. Baseline: [`57607451faa168497d971e2d50e91dae7dafdafe`](https://github.com/Rob1Ham/btc-lean/tree/57607451faa168497d971e2d50e91dae7dafdafe), verified against GitHub `main`. The working tree was clean before these review artifacts were added.

The repository has useful executable definitions, explicit residual disclosures and working static checks. Its principal weakness is composition: the public block replay path does not enforce several consensus rules that exist as separate, proved helpers. Its evidence gates also permit changes that contradict the published proof contract. Fixing the remaining property fixtures alone will not close those gaps.

This review was initially prepared before implementation. The user subsequently authorized the goal, which remains active. [execution-ledger.json](execution-ledger.json) records current progress separately from the historical findings below. The remediation branch has integrated merged PRs 18 and 19 (upstream `08208274bcdcab2a5baa1426c0057472e5c0de07`). R01 input-value enforcement and R09/R10 proof-gate enforcement are fixed with regression evidence. R02 now enforces checked fee accumulation and the coinbase reward bound on the public serialized-block path: all 20 funding cases and 13 input-value cases pass, and the default proof root plus affected consumers build. See [validation-r02.json](validation-r02.json) for commands, source hashes, Core-pin comparison and exact limits. The remaining findings stay open until separately resolved.

The review covers architecture, live validation call paths, proof/build scope, issue and PR evidence, selected wallet/serialization boundaries, release handling and gate enforcement. It is not an exhaustive independent verification of every theorem or the cryptographic arithmetic.

## Deliverables

- [GOAL-PROMPT.txt](GOAL-PROMPT.txt): complete `/goal` command and completion contract used by the active goal.
- [backlog.json](backlog.json): issue/PR snapshot, comments, provenance, checks and finding inventory.
- [issue4-checklist.tsv](issue4-checklist.tsv): all 57 visible issue checkboxes with snapshot state and proposed triage.
- [issue16-census.tsv](issue16-census.tsv): all 726 attachment classifications alongside current census applicability, status and targets. Attachment labels remain unverified hypotheses.
- [reproduce_checks.py](reproduce_checks.py) and [reproduction-results.json](reproduction-results.json): isolated reproductions and results. Fixtures use temporary files and a local mock downloader; they do not contact a server or modify model sources.
- [validation-results.json](validation-results.json): commands, results and unavailable verification.

The goal has been activated using `GOAL-PROMPT.txt` as its detailed specification. Its outcome, evidence, constraints and completion conditions follow the [official Codex Goals guidance](https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex). The original GitHub and validation snapshots remain historical evidence; use the execution ledger for subsequent results.

## Open GitHub work

| Item | Current state and assessment |
|---|---|
| [Issue 4](https://github.com/Rob1Ham/btc-lean/issues/4) | Audit summary reports 185 findings. Its public body enumerates 57 checkboxes: 39 checked, 18 unchecked. Some unchecked items are already addressed on main: INV-119 is disclosed as an accepted additive abstraction, and the build-disclosure list was updated. Other items remain open. The headline severity totals are upstream claims, not independently confirmed totals for this review. |
| [Issue 16](https://github.com/Rob1Ham/btc-lean/issues/16) | Includes 14 numbered behavioral topics plus policy/network classification and preservation constraints. The [full attachment](https://github.com/user-attachments/files/33628941/btc-lean-mainnet-audit.md) enumerates all 726 rows: 554 “matches”, 30 “false rule”, 61 “incorrect rule”, 81 “not a consensus rule”. It audits an older btc-lean revision and a different Core revision. Some conclusions are superseded or wrong; BLK-016 is a concrete example below. |
| [PR 18](https://github.com/Rob1Ham/btc-lean/pull/18) | Head `bef0c50cef17f52c1c630f1dfe5e7e73d6549b22`, seven files, merge state **CONFLICTING**, no submitted reviews. The returned check rollup contains one successful static-gates check. The PR body reports seven targeted builds and a default proof build, but these are author-reported runs, not independently reproduced current-main evidence. |

PR 18 corrects the Y08/Y09 overflow fixtures, Z21 truthiness runner, Y12/Y15 expectations, and the Merkle 1..64 range. Those directions are consistent with the inspected definitions. The correct core `singleOverflowOneB` must remain unchanged. The PR also changes many Y12/Y15 checks to `native_decide`, and named `one256_eq_singleOverflowOneB`, `row_2`, `row_3` and `merkle_matrix_64` acquire compiler-trust proof footprints. The Merkle header discloses that change. Review and enforce the distinction between compiled checks and kernel-only claims before accepting the PR; rebuilding a small root import closure cannot settle that question.

The source baseline pins Bitcoin Core [`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`](https://github.com/bitcoin/bitcoin/tree/cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66). Issue 16 instead compares some functions at `9be056a8a72b624dae9623b2f7bded92c2a21c91`. Its rbitcoin/Hornet comparisons should guide investigation, not replace the repository's pinned normative source.

## Additional findings

P1 means a high-priority defect in the model's accepted behavior or claimed verification boundary. P2 means a material verification, reproducibility or public-interface gap. These priorities describe this specification artifact, not an exploit in a deployed Bitcoin node. Findings overlap where one architectural root cause affects several independently required rules.

### R01 P1 Input value validation is omitted from the live block fold

[`Capstone/Block.lean:294`](../../../spec/core/Bitcoin/Capstone/Block.lean#L294) calls `checkTransaction`, script verification and `applyTxStepL`. It never calls `checkTxInputs`. [`Ledger/Interface.lean:527`](../../../spec/core/Bitcoin/Ledger/Interface.lean#L527) only checks availability and maturity before updating coins. Neither gate compares input value to output value or range-checks input values and their running sum.

A non-coinbase transaction spending a 1-satoshi non-coinbase OP_TRUE coin into a 2-satoshi OP_TRUE output passes this per-transaction path, subject to the ordinary shape checks. Core's [`CheckTxInputs`](https://github.com/bitcoin/bitcoin/blob/cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66/src/consensus/tx_verify.cpp#L170) rejects it as `bad-txns-in-belowout`. The model already implements the missing check in [`TxValidation/Interface.lean:241`](../../../spec/core/Bitcoin/TxValidation/Interface.lean#L241). The module header's claim that this check runs in the fold is therefore misleading.

Call it on the current UTXO view before scripts, propagate its checked fee and prove the composed acceptance invariant. Regressions need inflation, negative/out-of-range input coins, aggregate input range and zero-fee valid boundaries. This is broader than issue 16's TXV-069 partial-fold discussion.

### R02 P1 Coinbase rewards and accumulated fees do not gate block acceptance

[`validateBlock:390`](../../../spec/core/Bitcoin/Capstone/Block.lean#L390) accepts immediately after the ledger/script fold. It neither computes validated total fees nor invokes [`cbAmountOk`](../../../spec/core/Bitcoin/Block/Connect.lean#L159) or `feeAccumInRange`. A well-formed coinbase may exceed the height's subsidy plus fees while remaining below transaction `MAX_MONEY` bounds. Core rejects that in [`ConnectBlock`](https://github.com/bitcoin/bitcoin/blob/cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66/src/validation.cpp#L2608).

Thread fees from R01, enforce the running fee range and coinbase reward bound, and test reward plus one satoshi, exact reward, halving transitions and excessive accumulated fees. Proving the standalone predicate does not connect it to this verdict.

### R03 P1 Block finality and BIP68 are absent from the replay verdict

The same [`validateBlock`](../../../spec/core/Bitcoin/Capstone/Block.lean#L334) path does not call `isFinalTx`, `blockFinalityOk` or `sequenceLocksOk`. `CapState` has no parent-MTP history. Script-level CLTV/CSV checks cannot substitute for transaction-level locktime and sequence-lock validation. Even the separate [`validateTx`](../../../spec/core/Bitcoin/TxValidation/Interface.lean#L571) checks only the height-domain projection of BIP68; its comments disclose the missing time domain.

Add explicit parent-chain time context and compose both BIP68 domains and absolute finality. Test a future locktime with non-final input sequences, height-lock boundary and a time-based 512-second sequence lock. Until composition exists, expose the replay's contextual limitations in its result.

### R04 P1 Header acceptance checks a self-declared target without expected difficulty or time context

[`validateBlock:349`](../../../spec/core/Bitcoin/Capstone/Block.lean#L349) checks compact-target shape, PoW and parent hash. It does not check the candidate bits against expected work, parent MTP or node-clock future bounds. Its state lacks the context needed to do so. A header satisfying an easier self-selected target is not necessarily valid at the claimed height. The missing guards are present in the pinned [`ContextualCheckBlockHeader`](https://github.com/bitcoin/bitcoin/blob/cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66/src/validation.cpp#L4096).

Provide a contextual validator with expected difficulty and chain/time data, or clearly separate a limited historical replay adapter from a consensus-validity API. Test wrong-but-in-range nBits, exact expected bits, retarget transitions and both timestamp boundaries. Issue 16's powLimit/work corrections do not fix this wiring gap.

### R05 P1 A mining-template convention incorrectly rejects valid commitment outputs

[`Capstone/Merkle.lean:176`](../../../spec/core/Bitcoin/Capstone/Merkle.lean#L176) defines `commitmentValueZero` over every matching output, and [`validateBlock:371`](../../../spec/core/Bitcoin/Capstone/Block.lean#L371) rejects when it is false. Core's [`CheckWitnessMalleation`](https://github.com/bitcoin/bitcoin/blob/cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66/src/validation.cpp#L3878) checks the selected output script, reserved-value shape and commitment hash; it does not require output value zero. Ordinary amount and reward bounds still apply.

BLK-016's current summary explicitly acknowledges that distinction, but the live code still enforces zero. Issue 16's attachment incorrectly labels BLK-016 a match. Remove this consensus rejection and classify the generation convention appropriately. Test a correctly funded nonzero matching output and multiple matching outputs, with the highest-index commitment selected.

### R06 P1 The unjudged witness shortcut bypasses structural validity too

[`verifyInput:255`](../../../spec/core/Bitcoin/Capstone/Block.lean#L255) returns `unjudgedTaproot` before reading scriptSig or witness for **every** native witness program with version at least one. The fold then accepts that input. Thus the shortcut covers more than expensive Taproot cryptography: a native version-1 program with a nonempty scriptSig or empty Taproot witness also avoids structural failure. The ordinary [`verifyScriptFull`](../../../spec/core/Bitcoin/Interpreter/Defs.lean#L1338) and [`verifyWitnessProgram`](../../../spec/core/Bitcoin/Interpreter/Defs.lean#L1242) already express those checks.

The general Taproot unjudged limitation is disclosed. This finding concerns the excess structural bypass and the `.ok` block result carrying unjudged inputs. Run adjudicable gates first and distinguish incomplete replay from a fully validated verdict. Real BIP340 verification is present, but [`RealChecker`](../../../spec/core/Bitcoin/Capstone/RealChecker.lean#L115) still supplies a `none` Schnorr sighash and script paths return `.unjudged`; repairing q-binding alone does not wire a complete Taproot spend path.

### R07 P1 Historical exemptions rely on height without proving canonicality

The live script path uses [`getBlockScriptFlags(height)`](../../../spec/core/Bitcoin/Activation/Interface.lean#L133), reducing flags for every candidate at heights 170060/692261. The BIP30 path uses [`bip30Enforced(height)`](../../../spec/core/Bitcoin/Ledger/Interface.lean#L351), exempting heights 91842/91880 and assuming canonical BIP34 ancestry in its skip window. Core's exceptions depend on actual hashes/ancestry. More faithful hash-aware helpers and conditional agreement theorems already exist in this repository.

These are documented canonical-chain abstractions, but `validateBlock` neither takes nor establishes their canonicality hypotheses. An alternate block at an exception height inherits exemptions it should not have. Thread candidate hash and ancestor evidence through the contextual path; test canonical and alternate hashes at every exception and the BIP30 re-enable boundary.

### R08 P1 Green CI does not elaborate or execute the Lean deliverable

The push/PR workflows [`gates.yml`](../../../.github/workflows/gates.yml), [`indexes.yml`](../../../.github/workflows/indexes.yml) and [`proof-scope.yml`](../../../.github/workflows/proof-scope.yml) perform static checks. [`release-verify.yml`](../../../.github/workflows/release-verify.yml) is manual and checks data assets, not Lean. There is no workflow building the model/proofs or running dynamic axiom checks. Main's three returned workflow results are green despite 15 documented failing proof modules.

The default proof closure covers 29 of 409 modules, so adding only `lake build BitcoinProofs` would leave the same broad blind spot. Add pinned builds for deliverable/cited modules, explicit tests/negative probes, core and wallet surfaces, and dynamic evidence checks. Capture resource failures separately from false propositions and do not silently omit failed modules.

### R09 P1 The consensus static axiom check accepts arbitrary custom axioms

[`axiom_manifest.sh:52`](../../../spec/scripts/axiom_manifest.sh#L52) validates line grammar and a few forbidden substrings. It does not require footprints to be subsets of `propext`, `Classical.choice`, `Quot.sound`, nor bind entries to a current probe or complete target set. An isolated manifest containing `'Test.unsound' depends on axioms: [ArbitraryFalseAxiom]` exits **0**. The wallet manifest checker already has a stronger allowlist/coverage design.

Enforce the actual allowlist, declaration/coverage integrity and dynamic elaboration. Manifest regeneration must not authorize a new axiom merely because the resulting text matches the probe.

### R10 P1 A SORRY tag permits a deliverable sorry through the hygiene gate

[`sorry_lint.py:169`](../../../spec/scripts/sorry_lint.py#L169) treats nearby `SORRY[...]` text as permission for a code `sorry` or `admit`. The static consensus manifest is not rebuilt in CI, so an unprobed theorem can acquire `sorryAx` while both checks remain green. The isolated fixture `-- SORRY[REVIEW]` followed by `theorem unsound : False := by sorry` exits **0**. The current baseline itself has zero `sorry`; this is an enforcement gap.

Reject every deliverable `sorry`/`admit`. Keep any research escape mechanism in an explicitly separate non-deliverable surface and add a negative regression for the tag bypass.

### R11 P2 Traceability checks presence of text rather than the cited declaration

[`rule_crosscheck.py:69`](../../../spec/scripts/rule_crosscheck.py#L69) requires a nonempty `lean_target` and an occurrence of the row tag somewhere in raw source. It never resolves the target or associates the tag with its declaration. A fixture with target `Does.Not.Exist` and only a block comment `/- @[rule "SCR-001"] -/` exits **0**. This is weaker than the README's description of declaration-level binding.

Parse actual code attributes, resolve targets/aliases, distinguish theorem evidence from definitions and elaborate every cited declaration. A negative test must reject comment-only tags, nonexistent targets and tags attached to a different declaration.

### R12 P2 Download extraction accepts unlisted payloads and special files

[`fetch_data.sh:264`](../../../scripts/fetch_data.sh#L264) rejects links but does not reject FIFOs/devices; the final hash check only verifies listed manifest entries. It never compares exact archive/extracted membership with the manifest. An archive containing one listed regular file, an unlisted regular file and a FIFO extracts successfully and prints “all checks passed”, even with a correct out-of-band transport pin.

The transport hash still binds the whole archive: this is not a claim that an attacker can bypass a trusted SHA-256 pin. The failure is the advertised data/regular-file/content-coverage policy. Reuse the stricter checks from `verify_release.sh`, add root/type allowlists, stage extraction, and test all unsupported member types and coverage mismatches.

### R13 P2 The documented source plus release handoff collides with current evidence

The README recommends extraction at the repository root. [`release/manifest.sha256`](../../../release/manifest.sha256) contains seven `spec/db/` paths that already exist in a checkout. At this baseline, the release hashes for `spec/db/rules.yaml` and `spec/db/axiom-manifest-wallet.txt` differ from current files. `--keep-old-files` therefore causes refusal or later checksum failure; `--force` can replace current audit metadata with older release contents.

A local fixture with a newer existing listed file reproduces exit **1**. The full published 358 MB archive was not downloaded in this review; the actual overlap and differing digests were checked against the committed release manifest. Stage and verify the bundle independently, then promote compatible vector payloads without restoring obsolete metadata. Preserve the immutable published release and document which source/data combinations are supported.

### R14 P2 The exported parser disabled set disagrees with the interpreter

[`Script/Parser/Defs.lean:62`](../../../spec/core/Bitcoin/Script/Parser/Defs.lean#L62) disables `0x9a` and omits `0x99`. [`Interpreter/Defs.lean:435`](../../../spec/core/Bitcoin/Interpreter/Defs.lean#L435) correctly disables `0x99`; its comment acknowledges the discrepancy. `0x99` is RSHIFT, while `0x9a` is enabled BOOLAND. Current execution uses the correct table, so this is not a demonstrated live interpreter acceptance bug. It is an incorrect exported model predicate and a parallel source of truth that parser-side theorems preserve.

Share the correct table and prove equivalence over all 256 opcode bytes. Keep BOOLAND enabled and test disabled opcodes in both executed and unexecuted branches.

### R15 P2 The independent Merkle reference generator is absent

[`MerkleShapes64.lean:10`](../../../spec/proofs/BitcoinProofs/Theorems/Exhaust/MerkleShapes64.lean#L10), also touched by PR 18, attributes expected roots to `scratch/M01/merkle_ref.py`. That script is not in the checkout. `make gate-repro` checks 23 selected inputs and does not require it. The fixed expected roots can still detect some regressions, but the claimed independent generation cannot be reproduced from the checked-in source.

Track a small independent generator with inputs and an exact regeneration command, verify the entire 1..64 matrix, and check other claimed independent references. The broader release-regeneration gap is already disclosed in HARNESS.md; this is a specific missing generator inside a maintained proof/property module.

### R16 P2 Evidence snapshots and descriptive counts are inconsistent

All **15** digests in [`interface-hashes.txt`](../../../spec/db/interface-hashes.txt) differ from current files. [`axiom-audit-rows.txt`](../../../spec/db/axiom-audit-rows.txt) still reports 14 unavailable targets and 34 stale target names from its 2026-10-17 snapshot, while the newer build disclosure says no cited module is among the 15 failures. Those records may describe different revisions; neither should be read as a current proof result without provenance and regeneration.

The current wallet static probe inventories **838** declarations, while README/TCB/CLAIMS still say **844**. The subset gate reports **4,852,280** tracked bytes, while README/CLAIMS say **4,852,246**. The proof lakefile still recommends `lake update` and describes a nonexistent bootstrap state, despite committed manifests and the README's contrary instructions. Generated indexes pass because these prose and historical-evidence surfaces are not all checked.

Record source/toolchain/data provenance for build and axiom outputs, refresh evidence intentionally, and generate or validate public counts. Decide whether the interface hashes are historical records or enforced current contracts and label/check them accordingly.

## Existing gaps that remain important

The 27 consensus residuals and the wallet register's 99 unproved rows are substantial, explicitly documented work. They are not 27/99 new discoveries. In particular, MuHash is an accepted additive abstraction, BIP32 agreement lacks a group-law bridge, PSBT signing/verification and whole-file round trips remain incomplete, and wallet funding helpers need caller preconditions. For example, `fundWithChange [1] [2] 1 100` returns a negative fee rather than an error; the arithmetic helper's conservation law does not make it a safe transaction constructor. Preserve these boundaries and add checked public wrappers if they become supported construction APIs.

Likewise, source-to-Core fidelity is not proved by a row tag, an axiom-light theorem or a finite vector pass. The census currently freezes 676 “proven” / 50 obsolete rows, including true model residuals and policy/network misclassifications. A remediation pass should update the status contract transparently if necessary rather than preserving a flattering count by weakening statements. The mainnet applicability problems in issue 16 remain directly observable: SCR-039 is labeled consensus while its summary calls it mempool policy; SCR-147/SCR-167 remain non-consensus despite describing Taproot validity; BIP94/signet rows remain broadly tagged consensus. SCR-051, in contrast, is already corrected to `consensus: false` and should not be patched again blindly.

## Verification performed and limits

| Check | Result |
|---|---|
| Repository/GitHub baseline and issue/PR discussions/diff | Read; local HEAD matches GitHub main. No issue comments/reviews were posted. |
| `make gates gate-repro` | Passed in a temporary Python 3.12 environment with PyYAML 6.0.2. Initial system-Python run stopped for missing PyYAML; it was rerun successfully. |
| Theorem/residual/proof-scope generated checks | Passed; 726 consensus rows, 140 wallet rows, 27 residuals, 409 proof modules and 29-module default closure. |
| Tracked data manifest | All 160 listed content hashes matched; the 161st tracked file is the manifest itself. |
| BIP32 independent Python corpus | 17 valid seed-derived rows recomputed, 16 invalid rows rejected. This is reference-corpus verification, not a Lean/Core differential run. |
| Python and shell syntax | 44 tracked Python files parsed, 25 tracked shell scripts passed `bash -n`. |
| ShellCheck warnings | Non-fatal cleanup findings: redundant LFS pattern in `check_subset_size.sh`, unused retry variable in `fetch_anchors.sh`. |
| Gate and extraction negative fixtures | Reproduced R09/R10/R11/R12 and the existing-file conflict in R13. All fixtures isolated from project sources. |
| Pinned Core source | Read `validation.cpp`, `script/interpreter.cpp`, `consensus/tx_verify.cpp` at the resolved repository pin. |
| Lean builds, model tests and dynamic axiom probes | Not run: Lean/lake/elan and build caches are absent in this environment. The documented 15 failures are historical repository evidence, not a fresh build result from this review. |
| Full published archive and anchor replay | Not downloaded/run. Manifest compatibility was checked locally; extraction defects used small controlled fixtures. |

The remediation order should be live monetary/contextual validation, strict partial-verdict handling, proof/gate enforcement and complete builds, PR 18 reconciliation, census policy/network corrections, then data/evidence reproducibility. The prepared goal includes concrete success criteria for those steps and keeps unsolved research obligations visible.
