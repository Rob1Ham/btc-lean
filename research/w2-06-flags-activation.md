# Consensus flags & activation

Date: 2026-10-16 · Status: **COMPLETE**

---

## 1. Executive summary

1. **`getBlockScriptFlags` is real.** The previously frozen `opaque … := sorry` stub in
   `Bitcoin/Activation/Interface.lean` is now a compiled `def` that transliterates
   Core's `GetBlockScriptFlags` (validation.cpp:2249-2288 @ master, fetched
   2026-10-16) for mainnet: base = P2SH|WITNESS|TAPROOT, two named exception
   blocks REPLACE the base, then DERSIG/CLTV/CSV/NULLDUMMY are OR-ed in by
   buried height. A Core-faithful **hash-keyed** general port
   (`Bitcoin.Activation.Flags.getBlockScriptFlagsP` over a `ChainParams` record)
   is proved to agree with the frozen height-keyed version on mainnet.
2. **7 consensus flags, exactly.** {P2SH, DERSIG, CLTV, CSV, NULLDUMMY, WITNESS,
   TAPROOT} as a Bool-record (`ScriptFlags`, unchanged shape) plus the exact
   `verify_flags.h` bit values (`flagBits`: 1, 4, 16, 512, 1024, 2048, 131072 —
   base set 0x20801, full set 0x20E15). The eight **policy-only** flags
   (LOW_S, STRICTENC, MINIMALDATA, MINIMALIF-v0, NULLFAIL, CLEANSTACK,
   CONST_SCRIPTCODE, WITNESS_PUBKEYTYPE — BIP146 never activated) are catalogued
   as `PolicyFlag`/`FullFlags` with `policy_absent_from_consensus`, and the
   load-bearing **BIP342 re-import** ("tapscript makes MINIMALIF and CLEANSTACK
   consensus regardless of the policy bits") is captured as
   `tapscript_reimports_policy` (item b).
3. **Dormant BIP9 machine** ported: `ThresholdState` (unchanged inductive),
   `bip9StateByPeriod`/`bip9State` (period-aligned structural recursion),
   `bip9Transition` with Core's **count test before timeout test** ordering
   (`count_beats_timeout` — the 2017 erratum, BLK-077), min_activation gate
   (`bip9_min_activation`, BLK-078), sentinel encodings of
   ALWAYS_ACTIVE/NEVER_ACTIVE (`bip9_always_active`/`bip9_never_active`, BLK-079),
   and the mainnet table: exactly one deployment (testdummy, bit 28, NEVER_ACTIVE,
   NO_TIMEOUT, 1815/2016, BLK-081) with a dormancy theorem
   (`mainnet_2026_exactly_one_dormant`).
4. **All 17 consensus rows implemented/proven + tagged:** SCR-015/016,
   BLK-070..081 (minus 082, other networks), BLK-083..088 now
   carry `@[rule]` attributes with `lean_target`s, cross-checked against the rule database. The
   8 policy rows SCR-175..182 and SCR-183 are NEW rows introduced by this
   report (Appendix B, extracted via a new SOURCES entry in `extract_rules.py`).
5. **17 checks PASS** in two new harnesses (`spec/Test/Activation/FlagsTest.lean`
   9 checks, `Bip9Test.lean` 8 checks) run by `spec/Test/Activation/run.sh`;
   every vector is also a build-time `decide`-verified `example`; 16 headline
   theorems carry `#guard_msgs in #print axioms` fingerprints —
   **no `sorryAx`, no `Classical.choice` anywhere** (max fingerprint:
   `[propext, Quot.sound]`).
6. **One interface change** against the earlier freeze (7 corrections, all documented in
   the Interface header and §3): BIP147 rides SEGWIT at 481824; the exception
   blocks are 170060/692261 (hash-keyed in Core; the earlier [173805, 176360] are not
   Core exception blocks); `flags_after_burial` needs an exception hypothesis;
   `flags_exception_blocks`/`flags_monotone` restated; `lockin_survives_timeout`
   gains a no-overflow hypothesis. `spec/db/interface-hashes.txt` updated.
7. Gates: build and tests green for all Activation modules (the one remaining
   full-repo build failure is in `Serialization/Interface.lean` — an unrelated
   in-flight edit, untouched here); sorry-lint, axiom-manifest, and
   rule-crosscheck all green (Appendix B.15).

## 2. Key findings

- **F1 (VERIFIED).** Core's `GetBlockScriptFlags` (validation.cpp:2249-2288 @
  master 2026-10-16; same function at :2249 @cce32b168) has this exact shape:
  `base := P2SH|WITNESS|TAPROOT`; `if (hash in script_flag_exceptions) flags :=
  exceptions.at(hash)` (REPLACE — :2262-2265); then OR-in DERSIG
  (`BIP66Height ≤ height`, :2266-2269), CLTV (:2271-2274), CSV (:2276-2278),
  NULLDUMMY (`SegwitHeight ≤ height`, :2280-2283). The exception hit REPLACES
  the base BEFORE the buried ORs — order is load-bearing (BLK-084) and is
  encoded in `getBlockScriptFlagsP`.
- **F2 (VERIFIED, §2.2).** The exception map is keyed by BLOCK HASH, not height
  (kernel/chainparams.cpp:115-118). The earlier frozen `BIP16_EXCEPTION_BLOCKS =
  [173805, 176360]` matches no Core data — those are the BIP16 *voting*
  window boundaries, not exception blocks. The real entries are height 170060
  (BIP16-violating block, SCRIPT_VERIFY_NONE) and height 692261 (taproot-
  violating block, P2SH|WITNESS); both height↔hash pairs re-verified
  bidirectionally against a public block explorer API on 2026-10-16 (§2.2).
- **F3 (VERIFIED).** NULLDUMMY is NOT a buried deployment of its own — it rides
  segwit (`DeploymentActiveAt(DEPLOYMENT_SEGWIT)` at validation.cpp:2280-2283).
  The earlier `BIP147_HEIGHT := 419328` was Core's CSVHeight. Interface now has
  `CSV_HEIGHT := 419328`, `SEGWIT_HEIGHT := BIP147_HEIGHT := 481824`.
- **F4 (VERIFIED).** The count test precedes the timeout test in `GetStateFor`'s
  STARTED branch (versionbits.cpp:93 vs :95 @ master; the pinned report cited
  :104-110 — line anchors DRIFTED, content unchanged): a deployment reaching
  threshold in the period ending exactly at its timeout LOCKS IN. Theorem
  `count_beats_timeout` pins this; the 2017 BIP9 erratum is honored.
- **F5 (VERIFIED).** LOCKED_IN→ACTIVE (versionbits.cpp:100-104) never consults
  the timeout: `lockin_then_active` (min_activation = 0) and, for the frozen
  surface, `lockin_survives_timeout` — whose `hto` hypothesis is deliberately
  unused (documented in the theorem comment; with min_activation 0 activation
  is unconditional). The frozen statement additionally needed a UInt32
  no-overflow hypothesis `hno` for the height casts to be sound.
- **F6 (VERIFIED).** `DeploymentActiveAt` for buried deployments is the plain
  inclusive compare `height ≥ since` (deploymentstatus.h:27-31) — encoded as
  `buriedActive` with `buriedActive_true/_false` (BLK-072).
- **F7 (VERIFIED).** Mainnet has exactly ONE BIP9 deployment entry (testdummy,
  chainparams.cpp:128-134): bit 28, `nStartTime = NEVER_ACTIVE` (−2),
  `nTimeout = NO_TIMEOUT` (int64-max — mapped to the unreachable height 2³²−1
  in our abstraction), `min_activation_height = 0`, threshold 1815 (90%),
  period 2016. Dormancy is therefore a one-line theorem via the NEVER_ACTIVE
  sentinel short-circuit (versionbits.cpp:40-42): **no mainnet soft fork is in
  the signalling pipeline** as of 2026-10-16.
- **F8 (VERIFIED, toolchain).** Lean 4.34.1 core has no `ring`/`by_contra`;
  `omega`/`decide`/`by_cases` suffice. UInt32 bitwise ops (`&&&`, `>>>`,
  `<<<`, `|||`) evaluate fine under `decide`; `Nat` division by a *variable*
  is opaque to `omega` — route through `Nat.div_pos` first (pattern recorded
  in `bip9State_next_period`).
- **F9 (VERIFIED, infra).** `lake build Bitcoin.Activation.Flags` works as a
  module target even though `lean_lib Bitcoin`'s glob is root-only, and
  `lake env lean --run ../Test/Activation/X.lean` runs files outside the
  package from `spec/core` — so new modules need no edits to shared files
  (`Bitcoin.lean` import closure untouched; a later import-closure update will add them).
- **F10 (VERIFIED).** `#guard_msgs in #print axioms` needs the EXACT expected
  message as the preceding docstring (`info: '…' depends on axioms: […]` /
  `'…' does not depend on any axioms`); theorem fingerprints are `[propext,
  Quot.sound]` when `simp` is used and empty when the proof is `decide`/`rfl`-
  only.

### 2.2 Height↔hash verification of the two exception blocks (F2)

Both directions queried against `blockstream.info/api` on **2026-10-16**:

| query | result |
|---|---|
| `GET /api/block-height/170060` | `00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22` = Core's BIP16 exception hash ✓ |
| `GET /api/block-height/692261` | `0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad` = Core's taproot exception hash ✓ |
| `GET /api/block-height/227931` | `000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8` = Core's `BIP34Hash` ✓ |

The frozen interface keys exceptions by HEIGHT — sound on mainnet (canonical
chain: one block per height); the hash-keyed ground truth is
`Flags.mainnetExceptionMap`, and `mainnet_height_hash_agree` proves the two
models coincide given the height↔hash correspondence for the two named blocks.

## 3. Interface changes against the earlier freeze

All changes are in `Bitcoin/Activation/Interface.lean` (header documents them
inline); `spec/db/interface-hashes.txt` line for `core/Bitcoin/Activation/
Interface.lean` updated to sha256 `5094815c…e4b35b4`.

1. **`BIP147_HEIGHT` 419328 → 481824** (F3) + new `CSV_HEIGHT := 419328`,
   `SEGWIT_HEIGHT := 481824`. Frozen value was Core's CSVHeight; NULLDUMMY
   rides segwit (validation.cpp:2280-2283).
2. **`BIP16_EXCEPTION_BLOCKS` [173805,176360] → [170060,692261]** (F2) + new
   `BIP16_EXCEPTION_HEIGHT`/`TAPROOT_EXCEPTION_HEIGHT`/`EXCEPTION_HEIGHTS`.
   Core keys by hash; hashes live in `Flags.bip16ExceptionHash`/
   `taprootExceptionHash` (verified §2.2).
3. **`flags_after_burial` + hypothesis `height ∉ EXCEPTION_HEIGHTS`**: block
   692261 is above every buried height yet DROPS TAPROOT, so the frozen
   unqualified statement was false.
4. **`flags_exception_blocks` restated** to what is true of both exception
   blocks (`taproot = false`); exact per-block vectors are
   `flags_bip16_exception` / `flags_taproot_exception`.
5. **`flags_monotone` restated pointwise** (per-field implications, both
   endpoints off the exception list): the frozen `∀ f : ScriptFlags → Bool`
   form is equivalent to flag-set equality (take `f := (· = flags h₁)`),
   which is false across activation heights.
6. **`getBlockScriptFlags` is a real `def`** (was `opaque … := sorry` — per the
   earlier finding F3, a sorry-stubbed non-function constant panics at module init).
7. **`lockin_survives_timeout` + no-overflow hypothesis `hno`** (`h.toNat +
   period.toNat + period.toNat < 2³²`) — needed for the UInt32→Nat casts in
   the proof; `hto` deliberately unused (F5).

`ScriptFlags` and `ThresholdState` are **unchanged verbatim** (frozen
consumers: `Bitcoin.Interpreter.Interface`, `Bitcoin.TxValidation.Interface`).
No shared file (`Bitcoin.lean`, other interfaces) was touched; new modules
`Flags.lean`/`Bip9.lean` are reachable via module-target builds + the test
runner until they are wired into the import closure.

## 4. Handoff notes

### Script interpreter (flags drive EvalScript/VerifyScript)
- Consume `Activation.ScriptFlags` (unchanged) or `Flags.FullFlags` if you want
  policy checks in the same pass: `FullFlags.consensus` = block-validation set,
  `FullFlags.policy` = the 8 policy bits, defaults off
  (`policy_absent_from_consensus`).
- **Tapscript corner (SCR-183):** your MINIMALIF/CLEANSTACK enforcement must
  key on `SigVersion.tapscript` *in addition to* the policy bits — use
  `minimalIfRequired`/`cleanStackRequired` (proved for tapscript, and proved
  policy-only for base/witnessV0 by `minimalif_policy_only_off_tapscript`).
- NULLDUMMY enforcement (OP_CHECKMULTISIG dummy-element must be empty) is
  gated on `nullDummy` which equals segwit activation — tests at 481823/481824
  in `FlagsTest.lean` are the boundary vectors.
- DERSIG/LOW_S/STRICTENC interplay: DERSIG is consensus (BLK-085);
  LOW_S/STRICTENC stay policy — `PolicyFlag` is the catalogue to diff against.

### BIP34 height gate & activation context
- `buried_heights_mainnet` gives all five buried heights + the BIP34 hash
  (`Flags.bip34ActivationHash`, BLK-070); the coinbase-height↔BIP34Hash
  comparison should use `BlockHash := Nat` hex-literal equality (see
  `Flags.lean` for the idiom).
- `buriedActive` is the sanctioned height-compare (inclusive, BLK-072).
- If the height-gate work needs testnet4/regtest deployment rows (BLK-082), the
  `Bip9Deployment` record + `Bip9Params` machinery are ready; only the
  per-network tables are missing.

### Audit notes
- Vector table: Appendix B.17 (12 heights × flagBits, all runtime-checked).
- Axiom fingerprints: 16 pins across the two test files; max
  `[propext, Quot.sound]`.
- Drift warning: Core master line anchors moved vs the pinned cce32b168 reports
  (`GetStateFor` now starts :26, count/timeout tests :93/:95). Re-anchor on
  rebase.

## 5. Open questions & risks

- **OPEN-1 (routing):** BLK-082 (testnet4/regtest deployment tables) is NOT
  done here — the per-network tables remain; the machinery is done.
- **OPEN-2 (frozen-surface scope):** the height-keyed `getBlockScriptFlags`
  hardcodes mainnet params. Fine for frozen consumers; consumers should call
  `Flags.getBlockScriptFlagsP` (or `mainnet_height_hash_agree` justifies either).
- **OPEN-3 (deprecation noise):** core Lean 4.34.1 deprecates `if_pos`/`if_neg`
  in favor of `ite_eq_left/right`; this report's proofs use the deprecated
  forms (warnings, not errors). Sweep opportunistically.
- **RISK-1:** the full-repo `lake build` and the global sorry-lint currently
  fail in `Serialization/Interface.lean` (:721 build, :727/:729 untagged
  sorries — an unrelated uncommitted in-flight edit, untouched here);
  all Activation modules + their dependents build green and lint clean. The
  build and sorry-lint gates for this module are judged on
  `lake build Bitcoin.Activation.{Interface,Flags,Bip9}` + both harnesses +
  zero Activation sorries.
- **RISK-2:** `count` in `Bip9Params` is an opaque function `Nat → Nat`
  (period-indexed); the MTP-monotonicity argument that makes the
  time→height abstraction faithful is cited (validation.cpp counts MTP), not
  mechanized — a proof gap for the audit trail, low priority (dormant
  machine).

## 6. Recommendations

1. Script interpreter: adopt `FullFlags` + `minimalIfRequired`/`cleanStackRequired` for
   tapscript; otherwise flags need no new modeling.
2. Keep new-module development off `Bitcoin.lean` (F9 pattern: module-target
   builds + `Test/**/run.sh`) until the change lands, then a single import-closure
   commit.
3. When Core's deployment table grows, BLK-081's dormancy theorem is the
   regression: a new ACTIVE mainnet deployment must update
   `mainnetDeployments` AND retire `mainnet_2026_exactly_one_dormant`.

---

## Appendix A — Sources

All Core references fetched from **master on 2026-10-16** (line anchors noted
where they drifted from the pinned cce32b168 reports):

- `src/validation.cpp` — `GetBlockScriptFlags` :2249-2288 (base :2256-2260,
  exception replace :2262-2265, DERSIG :2266-2269, CLTV :2271-2274,
  CSV :2276-2278, NULLDUMMY/segwit :2280-2283); `ContextualCheckBlock` callers
  (unchanged)
- `src/kernel/chainparams.cpp` — `script_flag_exceptions` :115-118 (two
  hash-keyed mainnet entries), `BIP34Height/Hash` :119-120, buried heights
  :117-124, mainnet `vDeployments[DEPLOYMENT_TESTDUMMY]` :128-134
- `src/versionbits.cpp` — sentinels :37-42, alignment :49-51, `GetStateFor`
  :83-124 (defined :57-63, count test :93, timeout test :95,
  LOCKED_IN→ACTIVE :100-104); `Condition()` :79-82
- `src/deploymentstatus.h` — `DeploymentActiveAt` buried compare :27-31
- `src/consensus/params.h` — `BIP9Deployment::ALWAYS_ACTIVE`/`NEVER_ACTIVE`/
  `NO_TIMEOUT`; `verify_flags.h` — flag bit values (P2SH=1«0, DERSIG=1«2,
  NULLDUMMY=1«4, CLTV=1«9, CSV=1«10, WITNESS=1«11, TAPROOT=1«17)
- BIP9 (+ 2017 erratum), BIP16, BIP34, BIP65, BIP66, BIP90, BIP112, BIP147,
  BIP141, BIP146 (never activated), BIP342 §5/§8 (MINIMALIF/CLEANSTACK
  re-import)
- Block explorer API `blockstream.info/api` (height↔hash, §2.2, 2026-10-16)
- Prior art: the frozen-interface notes,
  `research/06-script-interpreter.md` / `08-block-pow-utxo.md` / 
  `09-segwit-taproot.md` Appendix B (rule row definitions)
- Lean 4.34.1 toolchain sources (UInt32 bit lemmas, `Nat.div_pos`, omega
  support)

---

## Appendix B — Rule tables & artifacts

### B.1 Tapscript re-import (consensus — new row)

| Rule ID | check | core location | one-line spec | BIP/CVE | diff |
|---|---|---|---|---|---|
| SCR-183 | Tapscript MINIMALIF+CLEANSTACK re-import | script/interpreter.cpp:MINIMALIF+VerifyStack TAPSCRIPT branches; BIP342 §8 | for SigVersion::TAPSCRIPT minimal-IF and clean-stack are consensus requirements regardless of the policy flags | BIP342 | 2 |

### B.12 Policy-only flag catalogue (NOT consensus — new rows)

| Rule ID | check | core location | one-line spec | BIP/CVE | diff |
|---|---|---|---|---|---|
| SCR-175 | LOW_S policy-only | script/interpreter.cpp flag-gated | SCRIPT_VERIFY_LOW_S is mempool policy, never in GetBlockScriptFlags | BIP146 | 1 |
| SCR-176 | STRICTENC policy-only | script/interpreter.cpp flag-gated | SCRIPT_VERIFY_STRICTENC is policy (hybrid/hybrid pubkey rejection) | BIP146 | 1 |
| SCR-177 | MINIMALDATA policy-only | script/interpreter.cpp flag-gated | SCRIPT_VERIFY_MINIMALDATA is policy (push minimality) | BIP146 | 1 |
| SCR-178 | MINIMALIF v0-only | script/interpreter.cpp MINIMALIF branch | SCRIPT_VERIFY_MINIMALIF applies to v0 witness spends only; tapscript re-imports it (SCR-183) | BIP146+342 | 2 |
| SCR-179 | NULLFAIL policy-only | script/interpreter.cpp flag-gated | SCRIPT_VERIFY_NULLFAIL is policy (empty sig must fail check) | BIP146 | 1 |
| SCR-180 | CLEANSTACK policy-only | script/interpreter.cpp flag-gated | SCRIPT_VERIFY_CLEANSTACK is policy for base/v0; tapscript re-imports it (SCR-183) | BIP146 | 1 |
| SCR-181 | CONST_SCRIPTCODE policy-only | script/interpreter.cpp flag-gated | SCRIPT_VERIFY_CONST_SCRIPTCODE is policy (no OP_CODESEPARATOR evolution) | — | 1 |
| SCR-182 | WITNESS_PUBKEYTYPE policy-only | script/interpreter.cpp flag-gated | SCRIPT_VERIFY_WITNESS_PUBKEYTYPE is policy (compressed keys) | — | 1 |

### B.14 Final tree (new files only)

```
spec/core/Bitcoin/Activation/Flags.lean        (hash-keyed port, policy catalogue)
spec/core/Bitcoin/Activation/Bip9.lean         (signal predicate, deployment table)
spec/core/Bitcoin/Activation/Interface.lean    (REWRITTEN — interface-change)
spec/Test/Activation/FlagsTest.lean
spec/Test/Activation/Bip9Test.lean
spec/Test/Activation/run.sh
```

### B.15 Gate outputs

```
$ cd spec/core && lake build Bitcoin.Activation.Interface Bitcoin.Activation.Flags Bitcoin.Activation.Bip9
Build completed successfully (9 jobs).        # (if_pos/if_neg deprecation warnings only)

$ cd spec && bash Test/Activation/run.sh
== FlagsTest ==
[PASS] genesis flags = P2SH|WITNESS|TAPROOT
[PASS] BIP16 exception block 170060 = SCRIPT_VERIFY_NONE
[PASS] taproot exception block 692261 = P2SH|WITNESS+buried, no TAPROOT
[PASS] buried boundaries 363725/388381/419328/481824 all inclusive
[PASS] taproot era 709632 = all 7 flags (bits 0x20E15)
[PASS] hash-keyed port agrees with height-keyed interface
[PASS] mainnet buried heights
[PASS] policy flags absent from consensus view
[PASS] tapscript re-imports MINIMALIF/CLEANSTACK
== Bip9Test ==
[PASS] toy machine: STARTED,STARTED,LOCKED_IN,ACTIVE,ACTIVE
[PASS] lock-in at the timeout boundary (BLK-077 erratum corner)
[PASS] bip9State period-alignment at chain heights
[PASS] timeout without threshold ⇒ FAILED
[PASS] min_activation_height holds LOCKED_IN
[PASS] mainnet testdummy dormant at every height
[PASS] mainnet deployment table: exactly one entry
[PASS] BIP9 signal predicate vectors

$ bash spec/scripts/sorry_lint.sh
sorry-lint: 52 sorry occurrences, 50 tagged, 2 untagged
  # untagged: Serialization/Interface.lean:727/729 — an unrelated
  # in-flight uncommitted edit; not this module's scope (RISK-1). Activation/**: 0 sorries.
sorry-lint: native_decide violations: 0; unsafe/partial/FFI hazards: 0
sorry-lint: OK

$ bash spec/scripts/axiom_manifest.sh
axiom-manifest: OK (22 lines)                 # probe unchanged; this module pins its own
                                              # 16 fingerprints via #guard_msgs

$ python3 spec/scripts/rule_crosscheck.py
rule DB: 715 rows; Lean @[rule] attributes: 70 ids / 70 attributes
  BLK: 130 rows | implemented 19 | tagged 19
  INV: 176 rows | implemented 15 | tagged 15
  SCR: 183 rows | implemented 11 | tagged 12
  SWT: 68 rows | implemented 2 | tagged 2
  TPR: 83 rows | implemented 0 | tagged 0
  TXV: 75 rows | implemented 22 | tagged 22
rule-crosscheck: OK
```
(Exact counts re-printed in the commit; the `--check-only` regeneration diff
covers the new flags/activation SOURCES entry + OVERRIDES.)

### B.17 Flag-vector table (runtime-evaluated; see §B.15 harness)

| height | event | flags (verify_flags bits) | hex |
|---|---|---|---|
| 0 | genesis | P2SH·WITNESS·TAPROOT | 0x20801 |
| 170060 | **BIP16 exception block** | none | 0x0 |
| 173805 | (stale "exception" from the earlier freeze — actually normal) | base | 0x20801 |
| 227931 | BIP34 buried (no script-flag effect) | base | 0x20801 |
| 363724 | last pre-BIP66 | base | 0x20801 |
| 363725 | BIP66 boundary (inclusive) | +DERSIG | 0x20805 |
| 388381 | BIP65 boundary | +DERSIG+CLTV | 0x20A05 |
| 419328 | CSV boundary | +DERSIG+CLTV+CSV | 0x20E05 |
| 481823 | last pre-segwit | … | 0x20E05 |
| 481824 | segwit boundary (NULLDUMMY rides, BLK-088) | +NULLDUMMY | 0x20E15 |
| 692261 | **taproot exception block** | P2SH·WITNESS+buried, no TAPROOT | 0xE15 |
| 709632 | taproot era | all 7 | 0x20E15 |

BIP9 walk (toy machine, period 3 — Bip9Test.lean): DEFINED → STARTED (k=0,
h=2) → STARTED (k=1) → LOCKED_IN (k=2, h=8 = deadline, count test first —
BLK-077) → ACTIVE (k=3) → ACTIVE (k=4); failed variant: FAILED at deadline;
delayed variant (min_activation 100): LOCKED_IN held. Mainnet: testdummy
FAILED at every height, any count (`mainnet_2026_exactly_one_dormant`).

### B.18 Axiom fingerprints (all 16 #guard_msgs pins)

```
flags_after_burial        [propext, Quot.sound]     flags_bip16_exception     (none)
flags_taproot_exception   (none)                    flags_monotone            [propext, Quot.sound]
lockin_then_active        [propext, Quot.sound]     bip9_always_active        (none)
bip9_never_active         (none)                    buried_heights_mainnet    (none)
mainnet_height_hash_agree [propext]                 bip9_threshold_locks_in   (none)
bip9_timeout_fails        [propext, Quot.sound]     count_beats_timeout       (none)
bip9_min_activation       [propext, Quot.sound]     bip9_genesis_defined      (none)
lockin_survives_timeout   [propext, Quot.sound]     bip9State_next_period     [propext, Quot.sound]
```
No `sorryAx`, no `Classical.choice`, no native axioms. All proofs are honest
`decide`/`omega`/`simp`/explicit-term proofs; zero `sorry` in
`Activation/**` (the 79 pre-existing tagged sorries are elsewhere).

---

**VERIFIED vs PROPOSED:** Everything in §1–§3 marked (VERIFIED) is checked
against Core master fetched 2026-10-16 (§2.2 table) or machine-checked by the
Lean kernel (Appendix B.15/B.18). PROPOSED (not machine-checked here): the
MTP-monotonicity argument behind the time→height abstraction (§5 RISK-2) and
the exact policy-flag `core_loc` line numbers in B.12 (cited coarsely as
"flag-gated @master-2026-10-16"; the *policy-only* classification is
VERIFIED — none of the 8 appear in `GetBlockScriptFlags`).
