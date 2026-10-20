# Notes — `checkmultisig/C-L-cms-enc-loop`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **row:** SCR-117, `scr_row_coverage: partial` (two pairs; validators abstract)
- **patches:** none
- **status:** Alive2 green (1/1, bidirectional, checker + validators
  uninterpreted); SAW green (12/12 proofs, 6 cases).

## Reproduce

From the repository root:

```bash
bash spec/equiv/cells/checkmultisig/C-L-cms-enc-loop/alive2/run.sh
bash spec/equiv/cells/checkmultisig/C-L-cms-enc-loop/saw/run.sh
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-enc-loop/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-enc-loop/saw/certificate.sha256
```

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (0ubuntu1~24.04.3) |
| LLVM | Ubuntu LLVM 20.1.2 |
| alive-tv | Alive2 v20.0 (Ubuntu LLVM 20.1.2) |
| SAW | 1.6 (`68eed5f release-1.6`) |

## Design

`cell_cms_enc(nkeys, nsigs)` reproduces the two gate calls inside Core's loop
(1171-1174): signature encoding first, then pubkey encoding, then the checker;
either gate aborts with its own contract ordinal and no counter update.  The
observable is a per-body trace (entered, sig-gate fired, pubkey-gate fired,
checker called, checker true) plus the first error ordinal, so a gate moved
outside the loop, evaluated in the wrong order, or evaluated *after* the
checker changes the packed value.

Element convention is shared with the order cell: signature k -> (len 1,
0x40+k), key j -> (len 1, 0x40+j).  The pushes sent to the validators are the
same elements, so a validator can distinguish signatures.

SAW cases (all with the same FindAndDelete-free build):

| Case | Signature gate | Pubkey gate | Checker | Purpose |
|---|---|---|---|---|
| 0 | accept | accept | false | early exit after one body |
| 1 | accept | accept | true | two matches, pass |
| 2 | accept | accept | diagonal | matching interplay |
| 5 | reject all (24) | accept | false | sig gate first, no checker |
| 6 | reject sig 1 only (24) | accept | diagonal | per-pair: body 0 checks, body 1 gate fires |
| 7 | accept | reject all (29) | false | pubkey gate before checker |

Case 6 required a stub change from the original family draft: the checker
mode is 2 (diagonal) and the signature gate rejects only the second signature
(low byte 0x41).  Without the diagonal checker, body 0 would fail to match,
the loop would early-exit, and body 1 would never be reached, so the per-pair
claim would have no witness.

## Anomaly fixed during development

The first packer wrote the *entered mask* into the "bodies entered" field.
For one body the mask and the count coincide; for two bodies they differ
(mask 3 vs count 2) and SAW found the mismatch at `nk=2, ns=1`.  Fixed by
passing the body count (`steps`) and keeping the mask for the per-body bits.

## Result detail

Alive2: `Transformation seems to be correct!`, 1 correct transformation,
0 errors.  SAW: 6 cases x 2 legs = 12 `Proof succeeded!` lines,
`STATUS=saw-green (12 proofs, 6 cases)`.

## Why partial

- The loop is unrolled twice (nKeys <= 2; the row allows 20).
- `flags = 0` and the validators are abstract seam symbols: the cell proves
  the call sites/order/precedence/latch, not BIP66/BIP62 policy content.

## Limits

- nKeys <= 2, nSigs <= nKeys.
- FindAndDelete and matching order are separate cells.
- Same-crypto premise for the checker; the validators are a second shared
  abstraction.
