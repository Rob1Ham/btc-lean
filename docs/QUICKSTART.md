# Quick start

`btc-lean` is a Lean 4 formalization of Bitcoin consensus rules. The
executable model is `spec/core` (namespace `Bitcoin.*`, no Lake dependencies);
the theorem package is `spec/proofs` (`BitcoinProofs.*`, mathlib as a leaf
dependency); the rule census is `spec/db/rules.yaml`.

## 1. Check the tree without Lean

Python 3.12+ with PyYAML is enough for the static gates:

```sh
python3 -m pip install PyYAML==6.0.2
make gates
make gate-repro
```

This checks the nine static gates: the core sorry/hazard lint, the `@[rule]`/census
cross-check, the static axiom manifest, the `rules.yaml` regeneration fixed
point, the 726-row census, the override mirror, the single Core anchor pin, the
wallet static battery, and the tracked-data subset. It does not build Lean. The
candidate passes 9/9 and prints `gates: all nine static gates passed`.
`make gate-repro` is a separate, Lean-free check of the reference scripts and
local-path hygiene.

## 2. Build the executable model

Install the pinned toolchain with elan (see `docs/REPRODUCIBILITY.md`), then:

```sh
cd spec/core
lake build Bitcoin
# recorded: Build completed successfully (72 jobs).
```

The optional test driver is `lake test`.

## 3. Build the theorems

Mathlib is large and is downloaded on the first build:

```sh
cd spec/proofs
lake build BitcoinProofs
# recorded: Build completed successfully (1722 jobs).
# validated on 2026-10-18: 1,731 jobs.
# 36-module default import closure, not all 416 proof modules.
```

Do not run `lake update`; the committed `lake-manifest.json` is the pin. A
fresh per-name run covers the 380 outside-closure modules (381 `.lean` entries
when the non-module `lakefile.lean` is counted): the recorded per-name census
is 372 builds and 8 failures; none of the recorded failures is a cited target.
The closeout-found `AF.PDW62b.PDW62b` failure has been repaired. See [`PROOF-BUILD.md`](PROOF-BUILD.md).

## 4. Wallet layer

The wallet layer is separate from consensus and has its own census:

```sh
CORE_SRC=/path/to/bitcoin/src bash spec/scripts/wallet_gates.sh
```

Without `CORE_SRC`, the 140-anchor census check is skipped; the tag, sorry,
isolation, and axiom checks still run. Wallet modules are built by explicit
targets, for example:

```sh
cd spec/proofs
lake build BitcoinProofs.Wallet.Desc.Checksum
```

## 5. Data

The repository tracks a 161-file, 4,852,246-byte curated subset under
`spec/data/` with a SHA-256 manifest. The data-only corpus and anchor blocks
are release assets: the archive is `btc-lean-data-2026.10.17.tar.gz`
(357,916,214 bytes; SHA-256
`1ac846bdc24740cfdcf599c3ccf357e48bed50d7fd32071efae605d2a84168b8`) and the
content manifest is `release/manifest.sha256` (SHA-256
`6c2f51e44624cbff05340610d5168dd869dbf9dd6c03f45d0c01a2f3594eba07`).

```sh
bash scripts/fetch_data.sh --base-url https://github.com/Rob1Ham/btc-lean/releases/download --extract .
```

See `docs/DATA.md`.

## 6. Where to look next

| Topic | Path |
|---|---|
| Census and row dispositions | `spec/db/rules.yaml` |
| Explicit model residuals | `docs/RESIDUALS.md` |
| Claims and what they do not mean | `docs/CLAIMS.md` |
| Trust base | `docs/TCB.md` |
| Wallet coverage | `docs/WALLET.md`, `docs/WALLET-OBLIGATIONS.md` |
| Reproducibility and pins | `docs/REPRODUCIBILITY.md` |
| Candidate tree layout | `docs/STRUCTURE.md` |
| Release data contract | `docs/DATA.md`, `docs/MANIFEST-SPEC.md`, `release/README.md` |
