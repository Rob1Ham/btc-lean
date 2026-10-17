# Proof build scope and status

`lake build BitcoinProofs` is the **default import closure**, not the whole
proof tree. It builds the root module plus its 28 direct/transitive local
imports: **29 modules**, recorded at **1722 jobs**. The package contains **410
Lean modules** (411 `.lean` files including `lakefile.lean`); **381 modules are
outside the default closure**.

This page records what was checked so that a default-root build is not mistaken
for a package-wide build.

## Default and per-module results

| Scope | Modules | Builds | Fails |
|---|---:|---:|---:|
| Default `BitcoinProofs` closure | 29 | 29 | 0 |
| Outside the default closure | 381 | 361 | 20 |
| — public theorem modules | 294 | 290 | 4 |
| — wallet proof modules | 22 | 22 | 0 |
| — tests / generated corpora | 31 | 23 | 8 |
| — audit / probes | 20 | 15 | 5 |
| — experiments / scratch | 14 | 11 | 3 |

The 410 modules include the 29 in the default closure. The 361/381 result is
from building each outside module by exact name against the pinned toolchain,
not from adding them to one target.

## Cited modules

Of the 183 outside-closure modules cited by `spec/db`, docs, or the wallet
record, **182 build** and **1 fails**: `BitcoinProofs.Theorems.Ops.O07`.
`SCR-100` cites `O07.step_codesep_const_dead`; its other tag carriers build,
but the cited target itself is not a passing build. This is disclosed rather
than hidden.

The four failing public-theorem modules are:

- `BitcoinProofs.Bip.B03.B03Subsidy`
- `BitcoinProofs.EcdsaDeep.PubKeyCor`
- `BitcoinProofs.Theorems.FuelStability`
- `BitcoinProofs.Theorems.Ops.O07`

The remaining 16 failures are test, audit/probe, or experiment/scratch
modules. They are not part of the default target, the public theorem surface,
or the wallet surface.

## What a clean build means

`BitcoinProofs` building means that the 29 default-closure modules elaborate
against the pinned Lean toolchain, mathlib revision, and core package. It does
**not** mean that all 410 proof modules were rebuilt, that every cited row
target builds, or that the Lean statements are faithful paraphrases of Bitcoin
Core. Statement fidelity is a separate review obligation, with the 26 known
consensus residuals in [`RESIDUALS.md`](RESIDUALS.md).

The static hygiene gate (`spec/scripts/sorry_lint.sh`) scans both
`spec/core` and `spec/proofs`, including modules outside the default closure.
It is a source-text gate, not a build of every module.
