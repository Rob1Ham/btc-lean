# CELLS → LEDGER — wave66 SCR-001

Status: new cell landed; Alive2 and SAW both green; certificates replay; a
real-Core concrete witness and a rejected concatenation mutant are recorded.
No shared file (`spec/db/equiv-cells.yaml`, `results/`, `docs/`) was edited.

Recommended disposition for SCR-001: **both-green**, with the existing partial
cell kept in `cells:` as supporting evidence (the derivation already lists
both), and `gap_note: null`.

Derivation check (read-only):

```sh
python3 spec/equiv/results/scripts/update_ledger.py --check
# cells scanned: 165 (valid 165, malformed 0)
# SCR-001: status='both-green', cells=['exec-verify/C-L-verify-sequential-boundary',
#   'exec-verify/C-L-w32-verify-sequential'], gap_note=None
```

Proposed ledger block (LEDGER applies; CELLS did not edit the file):

```yaml
- id: SCR-001
  family: exec-verify
  summary: Sequential evaluation, not concatenation
  core_ref: interpreter.cpp:VerifyScript:2026-2036@cce32b168
  consensus: true
  cells:
  - exec-verify/C-L-verify-sequential-boundary
  - exec-verify/C-L-w32-verify-sequential
  alive2:
    result: green
    cell: exec-verify/C-L-verify-sequential-boundary
    certificate: 8684af755609b4ef3c6dd53ccfd494486990d61a5e33bd8e14276bef2601721f
    note: Transformation seems to be correct!
  saw:
    result: green
    cell: exec-verify/C-L-verify-sequential-boundary
    certificate: af03d025c3cf897834d235bde488c53192b1ecbc5d7ce5b36ed6f16d507b9e4e
    note: Proof succeeded! cell_push_boundary
  status: both-green
  gap_note: null
```

Why the row is full:

- `exec-verify/C-L-verify-sequential-boundary` declares
  `scr_row_coverage: full for the row's claim, under the row's own
  EvalScript-outcome premise` (no per-row "partial" bullet).  It proves the
  sequential/same-stack handoff (`cell_verify_tail`) and the complete
  push-boundary decision over all push encodings and in-domain declared
  lengths (`cell_push_boundary`, `cell_split_verdict`, `cell_split_diff`).
- The universal composition statement is the existing Lean target
  `BitcoinProofs.AF.PDW90.verifyScriptFull_sequential`, conditional on the two
  EvalScript outcomes exactly as the row face is.
- The wave-32 residual (the CVE-2010-5141 parse-boundary witness) is
  discharged concretely on the real pinned Core IR in
  `findings/wave66/01-scr-001/core-witness/` (4 SAW proofs, BAD_OPCODE 16,
  scriptPubKey not evaluated).
- `exec-verify/C-L-w32-verify-sequential` remains `partial`; it is supporting
  evidence for the stack-threading half, not the row's discharge.  Listing it
  is harmless: the ledger only refuses to promote a row when *every* green
  cell is partial.

Out-of-row residual: EvalScript's whole-function opcode semantics (E5, also
SCR-003/SCR-045).  It is not part of SCR-001's cited claim.

Evidence hashes:

| artifact | sha256 |
|---|---|
| `cells/.../saw/result.txt` | `af03d025c3cf897834d235bde488c53192b1ecbc5d7ce5b36ed6f16d507b9e4e` |
| `cells/.../alive2/result.txt` | `8684af755609b4ef3c6dd53ccfd494486990d61a5e33bd8e14276bef2601721f` |
| `core-witness/result.txt` | `c8a3c9a75a0cfaa49352520c8d2e9cb1fa2868171a720d442dad3161002f46b6` |
| `mutant/result.txt` | `506ad8d97eecaad7bbf36b54a0ebf8b8ac01e9c02ff28a6bae2965e7cc744dcb` |
| pinned Core module `interp-script-roots3.bc` | `2795c02ea67c77ff3674d16da074b1f8b884861fc6f157b6274feba9d8227ae1` |
