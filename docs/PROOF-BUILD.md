# Proof build scope and status

`lake build BitcoinProofs` is the **default import closure**, not the whole
proof tree. It builds the root module plus its 35 direct/transitive local
imports: **36 modules**. The package contains **416
Lean modules** (417 `.lean` files including `lakefile.lean`); **380 modules are
outside the default closure**.

The generated static inventory is [`PROOF-SCOPE.md`](PROOF-SCOPE.md).

The R02 remediation run on 2026-10-18 built the default root plus the named
block-pipeline, generated-chain, PDW14, PDW29 and PDW61 consumers successfully
(1731 Lake jobs including dependencies). `CapstoneFunding` is a new default
import; it proves checked-fee range and the public coinbase subsidy bound.
See [validation-r02.json](reviews/2026-10-18/validation-r02.json) for exact
commands and evidence. This run does not verify the 380 outside modules.

The R04 run adds `CapstoneContext` to that default closure and builds the
public header-context and complete-MTP-window theorems with guarded standard
axiom footprints. The actual core build and compiled partial replay runner
also pass their builds. [validation-r04.json](reviews/2026-10-18/validation-r04.json)
records the checks and distinguishes unavailable replay input from success.

The R03 run adds `CapstoneSequence`: symbolic kernel proofs connect the
public contextual entry to absolute finality, both BIP68 domains at actual
intermediate views, and the checked-fee/subsidy bound. The exact commands and
baseline/public regressions are in
[validation-r03.json](reviews/2026-10-18/validation-r03.json).

The R17 live-budget run adds `CapstoneSigops`. Public success now implies
both the early legacy budget and an exact evolving-ledger sigop trace with
a final total at most 80,000. All eighteen new theorem footprints have
in-file guards and dynamic manifest entries using only the permitted axioms.
The default root and affected consumers passed the 1735-job scoped run;
after adding the guards, the root passed a 1728-job rebuild. All 53 wallet
probe imports built (3242 jobs); both dynamic probes passed (288 consensus,
838 wallet entries). These are scoped checks, not the outstanding complete
413-module matrix. See [validation-sigop-budget.json](reviews/2026-10-18/validation-sigop-budget.json).

The R05 run adds `CapstoneWitness`: ordered nonce/hash/unexpected-witness
verdicts, invariance under changing the actual coinbase output values, and
a public-success connection for both entries. Eleven new footprints are
pinned in-file and in the dynamic manifest (299 total entries, 385 lines).
Existing monetary, sequence, sigop and ledger contracts remain proved;
the incorrect witness-error mapping and its consumers were corrected. The default root plus named affected consumers build (1741 Lake jobs),
all 53 wallet probe imports build (3242 jobs), and both dynamic probes pass.
The fresh complete 416-module matrix remains
pending. Commands and exact limits are in
[validation-r05.json](reviews/2026-10-18/validation-r05.json).

The R06 run adds `WitnessSerialization` and `CapstoneTaproot`: kernel proofs
connect the actual witness encoder to the budget, the checked live-view input
cache to exact ordered amounts/scripts, and public script status to unjudged
counts. Real signed multi-input and same-block-spend regressions pass. Obsolete
universal bypass claims were removed, and typed-checker/state contracts were
corrected. The final scoped run builds all primary/wallet probe imports and every
changed proof module except the explicit `S02Flip` reduction experiment
(116 named targets, 3343 Lake jobs). The complete Z09 audit passes separately
(26 jobs, 165.379 seconds); S02 fixture declarations typecheck with its twenty
closed measurement experiments explicitly omitted. That partial interface
check is not a full S02 build. All sixteen new footprints are guarded; dynamic
probes cover 315 consensus and 836 wallet declarations. The complete
416-module matrix remains outstanding. Commands and bounds are in
[validation-r06.json](reviews/2026-10-18/validation-r06.json).

R18 corrects CSV's unsigned transaction-version comparison and the affected
version-gate proof statements. The new gate, wire-congruence and four high-bit
boundary claims use only `propext`, with exact in-file guards and dynamic
manifest entries. The scoped build includes the default root, all probe
imports and the affected BIP112/PDW46b/PDW68x/PDW6 consumers. Exact commands,
results and resource limits are in
[validation-r18.json](reviews/2026-10-18/validation-r18.json). The complete
core/proof/cited-target matrix remains R08 work.

The outside-closure results below are the upstream audit snapshot from before
PR 18 merged and before the remediation changes. They remain historical
results until the full module matrix is rerun under R08; the counts and failure
list must not be read as current-head verification.

## Upstream follow-up snapshot

Upstream commit `32e8463a47022307f4dc3e337bfdbb10999b7bcc` reports rerunning
the old 15-module failure set after PRs 18/19, leaving eight failures and
372 outside-closure passes. It records 1730 default-build jobs at its own
29-module root. These are upstream-reported results, not a fresh 380-module
run on this remediation branch. The eight reported remaining failures are:
`Audit.Z03.Probe`, `Audit.Z09.Corners`, `Bip.B03.B03Subsidy`,
`Bip.B10.Bip144Vectors`, `EcdsaDeep.DerBattery`, `EcdsaDeep.S02Flip`,
`Theorems.Audit.CV02` and `Theorems.FuelStabilityProbe` (all under
`BitcoinProofs`). Full current-head verification and evidence classification
remain R08 work; a compiler-evaluated fixture pass is not a kernel proof claim.

## Recorded upstream per-module results

The upstream 2026-10-18 audit reported every outside-closure module built by exact
name against the pinned Lean toolchain and mathlib revision:

```sh
cd spec/proofs
lake build <module>
```

Lake 5.0.0 rejects the `-j` option on `lake build`; the per-module command above
is the equivalent serial invocation. The run produced **365 passes and 15
failures** over the 380 outside-closure modules.

| Scope | Count | Builds | Fails |
|---|---:|---:|---:|
| Default `BitcoinProofs` closure | 36 modules | scoped current run | 0 |
| Outside the default closure | 381 entries (380 modules + `lakefile.lean`) | 365 | 15 |
| — `AF` namespace | 249 | 249 | 0 |
| — `Theorems` namespace | 24 | 21 | 3 |
| — `Wallet` namespace | 22 | 22 | 0 |
| — `EcdsaDeep` namespace | 20 | 18 | 2 |
| — `Audit` namespace | 18 | 14 | 4 |
| — `Property` namespace | 17 | 13 | 4 |
| — `Bip` namespace | 15 | 13 | 2 |
| — `ErrMap` namespace | 3 | 3 | 0 |
| — `Shortcuts` namespace | 3 | 3 | 0 |
| — `SmallCurve` namespace | 3 | 3 | 0 |
| — `Ledger` namespace | 2 | 2 | 0 |
| — `PDW9` namespace | 2 | 2 | 0 |
| — `Activation` namespace | 1 | 1 | 0 |
| — `Interpreter` namespace | 1 | 1 | 0 |

The historical 409-module snapshot included 29 in the default closure.
The current 416-module snapshot adds default `CapstoneFunding`,
`CapstoneContext`, `CapstoneSequence`, `CapstoneSigops` and `CapstoneWitness` modules. The outside-closure
table has 381 entries because it includes the non-module `lakefile.lean`, which
the static index excludes; `lakefile.lean` is the Lake build configuration, not
a module, so it is not built by name and the builds-plus-failures total is the
380 modules. The namespace rows are a fresh partition of those 380 modules,
not a re-use of the earlier five-way census categories.

## Failing modules

The upstream snapshot listed 15 failures outside the default closure and
reported no cited failures at that revision. Several were subsequently changed
by PR 18; this is a historical list awaiting current-head verification:

| Module | Observed failure |
|---|---|
| `BitcoinProofs.Audit.Z03.Audit` | unresolved `simp`/`decide` goals |
| `BitcoinProofs.Audit.Z03.Probe` | missing `DecidableEq`/`LawfulBEq` instances; false `decide` goal |
| `BitcoinProofs.Audit.Z09.Corners` | absent rewrite patterns; “no goals” |
| `BitcoinProofs.Audit.Z21.Audit` | `decide` fails to reduce |
| `BitcoinProofs.Bip.B03.B03Subsidy` | free variables, unknown tactic, unsolved goals |
| `BitcoinProofs.Bip.B10.Bip144Vectors` | Lean killed with exit 137 (out of memory) on retry |
| `BitcoinProofs.EcdsaDeep.DerBattery` | `import` after declarations |
| `BitcoinProofs.EcdsaDeep.S02Flip` | `decide` fails to reduce |
| `BitcoinProofs.Property.Y08.SighashLegacyProps` | `native_decide` evaluates the proposition as false |
| `BitcoinProofs.Property.Y09.Property` | `decide` proves the proposition false |
| `BitcoinProofs.Property.Y12.FoldProps` | Lean killed with exit 137 (out of memory) |
| `BitcoinProofs.Property.Y15.WitnessProps` | Lean killed with exit 137 (out of memory) |
| `BitcoinProofs.Theorems.Audit.CV02` | Lean killed with exit 137 (out of memory) |
| `BitcoinProofs.Theorems.Exhaust.MerkleShapes64` | type mismatch; maximum recursion depth |
| `BitcoinProofs.Theorems.FuelStabilityProbe` | deliberately failing probe (header says each `exact h` fails to dump a type) |

The earlier census of the same 381 outside-closure entries recorded 361 builds
and 20 failures. Those numbers are superseded by the fresh run above and are
not used elsewhere on this page. The historical census is retained only as
provenance; the static index does not regenerate it.

## Recorded upstream cited-module claims

The upstream snapshot reported no outside-closure cited module in its failing
set. This has not yet been verified package-wide on the remediation head.
In that snapshot, `SCR-100` cites
`O07.step_codesep_const_dead`; `BitcoinProofs.Theorems.Ops.O07` now builds, so
the single cited-target failure recorded by the earlier census is resolved.

The snapshot reported individual passes for six repaired modules:
`BitcoinProofs.SmallCurve.TweakCorSmall`,
`BitcoinProofs.EcdsaDeep.PubKeyCor`,
`BitcoinProofs.EcdsaDeep.PubKeyMatrix`,
`BitcoinProofs.EcdsaDeep.SmulCor`,
`BitcoinProofs.Theorems.Ops.O07`, and
`BitcoinProofs.Theorems.FuelStability`.

## What a clean build means

`BitcoinProofs` building means that the 34 default-closure modules elaborate
against the pinned Lean toolchain, mathlib revision, and core package. It does
**not** mean that all 416 proof modules were rebuilt, that every cited row
target builds, or that the Lean statements are faithful paraphrases of Bitcoin
Core. Statement fidelity is a separate review obligation, with the 26 known
consensus residuals in [`RESIDUALS.md`](RESIDUALS.md) and the accepted
proof-surface reductions in [`AUDIT-RESIDUALS.md`](AUDIT-RESIDUALS.md).

The static hygiene gate (`spec/scripts/sorry_lint.sh`) scans both
`spec/core` and `spec/proofs`, including modules outside the default closure.
It is a source-text gate, not a build of every module.

The core package also needs an explicit library matrix: its 131 tracked
`Bitcoin*.lean` files have a 72-module `Bitcoin` root import closure, leaving
59 outside that closure. The R19 compatibility-factory bug was exposed by
explicitly building one of those modules. The remaining core matrix is part
of R08 alongside the proof-package matrix. These counts describe static
imports, not a full source-validation result.
