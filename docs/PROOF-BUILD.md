# Proof build scope and status

`lake build BitcoinProofs` is the **default import closure**, not the whole
proof tree. It builds the root module plus its 28 direct/transitive local
imports: **29 modules**, recorded at **1722 jobs**. The package contains **409
Lean modules** (410 `.lean` files including `lakefile.lean`); **380 modules are
outside the default closure**.

The generated static inventory is [`PROOF-SCOPE.md`](PROOF-SCOPE.md).

This page records what was checked so that a default-root build is not mistaken
for a package-wide build. It also replaces the earlier per-name census numbers
with a fresh exact re-run of every outside-closure module.

## Fresh exact per-module results

On 2026-10-18 every outside-closure module was built individually by exact
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
| Default `BitcoinProofs` closure | 29 modules | 29 | 0 |
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

The 409 modules include the 29 in the default closure. The outside-closure
table has 381 entries because it includes the non-module `lakefile.lean`, which
the static index excludes; `lakefile.lean` is the Lake build configuration, not
a module, so it is not built by name and the builds-plus-failures total is the
380 modules. The namespace rows are a fresh partition of those 380 modules,
not a re-use of the earlier five-way census categories.

## Failing modules

All 15 failures are outside the default closure. None is cited by `spec/db`,
the docs, or the wallet record, and none imports a module changed in this
pass. The failure list is:

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

## Cited modules

No outside-closure module cited by `spec/db`, the docs, or the wallet record is
in the failing set. In particular, `SCR-100` cites
`O07.step_codesep_const_dead`; `BitcoinProofs.Theorems.Ops.O07` now builds, so
the single cited-target failure recorded by the earlier census is resolved.

The six modules repaired while reconciling this build all pass individually:
`BitcoinProofs.SmallCurve.TweakCorSmall`,
`BitcoinProofs.EcdsaDeep.PubKeyCor`,
`BitcoinProofs.EcdsaDeep.PubKeyMatrix`,
`BitcoinProofs.EcdsaDeep.SmulCor`,
`BitcoinProofs.Theorems.Ops.O07`, and
`BitcoinProofs.Theorems.FuelStability`.

## What a clean build means

`BitcoinProofs` building means that the 29 default-closure modules elaborate
against the pinned Lean toolchain, mathlib revision, and core package. It does
**not** mean that all 409 proof modules were rebuilt, that every cited row
target builds, or that the Lean statements are faithful paraphrases of Bitcoin
Core. Statement fidelity is a separate review obligation, with the 27 known
consensus residuals in [`RESIDUALS.md`](RESIDUALS.md) and the accepted
proof-surface reductions in [`AUDIT-RESIDUALS.md`](AUDIT-RESIDUALS.md).

The static hygiene gate (`spec/scripts/sorry_lint.sh`) scans both
`spec/core` and `spec/proofs`, including modules outside the default closure.
It is a source-text gate, not a build of every module.
