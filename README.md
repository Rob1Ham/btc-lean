# btc-lean — a machine-checked Lean 4 model of Bitcoin consensus

**Status: release snapshot (2026-10-17).** This tree is a release candidate
artifact, not a production node or an externally audited product. The data
release is distributed separately as checksum-pinned assets
(see [Data and release assets](#data-and-release-assets)).

btc-lean is a machine-checked Lean 4 model of Bitcoin consensus rules. The
executable model lives in `spec/core` as a zero-dependency Lean package; the
theorem package in `spec/proofs` proves properties about those same
definitions. The generated consensus theorem index is
[`docs/THEOREMS.md`](docs/THEOREMS.md); the wallet index is
[`docs/WALLET-THEOREMS.md`](docs/WALLET-THEOREMS.md). Traceability is a
row-by-row rule census in
`spec/db/rules.yaml`: each row records a Bitcoin Core reference, a BIP/CVE
attribution, the Lean declaration that carries the row's `@[rule "<ID>"]`
tag, and its test-vector selectors. The consensus census has **726 rows:
676 proven and 50 obsolete**, with no implemented or planned rows. Twenty-six
of the proven rows are **explicit model residuals**: the row claim is true of
Bitcoin Core, but the current Lean model does not yet entail it. They are
listed in [`docs/RESIDUALS.md`](docs/RESIDUALS.md) and the generated
[`docs/RESIDUALS-EVIDENCE.md`](docs/RESIDUALS-EVIDENCE.md). A second, independent
wallet census (`spec/db/rules-wallet.yaml`, **140 rows**) records wallet
construction and signing behaviour; it has its own gates and is never merged
into the consensus census. This is a model of consensus rules, not an
implementation of bitcoind — see [Scope and non-claims](#scope-and-non-claims).

## Census

The consensus census is `spec/db/rules.yaml`. Its contract is enforced by
`spec/scripts/gate_census.py`.

| Metric | Count |
|---|---:|
| Rows | 726 |
| Proven | 676 |
| Obsolete | 50 |
| Implemented | 0 |
| Planned | 0 |

| Namespace | Proven | Obsolete |
|---|---:|---:|
| INV | 139 | 37 |
| TXV | 75 | 0 |
| SCR | 183 | 0 |
| SGN | 11 | 0 |
| SWT | 67 | 1 |
| TPR | 71 | 12 |
| BLK | 130 | 0 |
| **Total** | **676** | **50** |

These are **rule-row dispositions, not theorem-declaration counts**. A
`proven` row names at least one Lean declaration carrying that row's
`@[rule]` tag; the tag-to-row relation is checked by
`spec/scripts/rule_crosscheck.py`. The census is the authoritative metric;
the repository does not publish a theorem-declaration count.

The 50 `obsolete` rows are retired duplicates, policy-only boundaries, or
out-of-scope entries. They remain rows rather than being deleted, which is
why the denominator stays 726. `proven` means the row has a named Lean
target and passes the traceability gates; it does not by itself assert
byte-for-byte equivalence with Bitcoin Core (see
[Scope and non-claims](#scope-and-non-claims)). The 26 explicit residuals are
counted in `proven` but are not claims of Core equivalence;
`docs/RESIDUALS.md` is authoritative for that list.

### Wallet census (separate)

`spec/db/rules-wallet.yaml` is a second, independent census for wallet
construction and signing: descriptors, Miniscript, PSBT, spend construction,
and wallet signing. It has **140 rows** (DESC 30, MS 35, PSBT 30, WSP 31,
SGN2 14). Every wallet row is a wallet-level proposition (`consensus: false`),
and the file is never merged into `spec/db/rules.yaml`. Wallet rows and
wallet proofs do not enter the consensus count.

The wallet layer is a **specification and obligation layer with partial
proofs**, not 140 proved row contracts. Forty rows carry a
`@[walletRule "<ID>"]` tag; 37 are recorded as entailed, and three tagged rows
also have partial obligations. The obligation register covers 99 rows (30
PARTIAL, 69 UNMODELLED; 75 model gaps and 24 proof gaps), and four further
rows had contradicted text corrected without a proof. The 844 wallet
theorem/lemma declarations pass a dedicated
axiom gate with only `propext`, `Classical.choice`, and `Quot.sound`. The full
obligation register is [`docs/WALLET-OBLIGATIONS.md`](docs/WALLET-OBLIGATIONS.md).

## Toolchain

| Component | Version / pin |
|---|---|
| Lean | `leanprover/lean4:v4.35.0` (`spec/lean-toolchain`, `spec/core/lean-toolchain`, `spec/proofs/lean-toolchain`) |
| mathlib | `cfc55fc58714a59dc06e6e79edc6d1d95140d3c2` (`spec/proofs/lake-manifest.json`) |
| Core package | No Lake dependencies (`spec/core/lake-manifest.json`) |
| Proofs package | mathlib is a leaf dependency of `spec/proofs` only |

## Build

Install [elan](https://elan.lean-lang.org) first; `lake` reads the pinned
toolchain from `lean-toolchain` automatically.

```sh
# Core: executable model, zero dependencies
cd spec/core
lake build Bitcoin
# recorded: Build completed successfully (72 jobs).
lake test

# Proofs: theorem package, mathlib leaf dependency
cd ../proofs
lake build BitcoinProofs
# recorded: Build completed successfully (1722 jobs).
# This is the 29-module default import closure, not all 410 proof modules.
```

Do not run `lake update`; the committed `lake-manifest.json` is the pin. The
default closure is 29 modules; the other 381 modules were checked individually:
361 build and 20 do not. See [`docs/PROOF-BUILD.md`](docs/PROOF-BUILD.md) for
the exact scope and the one cited target that fails. The
optional capstone runner replays serialized mainnet anchor blocks through the
model. Extract the data bundle at the repository root so its `spec/vectors`
tree is at the path the runner reads:

```sh
bash scripts/fetch_data.sh --base-url https://github.com/Rob1Ham/btc-lean/releases/download --assets-sha256 <64-hex-pin> --extract .
cd spec/core
lake exe capstone
```

The anchor blocks are supplied by the release bundle, not tracked in git (see
[Data and release assets](#data-and-release-assets)). The run is offline. It
is not a live-network node.

## Data and release assets

The candidate tracks a size-bounded corpus subset at `spec/data/`:

| Property | Value |
|---|---:|
| Tracked files | 161 |
| Tracked bytes | 4,852,246 |
| Subset manifest | `spec/data/MANIFEST.sha256` |
| Release archive | `btc-lean-data-2026.10.17.tar.gz` |
| Archive bytes | 357,916,214 |
| Archive SHA-256 | `1ac846bdc24740cfdcf599c3ccf357e48bed50d7fd32071efae605d2a84168b8` |
| Content manifest | `release/manifest.sha256` |
| Content-manifest SHA-256 | `6c2f51e44624cbff05340610d5168dd869dbf9dd6c03f45d0c01a2f3594eba07` |

The tagged release assets are published at
<https://github.com/Rob1Ham/btc-lean/releases/download/data-2026.10.17/>.
The data-only corpus payload and the serialized anchor blocks are release
assets, not git objects. The bundle carries only data files, not executable
sources, scripts, build caches, logs, or narrative worklogs. Verify the
in-tree subset from a checkout:

```sh
sha256sum -c --strict spec/data/MANIFEST.sha256
bash scripts/check_subset_size.sh --root spec/data
```

See [`docs/DATA.md`](docs/DATA.md), [`docs/MANIFEST-SPEC.md`](docs/MANIFEST-SPEC.md),
and `release/README.md` for the release layout, fetch/verify procedure, and
transport checksums. The transport checksums are not signatures.

## Gates

The candidate passes **9/9 static gates**. They do not build Lean and do not
download mathlib. They require Python 3.12 and PyYAML. `make gates` is the CI
equivalent and prints `gates: all nine static gates passed`. `make gate-repro`
then checks the reference scripts used by the conformance runners and rejects
local checkout paths in tracked shell/Python files.

| # | Gate | Command |
|---:|---|---|
| 1 | core `sorry`/hazard lint | `bash spec/scripts/sorry_lint.sh` |
| 2 | `@[rule]` tags ↔ census targets | `python3 spec/scripts/rule_crosscheck.py` |
| 3 | static axiom manifest | `bash spec/scripts/axiom_manifest.sh --check-static` |
| 4 | `rules.yaml` regeneration fixed point | `python3 spec/scripts/extract_rules.py --check` |
| 5 | 726-row census contract | `python3 spec/scripts/gate_census.py` |
| 6 | overrides mirror | `python3 spec/scripts/backfill_overrides.py --check` |
| 7 | single Core anchor pin | `python3 spec/scripts/anchor_pin_check.py` |
| 8 | wallet static battery | `python3 spec/scripts/wallet_sorry_lint.py`; `python3 spec/scripts/wallet_crosscheck.py`; `python3 spec/scripts/wallet_isolation.py`; `bash spec/scripts/wallet_axiom_manifest.sh --check-static` |
| 9 | tracked data subset | `bash scripts/check_subset_size.sh --root spec/data` |

The static axiom check validates the committed manifest without invoking
Lean. Two dynamic checks are separate from the nine static gates and require
the Lean build: `bash spec/scripts/axiom_manifest.sh` probes 223 consensus
axiom entries, and `bash spec/scripts/wallet_axiom_manifest.sh --probe` probes
844 wallet declarations.

Wallet gates also support the optional Core-source anchor census:

```sh
CORE_SRC=/path/to/bitcoin/src bash spec/scripts/wallet_gates.sh
```

The script runs the wallet static battery, the 140-anchor census when
`CORE_SRC` is set, and the dynamic wallet axiom probe. Set
`WALLET_SKIP_PROBE=1` only when Lean is not installed.

## Reading guide

| Path | Contents |
|---|---|
| `spec/db/` | Rule censuses (`rules.yaml`, `rules-wallet.yaml`), axiom manifests, conformance and capstone records. |
| `spec/core/` | Zero-dependency executable model in the `Bitcoin.*` namespace: serialization, script parser and interpreter, transaction and block validation, ledger, activation, and cryptographic seams. |
| `spec/proofs/` | `BitcoinProofs.*` theorem package, built against the core definitions; the only package allowed to depend on mathlib. |
| `spec/scripts/` | Census and traceability gates, rule extraction, axiom checks, conformance runners, and wallet gates. |
| `spec/data/` | Size-bounded in-tree corpus subset with a checksum manifest; the larger data-only corpus payload and anchor blocks are checksum-pinned release assets. |
| `spec/runners/` | Executable corpus and wallet-differential runners. |
| `release/` | Data-release transport checksums and README; the archive and content manifest are release assets. |
| `docs/` | Scope and trust-base notes (`TCB.md`), claims (`CLAIMS.md`), residuals (`RESIDUALS.md` and the generated evidence matrix), generated theorem and wallet indexes (`THEOREMS.md`, `WALLET-THEOREMS.md`), provenance, reproducibility, data layout, and the wallet obligation register. |

### Where evidence lives

| Evidence | Location |
|---|---|
| Rule census and per-row disposition | `spec/db/rules.yaml`; contract in `spec/scripts/gate_census.py` |
| Tag-to-row traceability | `@[rule "<ID>"]` attributes under `spec/core` and `spec/proofs`; `spec/scripts/rule_crosscheck.py` |
| Axiom footprints | `spec/db/axiom-manifest.txt`; static gate and optional dynamic probe in `spec/scripts/axiom_manifest.sh` |
| Conformance results | `spec/db/results.json` and the compiled runners under `spec/Test` and `spec/runners` |
| Anchor-block replay record | `spec/db/capstone.md`; inputs in the release data bundle (`docs/DATA.md`) |
| Trust base and residual limits | `docs/TCB.md`; row-level gaps in `docs/RESIDUALS.md` |
| Third-party provenance and licenses | `docs/PROVENANCE.md`; `spec/data/MANIFEST.sha256` and the release `manifest.sha256` |
| Wallet census and separation checks | `spec/db/rules-wallet.yaml`, `spec/db/rules-wallet.lock`, and `spec/scripts/wallet_*.py` |

## Scope and non-claims

- **This is a model of consensus rules, not bitcoind.** It does not implement
  peer-to-peer networking, mempool policy, RPC, wallet storage, the GUI,
  databases, or operational node behaviour. Consensus is modelled at the
  validation-rule level; policy and availability boundaries are catalogued
  separately.
- **No claim of live-network validation.** The capstone replays historical,
  serialized blocks from the checksum-pinned data release. It does not sync
  with a live network, follow the current chain tip, or validate arbitrary
  network input.
- **No claim of byte-for-byte equivalence with Bitcoin Core.** Bitcoin Core
  at the pinned commit is the normative reference for each row. Some rules
  are abstractions of C++ behaviour, and port fidelity for the cryptographic
  layer is supported by conformance vectors and line-level review, not by a
  theorem that Lean equals libsecp256k1 or Core (`docs/TCB.md`).
- **The wallet layer is a separate package with partial proofs.** Its 140-row
  census, proofs, and gates are independent of the consensus census. Forty
  rows carry tags, 99 appear in the obligation register, and four have
  corrected statements without a proof. Wallet results are not consensus
  results and are never added to the 726-row denominator.
- **Twenty-six consensus rows are explicit model residuals.** Their Core
  behaviour is retained as the row claim, but the current Lean model does not
  entail it. They are listed with the missing link in `docs/RESIDUALS.md`;
  `status: proven` refers to the cited Lean target, not to Core equivalence.
- **No external audit or certification is claimed.** The residual and review
  records are internal evidence. No third-party security audit,
  certification, or endorsement is asserted.
- **`proven` is a kernel claim about a stated Lean proposition.** It is not a
  claim that the proposition captures every relevant Bitcoin behaviour, and
  it is not a theorem-declaration count. Statement fidelity remains a review
  obligation; `docs/RESIDUALS.md` lists the row-level residuals and
  `docs/TCB.md` records the permanent trust boundary.
- **The obsolete count is a disposition, not a deletion.** Retired rows stay
  visible so the census denominator and the audit trail remain stable.

## License

MIT. See [`LICENSE`](LICENSE). Third-party provenance, including
Bitcoin Core ports and vendored test vectors, is documented in
[`docs/PROVENANCE.md`](docs/PROVENANCE.md). mathlib and its transitive
dependencies remain external dependencies of `spec/proofs` only; they are
Apache-2.0, except `Cli`, which is MIT.

## Citation

Citation metadata is in [`CITATION.cff`](CITATION.cff). Cite the repository
and the exact commit or release you used. No DOI, arXiv identifier, or
publication venue is claimed.
