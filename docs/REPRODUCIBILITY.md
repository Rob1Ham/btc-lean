# Reproducibility and toolchain

Snapshot: **2026-10-17**. This is a release snapshot, not an externally
audited artifact. This page records the pins and
commands needed to rebuild and re-check the candidate tree. It separates three
things that are easy to conflate: the Lean toolchain, the Lean model, and the
Bitcoin Core source pin used only for rule anchors.

## 0. Two different "core"s

* **`spec/core`** — the zero-dependency Lean package (`Bitcoin.*`). It is the
  executable model.
* **Bitcoin Core** — the C++ reference implementation at commit
  `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`. It is the source-of-truth pin for
  row anchors and optional differential testing. It is **not** a Lake
  dependency and is **not** required to build or check the Lean model.

The rest of this page says "Lean core" for the first and "Bitcoin Core" for the
second.

## 1. Exact pins

### 1.1 Lean toolchain

All three `lean-toolchain` files are byte-identical:

| File | Contents | SHA-256 |
|---|---|---|
| `spec/lean-toolchain` | `leanprover/lean4:v4.35.0` | `ead308ab4fc749eb2389819903fd7baa11bf06e490827f6896a8cbfe622fa703` |
| `spec/core/lean-toolchain` | same | same |
| `spec/proofs/lean-toolchain` | same | same |

Recorded toolchain:

```text
Lean (version 4.35.0, x86_64-unknown-linux-gnu,
      commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc, Release)
Lake version 5.0.0-src+eb6cafb (Lean version 4.35.0)
```

### 1.2 Lake manifests

| File | Packages | SHA-256 |
|---|---|---|
| `spec/lake-manifest.json` | `core` (path) only | `df3a505b5ddbaae11db70aae816fafc176950d9da86ab85a6c0f54a7963760ee` |
| `spec/core/lake-manifest.json` | none | `1597b2e1c43b2be1ea9e95786b56e1faab738d48d5bea4bded945dcd13e94067` |
| `spec/proofs/lake-manifest.json` | mathlib + eight transitive dependencies + `core` path | `e53a2c4d4fe1e22ebcbcf5bdca92376fa04518785d267ff4981af09e599ae5a0` |

The proofs manifest is authoritative. `spec/proofs/lakefile.lean` names mathlib
as a moving branch, but Lake resolves the revision recorded in the manifest as
long as the manifest is present and `lake update` is not run.

| Package | Revision |
|---|---|
| mathlib | `cfc55fc58714a59dc06e6e79edc6d1d95140d3c2` |
| plausible | `dfa4f38190d07c37e315953e08b90fe2d95b3c24` |
| LeanSearchClient | `d6b4c7be5be75ec4917c873ac50c756dc1436372` |
| importGraph | `a41f0e9a4dea23188ea9cc1c41ac9f8bbafe0b93` |
| proofwidgets | `df72b022e558978a1c50264cfc4d7fec86fa8e04` |
| aesop | `4a174c490d8707121c4a9290800489f105d85e07` |
| Qq | `dce0ad79c486cb1fb504af04f953c3466b0c6db8` |
| batteries | `66e469188fe07963e5cf666c7d4433f45b8131c5` |
| Cli | `c24fe6078c630e89b489bffe59b3e20ac30d12c8` |

### 1.3 Bitcoin Core reference pin

| Field | Value |
|---|---|
| Repository | `https://github.com/bitcoin/bitcoin.git` |
| Commit | `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` |
| Version | v32.99.0 (pre-release; `IS_RELEASE false`) |
| Commit date | 2026-10-15 17:15:30 +0900 |
| Subject | `Merge bitcoin/bitcoin#36379: fuzz: fix stale comments in http_request` |

Every `core_ref` in `spec/db/rules.yaml` uses the single short pin
`@cce32b168`. Verify the source before citing an anchor:

```sh
git clone --filter=blob:none https://github.com/bitcoin/bitcoin.git bitcoin-core
cd bitcoin-core
git checkout cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
test "$(git rev-parse HEAD)" = cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
```

The Lean build does not read this checkout. If an anchor review needs the C++
source, use the commit above or the same bytes from a local mirror.

## 2. Toolchain setup

`lake` reads the nearest `lean-toolchain` and asks elan for that exact
toolchain:

```sh
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh \
  | sh -s -- -y --default-toolchain leanprover/lean4:v4.35.0
export PATH="$HOME/.elan/bin:$PATH"

lean --version   # must print 4.35.0, commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc
lake --version   # must print Lake 5.0.0-src+eb6cafb
```

The installer script is fetched over HTTPS and is not content-pinned here; the
version and commit above are the authority.

## 3. Build

The core package has no Lake dependencies:

```sh
cd spec/core
lake build Bitcoin
# recorded: Build completed successfully (72 jobs).
```

The proof package uses mathlib as a leaf dependency. The first build downloads
and compiles mathlib and may take a long time and several GiB:

```sh
cd spec/proofs
lake build BitcoinProofs
# recorded: Build completed successfully (1722 jobs).
```

Do not use a bare `lake build`: it builds the default target and makes the
expected job count ambiguous. This Lake version has no `-j` flag. For a single
change, build the module that declares or imports it, for example:

```sh
cd spec/proofs
lake build BitcoinProofs.AF.PDW82.PDW82
```

The optional model test driver is separate from the 72-job core build:

```sh
cd spec/core
lake test
```

### Recorded build results

| Build | Target | Jobs | Result |
|---|---|---:|---|
| Lean core | `Bitcoin` | 72 | success |
| Proof root | `BitcoinProofs` | 1722 | success (29-module closure) |
| Proof modules outside default closure | exact module names | — | 361 pass / 20 fail; see `docs/PROOF-BUILD.md` |
| Wallet core modules | explicit `Bitcoin.Wallet.*` targets | 60 | success |
| Wallet proof modules | explicit `BitcoinProofs.Wallet.*` targets | 3230 | success |

Job counts are a build-health signal, not a mathematical invariant. Adding a
module or changing the import graph changes the count.

### Disk and memory

A checked-out tree with a prebuilt mathlib package needs roughly 6 GiB; a clean
build plus downloads and logs needs roughly 10 GiB more. The warm/no-op Lake
process uses under 1 GiB of RAM, but a parallel cold build benefits from 8 GiB
minimum and 16 GiB recommended. The release data bundle is additional disk.

## 4. Static and dynamic checks

```sh
make gates                         # all nine static gates; no Lean; 9/9 pass
CORE_SRC=/path/to/bitcoin/src bash spec/scripts/wallet_gates.sh
bash spec/scripts/axiom_manifest.sh # full #print axioms probe; needs Lean
```

`make gates` covers sorry lint, rule/tag cross-check, static axiom manifests,
the census fixed point, the 726-row census, overrides sync, the anchor pin, the
wallet static battery, and the tracked-data subset. The consensus dynamic probe
re-elaborates 223 consensus axiom entries; the wallet probe covers 844
theorem/lemma declarations. The wallet script also covers the 140-anchor census when
`CORE_SRC` is supplied, and runs the dynamic wallet axiom probe unless
`WALLET_SKIP_PROBE=1`. Neither dynamic probe is part of CI.

## 5. Data

The repository tracks a 161-file, 4,852,246-byte curated subset under
`spec/data/` with a `sha256` manifest. The data-only corpus and anchor blocks
are release assets, not git objects: the archive is
`btc-lean-data-2026.10.17.tar.gz` (357,916,214 bytes; SHA-256
`1ac846bdc24740cfdcf599c3ccf357e48bed50d7fd32071efae605d2a84168b8`), and the
content manifest is `release/manifest.sha256` (SHA-256
`6c2f51e44624cbff05340610d5168dd869dbf9dd6c03f45d0c01a2f3594eba07`).
See `docs/DATA.md`, `docs/MANIFEST-SPEC.md`, and `scripts/fetch_data.sh`. No
git-lfs is used.

## 6. What is not reproducible here

* The theorem statements are about the Lean model, not a byte-for-byte
  equivalence with Bitcoin Core. The C++ port and cryptographic primitives are
  supported by line-level review and conformance vectors, not by a theorem that
  Lean equals libsecp256k1.
* The forty tagged wallet rows include three with partial obligations; 99 rows
  are in the obligation register. See `docs/WALLET.md` and
  `docs/WALLET-OBLIGATIONS.md`.
* Twenty-six consensus rows are explicit model residuals. See
  `docs/RESIDUALS.md`.
* No external security audit or certification is claimed.
