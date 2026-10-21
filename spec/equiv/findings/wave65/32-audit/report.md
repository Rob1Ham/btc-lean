# Wave 65 / agent 32 — independent audit of `76dbfe5`

**Target:** `76dbfe5e42f8a337e41a7308158b0de078afafd9` (`equiv/llvm-three-leg`, PR #29)
**Base:** `d390f7932e64a134aec3cca1614bed3276539f2d` (`main`)
**Worktree:** `/tmp/opencode/wave65/32-audit` (branch `wave65/32-audit`, cut from the target)
**Mode:** findings only. No cell, ledger, doc, proof, pin, contract, or matrix was edited.

This audit does **not** re-prove any row. It checks the snapshot's own claims
against its own records and re-runs the read-only gates. The headline counts
are correct; the problems are in what several individual `green` labels mean,
in which cell records are cited, and in the documentation/hygiene around the
snapshot.

---

## 1. Verdict at a glance

| Check | Result |
|---|---|
| Ledger counts | **183 rows, 156 both-green, 2 unjudged-seam, 25 gap, 0 planned** — reproduced exactly |
| Cell records | **164 cells**, 0 malformed, 164 with both leg records, 164 with both tool success markers |
| Certificates | **344** cell certificates replay in `gate_ir_pin` (0 failures, 0 warnings) |
| Clean-checkout replay | **0 errors** across 344 cell certs + 9 manifests; **531 hygiene warnings** |
| Matrix / ledger drift | `update_ledger.py --check` rc 0, 0 changes; `build_matrix.py --check` up to date |
| Strict coverage gate | `coverage_report.py --strict` rc 0 — all 183 rows adjudicated |
| PR body vs ledger | 183/156/2/25/0, 164 cells, 344 certs all match; PR head = audit target; CI green at audit time |
| Constraint compliance | No `spec/db/rules.yaml` or `spec/proofs` changes in the PR; `PINS.lock`/`contract`/`patches` added once in `5645bc1` and never modified; every cell says `patches: none`; `patches/core` is PROPOSED only |
| **Rows that overclaim their own coverage** | **4 clear cases** (`SCR-003`, `SCR-006`, `SCR-057`, `SCR-132`), 1 borderline (`SCR-049`) |
| **Green rows whose ledger evidence record points at a partial cell** | **13** |
| **Gaps without a row-specific blocker** | **6 of 25** (`SCR-036`, `SCR-044`, `SCR-104`, `SCR-112`, `SCR-115`, `SCR-175`) |
| **Stale reviewer-facing counts** | 6 current docs (plus a template header) still say 4/20/159; `STATE.md` says 501 warnings and 155/2/26 |
| **Tracked build/lock artifacts** | 15 files under ignored `build/` + 3 tracked `.w32.lock` |

Bottom line: the snapshot is internally consistent at the aggregate level, and
the gates do what they say. But **the 156 is an upper bound, not a clean
count**: four rows are green on cells that explicitly say they do not cover
part of the row (or exclude an open divergence), and 13 rows name the wrong
cell record as their evidence. A reviewer who trusts the matrix headline
("three engines agree") or the old README ("4 green") is misled in opposite
directions.

---

## 2. Ranked findings

Severity is about how much a reader would be misled, not about exploitability.
Every finding includes the smallest corrective action; none was applied.

### F1 — `SCR-132` is a false green: the cell proves a two-input instance, the row is general (`vin` list) — **high**

- Row: `SCR-132` — `CheckLockTime/Sequence see only input nIn`.
- Cell: `locktime/C-L-locktime-input-index`.
- The cell's own coverage text says:
  - "The only bounded dimension is the vin length (2 inputs instead of an
    arbitrary list)"; and
  - "The general-n induction is not mechanized and is not claimed; the
    two-input instance is what the LLVM cell proves."
  (`spec/equiv/cells/locktime/C-L-locktime-input-index/spec.md:64-68`)
- Yet the same field starts with `full` (line 55), so `_partial_coverage`
  returns false and the row is `both-green` in the ledger.
- This is exactly the case `docs/TRUST-BASE.md:355-357` says cannot be green:
  a green row needs `scr_row_coverage: full`; a partial cell is not green.

**Smallest fix:** change the `SCR-132` bullet / field to `partial` (the row
becomes a 26th gap), or narrow the row statement itself to the `vin.length = 2`
instance and re-generate the census. Do not leave `full` in the field while
the prose disclaims the general case.

---

### F2 — `SCR-003` is a false green for the "short" half of the row — **high**

- Row summary (`spec/db/rules.yaml`): `Empty/short script evaluates to success
  with unchanged stack`; check: `Empty script success`.
- Cell: `exec-verify/C-L-eval-empty`.
- The cell's coverage says `full ... and the row's own statement` (line 42),
  then in the same field: "Execution of any opcode (pushes included) is the
  E5 dispatch residual and is NOT covered here; the cell therefore says
  nothing about 'short scripts with one or more ops'." (lines 47-49)
- A short script such as `OP_NOP` is a short script with an opcode; the cell
  explicitly does not cover it. The row's summary includes "short"; the
  check field narrows to empty, but the ledger tracks the summary row.

**Smallest fix:** mark the cell `partial` for `SCR-003` (row → gap), or change
the census row summary/check to "empty script" (and regenerate the ledger).
The current combination of `full` + "says nothing about short scripts" is the
overclaim.

---

### F3 — `SCR-057` is a false green: lengths 3–520 are called "a stated domain gap" — **high**

- Row: `SCR-057` — `any nonzero byte = true; lone 0x80 = false; ∅ = false`.
- Cell: `control-flow/C-L-casttobool`.
- Coverage: `full branch coverage` (line 26), then: "Domain bound: element
  length is 0-2 bytes; lengths 3-520 are not machine-enumerated by this cell
  and are a stated domain gap, not a fourth branch." (lines 30-32)
- The row quantifies over elements of any length (up to Core's 520-byte
  limit); the cell checks only 0–2. Calling this `full` contradicts the
  cell's own "domain gap" and the `TRUST-BASE` rule.

**Smallest fix:** `partial` for `SCR-057` (row → gap), or add the missing
length induction / a bounded-length statement to the row. A reviewer who
reads only the matrix will otherwise believe lengths 3–520 are checked.

---

### F4 — `SCR-006` is green while the cell excludes the open `F-DIV-001` error-kind divergence — **high**

- Row: `SCR-006` — `scriptSig must be push-only for P2SH evaluation`.
- Discharging cell: `exec-verify/C-L-w32-p2sh-pushonly`.
- The cell's coverage says `full for the row's branch set over decoded
  scriptSig` (line 37), then: "scriptSig decoding is abstracted, so the
  malformed-tail input class is not judged (F-DIV-001)" (lines 44-45).
- `F-DIV-001` is a confirmed Core/Lean divergence on malformed scriptSig
  tails (Core returns `SIG_PUSHONLY`, Lean `BAD_OPCODE`). The verdict may
  agree (both fail), but the matrix's claim form is "verdict **and error
  kind**". On the excluded input class the error kind differs; the cell says
  it is not judged, yet the row is green.
- The ledger also cites `exec-verify/C-L-pushonly` (a `partial` cell) as the
  `alive2.cell`/`saw.cell` for this row (see F6).

**Smallest fix:** mark the cell `partial` for the malformed-tail class (row
→ gap/seam until `F-DIV-001` is resolved), or add the malformed-tail case to
the cell and prove the error-kind equality. At minimum, say in the row/matrix
that the claim is verdict-only.

---

### F5 — the matrix headline says "three engines agree"; all 164 cells are `C, L` only, and no cell consumes the pinned Core/twin/rbitcoin IR closures — **high (framing)**

- `spec/equiv/results/matrix.md:9`: "then the three engines agree on verdict
  and error kind."
- Every cell declares `legs: C, L` (`grep -h '^legs:' ... | sort | uniq -c`
  = 164 × `legs: C, L`). There is no R cell. The R proof lane is blocked
  (`F-TOOL-001`), and the matrix itself says so later.
- The 156 green cells compare a **cell-local C source-excerpt slice**
  (`src/c_leaf.cpp` / `_tools/...`) against an L slice. None of the 164
  `alive2/run.sh` files references the pinned `interpreter-O0`, `core.ir`, or
  `ir/manifest.json` closure. The only cell script that loads the pinned
  closure is `cells/e5-whole/saw/e5-verifyscript-empty.saw` (the non-ledger,
  non-pin concolic run that the docs already exclude). 73 cells describe L
  as a "reviewed transliteration", not generated twin code;
  `hash-ops/C-L-hash-widths` uses a **cell-local** SHA1 L handler because the
  pinned twin maps `0xa7` to `OP_UNSUPPORTED_SHA1` (`spec.md:19-21`).
- Each cell's `trust_note` discloses this ("C is a line-cited source-excerpt
  slice ... not a whole-engine equivalence proof"). The aggregate claim does
  not. This is a claim-form problem, not a hidden proof.

**Smallest fix:** change the claim-form sentence to "the Core slice and the
Lean-derived twin agree ...; all cells are C/L, no R cell; C/L are line-cited
slices, not the pinned IR closures" (two lines in
`results/scripts/build_matrix.py:348-353`, then regenerate). Add the same
sentence to the PR summary. Optionally add an `l_provenance:
twin|transliteration|cell-local` field and a matrix column.

---

### F6 — 13 green rows cite a `partial` cell as their `alive2.cell`/`saw.cell` evidence record — **medium-high**

Rows: `SCR-004, 006, 012, 073, 074, 075, 076, 089, 093, 094, 110, 116, 117`.

For each, the ledger's `alive2.cell` and `saw.cell` point at a cell whose
`scr_row_coverage` is `partial` for that row, while a different, non-partial
both-green cell exists. Example: `SCR-006` cites
`exec-verify/C-L-pushonly` (partial) but the discharging cell is
`exec-verify/C-L-w32-p2sh-pushonly`; `SCR-093` cites
`e2-hash/hash160-vector` (partial) but the full cell is
`hash-ops/C-L-hash-widths`.

Cause: `spec/equiv/results/scripts/update_ledger.py:762-766` chooses
`both[0]` without filtering `_partial_coverage`:

```python
both = [
    cell for cell in row_cells
    if cell.alive2.state == "green" and cell.saw.state == "green"
]
alive2_cell = both[0] if both else alive2_green[0]
saw_cell = both[0] if both else saw_green[0]
```

The row verdict is not false (all 13 have a full discharging cell, verified),
but the ledger/matrix evidence pointer is. A consumer who follows
`alive2.cell` lands on a cell that cannot discharge the row.

**Smallest fix:** filter `both` with `not _partial_coverage(cell, rule_id)`;
if no single cell is both-green and full, record `alive2_cell =
alive2_green[0]` and `saw_cell = saw_green[0]` separately. Regenerate the
ledger and matrix. Add a regression check that every green row's
`alive2.cell` and `saw.cell` are non-partial for that row.

---

### F7 — reviewer-facing docs still publish the old 4/20/159 snapshot, and `STATE.md` has stale counters — **medium-high**

The PR body and `results/matrix.md` say 156/2/25. The following current
entry points still say 4 both-green / 20 seams / 159 gaps:

| File | Line | Text |
|---|---|---|
| `spec/equiv/README.md` | 207 | "4 rows are both-tool green, 20 are unjudged seams, and 159 are filed gaps" |
| `spec/equiv/GOAL.md` | 10 | "183/183 ... (4 both-green, 20 seams, 159 gaps, 0 planned)" |
| `spec/equiv/docs/INDEX.md` | 42, 45, 92 | "only 4 rows full"; "4 both-green, 20 unjudged-seam, 159 gap"; "4 green / 20 seam / 159 gap" |
| `spec/equiv/docs/REPRODUCE.md` | 159, 214 | "only 4 SCR rows are both-tool green ... remaining 20 ... 159"; "The 4 green rows are ..." |
| `spec/equiv/docs/TRUST-BASE.md` | 317 | "only 4 SCR rows are both-tool green; 20 are seams and 159 are gaps" |
| `spec/equiv/findings/README.md` | 64 | "20 seam + 159 gap" |
| `spec/equiv/results/matrix-template.md` | 2-4 | "4 both-green, 20 unjudged-seam, 159 gap" (header says template only) |

`spec/equiv/docs/STATE.md` (current, updated at `76dbfe5`) still says:

- line 126: "**501** hygiene warnings remain" — the checker reports **531**;
- line 130: "the **155/2/26** coverage counts" — the matrix is **156/2/25**.

`STATE.md:90` says "Each has a row-specific blocker in
`findings/coverage/F-E6-GAPS.md`" — false for the six rows in F8.

**Smallest fix:** replace the old counts in those six files with
156/2/25 (or label the sections "historical snapshot at <sha>"); update
`STATE.md` to 531 and 156/2/25. The generated matrix is already correct; do
not hand-edit it.

---

### F8 — six of the 25 gap notes are not row-specific, contradicting "named blockers" — **medium**

| Row | Gap note today | Problem |
|---|---|---|
| `SCR-104` | "auto(cells): partial row coverage; checksig/C-L-checksig-lows: partial; checksig/C-L-checksig-lows-numeric: partial" | no blocker; the cell's `notes.md` has a "Why partial" section (canonical-scalar domain / SGN-107 seam) |
| `SCR-112` | "…C-L-checksig-invalid-pubkey: partial; e3-checksig/C-L-checksig-dispatch: partial" | no blocker; notes.md has the byte-level `IsValid`/`Set` gap |
| `SCR-115` | "…C-L-cms-fad-probe: partial; e3-cms/C-L-w32-cms-finddelete: partial" | no blocker; notes.md says FindAndDelete abstract, nSigs ≤ 2 |
| `SCR-175` | "…C-L-flag-source: partial; policy-flags/C-L-lows-policy: partial" | no blocker; notes.md has the ordering/flag-source gap |
| `SCR-036` | "no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement" | generic; no exact IR feature/tool limit |
| `SCR-044` | same generic sentence | generic |

The other 19 gap notes name a concrete feature/tool limit (e.g. `GetScriptOp`,
`OP_ROLL` loop, `SHA256` leaf, `F-DIV-W32-01`), which is the quality the
state doc claims for all 25.

**Smallest fix:** make `update_ledger.py:729-734` build the gap note from
(a) the row's own coverage bullet (the regex already used by
`_partial_coverage`) and (b) the first "Why partial" paragraph of the cell's
`notes.md`, then truncate at a word boundary. Regenerate
`findings/coverage/F-E6-GAPS.md`. For `SCR-036`/`SCR-044`, add the exact
missing feature/placement.

Related note-pollution bug: `SCR-005` and `SCR-008` gap notes start with a
**sibling row's** bullet (`- SCR-007 **full** ...`, `- SCR-002 full ...`) and
are truncated mid-word (`"The cell prove"`). Same root cause: the code dumps
the whole `scr_row_coverage` string and caps it at 1200 chars
(`update_ledger.py:733,739`). The per-row extractor fixes both.

---

### F9 — certificate hygiene is under-reported: 531 warnings, not 0 and not 501 — **medium**

`cert_repro_check.py --rev HEAD --fuzz 0`:

```
targets: 353 (cell certificates=344, manifests=9)
certificate lines: 5827; resolved files: 5827; bytes: 39194249
errors: 0; warnings: 531 in 352 target(s)
by code: cross-leg=344, divergence-parent-leak=2,
         machine-path-in-content=177, nested-divergence=2,
         uncovered-cell-input=6
```

- Every one of the 344 certificates includes sibling-leg inputs
  (`cross-leg=344`), because `normalize_certificates.py:101` walks
  `cell.rglob("*")` for the whole cell rather than only the certificate's
  leg. This couples the two legs' evidence and makes each cert cover the
  other leg's files.
- 177 targets bind content containing absolute machine paths; the bound
  transcripts contain 191 references to `/tmp/opencode/wave64-integrate`
  and 26 to `/home/ubuntu/btc-lean-public` (e.g.
  `limits/C-L-cms-count-bounds/build/build.txt` has
  `shared=/tmp/opencode/wave64-integrate/...`).
- The two `C-L-w32-cleanstack/divergence/*` certs bind outer-leg inputs and
  nested `divergence/` inputs (`divergence-parent-leak=2`,
  `nested-divergence=2`).
- 6 targets flag the tracked `.w32.lock` files (`uncovered-cell-input=6`).

The PR table says "clean-checkout replay PASS — 0 errors" (true) and the
`make gate-ir-pin` row says "0 warnings" (true for that weaker gate). Neither
says 531. `STATE.md` says 501, which is stale.

**Smallest fix:** report the 531 and the five categories in the PR body and
`STATUS.md`/`STATE.md`. Then fix the cause in
`normalize_certificates.py`: for a normal cert, walk only the cert's leg
directory plus `src/`, `spec.md`, `notes.md`, and the shared tools actually
used; for a `divergence/<leg>` cert, walk only that divergence leg plus the
cell record. Strip/replace the absolute roots in bound transcripts (or
canonicalize them to `<worktree>`). Add `--strict` to CI only after the
warning count reaches 0.

---

### F10 — tracked build artifacts and lock files remain in the tree — **medium-low**

- 15 tracked files under `spec/equiv/cells/limits/*/build/`:
  `build.txt`, `cell.cry`, `cell.saw` in five cells. `git check-ignore
  --no-index` confirms `spec/equiv/.gitignore:5:build/` would ignore them;
  they are force-added. They are **not** referenced by any certificate (good),
  but five `build.txt` files contain
  `shared=/tmp/opencode/wave64-integrate/...` and are stale.
- 3 tracked empty `.w32.lock` files under `e3-cms/C-L-w32-cms-*`. They cause
  the 6 `uncovered-cell-input` warnings. `.gitignore` only lists `.e3.lock`.
- `git ls-files -ci --exclude-standard` returns 16 paths: the 15 build files
  plus `findings/wave64/24-scr-104-low-s/probe_lows.c` (a tracked evidence
  source matched by the root `*.c` ignore rule, not an artifact). The 3
  `.w32.lock` files are not ignored by any rule, so they are not in `-ci`;
  they are tracked empty run locks.

**Smallest fix:** `git rm --cached` the 15 build files and the 3 locks (or
delete them); add `.w32.lock` to `spec/equiv/.gitignore`; add a CI check
`test -z "$(git ls-files -ci --exclude-standard)"`. The certs do not need
regeneration for these paths (none is cert-bound), but re-run
`normalize_certificates.py --check` after the lock removal.

---

### F11 — wave64 reports reference cells that are absent at HEAD — **medium-low**

`spec/equiv/findings/wave64/34-scr-147/report.md:9` says the cell is
`spec/equiv/cells/tapscript/C-L-taproot-commitment`, and lines 104/113-115
give reproduce commands. That cell exists only on branch
`wave64/34-scr-147` (commit `25cc947`), which is **not an ancestor of
`76dbfe5`**; the report itself was integrated (`dc3d5d0`) without the cell.
The ledger correctly keeps `SCR-147` as an `unjudged-seam`, so this is not a
false green, but the report's "Alive2 green, SAW green" is not reproducible
at the audit target.

The same pattern appears in `40-scr-175` (`C-L-lows-flag-source`), `49-bip143`
(`C-L-bip143-layout-bytemap`), `54-taproot-annex-control`
(`C-L-w64-taproot-annex-control-layout`), `55-tapscript-opsuccess-symbolic`
(`C-L-w64-op-success-prescan`), and `59-lows-numeric`
(`C-L-w64-lows-halforder-seam`). Their ledger rows are gaps/seams, not green
rows, so the aggregate counts are unaffected.

**Smallest fix:** either merge the cells (and re-adjudicate), or add a
one-line banner to each report: "Not integrated at `76dbfe5`; the cell lives
on branch `wave64/<n>`; the commands below do not run at this head." Add the
same pointer to the `SCR-147` seam note, which currently says only "Pure
secp256k1 EC; outside the seam."

---

### F12 — cell-local L / one-direction Alive2 is invisible in the ledger and matrix — **medium-low**

- `hash-ops/C-L-hash-widths` (rows `SCR-093`, `SCR-095`) and
  `hash-ops/C-L-hash-compose` (`SCR-094`) declare only `direction: L ⊑ C`.
  These are the only 2 of 164 cells without `C ⊑ L`. The cells say SAW
  verifies both legs against the shared Cryptol function, so the missing
  Alive2 direction is arguably covered; the ledger's "both-green" does not
  record direction completeness.
- `C-L-hash-widths` uses a reviewed **cell-local** L handler for `0xa7`
  because the pinned twin maps `0xa7` to `OP_UNSUPPORTED_SHA1` (result 3).
  The cell is explicit (`spec.md:19-21,91-101`) and says the shared twin's
  declared subset is unchanged. The row still calls L "the twin" in the
  aggregate.

**Smallest fix:** add `direction`/`l_provenance` to the ledger's per-row
evidence record (or a matrix column) and regenerate. If the workstream wants
the pinned-twin claim, integrate the SHA1 arm into `runtime.inc` +
`ops_ir.py` and re-run the three cells before keeping them green.

---

### F13 — `SCR-049` is a borderline variant of F1/F3 — **low**

- Row: `SCR-049` — `fExec-gated (unexecuted non-minimal pushes OK)`.
- Cell `push-encoding/C-L-w32-fexec-push` says `full for the row's premise`
  (line 32-33), then "does not cover other fExec constructions (ELSE, nested
  IF, NOTIF) or multi-byte payloads; those are wider E2/E5 work" (lines
  37-39).
- The cell exercises one fExec construction. Whether the row is satisfied by
  one construction or requires all is a judgment call; it is listed here so
  the reviewer sees the same pattern as F1/F3 rather than discovering it
  later.

**Smallest fix:** either say "representative fExec construction" in the
coverage field (and keep the green with a named scope), or mark `partial`.
Do not call it `full` without the scope sentence.

---

## 3. What is solid (so the findings are not read as a blanket rejection)

- The **aggregate ledger arithmetic** is correct and reproducible:
  183 rows, 156 both-green, 2 seams, 25 gaps, 0 planned; 164 cell records,
  0 malformed; 344 certificates.
- **Every green row has at least one non-partial both-green discharging
  cell.** The 13 mis-citations in F6 are evidence-pointer bugs, not 13 false
  greens.
- **All 164 cell records** contain both alive2 and saw result records with
  valid success markers; `update_ledger.py --check` reports 0 changes.
- **Certificate replay is real**: `gate_ir_pin.py` replays all 344 certs with
  0 failures; `cert_repro_check.py` uses a clean checkout and reports 0
  errors. The 531 warnings are portability/provenance warnings, not hash
  mismatches.
- **No consensus-changing patch is hiding a divergence**: every cell says
  `patches: none`; `spec/equiv/patches/core/*` are `PROPOSED` prototypes with
  an empty registry/evidence table; no cell builds with
  `BTC_EQUIV_NO_SCRIPTNUM_THROW`; no `spec/proofs` or `spec/db/rules.yaml`
  diff exists in the PR. `PINS.lock`, `contract/`, and `patches/` were added
  once in `5645bc1` and have zero diff from `5645bc1..HEAD`.
- **The PR body's counts match the ledger and matrix**, and the PR head is the
  audit target (`gh pr view 29` → `76dbfe5...`); GitHub check-runs at that
  commit are all `success` (the earlier `pending` entries were transient).
- The 2 seam notes (`SCR-146`, `SCR-147`) are terse and name the exact Core
  region and the crypto/EC reason; the blocker is clear. The only issue is
  the missing pointer to the off-snapshot SCR-147 cell (F11).

---

## 4. Exact commands and outputs

Run from `/tmp/opencode/wave65/32-audit` unless noted. All are read-only with
respect to tracked files.

```sh
git rev-parse HEAD
# 76dbfe5e42f8a337e41a7308158b0de078afafd9
git status --porcelain
# (empty)
git diff --stat 5645bc1..HEAD -- spec/equiv/PINS.lock spec/equiv/contract
# (empty)
git diff --stat d390f7932e64a134aec3cca1614bed3276539f2d..HEAD -- \
  spec/db/rules.yaml spec/proofs
# (empty)

python3 spec/equiv/results/scripts/update_ledger.py --check
# statuses: planned=0, alive2-green=0, saw-green=0, both-green=156,
#           unjudged-seam=2, gap=25
# green rows: 156; blocked rows: 0
# changes: 0
# check: .../spec/db/equiv-cells.yaml is up to date

python3 spec/equiv/results/scripts/coverage_report.py --strict
# cell records scanned: 164 (malformed: 0)
# strict: PASS - all 183 SCR rows adjudicated (green, unjudged-seam, or filed gap)

python3 spec/equiv/tools/gate_ir_pin.py
# cell records: 164
# failures: 0; warnings: 0
# RESULT: PASS

python3 spec/equiv/results/scripts/build_matrix.py --check
# .../results/matrix.md: up to date

python3 spec/equiv/findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py \
  --rev HEAD --fuzz 0
# errors: 0; warnings: 531 in 352 target(s)
# by code: cross-leg=344, divergence-parent-leak=2,
#          machine-path-in-content=177, nested-divergence=2,
#          uncovered-cell-input=6
# RESULT: PASS

git ls-files 'spec/equiv/cells/*/build/*' | wc -l
# 15
git ls-files -ci --exclude-standard | wc -l
# 16
git check-ignore --no-index -v \
  spec/equiv/cells/limits/C-L-cms-count-bounds/build/build.txt
# spec/equiv/.gitignore:5:build/ ...
```

Reproduction snippet for F6 (run from the repo root; read-only):

```python
import sys, yaml
from pathlib import Path
sys.path.insert(0, "spec/equiv/results/scripts")
import update_ledger as U

led = yaml.safe_load(open("spec/db/equiv-cells.yaml"))
rows = {r["id"]: r for r in led["rows"]}
cells, _ = U.scan_cells(
    Path("spec/equiv/cells"), set(rows), U._load_contract_pin(U.DEFAULT_PINS)
)
byid = {c.rel: c for c in cells}
for rid, r in sorted(rows.items()):
    if r["status"] != "both-green":
        continue
    for leg in ("alive2", "saw"):
        rel = r[leg]["cell"]
        if U._partial_coverage(byid[rel], rid):
            print(rid, leg, rel)
```

Expected: 26 lines covering the 13 rows in F6 (both legs per row).

### `make equiv` re-run

A detached worktree `/tmp/opencode/wave65/32-audit-run` was created at
`76dbfe5` and `make equiv` was started there so the audit worktree stays
clean. The run overwrites `result.txt` and certificates in that detached
worktree, not in the audit branch.

#### 4.1 Result

**Not completed within the audit window and not used as evidence.** After
~10 minutes the sequential runner was still in the `checksig` family; it was
stopped to avoid holding the host for an unbounded time. The files it had
rewritten contained no `STATUS=alive2-not-green` / `STATUS=saw-not-green`
marker, but that is a partial observation, not a full-suite result. The
recorded `make equiv PASS (164 cells, 0 red, 0 TODO)` claim is therefore
**unverified by this audit**; the read-only gates
(`update_ledger.py --check`, `coverage_report.py --strict`,
`gate_ir_pin.py`, `cert_repro_check.py`) were verified and are cited above.
If the owner wants this closed, run `make equiv` on an idle host and compare
the regenerated `result.txt`/certificate set to `HEAD`.

---

## 5. Smallest fix order (if the owner wants to act)

1. **F1, F2, F3, F4** — four `scr_row_coverage: partial` edits (or row
   narrowing) would move 4 rows to gap/seam and make the "156" defensible.
   No proof work is needed; this is an honesty edit.
2. **F6** — one-line filter in `update_ledger.py` + regenerate; fixes 13
   evidence pointers.
3. **F5** — two-line claim-form fix in `build_matrix.py` + regenerate; makes
   the headline match the C/L-only evidence.
4. **F7** — update six docs to 156/2/25 and `STATE.md` to 531/156/2/25.
5. **F8** — one extraction helper + regenerate `F-E6-GAPS.md`; fixes 6 gap
   notes and 2 polluted notes.
6. **F9, F10** — normalize per-leg certs, strip machine paths, remove 18
   tracked artifacts; then report the warning count truthfully.
7. **F11, F12, F13** — provenance banners/fields; lower urgency, but a
   reviewer will otherwise follow broken reproduce commands or assume the
   pinned twin/IR closure was used.

---

## 6. Scope limits

- This audit did not complete a full `make equiv` re-run (it was started in a
  detached worktree and stopped; see 4.1). It did not re-run the mutation
  catalogues, E0, or `make e0`.
- It did not attempt to reproduce the four suspected false greens against
  Core; the finding is textual: the cell's own coverage text contradicts the
  `full` label and the row's own statement.
- It did not audit the R lane's off-pin LLVM-20 advisory results; the PR and
  matrix already disclose the R proof lane as blocked.
- The 531 warnings are not hash failures; they are portability/coupling
  warnings. A certificate can replay and still contain a machine path. The
  finding is about what "clean-checkout replay" is claimed to establish, not
  about whether the hashes match.
