# LEDGER REPORT — current SCR coverage ledger

**Date:** 2026-10-21 (wave66 accepted integration; evidence tier)
**Census pin:** Bitcoin Core v32.99 @ `cce32b168`
**Scope:** `spec/db/rules.yaml` → `spec/db/equiv-cells.yaml`

## 1. Counts (verified programmatically)

| Metric | Value |
|---|---:|
| Rows in `rules.yaml` (all ids) | 726 |
| `SCR-*` rows | **183** |
| Unique SCR ids | 183 |
| Id range | `SCR-001` … `SCR-183` (contiguous, no gaps) |
| Duplicate / malformed SCR ids | 0 |
| Ledger entries | **183** |
| Families | **15** |
| Consensus `true` | **156** |
| Consensus `false` (policy/boundary) | **27** |
| Ledger status `planned` | **0** |
| Green (`alive2`/`saw`/`both`) | 0 / 0 / **159** |
| `unjudged-seam` | **1** |
| Filed `gap` | **23** |
| Missing from ledger | 0 |
| Ledger ids absent from `rules.yaml` | 0 |

Current `coverage_report.py --strict` result: **PASS**. All 183 rows are
adjudicated; the 159 green rows are listed in `results/matrix.md` and the
non-green dispositions in `findings/coverage/F-E6-GAPS.md`.

## 2. Family mapping and green coverage

Families are derived from the `source` field. The family id is also the
intended directory name under `spec/equiv/cells/`.

| Family id | Source | Rows | Consensus | Non-consensus | Green |
|---|---|---:|---:|---:|---:|
| `exec-verify` | `06-script-interpreter.md` §B.1 Execution model & VerifyScript | 17 | 14 | 3 | 12 |
| `limits` | `06-script-interpreter.md` §B.2 Limits & accounting | 27 | 26 | 1 | 23 |
| `push-encoding` | `06-script-interpreter.md` §B.3 Push & encoding rules | 11 | 7 | 4 | 11 |
| `control-flow` | `06-script-interpreter.md` §B.4 Control flow | 17 | 16 | 1 | 17 |
| `stack-ops` | `06-script-interpreter.md` §B.5 Stack ops | 6 | 6 | 0 | 5 |
| `numeric` | `06-script-interpreter.md` §B.6 Numeric ops & ScriptNum | 14 | 14 | 0 | 13 |
| `hash-ops` | `06-script-interpreter.md` §B.7 Hash ops | 3 | 3 | 0 | 3 |
| `checksig` | `06-script-interpreter.md` §B.8 Checksig (pre-tapscript) | 18 | 11 | 7 | 16 |
| `checkmultisig` | `06-script-interpreter.md` §B.9 CHECKMULTISIG | 8 | 8 | 0 | 7 |
| `locktime` | `06-script-interpreter.md` §B.10 Locktime | 11 | 11 | 0 | 10 |
| `witness-v0` | `06-script-interpreter.md` §B.11 SegWit v0 | 9 | 9 | 0 | 7 |
| `tapscript` | `06-script-interpreter.md` §B.12 Taproot/Tapscript | 28 | 26 | 2 | 21 |
| `disabled-opcodes` | `06-script-interpreter.md` §B.13 Disabled opcodes | 5 | 4 | 1 | 4 |
| `tapscript-reimport` | `w2-06-flags-activation.md` §B.1 Tapscript re-import | 1 | 1 | 0 | 1 |
| `policy-flags` | `w2-06-flags-activation.md` §B.12 Policy-only flags | 8 | 0 | 8 | 7 |
| **Total** | | **183** | **156** | **27** | **159** |

Every family is present; the sum of family row counts equals 183. Green counts
are row counts, not cell counts; a row may cite more than one cell.

## 3. `rules.yaml` oddities and decisions

1. **Two different sections labelled §B.12.** The `06-script-interpreter.md`
   §B.12 is Taproot/Tapscript (28 rows); the `w2-06-flags-activation.md`
   §B.12 is the policy-only flag catalogue (8 rows, all non-consensus).
   Mapping by section number alone would merge 36 unrelated rows. The ledger
   keys the full `source` string and uses distinct families (`tapscript`,
   `policy-flags`).
2. **One ordering inversion.** The census lists `SCR-183` between `SCR-174`
   and `SCR-175`. Ids themselves are valid and contiguous. The generator sorts
   numerically, so ledger order is deterministic and monotonic.
3. **Mixed `core_ref` path spellings.** 142 rows say
   `interpreter.cpp:...`; 11 say `src/script/interpreter.cpp:...`; the
   remaining 30 use 9 other prefixes (`script.cpp`, `script.h`,
   `src/consensus/consensus.h`, `src/validation.cpp`, `kernel/chainparams.cpp`,
   `tx_verify.cpp`, `policy/policy.h`, `validation.cpp`,
   `primitives/transaction.h`). The ledger preserves `core_ref` verbatim; no
   path normalization is applied.
4. **Multi-anchor refs.** 20 rows carry `;`-separated anchors in `core_ref`
   (e.g. `SCR-015`, `SCR-016`, `SCR-104`, `SCR-172`, `SCR-183`). All 183 refs
   end in `@cce32b168`; none is missing the pin suffix.
5. **Census status ≠ IR status.** All 183 SCR rows already have
   `status: proven` in `rules.yaml` (Lean-level). That does **not** imply any
   LLVM cell is green. The equivalent ledger status is derived only from
   tool-cell evidence.
6. **Policy rows.** 27 rows are `consensus: false`. All 8 `policy-flags`
   rows are non-consensus, plus 19 boundary/policy rows in other families.
   These still need adjudication (green or filed gap), not silent exclusion.
7. **Placeholders and lengths.** 63 rows use `bip_cve: "—"` (em dash, not
   empty). 12 summaries exceed 200 chars; the longest is `SCR-167` at 383
   chars. All summaries are preserved verbatim; the YAML dump is
   Unicode-safe and unwrapped (`width=4096`).
8. **Auxiliary census fields.** 7 rows have `notes` and 1 has `notes_extra`.
   Those fields are retained in `rules.yaml`; the ledger contract does not
   copy them.
9. **No missing data in the SCR slice.** Every SCR row has `summary`,
   `core_ref`, `source`, `consensus` and `lean_target`. No source string fell
   through to the `unassigned` fallback.

## 4. Regeneration and state preservation

`results/scripts/update_ledger.py` is the only supported status writer. It
validates each `spec.md` front matter, checks the contract hash against
`PINS.lock`, parses the raw `alive2/result.txt` and `saw/result.txt`, and
requires a raw success marker before any green status. A filed
inapplicability requires `notes.md` with an `F-TOOL-nnn` id. Malformed records
leave their rows `planned` and are reported verbatim.

`build_equiv_cells.py` regenerates the computed fields (`id`, `family`,
`summary`, `core_ref`, `consensus`, `families`) and preserves the
hand-maintained fields (`status`, `cells`, `alive2`, `saw`, `gap_note`) by id.
If the existing ledger is unparseable, it aborts rather than discarding state.

Determinism check: `python3 .../build_equiv_cells.py --check` reports
`up to date`; the output contains no timestamps or absolute paths.

## 5. Status derivation and gates

- **Updater:** `results/scripts/update_ledger.py` is the only supported
  status writer. A row becomes `both-green` only when a valid cell lists it
  and the raw `alive2/result.txt` and `saw/result.txt` both contain the
  success marker. A partial-coverage cell can be tool-green without promoting
  its row; per-row coverage bullets are honored, so a partial bullet for one
  row does not demote a fully covered sibling row.
- **SAW classification:** `Proof failed`, `saw: error`, `Failed to verify`,
  `Could not find definition`, `Stack trace`, `Symbolic execution failed`,
  `Error during`, `Aborted`, and `panic` all prevent a green status. This
  closes the wave64 finding that a shared runner could print `saw-green`
  after an unknown-function error.
- **Coverage gate:** `coverage_report.py --strict` covers 183/183 and fails on
  a green row whose cited cell is missing/malformed, does not list the row,
  or lacks the required tool success marker.
- **Matrix:** `results/scripts/build_matrix.py` writes `results/matrix.md`
  with per-family counts, the named trust base, the claim form, and links to
  cell records. It fails loudly (no write) if a green row has no cell or if
  the ledger disagrees with the cell-derived state.
- **Certificate gate:** `tools/gate_ir_pin.py` replays all nested
  certificates; the current tree has 376 certificates and 0 failures. The
  clean-checkout checker
  `findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py`
  additionally replays manifests and moves non-tracked historical hashes to
  explicit `EXTERNAL-HASHES.txt` records.

## 6. Current non-green dispositions

- **`unjudged-seam` (1):** SCR-147 (Taproot tweak/commitment).
- **Filed gaps (23):** SCR-003, 005, 006, 008, 010, 021, 036, 043, 044,
  078, 104, 112, 115, 133, 140, 142, 146, 153, 154, 167, 169, 172, 175.
  SCR-001/040/051/057/086/132 were closed by the accepted wave66 cells.
- Each row has a row-specific blocker in `findings/coverage/F-E6-GAPS.md`;
  wave64 added exact witnesses for SCR-008 (`F-DIV-W32-01`), SCR-112
  (`F-DIV-004`), SCR-043 (miniscript bound), SCR-142 (no pin height gate), and
  the SCR-146/147 crypto seams.
