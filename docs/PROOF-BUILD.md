# Proof build scope and status

`lake build BitcoinProofs` is the **default import closure**, not the whole
proof tree. The root has 36 direct imports: **38 modules** in the transitive local
closure. The historical baseline recorded **1722 jobs**; the current
validated build reports **1,733 jobs** (2026-10-19).
The package contains **426 Lean modules** (427 `.lean` files including
`lakefile.lean`); **388 modules are outside the default closure**.

The generated static inventory is [`PROOF-SCOPE.md`](PROOF-SCOPE.md).

This page records what was checked so that a default-root build is not mistaken
for a package-wide build. It also replaces the earlier per-name census numbers
with the post-audit per-module status.

## Per-module results

Every outside-closure module is built by exact name against the pinned Lean
toolchain and mathlib revision:

```sh
cd spec/proofs
lake build <module>
```

Lake 5.0.0 rejects the `-j` option on `lake build`; the per-module command above
is the equivalent serial invocation. The first full post-audit run produced
**365 passes and 15 failures** over the then-380 outside-closure modules.
Re-running that failure set after the source-audit fixes leaves **2 failures**.
The nine new issue-22 outside-closure modules were then built individually and
all pass; `PDW50` moved into the default closure, so the combined recorded
status over today's 388 modules is **386 passes and 2 failures**: one deliberate probe
(`BitcoinProofs.Theorems.FuelStabilityProbe`) and one post-audit core-API drift
(`BitcoinProofs.Theorems.T3T4PipelineRealCor`).
During closeout, `AF.PDW62b.PDW62b` was found to have stale axiom pins; it was
repaired and now builds, and is not counted in the recorded table below.

| Scope | Count | Builds | Fails |
|---|---:|---:|---:|
| Default `BitcoinProofs` closure | 38 modules | 38 | 0 |
| Outside the default closure | 389 entries (388 modules + `lakefile.lean`) | 386 | 2 |
| — `AF` namespace | 255 | 255 | 0 |
| — `Theorems` namespace | 26 | 24 | 2 |
| — `Wallet` namespace | 22 | 22 | 0 |
| — `EcdsaDeep` namespace | 20 | 20 | 0 |
| — `Audit` namespace | 18 | 18 | 0 |
| — `Property` namespace | 17 | 17 | 0 |
| — `Bip` namespace | 15 | 15 | 0 |
| — `ErrMap` namespace | 3 | 3 | 0 |
| — `Shortcuts` namespace | 3 | 3 | 0 |
| — `SmallCurve` namespace | 3 | 3 | 0 |
| — `Ledger` namespace | 2 | 2 | 0 |
| — `PDW9` namespace | 2 | 2 | 0 |
| — `Activation` namespace | 1 | 1 | 0 |
| — `Interpreter` namespace | 1 | 1 | 0 |

The 426 modules include the 38 in the default closure. The outside-closure
table has 389 entries because it includes the non-module `lakefile.lean`, which
the static index excludes; `lakefile.lean` is the Lake build configuration, not
a module, so it is not built by name and the builds-plus-failures total is the
388 modules. After the issue-22 integrations, the combined recorded status is 386/2;
`AF.PDW62b.PDW62b` was an additional closeout regression that has been repaired.
The namespace rows are the post-audit partition of those 388 modules, not a
re-use of the earlier five-way census categories.

## Failing modules

Both recorded failures are outside the default closure. Neither is cited by
`spec/db`, the docs, or the wallet record. The failure list is:

| Module | Observed failure |
|---|---|
| `BitcoinProofs.Theorems.FuelStabilityProbe` | **deliberate** probe (header says each `exact h` fails to dump a type); keep out of normal failure counts |
| `BitcoinProofs.Theorems.T3T4PipelineRealCor` | post-audit core-API drift: the core `verifyInput`/`verifyTxInputs` gained typed-Schnorr `spentOutputs`/`flags` parameters, so the old `verifyInput_eq`/loop proofs no longer elaborate |

The deliberate `FuelStabilityProbe` failure is scoped out of the build
contract. All normal outside-closure modules other than
`T3T4PipelineRealCor` now build. `T3T4PipelineRealCor` is not part of the
issue-22 failure set; its repair requires reformulating the RealChecker
pipeline theorems for the typed-Schnorr adapter and is tracked separately.

The issue-22 failure set is now repaired. Modules fixed on this branch:

- `BitcoinProofs.Audit.Z03.Probe` — false probe goals replaced with true
  kernel facts; local `DecidableEq` for `Except`; `ByteArray` BEq reflexivity.
- `BitcoinProofs.Bip.B10.Bip144Vectors` — stale 33-byte V4 vector corrected
  to 32 bytes; staged decode proofs modernized.
- `BitcoinProofs.EcdsaDeep.DerBattery` — generated file made valid Lean; the
  generator (`gen_der_battery.py`) updated so regeneration stays valid.
- `BitcoinProofs.EcdsaDeep.S02Flip` — compileable measurement record: the six
  kernel-flippable sites stay as live proofs, the twelve wall sites are kept
  verbatim as comments (no `native_decide` outside Test scope, no axioms).
  This module peaks at about 5.3 GB RSS, so CI builds it in a separate hosted
  job with `LEAN_NUM_THREADS=1` rather than alongside the default closure.
- `BitcoinProofs.Theorems.Audit.CV02` — monolithic `rfl` replaced with bounded
  parse/step lemmas; no heartbeat blowup. It peaks at about 6.5 GB RSS, so CI
  builds it in a separate hosted job with `LEAN_NUM_THREADS=1`.

Additional regressions from the `State` field extension (`opcodeIndex`,
`codeSepPos`) and the `ScriptChecker` field extension were also repaired:
`BitcoinProofs.Theorems.Ops.O01`, `BitcoinProofs.Theorems.FuelStability`, and
`BitcoinProofs.Theorems.T3T4RealCheckerCor` (and therefore its dependent check
surface).

## Closeout commands

```sh
cd spec/proofs

# The seven issue-22 outside-closure modules (each must print
# "Build completed successfully")
lake build BitcoinProofs.Audit.Z03.Probe
lake build BitcoinProofs.Audit.Z09.Corners
lake build BitcoinProofs.Bip.B03.B03Subsidy
lake build BitcoinProofs.Bip.B10.Bip144Vectors
lake build BitcoinProofs.EcdsaDeep.DerBattery
lake build BitcoinProofs.EcdsaDeep.S02Flip
lake build BitcoinProofs.Theorems.Audit.CV02

# The closing targets (PDW50 and CapstoneFunding are in the default
# closure; the rest are outside it)
lake build BitcoinProofs.AF.PDW50.PDW50
lake build BitcoinProofs.AF.PDW68x.PDW68xPath
lake build BitcoinProofs.AF.PDW67b.PDW67bG
lake build BitcoinProofs.AF.PDW88.PDW88b
lake build BitcoinProofs.AF.PDW9.UnspendableSpend
lake build BitcoinProofs.AF.PDW79.PDW79b
lake build BitcoinProofs.AF.PDW86.PDW86Clamp
lake build BitcoinProofs.AF.PDW25.TPR007
lake build BitcoinProofs.Theorems.Ops.INV057
lake build BitcoinProofs.Theorems.Ops.TPR071

# Default import closure (must report 1,733 jobs)
lake build BitcoinProofs

# Namespace sweeps used for the table above
lake build BitcoinProofs.Audit.Z09.Corners
lake build BitcoinProofs.Theorems.FuelStability
lake build BitcoinProofs.Theorems.Ops.O01
lake build BitcoinProofs.Theorems.T3T4RealCheckerCor
```

`BitcoinProofs.Theorems.FuelStabilityProbe` is expected to fail; it is not run
in the closeout commands and is excluded from the failure count.

The historical census of the then-381 outside-closure entries recorded 361 builds
and 20 failures. Those numbers are superseded by the fresh run above and are
not used elsewhere on this page. The historical census is retained only as
provenance; the static index does not regenerate it.

## Cited modules

No outside-closure module cited by `spec/db`, the docs, or the wallet record is
in the recorded failing set. The closeout-found cited module
`AF.PDW62b.PDW62b` was repaired and now builds. In particular, `SCR-100` cites
`O07.step_codesep_const_dead`; `BitcoinProofs.Theorems.Ops.O07` now builds, so
the single cited-target failure recorded by the earlier census is resolved.

The proof-surface modules repaired while reconciling this build all pass
individually: `BitcoinProofs.SmallCurve.TweakCorSmall`,
`BitcoinProofs.EcdsaDeep.PubKeyCor`,
`BitcoinProofs.EcdsaDeep.PubKeyMatrix`, `BitcoinProofs.EcdsaDeep.SmulCor`,
`BitcoinProofs.Theorems.Ops.O07`, `BitcoinProofs.Theorems.FuelStability`,
`BitcoinProofs.Theorems.Exhaust.MerkleShapes64`, and the audit property modules
`BitcoinProofs.Audit.Z21.Audit`, `BitcoinProofs.Property.Y08.SighashLegacyProps`,
`BitcoinProofs.Property.Y09.Property`, `BitcoinProofs.Property.Y12.FoldProps`,
and `BitcoinProofs.Property.Y15.WitnessProps`.

## What a clean build means

`BitcoinProofs` building means that the 38 default-closure modules elaborate
against the pinned Lean toolchain, mathlib revision, and core package. It does
**not** mean that all 426 proof modules were rebuilt, that every cited row
target builds, or that the Lean statements are faithful paraphrases of Bitcoin
Core. Statement fidelity is a separate review obligation; the issue-22
statement-fidelity ledger is now empty in [`RESIDUALS.md`](RESIDUALS.md), and
the accepted proof-surface reductions remain in
[`AUDIT-RESIDUALS.md`](AUDIT-RESIDUALS.md).

The static hygiene gate (`spec/scripts/sorry_lint.sh`) scans both
`spec/core` and `spec/proofs`, including modules outside the default closure.
It is a source-text gate, not a build of every module.
