# Notes — `checkmultisig/C-L-cms-nullfail-loop`

- **repo_head (base of this branch):** `5946c024546e39f55775bfd9a077b042e3feeef4`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **row:** SCR-110, `scr_row_coverage: partial` (NULLFAIL at the CHECKMULTISIG
  site; counts bounded at two keys)
- **patches:** none
- **status:** Alive2 green (1/1, bidirectional, checker uninterpreted);
  SAW green (4/4 proofs, 2 cases)

## Reproduce

From the repository root:

```bash
bash spec/equiv/cells/checkmultisig/C-L-cms-nullfail-loop/alive2/run.sh
bash spec/equiv/cells/checkmultisig/C-L-cms-nullfail-loop/saw/run.sh
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-nullfail-loop/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-nullfail-loop/saw/certificate.sha256
```

Certificates are the normalized, tracked-input form produced by
`spec/equiv/tools/normalize_certificates.py` (no `build/` artifacts; the raw
`result.txt` transcript is the only generated file hashed).

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (0ubuntu1~24.04.3) |
| LLVM | Ubuntu LLVM 20.1.2 |
| alive-tv | Alive2 v20.0 (Ubuntu LLVM 20.1.2) |
| SAW | 1.6 (`68eed5f release-1.6`) |

Both lanes use the family's shared harness (`../_shared/run_alive2.sh`,
`../_shared/run_saw.sh`, `../_shared/build_ir.sh`, `../_shared/cms_seam.h`)
and the shared checker stub.  Only the cell directory was added; no shared
file was edited.

## Design

`cell_cms_nullfail(nkeys, nsigs, nullfail, nulldummy, sig0, sig1, dummylen)`
models `interpreter.cpp:1132-1215` for `0 <= nSigs <= nKeys <= 2`:

1. **Loop (`1163-1191`).** Two unrolled bodies; one key is consumed per body,
   so two bodies cover the domain.  `sigId` advances only on a checker match,
   `nKeysCount` always decreases, and `nSigsCount > nKeysCount` sets
   `fSuccess = false` (the early exit).  With the cell's flags there is no
   DERSIG/LOW_S/STRICTENC gate to evaluate; the checker is the family seam.
2. **Scan (`1194-1201`).** Six unrolled pops, `pops = nKeys+nSigs+2`.
   `ikey2` starts at `nKeys+2`; at pop `p` the tested value is
   `nKeys+2-(p-1)` clamped at 0.  The test runs *before* the decrement and
   before the pop, so a firing step performs `p-1` pops and returns.
3. **Tail (`1211-1215`).** `NULLDUMMY && dummylen != 0 -> 28`; otherwise pop
   the dummy and push `vchTrue`/`vchFalse`.

The stack is canonical and top-down:

| position | item | length | value |
|---|---|---|---|
| 1 | nKeys count | 1 | `nKeys` |
| 2..nKeys+1 | pubkeys | 1 | `0x40+key index` |
| nKeys+2 | nSigs count | 1 | `nSigs` |
| nKeys+3..nKeys+nSigs+2 | signatures | `sig0`/`sig1` emptiness | `0x40+sig index` |
| nKeys+nSigs+3 | dummy | `dummylen` emptiness | — |

Every non-signature item is non-empty on purpose: the only way the gate can
fire is on a signature, because `ikey2` is non-zero above the signature
region.  For `nKeys = 1, nSigs = 1` the scan is:

| pop p | top item | tested ikey2 | gate? |
|---|---|---|---|
| 1 | nKeys count (len 1) | 3 | no (ikey2 != 0) |
| 2 | pubkey (len 1) | 2 | no |
| 3 | nSigs count (len 1) | 1 | no |
| 4 | signature (slot sig0) | 0 | **fires iff !fSuccess && NULLFAIL && sig0 != 0** |

## Witnesses (Alive2 input space; SAW case 0 = checker false, 1 = true)

Packed value layout in `src/cms_nullfail_obs.h`.  All values below were
observed on both legs (Alive2 proves the equality for every input; the
decoded fields are quoted for review).

| # | mode | nk | ns | nf | nd | s0 | s1 | dl | packed | decoded |
|---|---|---|---|---|---|---|---|---|---|---|
| W1 | 0 | 1 | 1 | 1 | 0 | 1 | 0 | 0 | `0x10484380` | res 0, err 32, popped 3, firePos 4, ikey2 0, fireLen 1, depthAfter 2, pushed 2, fsv 0 |
| W2 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | `0x20370401` | res 1, err 0, popped 4, no fire, depthAfter 1, pushed 0 (false), finalDepth 1, fsv 0 |
| W3 | 0 | 1 | 1 | 0 | 0 | 1 | 0 | 0 | `0x20370401` | NULLFAIL off: continuation, identical to W2 |
| W4 | 0 | 2 | 1 | 1 | 1 | 0 | 0 | 1 | `0x12370570` | res 0, err 28 (NULLDUMMY), popped 5, no NULLFAIL fire, dummyLen 1 |
| W6 | 0 | 2 | 2 | 1 | 0 | 0 | 1 | 0 | `0x10486580` | res 0, err 32, popped 5, firePos 6, ikey2 0, fireLen 1 (second signature; the first is empty) |
| W7 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | `0x68370201` | res 1, popped 2, pushed 1 (true), fsv 1 (nSigs = 0 -> ok true) |
| — | 1 | 1 | 1 | 1 | 0 | 1 | 0 | 0 | `0x68370401` | checker true: continuation, pushed true |
| — | 1 | 2 | 1 | 1 | 1 | 0 | 0 | 1 | `0x52370570` | checker true but non-empty dummy + NULLDUMMY -> 28 |

W1 is the row's target case: `nKeys = 1, nSigs = 1`, failing non-empty
signature, NULLFAIL set -> `SIG_NULLFAIL = 32` at the signature pop, after
three pops, with no pop performed on the failing step.  W4 shows the
precedence boundary: a non-empty but *empty-signature* case passes the
NULLFAIL arm and reaches the NULLDUMMY arm; the error is 28, not 32.

## Mutation sensitivity (checked in a scratch copy, not committed)

Each mutant edits one condition in `src/c_cms_nullfail.cpp`; the L leg and the
oracle stay unchanged.

| mutant | edit | Alive2 | SAW (case 0) |
|---|---|---|---|
| M1 | drop `&& k2 == 0` (no `!ikey2` position gate) | Value mismatch, src `0x10ec1080` vs tgt `0x20370601` | `Proof failed` |
| M2 | test `k2 == 1` (ikey2 after the decrement) | Value mismatch, src `0x10894380` vs tgt `0x20370601` | `Proof failed` |
| M3 | drop `&& len != 0` (no non-empty-signature guard) | Value mismatch, src `0x10404380` vs tgt `0x20370401` | `Proof failed` |

The `src` value is the mutated C leg and `tgt` the unchanged L leg at the
input Alive2 chose; the mismatch is the point.  M1/M2 fire on the non-empty
nKeys count / nSigs count respectively, which the `firePos`/`ikey2Fire`/
`fireLen` fields expose; M3 fires on an empty signature, which the
continuation witnesses expose (its counterexample target equals W2's correct
continuation value).  The SAW check is on the mutated C module only; the L
module still proves against the oracle.

## Residual (filed)

The exact remaining gap for the CHECKMULTISIG NULLFAIL site is the count
domain: this cell proves `0 <= nSigs <= nKeys <= 2`, while the row allows
`nKeys <= MAX_PUBKEYS_PER_MULTISIG = 20`.  Both the loop body count and the
scan length grow with the counts, so the residual is `nKeys in [3,20]`
(and the corresponding `nSigs`).  Closing it requires a 20-body unroll of the
loop and a 42-pop scan (or a symbolic-trip-count scan with a SAW loop
invariant, which this harness does not support).  The residue is recorded in
`spec/equiv/findings/wave64/58-cms-nullfail-loop/report.md`; the shared
ledger `spec/db/equiv-cells.yaml` and `cells/INDEX.md` are generated/shared
and intentionally not edited by this cell.

## Notes

- No anomaly was found during development.  The first draft carried an
  `extra` prefix input; it was removed to keep the cell focused on the scan
  and to keep the Alive2 query under the default SMT timeout.  The surviving
  prefix shape is the tail cell's row (NULLFAIL off).
- SAW's unused-argument warnings for the constant checker instances are
  expected (`chk0`/`chk1` ignore their arguments).
