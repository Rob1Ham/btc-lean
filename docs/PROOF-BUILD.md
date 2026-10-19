# Proof build scope and status

`lake build BitcoinProofs` is the **default import closure**, not the whole
proof tree. It builds the root module plus its 36 direct/transitive local
imports: **37 modules**. The historical baseline recorded **1722 jobs**; the
current validated build reports **1,732 jobs** (2026-10-18).
The package contains **417 Lean modules** (418 `.lean` files including
`lakefile.lean`); **380 modules are outside the default closure**.

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
**365 passes and 15 failures** over the 380 outside-closure modules. Re-running
that failure set after the source-audit fixes leaves **7 failures**, so the
recorded outside-closure status is **373 passes and 7 failures**. During
closeout, `AF.PDW62b.PDW62b` was found to have stale axiom pins; it was
repaired and now builds, and is not counted in the recorded table below.

| Scope | Count | Builds | Fails |
|---|---:|---:|---:|
| Default `BitcoinProofs` closure | 37 modules | 37 | 0 |
| Outside the default closure | 381 entries (380 modules + `lakefile.lean`) | 373 | 7 |
| — `AF` namespace | 249 | 249 | 0 |
| — `Theorems` namespace | 24 | 22 | 2 |
| — `Wallet` namespace | 22 | 22 | 0 |
| — `EcdsaDeep` namespace | 20 | 18 | 2 |
| — `Audit` namespace | 18 | 16 | 2 |
| — `Property` namespace | 17 | 17 | 0 |
| — `Bip` namespace | 15 | 13 | 2 |
| — `ErrMap` namespace | 3 | 3 | 0 |
| — `Shortcuts` namespace | 3 | 3 | 0 |
| — `SmallCurve` namespace | 3 | 3 | 0 |
| — `Ledger` namespace | 2 | 2 | 0 |
| — `PDW9` namespace | 2 | 2 | 0 |
| — `Activation` namespace | 1 | 1 | 0 |
| — `Interpreter` namespace | 1 | 1 | 0 |

The 417 modules include the 37 in the default closure. The outside-closure
table has 381 entries because it includes the non-module `lakefile.lean`, which
the static index excludes; `lakefile.lean` is the Lake build configuration, not
a module, so it is not built by name and the builds-plus-failures total is the
380 modules. The candidate adds modules to the default closure without changing the
380-module outside-closure count. After the BIP-42 module and the B03 repair,
the recorded status is 373/7; `AF.PDW62b.PDW62b` is an additional closeout
regression that has been repaired. The namespace rows are the post-audit partition of those 380 modules,
not a re-use of the earlier five-way census categories.

## Failing modules

All 7 recorded failures are outside the default closure. None is cited by
`spec/db`, the docs, or the wallet record. The failure list is:

| Module | Observed failure |
|---|---|
| `BitcoinProofs.Audit.Z03.Probe` | missing `DecidableEq`/`LawfulBEq` instances; false `decide` goal |
| `BitcoinProofs.Audit.Z09.Corners` | absent rewrite patterns; “no goals” |
| `BitcoinProofs.Bip.B10.Bip144Vectors` | stale staged vector decode (`rfl` mismatches); the signedness fix is covered in `Bip144.lean` |
| `BitcoinProofs.EcdsaDeep.DerBattery` | generated table is not valid Lean (`import` after declarations / missing `def`) |
| `BitcoinProofs.EcdsaDeep.S02Flip` | `decide` fails to reduce |
| `BitcoinProofs.Theorems.Audit.CV02` | Lean killed with exit 137 (out of memory) |
| `BitcoinProofs.Theorems.FuelStabilityProbe` | deliberately failing probe (header says each `exact h` fails to dump a type) |

The earlier census of the same 381 outside-closure entries recorded 361 builds
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

`BitcoinProofs` building means that the 36 default-closure modules elaborate
against the pinned Lean toolchain, mathlib revision, and core package. It does
**not** mean that all 417 proof modules were rebuilt, that every cited row
target builds, or that the Lean statements are faithful paraphrases of Bitcoin
Core. Statement fidelity is a separate review obligation, with the 18 known
consensus residuals in [`RESIDUALS.md`](RESIDUALS.md) and the accepted
proof-surface reductions in [`AUDIT-RESIDUALS.md`](AUDIT-RESIDUALS.md).

The static hygiene gate (`spec/scripts/sorry_lint.sh`) scans both
`spec/core` and `spec/proofs`, including modules outside the default closure.
It is a source-text gate, not a build of every module.
