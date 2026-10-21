# CELLS → LEDGER — wave64 policy flag-source (SCR-175, SCR-181)

Status: new cell landed, both tools green, certificates replay clean.
No shared file (`spec/db/equiv-cells.yaml`, `results/`, `docs/`) was edited.

## Artifact

- Cell: `spec/equiv/cells/policy-flags/C-L-flag-source/`
- Rows: SCR-175 (LOW_S), SCR-181 (CONST_SCRIPTCODE)
- Legs: C (validation.cpp:2249-2284 + policy.h:104-133 excerpt) and
  L (reviewed transliteration of `Bitcoin.Activation.Flags` + `PDW93b.standardPolicy`)
- Alive2: `alive2/result.txt` sha256
  `a0822d4dd7df08a47dcf97ac694c980333b60acfefb2f05e9e234653aaa9b0ea`
  (12 direction checks, 6 roots)
- SAW: `saw/result.txt` sha256
  `9be22b7cfa6c5efb032d685eabeb700bf5514b8aac9ea4f1e345a1aa0eb432b2`
  (12 proofs, 6 roots x 2 legs)
- Certificates: `alive2/certificate.sha256`, `saw/certificate.sha256`
  verify with `sha256sum -c` from the repo root.
- Coverage record: `scr_row_coverage: partial` (source/ordering half only;
  the gate halves are the sibling cells).

## What the cell proves

Bounded input `(exceptionClass, height)` where exceptionClass is the hash's
equivalence class under the two-entry mainnet `script_flag_exceptions` map
(TXV-056), and height is masked to 32 bits.

1. `cell_flag_source` = Core's composition: base, then exception replacement,
   then DERSIG/CLTV/CSV/NULLDUMMY ORs by buried height.  Order is proved.
2. `cell_flag_source_policy_mask` = block word & (LOW_S|CONST_SCRIPTCODE) = 0
   for every (class, height).
3. `cell_standard_policy_mask` = 0x10008 (both bits in the standard word).
4. `cell_mandatory_policy_mask` = 0 (neither bit mandatory).
5. `cell_lows_gate_block` feeds the block word to the LOW_S branch on the
   canonical DER skeleton; SIG_HIGH_S (27) is unreachable.
6. `cell_const_gate_block` feeds the block word to both CONST_SCRIPTCODE
   gates; 53 and 54 are unreachable.

A wrong-order mutant (exception replacement after the ORs) is rejected by
Alive2 with a counterexample: `tools/ordering_mutant.out`.
Hand-computed vectors: `tools/concrete_check.out` (C == L == expectation).

## Proposed ledger edits (LEDGER applies; CELLS did not edit the shared file)

### SCR-181 (recommend both-green)

```yaml
- id: SCR-181
  family: policy-flags
  summary: SCRIPT_VERIFY_CONST_SCRIPTCODE is policy (no OP_CODESEPARATOR evolution)
  core_ref: src/script/interpreter.cpp:484-486; src/script/interpreter.cpp:339-343@cce32b168
  consensus: false
  cells:
  - policy-flags/C-L-const-scriptcode
  - policy-flags/C-L-flag-source
  alive2:
    result: green
    cell: policy-flags/C-L-const-scriptcode
    certificate: 231da309d535b268137512d6c60b0a2a944b0d610860bdcd62541e45c41e2173
    note: Transformation seems to be correct!
  saw:
    result: green
    cell: policy-flags/C-L-const-scriptcode
    certificate: b7678981b99907151bc573f0f0552d8eb517d5df417ba01aabe8c4e1460c32c1
    note: Proof succeeded! cell_const_scriptcode_codesep
  status: both-green
  gap_note: null
```

The cited gates are full in `C-L-const-scriptcode`; the new cell adds the
source/order half and proves the gates cannot fire under the block word.

### SCR-175 (two defensible dispositions)

**Option A (recommended): both-green, with the parser domain recorded.**

```yaml
- id: SCR-175
  family: policy-flags
  summary: SCRIPT_VERIFY_LOW_S is mempool policy, never in GetBlockScriptFlags
  core_ref: src/script/interpreter.cpp:219-221@cce32b168
  consensus: false
  cells:
  - policy-flags/C-L-lows-policy
  - policy-flags/C-L-flag-source
  alive2:
    result: green
    cell: policy-flags/C-L-flag-source
    certificate: a0822d4dd7df08a47dcf97ac694c980333b60acfefb2f05e9e234653aaa9b0ea
    note: Transformation seems to be correct!
  saw:
    result: green
    cell: policy-flags/C-L-flag-source
    certificate: 9be22b7cfa6c5efb032d685eabeb700bf5514b8aac9ea4f1e345a1aa0eb432b2
    note: Proof succeeded! cell_flag_source
  status: both-green
  gap_note: null
```

Rationale: the row text is "LOW_S is mempool policy, never in
GetBlockScriptFlags".  That claim is now fully machine-proved: the block
selector never emits bit 3, the standard word does, the mandatory word does
not, and SIG_HIGH_S is unreachable when the gate is driven by the block
word.  The only residual is the *DER parser* domain of
`C-L-lows-policy` (other DER shapes), which is SCR-102's row
(interpreter.cpp:118-181), not SCR-175's cited lines (219-221).

**Option B: keep `gap` with a precise note.**

```yaml
  gap_note: >-
    flag-source/ordering half now proved by policy-flags/C-L-flag-source
    (block word never sets LOW_S; standard sets it; SIG_HIGH_S unreachable
    under the block word).  The LOW_S gate itself is proved only on the
    canonical DER skeleton by policy-flags/C-L-lows-policy.  The remaining
    domain (lenR > 1, lenS != 32, libsecp DER-lax parse) is blocked by the
    contract, not by a missing cell: ABI/tape take a concrete serialized
    tx_bytes/spk with no symbolic-length byte-array channel; the cell lane's
    C/L leaves are scalar uint64_t functions, and there is no agreed memory
    model for CScript/CScriptNum/FindAndDelete.  Full coverage needs a new
    contract version with a symbolic tape (or a byte-addressed leaf ABI with
    a memory spec) plus an unbounded-loop invariant for the lax parser, and
    still keeps the same-crypto seam of docs/DECISION-lax-ecdsa.md §2-3
    (SGN-107) for libsecp's parse/normalisation.  Until that contract change,
    the skeleton cell is the honest gate coverage.
```

Option B is the conservative reading if LEDGER requires every cell listed on
a green row to be full.  Option A is the reading that keeps row scope equal
to the row's cited lines and files the DER-parser residual under SCR-102,
where it belongs.  Either way the new cell is green and replayable.

## Blockers

- Full-DER-shape equivalence for `CheckSignatureEncoding`/`CheckLowS`:
  contract-context blocker above (concrete tape + no symbolic byte-array
  memory model), plus the same-crypto seam for libsecp.
- No tool blocker: Alive2 v20.0 and SAW 1.6 both ingest the new modules.
- No pin, patch, or twin change.
