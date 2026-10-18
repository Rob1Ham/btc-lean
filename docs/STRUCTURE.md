# Candidate tree structure

This note describes the candidate checkout: what each directory is for, what is
deliberately absent, how a rule row leads to a theorem, and what the rule-ID
prefixes and statuses mean. It is a layout note, not a proof claim. The proof
claims are the tagged declarations and the census in `spec/db/rules.yaml`.

Snapshot: 2026-10-17. The census has 726 rows: 676 `proven`, 50 `obsolete`,
0 `implemented`, 0 `planned`. Twenty-seven of the proven rows remain explicit
model residuals ([`RESIDUALS.md`](RESIDUALS.md)). Counts describe rule rows,
not Lean theorem declarations.

## 1. Top-level shape

```text
spec/
├── lakefile.lean                 root workspace: requires core only
├── lean-toolchain                pinned Lean version
├── BtcLean.lean                  root umbrella import
├── core/                         executable model, zero Lake dependencies
│   ├── lakefile.lean
│   ├── Bitcoin.lean              root model import
│   ├── Bitcoin/                  all Bitcoin.* namespaces
│   └── Test/                     compiled model checks
├── proofs/                       theorem package, mathlib leaf dependency
│   ├── lakefile.lean
│   ├── BitcoinProofs.lean        root theorem import
│   └── BitcoinProofs/            all BitcoinProofs.* namespaces
├── db/                           census, overrides mirror, manifests, records
├── scripts/                      gates, extraction, runners, audit tooling
├── data/                         curated in-tree corpus subset
├── Test/                         root-level conformance checks
└── runners/                      executable corpus runners
```

`spec/data/` is the in-tree, size-bounded corpus subset. The source corpus is
staged under `spec/vectors/` for release packaging; the release bundle carries
only the data files, not executable sources, scripts, build caches, logs, or
narrative worklogs. The candidate installs only the selected subset at
`spec/data/` and distributes the larger data payload as checksum-pinned release
assets. `spec/data/` contains data only and is read by the runners, not by the
model or proof namespaces. No Lean module is renamed by that packaging step.

## 2. Directory roles

### `spec/core/` — the model

The executable, zero-dependency Lean package. It contains definitions and
executable checks, not the row-closing theorems. Principal namespaces:

| Area | Contents |
|---|---|
| `Bitcoin/Data/`, `Serialization/`, `DataLaws/`, `Numeric/` | bytes, CompactSize, amounts, transaction/block framing, weight, txid/wtxid, ScriptNum and casts |
| `Bitcoin/Script/`, `Script/Parser/`, `Script/Tapscript/`, `Interpreter/` | script parser, opcode semantics, stack machine, limits, sigop counting, witness/tapscript dispatch |
| `Bitcoin/Consensus/`, `TxValidation/`, `SigHash/` | `CheckTransaction`, `CheckTxInputs`, `validateTx`, locktime/sequence, legacy/BIP143/BIP341 digests |
| `Bitcoin/Activation/` | buried activation heights, flag selection, BIP9 state machine |
| `Bitcoin/Ledger/`, `Block/`, `Chain/`, `Capstone/`, `Conservation/` | UTXO application and undo, header/PoW, block connection, composed validation, subsidy/conservation |
| `Bitcoin/Crypto/` | curve, field, ECDSA, Schnorr, Taproot, hash/checker seams |
| `Bitcoin/Invariants/` | named invariant bundles used by row targets |
| `Bitcoin/RuleAttr.lean` | the kernel-side `@[rule "<ID>"]` parametric attribute |

`spec/core/Test/` holds executable model checks. It is data-driven but remains
part of the zero-dependency package.

### `spec/proofs/` — the theorems

The theorem package. It imports the core model and may depend on mathlib, which
is a leaf dependency of this package only. Principal locations:

| Area | Contents |
|---|---|
| `BitcoinProofs/AF/PDW*/` | row-facing proof modules; the majority of `lean_target` declarations. Historical names are explained in `NAMING.md` |
| `BitcoinProofs/Theorems/` | composed correspondence and capstone modules (`Capstone*`, `BlockCor`, `LedgerCor`, `InterpCor`, `ParserCor`, ...) |
| `BitcoinProofs/{Activation,Bip,Conservation,Crypto,EcdsaDeep,ErrMap,Interpreter,Ledger,Property,Shortcuts,SmallCurve,Audit}/` | domain proofs, error-taxonomy maps, property checks, and audit-support modules |
| `BitcoinProofs.lean` | root import for the stable theorem surface |

Modules under `AF/` are row-facing and may be built individually; they are not
all imported by `BitcoinProofs.lean`. Use the rule tag rather than the import
graph to locate a row's theorem (section 5).

### `spec/db/` — census, overrides, records

| Path | Role |
|---|---|
| `rules.yaml` | the authoritative 726-row census: ID, summary, Core anchor, Lean target, vectors, status, source |
| `rules-wallet.yaml`, `rules-wallet.obligations.tsv` | the 140-row wallet census and its obligation register |
| `residuals.yaml` | generated ID -> claim/Core/target/missing-link record for the 27 residuals |
| `results.json` | machine-readable conformance record |
| `axiom-manifest.txt`, `axiom-audit-rows.txt` | committed `#print axioms` fingerprints and row-level record |
| `interface-hashes.txt` | hashes of frozen `Interface.lean` signatures |
| `vector_ids.yaml` | vector-selector index |
| `capstone.md` | capstone replay record |
| `axiom-manifest-wallet.txt` | the separate wallet axiom manifest |

The override layer is kept next to the generator rather than as a second
database: `spec/scripts/extract_rules.py` holds the curated `OVERRIDES` table,
`spec/scripts/rules_overrides_sync.py` is its generated mirror, and gate 6
checks that the mirror still matches `rules.yaml`. This keeps the census
reproducible from source tables plus one visible curation layer.

### `spec/scripts/` — gates and evidence tooling

The static gates are the acceptance contract. They do not build Lean and do not
download mathlib; `make gates` runs the consensus and static wallet battery
(9/9 pass in this candidate), and `bash spec/scripts/wallet_gates.sh` adds the
optional Core-source anchor census and the dynamic wallet axiom probe.
`make gate-repro` is a separate reproducibility check: it verifies the
reference/generator scripts cited by the test runners and scans shell/Python
files for local checkout paths.

| Gate | Script | Contract |
|---|---|---|
| 1 | `sorry_lint.sh`, `sorry_lint.py` | no untagged `sorry` in `spec/core`; no core `native_decide`, `unsafe`, `partial`, or FFI hazard |
| 2 | `rule_crosscheck.py` | every `@[rule]` names a row; every non-obsolete row is tagged |
| 3 | `axiom_manifest.sh --check-static` | committed manifest has the expected shape and no forbidden axiom marker |
| 4 | `extract_rules.py --check` | `rules.yaml` is a regeneration fixed point |
| 5 | `gate_census.py` | 726 rows, unique IDs, exactly 676 proven / 50 obsolete / 0 implemented / 0 planned |
| 6 | `backfill_overrides.py --check` | `rules_overrides_sync.py` matches the YAML curation layer |
| 7 | `anchor_pin_check.py` | every row anchor carries the single pin `@cce32b168` |
| 8 | `wallet_sorry_lint.py`, `wallet_crosscheck.py`, `wallet_isolation.py`, `wallet_axiom_manifest.sh --check-static` | wallet-side sorry/hazard lint, tag/row traceability, consensus isolation, and static axiom manifest |
| 9 | `check_subset_size.sh` | the tracked data subset is 2-5 MiB and contains no git-lfs pointer |

The reproducibility check is separate from the nine static gates:
`check_reproducibility.py` verifies the reference scripts and data files used by
the conformance runners, and rejects absolute checkout paths in tracked
shell/Python files.

`axiom_manifest.sh` without `--check-static` runs the full Lean `#print axioms`
probe using `axiom_probe.lean` and `axiom_probe_rows.lean`. `spec/runners/`
holds conformance drivers; they produce records, not gate results.

### `spec/data/` — the in-tree subset

A curated, size-bounded slice of the conformance corpus: 161 files,
4,852,246 bytes, selected so a clone is small enough to inspect and a gate run
does not need the network. It carries a checksum manifest and is consumed by
the runners only. The larger data-only corpus payload and
the serialized anchor blocks are release assets; they are not part of the
in-tree candidate. Data files never carry `@[rule]` attributes and never
stand in for a theorem.

## 3. What is excluded, and why

| Excluded path | Reason |
|---|---|
| Scratch modules (`spec/proofs/ScratchREM08.lean`, `spec/proofs/BitcoinProofs/ScratchB.lean`, `spec/proofs/BitcoinProofs/AF/TS01Ax*.lean`) | exploratory probes. They are not imported by the candidate theorem root, carry no row claim, and may use experimental imports or hypotheses. Keeping them would imply a claim the project does not make. |
| Build artifacts (`.lake/`, `build/`, `*.olean`, `*.ilean`, `*.c`, `*.trace`, `*.hash`, `__pycache__/`) | machine-local, toolchain-specific, regenerable, and large. They are produced by `lake build` and are not evidence of a proof. |
| `spec/vectors/` (source corpus) | the source corpus is dominated by serialized anchor blocks and is hundreds of megabytes. Only the representative subset at `spec/data/` is in-tree; the larger data-only payload is distributed as checksum-pinned release assets and fetched on demand. |

Exclusion is not a judgement about the excluded material's correctness. It is a
scope decision: the candidate tree contains the model, the theorems, the census,
the gates, and enough data to check them.

## 4. Anatomy of a rule row

Each row in `spec/db/rules.yaml` is one claim at one pinned Core location.

| Field | Meaning |
|---|---|
| `id` | immutable `PREFIX-nnn` identifier; never renumbered or reused |
| `summary` | one-line statement of the rule; this is what a `proven` row claims |
| `check` | short Core-side label |
| `core_ref` | `file:function:lines@commit` in the pinned Bitcoin Core tree |
| `bip_cve` | BIP, CVE, or attribution string (`-` when none) |
| `lean_target` | fully-qualified Lean declaration that anchors the row; comma-separated when the row is a conjunction |
| `test_vector_ids` | corpus selectors |
| `status` | `planned`, `stubbed`, `implemented`, `proven`, or `obsolete` |
| `consensus` | `false` for policy/availability boundary rows that are catalogued but not modelled as consensus claims |
| `source` | report and section the row was extracted from |

The row is the unit of traceability. A theorem is not a row, and a row is not a
theorem count: one theorem can close several rows, and one row can name several
conjuncts.

## 5. From a rule row to the proof

The route is `id -> summary -> lean_target -> theorem`. The reliable locator is
the `@[rule "<ID>"]` attribute, because the attribute is stored in the Lean
environment and is what the cross-check gate reads.

1. **Read the row.** Use the ID boundary so the next row is not captured:

   ```sh
   sed -n '/^- id: INV-001$/,/^- id: INV-002$/p' spec/db/rules.yaml
   ```

   Read `summary` first. That sentence, not the theorem name, is the claim.
   Check `status` and `consensus`. If the status is `obsolete`, there is no
   theorem obligation; the summary and `core_ref` record why the row was retired.

2. **Read `lean_target`.** For `INV-001` it is
   `BitcoinProofs.AF.PDW22.checkTransaction_vin_empty_reject`. Split on commas
   if the row is a conjunction. The target may be a theorem or an executable
   definition; the row's `lean_target` is the proof face.

3. **Find the tag.** This is more robust than guessing a file from the dotted
   name:

   ```sh
   grep -rn 'rule "INV-001"' spec/core spec/proofs --include='*.lean'
   ```

   The attribute syntax permits several IDs on one declaration, for example
   `@[rule "INV-011", rule "TXV-027"]`; the grep above still finds it.

4. **Open the theorem.** For `INV-001` the result is
   `spec/proofs/BitcoinProofs/AF/PDW22/PDW22.lean`, containing
   `checkTransaction_vin_empty_reject`. Read the statement and then the proof
   term. The statement's conclusion must entail the row's `summary`; a special
   case or one direction of an iff is not enough.

5. **Check the axiom pin.** Row-closing modules carry an in-module
   `#guard_msgs in #print axioms` pin, and the declaration appears in
   `spec/db/axiom-manifest.txt`. The permitted footprint is `propext`,
   `Quot.sound`, and `Classical.choice`; `sorryAx` is not permitted. The static
   gate checks the manifest shape; `bash spec/scripts/axiom_manifest.sh` runs
   the full probe where Lean is available.

6. **Follow the model.** Imports at the top of the proof module lead to the
   `Bitcoin.*` definitions in `spec/core/`. The `core_ref` field in the row
   gives the corresponding C++ location at the pinned commit. This is the chain
   from a sentence about Bitcoin Core to a kernel-checked Lean proposition.

The intended invariant is: every non-obsolete row has a non-null
`lean_target`, every such row has at least one `@[rule]` tag, and `gate_census.py`
plus `rule_crosscheck.py` fail if that stops being true. Tag presence and build
success are necessary but not sufficient: statement fidelity is a review
obligation recorded in [`RESIDUALS.md`](RESIDUALS.md) where the model is incomplete.

## 6. Rule-ID scheme

IDs have the form `PREFIX-nnn`. The prefix identifies the subject area; the
number is an immutable sequence within that area. The ranges are contiguous,
including retired rows.

| Prefix | Subject | Rows | Range | Proven | Obsolete |
|---|---|---:|---|---:|---:|
| `BLK` | block-level consensus: header/body framing, PoW and retarget, merkle root and BIP30, activation, chain/UTXO transition, genesis | 130 | `BLK-001`..`BLK-130` | 130 | 0 |
| `INV` | acceptance-path invariants spanning transaction, script, block, and ledger checks | 176 | `INV-001`..`INV-176` | 139 | 37 |
| `SCR` | Script interpreter: evaluation order, opcodes, limits, P2SH, signature checks, verify flags | 183 | `SCR-001`..`SCR-183` | 183 | 0 |
| `SGN` | signature primitives and encodings: DER, low-S, pubkey parsing, curve/seam facts | 11 | `SGN-101`..`SGN-111` | 11 | 0 |
| `SWT` | SegWit: witness programs, BIP143 digests, witness limits, weight | 68 | `SWT-001`..`SWT-068` | 67 | 1 |
| `TPR` | Taproot and Tapscript: output keys, BIP341 digests, annex, tapscript rules | 83 | `TPR-001`..`TPR-083` | 71 | 12 |
| `TXV` | transaction validation: stateless and contextual checks, locktime/sequence, sigop cost, mempool boundary | 75 | `TXV-001`..`TXV-075` | 75 | 0 |

`SGN` numbering begins at 101; the gap below it is intentional and is not a
missing-row defect.

## 7. Status vocabulary

Statuses advance in one direction: `planned -> stubbed -> implemented ->
proven`. A row can be retired as `obsolete`; it is never silently deleted, and
an ID is never reused.

| Status | Meaning |
|---|---|
| `planned` | catalogued from the Core inventory; no Lean declaration assigned yet |
| `stubbed` | a Lean signature or definition exists, but the row statement is not yet closed |
| `implemented` | the executable definition or declaration exists and carries the `@[rule]` tag, but the entailment is not proved |
| `proven` | a tagged theorem exists, builds, and its conclusion is the row's cited Lean target; its axiom footprint is pinned and within the permitted set. Twenty-seven rows have a known target-to-summary gap and are listed in [`RESIDUALS.md`](RESIDUALS.md) |
| `obsolete` | retired: duplicate, policy/availability boundary, or outside the modelled consensus surface. The row remains in the denominator and keeps its ID |

Current census: 676 `proven`, 50 `obsolete`, 0 `implemented`, 0 `planned`.
The 50 obsolete rows (37 `INV`, 12 `TPR`, 1 `SWT`) explain why the denominator
stays 726. A `consensus: false` row is catalogued evidence about a
policy/availability boundary; it is not a consensus theorem even when its
status is `proven`.

## 8. Stability

The candidate layout is stable in three respects:

- **Module names are not renamed.** Fully qualified Lean names are part of the
  stable API and of the `lean_target` field; renaming a theorem module would
  break row traceability and external citations. Historical names under
  `AF/PDW*` and `Rows*` are therefore retained; see `NAMING.md`.
- **Rule IDs are not renumbered.** New work appends rows; retired rows remain.
- **The census is generated.** Curation is recorded in the override layer and
  the fixed-point gate, not by hand-editing `rules.yaml`.
