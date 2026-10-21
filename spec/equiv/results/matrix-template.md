> **TEMPLATE ONLY — not current coverage.** The live generated matrix is
> `results/matrix.md` (152 both-green, 2 unjudged-seam, 29 gap, 0 planned at
> the E6 checkpoint). The `0/0`/`planned` values below are placeholders from
> the E0 skeleton.

# LLVM equivalence matrix — template

Skeleton for the published matrix in `docs/LLVM-EQUIVALENCE.md`. Replace the
`0/0` placeholders with **green / attempted** cell counts once E1–E4 land.
`Status` is the ledger aggregate for the family (all `planned` at E0); a family
is not green until every row is green, `unjudged-seam`, or a filed gap.
Generate the live values from `spec/db/equiv-cells.yaml` at E6.

| Family | SCR rows | Alive2 | SAW | Status | Notes |
|---|---:|---|---|---|---|
| `exec-verify` | 17 | 0/0 | 0/0 | planned | §B.1 execution model & VerifyScript; whole-function cell at E5 |
| `limits` | 27 | 0/0 | 0/0 | planned | §B.2 limits & accounting |
| `push-encoding` | 11 | 0/0 | 0/0 | planned | §B.3 push & encoding rules |
| `control-flow` | 17 | 0/0 | 0/0 | planned | §B.4 control flow |
| `stack-ops` | 6 | 0/0 | 0/0 | planned | §B.5 stack ops; E1 pilot family + mutation test |
| `numeric` | 14 | 0/0 | 0/0 | planned | §B.6 numeric ops & ScriptNum |
| `hash-ops` | 3 | 0/0 | 0/0 | planned | §B.7 hash ops |
| `checksig` | 18 | 0/0 | 0/0 | planned | §B.8 checksig (pre-tapscript); symbolic checker seam |
| `checkmultisig` | 8 | 0/0 | 0/0 | planned | §B.9 CHECKMULTISIG |
| `locktime` | 11 | 0/0 | 0/0 | planned | §B.10 locktime (CLTV/CSV) |
| `witness-v0` | 9 | 0/0 | 0/0 | planned | §B.11 SegWit v0 |
| `tapscript` | 28 | 0/0 | 0/0 | planned | §B.12 Taproot/Tapscript (`06-script-interpreter.md`) |
| `disabled-opcodes` | 5 | 0/0 | 0/0 | planned | §B.13 disabled opcodes |
| `tapscript-reimport` | 1 | 0/0 | 0/0 | planned | w2-06 §B.1 tapscript re-import (consensus) |
| `policy-flags` | 8 | 0/0 | 0/0 | planned | w2-06 §B.12 policy-only flags (all non-consensus) |
| **Total** | **183** | **0/0** | **0/0** | **planned** | **0 green, 0 unjudged-seam, 0 filed gaps** |

## Column and status legend

- **Alive2 / SAW:** `green / attempted`; an inapplicable tool still counts as
  attempted and its reason lives in the ledger's `alive2` or `saw` record.
- **Status:** `planned` | `alive2-green` | `saw-green` | `both-green` |
  `unjudged-seam` | `gap` (same enum as `spec/db/equiv-cells.yaml`).
- **Notes:** name the source section; every gap must name its blocking IR
  feature or seam in the ledger's `gap_note`, never only here.

## Coverage footer skeleton

| Metric | Value |
|---|---:|
| SCR rows | 183 |
| Both-tool green | 0 |
| One-tool green | 0 |
| Unjudged seam | 0 |
| Filed gaps | 0 |
| Rows still planned | 183 |
| `coverage_report.py --strict` | FAIL (expected at E0) |
