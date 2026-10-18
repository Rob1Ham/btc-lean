# Proof build scope and status

`lake build BitcoinProofs` is the **default import closure**, not the whole
proof tree. It builds the root module plus its 28 direct/transitive local
imports: **29 modules**, recorded at **1722 jobs**. The package contains **409
Lean modules** (410 `.lean` files including `lakefile.lean`); **380 modules are
outside the default closure**.

The generated static inventory is [`PROOF-SCOPE.md`](PROOF-SCOPE.md).

This page records what was checked so that a default-root build is not mistaken
for a package-wide build.

## Default and per-module results

| Scope | Count | Builds | Fails |
|---|---:|---:|---:|
| Default `BitcoinProofs` closure | 29 modules | 29 | 0 |
| Outside the default closure | 381 entries (380 modules + `lakefile.lean`) | 361 | 20 |
| — public theorem modules | 294 | 290 | 4 |
| — wallet proof modules | 22 | 22 | 0 |
| — tests / generated corpora | 31 | 23 | 8 |
| — audit / probes | 20 | 15 | 5 |
| — experiments / scratch | 14 | 11 | 3 |

The 409 modules include the 29 in the default closure. The build census totals
381 outside-closure entries (361 builds, 20 failures): the 380 outside modules
plus the non-module `lakefile.lean`, which the earlier `.lean`-file count
treated as a module and which the static index excludes. Build results are from
building each module by exact name against the pinned toolchain, not from adding
them to one target. The five subcategory rows partition the same 381-entry
historical census (294 + 22 + 31 + 20 + 14), so they also total 381; they are
retained as recorded and are not recomputed by the static index.

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
**not** mean that all 409 proof modules were rebuilt, that every cited row
target builds, or that the Lean statements are faithful paraphrases of Bitcoin
Core. Statement fidelity is a separate review obligation, with the 26 known
consensus residuals in [`RESIDUALS.md`](RESIDUALS.md).

The static hygiene gate (`spec/scripts/sorry_lint.sh`) scans both
`spec/core` and `spec/proofs`, including modules outside the default closure.
It is a source-text gate, not a build of every module.
