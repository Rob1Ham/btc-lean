# spec/vectors/incidents/CV01 — CVE-2018-17144 (duplicate-input inflation + 2x-spend)

**Case set:** CV01 · **Date:** 2026-10-16
**Scope:** CVE-2018-17144 audit — (1) inspect the spec for the
duplicate-input check (INV/TXV paths); (2) construct the attack tx
shape (same outpoint spent twice inside one tx) as a decisive reject
vector; (3) run it through the `validateTx` path (and #eval the
checkers) and record the verdict; (4) the 0-value-inflation variant;
(5) forced-lane replay of the pre-fix bug.

## **VERDICT: the spec REJECTS the attack at every entry lane — no
F-CV01-CRITICAL.** (19/19 battery lines PASS, exit 0.)

## Contents

| file | what |
|---|---|
| `cve-2018-17144-dup-input-inflation.json` | ATTACK A: one 1-COIN prevout spent twice → one 2-COIN output (the a8cab26 inflation shape). Expected + got: `bad-txns-inputs-duplicate` at every lane; forced-gate `checkTxInputs` accepts with `valueIn` double-counted (bug replay). |
| `cve-2018-17144-dup-input-0value.json` | ATTACK B: 0-value variant (no inflation, pure 2x-spend shape). Expected + got: same value-blind reject. |
| `CV01Runner.lean` | The decisive executable battery (A/B/C/D lanes: stateless `checkTransaction` → `hasDupPrevouts` (BLK-031); `validateTx` (TXV entry); forced `checkTxInputs`/`inputValuesLoop` (Core `CheckTxInputs`, stateless gate BYPASSED); forced `applyTxStepL` (ledger fold); `Bitcoin.Capstone.Block.applyTx` (W17 capstone block lane, BLK-030); `bad-txns-inputs-missingorspent` ordering probe C; honest-spend controls D). |
| `CV01Runner.log` | Verbatim `--run` output (19/19 PASS) + provenance footer. |

Findings (VERIFIED/PROPOSED split): `spec/db/findings-af/CV01.md`.

## Running

    cd <checkout>/spec/core
    lake env lean --run ../vectors/incidents/CV01/CV01Runner.lean

Read-only elaboration against the existing core oleans (NOT a
`lake build`; `spec/scripts/audit/cve_replay.py:178-192` uses the same
no-build approach)
— so it does not need the shared `build.lock`, which is for olean
*writers*. If the tree has been rebuilt since, rebuild nothing here:
the reference `CV01Runner.log` is the evidence record. At the first run
(2026-10-16 ~21:30) the `build.lock` was held for the whole
evening by mathlib `BitcoinProofs.*` builds in the separate
`spec/proofs` `.lake` tree (build waiters queued for hours); the
lock-free `lake env lean` run was clean (exit 0).

Not run: the RC08 `checkBlockTxs` (the INV-085 `CheckBlock` per-tx loop)
— `Bitcoin.Invariants.RC08` was not in the core build dir (the
invariants build was not yet available), so it is NOT imported/rebuilt here; its decide-pinned
`checkBlockTxs_dup` (RC08.lean:101-103) is cited in the findings.

## Non-goals / hand-offs

* The stateless-tier vector `spec/vectors/cve/cve-2018-17144-dup-inputs.json`
  (cve_replay.py tier) is NOT touched; these incident vectors are the
  full-lane + forced-lane tier. Registration of the two JSONs in
  `db/vector_ids.yaml` (vector-DB inventory) is a PROPOSED hand-off
  (P-CV01-002) — CV01 does not edit `db/` beyond `findings-af/CV01.md`.
* The forced-lane hole (stateless gate = the only duplicate defense) is
  recorded as F-CV01-006 + PROPOSED hardening P-CV01-001 — NOT filed as
  a defect (Core-faithful; see findings).
