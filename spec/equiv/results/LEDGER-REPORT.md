# LEDGER REPORT — current SCR coverage ledger

**Date:** 2026-10-20 (post wave 16/32 integration; E0 bootstrap retained in the family mapping)
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
| Green (`alive2`/`saw`/`both`) | 0 / 0 / **116** |
| `unjudged-seam` | **2** |
| Filed `gap` | **65** |
| Missing from ledger | 0 |
| Ledger ids absent from `rules.yaml` | 0 |

Current `coverage_report.py --strict` result: **PASS**. All 183 rows are
adjudicated; the 116 green rows are listed in `results/matrix.md` and the
non-green dispositions in `findings/coverage/F-E6-GAPS.md`.

## 2. Family mapping

Families are derived from the `source` field. The family id is also the
intended directory name under `spec/equiv/cells/`.

| Family id | Source | Rows | Consensus | Non-consensus |
|---|---|---:|---:|---:|
| `exec-verify` | `06-script-interpreter.md` §B.1 Execution model & VerifyScript | 17 | 14 | 3 |
| `limits` | `06-script-interpreter.md` §B.2 Limits & accounting | 27 | 26 | 1 |
| `push-encoding` | `06-script-interpreter.md` §B.3 Push & encoding rules | 11 | 7 | 4 |
| `control-flow` | `06-script-interpreter.md` §B.4 Control flow | 17 | 16 | 1 |
| `stack-ops` | `06-script-interpreter.md` §B.5 Stack ops | 6 | 6 | 0 |
| `numeric` | `06-script-interpreter.md` §B.6 Numeric ops & ScriptNum | 14 | 14 | 0 |
| `hash-ops` | `06-script-interpreter.md` §B.7 Hash ops | 3 | 3 | 0 |
| `checksig` | `06-script-interpreter.md` §B.8 Checksig (pre-tapscript) | 18 | 11 | 7 |
| `checkmultisig` | `06-script-interpreter.md` §B.9 CHECKMULTISIG | 8 | 8 | 0 |
| `locktime` | `06-script-interpreter.md` §B.10 Locktime | 11 | 11 | 0 |
| `witness-v0` | `06-script-interpreter.md` §B.11 SegWit v0 | 9 | 9 | 0 |
| `tapscript` | `06-script-interpreter.md` §B.12 Taproot/Tapscript | 28 | 26 | 2 |
| `disabled-opcodes` | `06-script-interpreter.md` §B.13 Disabled opcodes | 5 | 4 | 1 |
| `tapscript-reimport` | `w2-06-flags-activation.md` §B.1 Tapscript re-import | 1 | 1 | 0 |
| `policy-flags` | `w2-06-flags-activation.md` §B.12 Policy-only flags | 8 | 0 | 8 |
| **Total** | | **183** | **156** | **27** |

Every family is present; sum of family row counts equals 183.

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
   LLVM cell is green. The equivalent ledger status is initialized to
   `planned` for every row; only tool-cell evidence can promote it.
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

`build_equiv_cells.py` regenerates the computed fields (`id`, `family`,
`summary`, `core_ref`, `consensus`, `families`) and preserves the
hand-maintained fields (`status`, `cells`, `alive2`, `saw`, `gap_note`) by id.
If the existing ledger is unparseable, it aborts rather than discarding state.
Verified by promoting `SCR-001` to `both-green` with cells, regenerating, and
confirming the state survived, then restoring the bootstrap ledger.

Determinism check: `python3 .../build_equiv_cells.py --check` reports
`up to date`; the output contains no timestamps or absolute paths.

## 5. TODO / blockers

- **No LLVM cells yet.** `spec/equiv/cells/` does not exist; all 183 rows are
  `planned`. CELLS must populate `cells`, `alive2`, `saw`, and `status`.
- **Result-record schema not frozen.** `alive2` and `saw` currently accept
  `null` or a free-form result mapping (`result`, `cell`, `certificate`,
  `note`). Freeze this when the first E1 cell lands.
- **Gate integration pending.** The Makefile references
  `tools/gate_ir_pin.py`, but `spec/equiv/tools/` does not exist at E0. Wire
  `coverage_report.py --strict` into that gate once TOOLS lands it.
- **Pins incomplete.** `PINS.lock` still has `TODO` for clang, LLVM version,
  Alive2, SAW, solvers, rbitcoin commit, and builds; no IR hashes exist yet.
- **Matrix is a template.** `results/matrix-template.md` has the E0 skeleton;
  final generation from the ledger is an E6 deliverable.
- **No commit made.** Changes are left in the working tree per instructions.

## 6. E1 update: cell-derived status and published matrix

This section records what changed after the E0 bootstrap; it supersedes the
stale bullets above where they conflict.

- **Updater landed:** `results/scripts/update_ledger.py` is the only supported
  status writer. It validates `cells/<family>/<cell>/spec.md` (required front
  matter: `contract`, `legs`, `precondition`, `postcondition`, `direction`,
  `scr_rows`, `patches`, `trust_note`), parses `alive2/result.txt` and
  `saw/result.txt`, and requires a raw success marker before any green status.
  `contract` must match `PINS.lock [contract] hash`. A filed inapplicability
  requires `notes.md` with an `F-TOOL-nnn` id. Malformed records leave their
  rows `planned` and are reported verbatim.
- **Status derivation:** both tool markers → `both-green`; one green + the
  other filed inapplicable → `alive2-green`/`saw-green`; both inapplicable with
  a valid `unjudged_seam:` declaration citing `DECISION-lax-ecdsa.md` and a
  finding → `unjudged-seam`; any red/ambiguous result or no green leg →
  `gap` with an `auto(cells):` note naming the exact cell and leg outcomes. A
  row with a malformed cell is never promoted.
- **Result-record schema is now frozen** by the updater: `alive2`/`saw` are
  either `null` or `{result, cell, certificate, note}` with `result: green`
  and `cell` a path relative to `spec/equiv/cells/`.
- **Coverage gate extended:** `coverage_report.py --strict` still covers
  183/183 and now additionally fails on a green row whose cited cell is
  missing/malformed, does not list the row, or lacks the required tool success
  marker.
- **Matrix published:** `results/scripts/build_matrix.py` writes
  `results/matrix.md` with per-family counts, the named trust base, the claim
  form, and links to cell records. It fails loudly (no write) if a green row
  has no cell or if the ledger disagrees with the cell-derived state.
- **Round trip verified:** `build_equiv_cells.py --ledger <copy>` regenerates a
  byte-identical ledger and preserves `status`, `cells`, `alive2`, `saw`,
  `gap_note`. The optional `--ledger` flag is a testability hook; the default
  path and interface are unchanged.
- **Honest current state:** 0 cell directories, 183 `planned`, 0 green,
  0 filed gaps. No row was promoted by hand. See
  `findings/ledger/E1-report.md` for exact commands and outputs.
- **Still open:** one `PINS.lock` build TODO (`[rbitcoin] build`), L/R E0
  stubs, and the absence of cell records. These are external to the ledger
  machinery.


---

## Current snapshot addendum — `2026-10-19T23:10:00Z`

The §§1–4 counts above are the **E0 bootstrap** state (183 `planned`). They
are retained as history. The current ledger, generated by
`results/scripts/update_ledger.py` and adjudicated by
`results/scripts/adjudicate.py`, is:

| Metric | Current |
|---|---:|
| Ledger entries | 183 |
| Families | 15 |
| Cell directories (valid) | 17 |
| `planned` | **0** |
| `both-green` | **4** (SCR-069, SCR-071, SCR-072, SCR-074) |
| `alive2-green` / `saw-green` only | 0 / 0 |
| `unjudged-seam` | **20** |
| Filed `gap` | **159** |
| `coverage_report.py --strict` | **PASS** |
| `make gate-ir-pin` | **PASS** (0 failures, 0 warnings) |

The 183 rows are not all green. E2/E3/E4 cells are tool-green but explicitly
partial; their rows stay gaps. Every non-green row has a row-specific
disposition in `findings/coverage/F-E6-GAPS.md`. The generated authoritative
view is `results/matrix.md`; do not hand-edit either file.
