# Notes — C-L-verify-sequential-boundary

**Verdict:** both tools green over fully symbolic inputs.
`scr_row_coverage` is **full** for SCR-001 under the row's own
EvalScript-outcome premise (`hss`, `hspk`).  The whole-function opcode
semantics of EvalScript is the E5 residual and is explicitly out of this row's
claim.

**Raw runs** (from the repository root):

```sh
bash spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/saw/certificate.sha256
```

Result files: `alive2/result.txt` (4 function pairs, 4 ×
`Transformation seems to be correct!`, `STATUS=alive2-green`) and
`saw/result.txt` (8 × `Proof succeeded!`, `STATUS=saw-green`).

## The four obligations

The C leg is a line-cited source slice of the pinned Core
(`script.cpp:313-363`, `interpreter.cpp:419-421`, `455-456`, `2026-2040`);
the L leg is a reviewed transliteration of the generated twin
(`runtime.inc:240-280`, `592-608`, `781-805`).  Both are closed against the
independent contract in `src/cell.cry`.

1. `cell_push_boundary` — GetScriptOp's boundary decision for one push header,
   complete over every opcode byte and every declared length in the reachable
   domain (`end - pc <= MAX_SCRIPT_SIZE`).  C uses
   `(unsigned)(end - pc) < nSize`; L uses `k > size - i - prefix`.  The two
   expressions are different, so Alive2 is doing a semantic comparison.
2. `cell_split_verdict` — the (sequential, concatenated) verdict pair for the
   straddling-push family.  Sequentially the push is truncated at
   `scriptSig.end()` and yields BAD_OPCODE(16); concatenation sees the whole
   payload and yields the element verdict.
3. `cell_split_diff` — 1 exactly when the two verdicts differ, i.e. exactly
   when `after < declared`.
4. `cell_verify_tail` — VerifyScript order: a scriptSig error short-circuits
   before the scriptPubKey; otherwise the scriptPubKey runs on the same stack
   and its result decides the final verdict.

## Two modelling errors found by SAW (kept as evidence)

The first green attempt was not accepted on trust; both errors were found by
the tool itself and are recorded here rather than hidden.

1. **Length-prefix accounting.**  The initial family passed
   `after` ("payload bytes present") straight to `GetScriptOp` as `end - pc`,
   dropping the 1/2 length bytes of OP_PUSHDATA1/2.  SAW produced the
   counterexample `declared = 8190, after = 4095` where the concatenated
   verdict was wrongly BAD_OPCODE.  Fixed by handing the parser
   `header_len(declared) + present`, and by adding the MAX_SCRIPT_SIZE check
   on the concatenated buffer (`1 + header_len + declared <= 10000`).
2. **Truth-value of the carried element.**  The first contract said the
   verdicts differ only when the element casts true.  They differ for
   `truthy = 0` too: sequential is BAD_OPCODE(16), concatenated is
   EVAL_FALSE(2).  SAW counterexample `declared = 154, after = 46,
   truthy = 0`.  Fixed in `cell.cry` (`split_diff` no longer inspects truthy).

## Discriminating mutant

`spec/equiv/findings/wave66/01-scr-001/mutant/run.sh` feeds the sequential arm
the concatenated end (`hdr + after_op` -> `hdr + declared`).  SAW rejects it
with `declared = 8334, after = 8191, truthy = 0` and
`STATUS=mutant-rejected`; the unmutated cell is green.  The cell is therefore
not vacuous.

## What is *not* in this cell

EvalScript's opcode semantics for arbitrary scripts (E5, also SCR-003/SCR-045).
The universal composition statement conditional on the two EvalScript outcomes
is the already-present Lean target
`BitcoinProofs.AF.PDW90.verifyScriptFull_sequential`
(`spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:36-50`).  The concrete
CVE-2010-5141 witness is separately executed on the real pinned Core IR in
`spec/equiv/findings/wave66/01-scr-001/core-witness/`.

**Certificate.** `alive2/certificate.sha256` and `saw/certificate.sha256` hash
the spec, sources, shared `_tools/w32-exec` harness, pinned
`contract/error_kind.h`, twin sources, build IR and the raw result; verify from
the repository root with `sha256sum -c`.
