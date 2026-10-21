# SCR-001 — Sequential evaluation, not concatenation (CVE-2010-5141)

Status: **full green row, both tools, plus a concrete witness on the real
pinned Core IR.**  Base `8142cff`, branch `wave66/01-scr-001`, worktree
`/tmp/opencode/wave66/01-scr-001`.  No shared file (`spec/db/**`,
`spec/proofs/**`, `spec/core/**`, `PINS.lock`, `contract/**`, `results/**`,
`docs/**`, existing cells) was edited.

## Artifacts

- New cell: `spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/`
  - `scr_rows: SCR-001`, `scr_row_coverage: full` (under the row's own
    EvalScript-outcome premise), `tool_status: both-green`.
  - SAW: 8 proofs = 4 functions × 2 legs, all `Proof succeeded!`;
    `saw/result.txt` sha256
    `af03d025c3cf897834d235bde488c53192b1ecbc5d7ce5b36ed6f16d507b9e4e`,
    `STATUS=saw-green`.
  - Alive2: 4 function pairs, 4 × `Transformation seems to be correct!`,
    4 × `1 correct transformation`; `alive2/result.txt` sha256
    `8684af755609b4ef3c6dd53ccfd494486990d61a5e33bd8e14276bef2601721f`,
    `STATUS=alive2-green`.
- Real-Core witness:
  `spec/equiv/findings/wave66/01-scr-001/core-witness/` — 4 SAW proofs on the
  pinned linked Core module; `result.txt` sha256
  `c8a3c9a75a0cfaa49352520c8d2e9cb1fa2868171a720d442dad3161002f46b6`,
  `STATUS=core-witness-green`.
- Mutant:
  `spec/equiv/findings/wave66/01-scr-001/mutant/` — concatenation mutant
  rejected by SAW with a counterexample; `result.txt` sha256
  `506ad8d97eecaad7bbf36b54a0ebf8b8ac01e9c02ff28a6bae2965e7cc744dcb`,
  `STATUS=mutant-rejected`.
- Ledger handoff: `handoff.md` (CELLS does not edit the ledger).

## Exact commands

```sh
cd /tmp/opencode/wave66/01-scr-001

# cell, both tools (each run rebuilds build/ then emits its certificate)
bash spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/saw/run.sh
bash spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/alive2/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/saw/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-verify-sequential-boundary/alive2/certificate.sha256

# concrete CVE witness on the real pinned Core IR
bash spec/equiv/findings/wave66/01-scr-001/core-witness/run.sh
( cd spec/equiv/findings/wave66/01-scr-001/core-witness && sha256sum -c certificate.sha256 )

# discrimination: the concatenation mutant must be rejected
bash spec/equiv/findings/wave66/01-scr-001/mutant/run.sh
grep -q STATUS=mutant-rejected spec/equiv/findings/wave66/01-scr-001/mutant/result.txt

# ledger derivation (read-only; confirms the new cell is valid and SCR-001
# derives to both-green)
python3 spec/equiv/results/scripts/update_ledger.py --check
```

The derivation prints `cells scanned: 165 (valid 165, malformed 0)` and
`SCR-001: gap -> both-green (2 cell(s))`, with the new cell's certificates as
recorded above.

## What is proved

The row is decomposed into three machine-checked parts.

1. **Universal sequencing / stack handoff (Lean, already in the repo).**
   `BitcoinProofs.AF.PDW90.verifyScriptFull_sequential`
   (`spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:36-50`) proves, for
   arbitrary `ss`, `spk`, on the bare non-P2SH / non-witness face:
   `evalScriptBytes ss` succeeds on the empty stack with `stack1`, then
   `evalScriptBytes spk stack1` succeeds with a truthy top, implies
   `verifyScriptFull ss spk = .ok`.  The scriptPubKey receives `stack1`, not
   the scriptSig bytes.  The theorem is conditional on the two EvalScript
   outcomes (`hss`, `hspk`) and uses only `propext`/`Quot.sound` per its
   `#print axioms` guard.

2. **Complete finite-state boundary decision (new cell).**
   `cell_push_boundary` gives GetScriptOp's decision for every opcode byte and
   every declared length with `end - pc <= 10000`, covering direct pushes and
   OP_PUSHDATA1/2/4.  `cell_split_verdict` / `cell_split_diff` state the row's
   distinction for the straddling-push family over every in-domain
   `declared` (including the MAX_SCRIPT_SIZE domain check): sequentially the
   push is rejected at `scriptSig.end()` with BAD_OPCODE(16); a concatenated
   parse accepts it and yields the element verdict.  `cell_verify_tail`
   proves that a scriptSig error short-circuits (scriptPubKey never runs) and
   that otherwise the second evaluation decides the final truth on the same
   stack.  Alive2 compares two different expressions of the boundary
   (Core `(unsigned)(end - pc) < nSize` vs twin `k > size - i - prefix`) and
   SAW compares each leg to the independent Cry contract.

3. **Concrete CVE-2010-5141 witness on the real pinned Core IR.**
   Four singleton `VerifyScript` executions on
   `interp-script-roots3.bc` (sha256
   `2795c02ea67c77ff3674d16da074b1f8b884861fc6f157b6274feba9d8227ae1`),
   built by the wave16b probe from PINS.lock's pinned interpreter bitcode
   (`f5718af7...`) linked with the real `script.cpp` at pin `cce32b168`
   (`script-O0.bc` `657530a8...`).  Each returns `false` and writes
   `ScriptError_t = SCRIPT_ERR_BAD_OPCODE (16)`:

   | spec | scriptSig | scriptPubKey | result |
   |---|---|---|---|
   | `w01-ss-direct-trunc.saw` | `{0x01}` | `{0x51}` OP_1 | false, 16 |
   | `w02-ss-direct-trunc-spk-opdup.saw` | `{0x01}` | `{0x76}` OP_DUP | false, 16 |
   | `w03-ss-direct-trunc-spk-opreturn.saw` | `{0x01}` | `{0x6a}` OP_RETURN | false, 16 |
   | `w04-ss-pd4-trunc.saw` | `{0x4e,ff,ff,ff,ff}` | `{0x51}` OP_1 | false, 16 |

   `w02`/`w03` are the first-error-precedence checks: if the scriptPubKey
   were evaluated after a concatenated (or otherwise continued) parse, OP_DUP
   would report 18 and OP_RETURN 3; the observed 16 means the scriptPubKey was
   never evaluated.  `w04` covers OP_PUSHDATA4.

## Honest scope of the real-Core witness

This is a **concrete/singleton** proof, not a universal contract.  It inherits
the wave16b probe's module transforms, which are assumptions: exception
erasure (unwind edges to `unreachable`), internalization to the five-symbol
public API, ABI-global stubs, and `__cxa_guard` bytes pinned to 1.  The module
and upstream input hashes are in `core-witness/inputs.txt`; the builder is
`PROTO-w16b-getscriptop/builder/build-pinned-linked.sh` (sha256
`20c8199f...`).  The universal half of the row is the cell and the Lean target
above; the witness shows the pinned Core binary itself takes the truncation
branch and does not run the scriptPubKey.

## Residual (precise)

There is **no SCR-001 residual**.  The row claim is exactly "sequential
evaluation, not concatenation", i.e. the scriptPubKey is evaluated after — and
on the stack produced by — the scriptSig, never as bytes appended to the
scriptSig.  That is now:

- universally proved for arbitrary scripts in Lean, conditional on the two
  EvalScript outcomes;
- decided completely for every in-domain push encoding at the parse boundary
  by the new cell;
- exhibited on the real pinned Core IR for the CVE witness.

What remains **outside this row** is E5: EvalScript's opcode semantics for
arbitrary scripts (also tracked as SCR-003/SCR-045).  Neither the Lean row
target nor this cell claims it.

## Modelling corrections caught by the tools

Two real modelling bugs were found by SAW during this work and fixed; they are
recorded in `cells/.../notes.md`:

1. the length-prefix bytes of OP_PUSHDATA1/2 were initially omitted from
   `end - pc` (counterexample `declared=8190, after=4095`);
2. the first `split_diff` contract inspected the element's truth value
   (counterexample `declared=154, after=46, truthy=0`; a truncated push is
   BAD_OPCODE even when the carried element would be false).

The final mutant check (`hdr + after_op` -> `hdr + declared`) is rejected with
`declared=8334, after=8191, truthy=0`, so the green cell is discriminating.
