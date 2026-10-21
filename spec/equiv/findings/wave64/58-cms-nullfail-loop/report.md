# Wave64 / 58 — CHECKMULTISIG NULLFAIL site (SCR-110)

**Date:** 2026-10-20
**Base:** `5946c024546e39f55775bfd9a077b042e3feeef4`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Cell:** `spec/equiv/cells/checkmultisig/C-L-cms-nullfail-loop`
**Row:** SCR-110 (`NULLFAIL`), second site `interpreter.cpp:1196-1197`

## Scope

The SCR-110 row has two sites: the pre-tapscript CHECKSIG tail
(`interpreter.cpp:351-352`, already covered by
`checksig/C-L-checksig-nullfail-hashtype`) and the CHECKMULTISIG cleanup scan
(`interpreter.cpp:1196-1197`).  The checkmultisig family's previous cells
covered the scan with NULLFAIL *off* (`C-L-cms-tail-sym`) and the loop's
encoding gates (`C-L-cms-enc-loop`), leaving the second site unproved.  This
work adds the missing cell at a small count unroll: `0 <= nSigs <= nKeys <= 2`,
starting from the requested `nKeys = 1, nSigs = 1`, failing non-empty
signature, NULLFAIL set.

## What is proved

`cell_cms_nullfail(nkeys, nsigs, nullfail, nulldummy, sig0, sig1, dummylen)`
is a line-cited C slice (`1132-1215`) and a reviewed Lean transliteration of
`cmsLoop` / `cmsCleanup` / `checkMultiSig` (`Defs.lean:672-718`, `1091-1127`).
It covers:

1. **Error ordinal.** A failing non-empty signature with NULLFAIL set returns
   `SIG_NULLFAIL = 32` at the signature pop, *before* the pop, before the
   NULLDUMMY arm and before the boolean push.  For 1-of-1 this is pop 4 of 4
   (`ikey2 = 0`), packed `0x10484380` (res 0, err 32, popped 3, firePos 4,
   ikey2 0, fireLen 1).
2. **Position gate.** The tested `ikey2` is the *pre-decrement* value
   `nKeys+2-(p-1)`, so only the signature region (`p >= nKeys+3`) can fire.
   Non-signature items are non-empty, so dropping `!ikey2` or testing after
   the decrement changes the observable.
3. **Continuation.** An empty signature, or NULLFAIL off, completes all
   `nKeys+nSigs+2` pops, reaches the NULLDUMMY gate and pushes
   `vchTrue`/`vchFalse` (`0x20370401` for the 1-of-1 empty-signature case).
   The 2-keys/1-empty-signature/NULLDUMMY case reaches ordinal 28, not 32
   (`0x12370570`), which pins the precedence.
4. **Loop verdict coverage.** Alive2 quantifies over the abstract checker, so
   both loop outcomes are covered; SAW links the always-false and always-true
   stub instances (cases 0 and 1).

## Evidence

| Lane | Command | Result | Certificate |
|---|---|---|---|
| Alive2 | `alive2/run.sh` (`alive-tv --bidirectional`) | 1 correct, 0 incorrect, 0 failed-to-prove | `4d0a235e201ad053d6ad16800b982a4049f6adcc666a6b37ecfc5e2b9de9c6e6` (15 tracked entries) |
| SAW | `saw/run.sh` (cases 0,1) | 4/4 `Proof succeeded!`, `STATUS=saw-green` | `1b15a9ff1477ea0d4a10e92fd469cad392ba701b70d729c1d7caef3fb732d425` (16 tracked entries) |

Certificates are normalized with
`spec/equiv/tools/normalize_certificates.py`: they hash only tracked cell
inputs (spec, notes, sources, oracle, runners) plus the raw `result.txt` and
the shared harness files; no `build/` artifact is referenced.  Both
`sha256sum -c` runs pass.

Raw IR hashes (from `alive2/result.txt` and `build/build.txt`):

- C leaf `24e7e22e7621d64d65415470cbc53818907e4c18f0137a09a606017e5ce13f0b`
- L leaf `77e0f3a8017ab8238dc1d784716d1f4063ae4504090f8cec77f0e85c84e019ac`
- compared IR `fbb7cb81e682ca8fdb6a1906822d51e48681ec2658ebaee051e4378d69aa0239`
  (C) / `6099f0ce7727b5db2718d96f3e6530e31d4ef2b9b2471c0103110359de8c4f93` (L)

## Mutation sensitivity

Three mutants of the C leg (L leg and oracle untouched) were checked in a
scratch copy:

| mutant | edit | Alive2 | SAW case 0 |
|---|---|---|---|
| M1 | drop `&& k2 == 0` (no `!ikey2`) | Value mismatch (`0x10ec1080` vs `0x20370601`) | `Proof failed` |
| M2 | test `k2 == 1` (ikey2 after decrement) | Value mismatch (`0x10894380` vs `0x20370601`) | `Proof failed` |
| M3 | drop `&& len != 0` (empty signature fires) | Value mismatch (`0x10404380` vs `0x20370401`) | `Proof failed` |

## Residual filed

The exact loop residual for the CHECKMULTISIG NULLFAIL site is the count
domain:

> The cell proves `0 <= nSigs <= nKeys <= 2` (loop unrolled twice, scan
> unrolled six times), while the row allows
> `nKeys <= MAX_PUBKEYS_PER_MULTISIG = 20`.  **Residual: `nKeys in [3,20]`**
> (and the corresponding `nSigs <= nKeys`), because both the loop trip count
> and the scan length (`i-1 = nKeys+nSigs+2 <= 42`) grow with the counts.

Closing it requires a 20-body loop unroll and a 42-pop scan, or a
symbolic-trip-count scan with a SAW loop invariant (not supported by the
current family harness).  No other property at this site is left open:
the `!ikey2` position gate, the pre-decrement order, the non-empty-signature
guard, the ordinal `32`, and its precedence over NULLDUMMY `28` are proved for
the unrolled domain.  Signature *contents* reduce to emptiness at the seam,
which is all the guard reads; the checker verdict is the same-crypto premise
(`docs/DECISION-lax-ecdsa.md`), as for the rest of the family.

## Registration

`spec/db/equiv-cells.yaml` and `spec/equiv/cells/INDEX.md` are shared,
generated artifacts and were intentionally **not** edited.  The ledger tool
already resolves the new cell and keeps the row's status unchanged:

```
cells scanned: 142 (valid 142, malformed 0)
changes: 1
  - SCR-110: both-green -> both-green (2 cell(s))
```

The row stays `both-green` on the strength of the pre-tapscript CHECKSIG cell
(non-partial); this cell contributes partial evidence for the CMS site and
never discharges the whole row (the derivation consults
`scr_row_coverage: partial`).

## Files

```
cells/checkmultisig/C-L-cms-nullfail-loop/
  spec.md                          front matter + claim, residual, citations
  notes.md                         design, witnesses, mutation table, reproduce
  alive2/{run.sh,result.txt,certificate.sha256}
  saw/{run.sh,spec.saw.in,model.cry,result.txt,certificate.sha256}
  src/c_cms_nullfail.cpp           line-cited C slice
  src/l_cms_nullfail.cpp           reviewed Lean transliteration
  src/cms_nullfail_obs.h           cell-local observable packer
```

No shared file was modified; no other cell's certificate changed (the
normalizer's unrelated `stack-ops/C-L-pick` drift was reverted).
