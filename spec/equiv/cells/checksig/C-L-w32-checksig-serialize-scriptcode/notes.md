# Notes — `C-L-w32-checksig-serialize-scriptcode`

- **repo_head:** `4d62a97e551082a69b13f495365bff0a903b0c99`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **patches:** none. No Core source was modified.

## Reproduce

From the worktree root:

```bash
spec/equiv/cells/checksig/C-L-w32-checksig-serialize-scriptcode/alive2/run.sh
spec/equiv/cells/checksig/C-L-w32-checksig-serialize-scriptcode/saw/run.sh
```

Each lane regenerates its `result.txt` and `certificate.sha256`.
Certificates are repo-root relative; verify from the worktree root:

```bash
sha256sum -c spec/equiv/cells/checksig/C-L-w32-checksig-serialize-scriptcode/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checksig/C-L-w32-checksig-serialize-scriptcode/saw/certificate.sha256
```

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 |
| LLVM (`llvm-extract`, `llvm-dis`, `opt`) | Ubuntu LLVM 20.1.2 |
| alive-tv | Ubuntu LLVM 20.1.2 (Alive2 v20.0) |
| SAW | 1.6 (`68eed5f release-1.6`) |

Alive2 is run with `--fail-src-ub --smt-to=180000 --bidirectional`.
The extracted IR is loop-checked with `opt -passes='print<loops>'`; a
non-zero loop count is a hard failure (Alive2's loop model is unsound for this
cell pattern).  The scalar byte-select / unrolled GetOp form is used
deliberately: symbolic array indexing made the same proofs time out.

SAW runs the `-O0` bitcode on concrete oracle-derived inputs.  It is a
closed-scenario lane complementary to the symbolic Alive2 proof; it is not a
second symbolic equivalence proof.

## Caveats

- Bounded source-slice transliterations, not whole-engine equivalence.
- No crypto/hash claim.  The signature bytes are uninterpreted payload; the
  cells in this family do not call a signature checker except where noted.
- Full row coverage refers to every branch/edge named by the SCR row within
  the declared bounded domain, per the cell contract.

## Result (this run)

- Alive2: loop count 0, `1 correct transformation`, `STATUS=alive2-green`.
- SAW: 13 closed scenarios x 2 legs = 26/26 proofs; `STATUS=saw-green`
  (the two malformed-tail scenarios prove the shared out-of-domain sentinel).
- Row: SCR-101; `scr_row_coverage: full` on the declared six-byte domain.
- Raw: `alive2/result.txt`, `saw/result.txt`; certificates verified from the
  worktree root.

## Note on malformed scriptCode

The reachable scriptCode is fully parseable: EvalScript returns BAD_OPCODE
before a CHECKSIG can build a scriptCode from a malformed push.  Core's
`GetScriptOp` advances its iterator past the opcode/length bytes even when it
then fails on a truncated payload, so `SerializeScriptCode`'s final
`it - itBegin` write has writer-specific behaviour on an unreachable malformed
tail.  The Lean `getOpAt`/`walkOps` leaves the index at the failure point.
This cell does not model that unreachable difference: it returns a shared
sentinel on a malformed walk and restricts the equivalence claim to fully
parseable scriptCode, which is the reachable domain.  This is not an SCR-101
gap; it is an explicit out-of-domain abstention.
