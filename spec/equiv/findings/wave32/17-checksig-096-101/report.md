# Wave 32 / task 17 — checksig SCR-096..101

- **Worktree:** `/tmp/opencode/wave32/17-checksig-096-101`
- **Branch:** `wave32/17-checksig-096-101`
- **Base:** `805c8042f92d3bed909ca40219a4d21fc9150cc1` (additive to PR #29)
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **Lean source of record:** `4d62a97e551082a69b13f495365bff0a903b0c99`
- **Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **Tools:** Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f release-1.6`),
  clang/clang++ 20.1.2.
- **Patches:** none. No Core, pin, contract, ledger, generated-results, Lean or
  existing-cell file was edited.

## Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| SCR-096 | **closed (full, bounded)** | `cells/checksig/C-L-w32-checksig-codesep` | For every six-byte script, every per-opcode fExec trace, both sigversions and the CONST_SCRIPTCODE bit: `scriptCode = script[codeSep..6]` where `codeSep` starts at 0 and is updated to `op.next` only by an executed OP_CODESEPARATOR; both legs agree in both directions. | Unbounded script length and the IF/ELSE derivation of the fExec trace are outside the cell. | None for the row; the bounded domain and the abstract fExec input are declared in `spec.md`. |
| SCR-097 | **closed (full, bounded)** | same codesep cell | Only an **executed** OP_CODESEPARATOR moves `codeSep`; an unexecuted one is ignored (constsc off) or rejected by the pre-check (constsc on, SCR-100). Covered with the same separator under both mask values and with two selectively executed separators. | The fExec trace is an unconstrained per-opcode input, not derived from IF/ELSE/ENDIF. | None for the row; declared abstraction. |
| SCR-098 | **closed (full, bounded)** | `cells/checksig/C-L-w32-checksig-findanddelete` | Byte-level FindAndDelete for serialized sig pushes of length 1/2/3 (sig length 0/1/2): matches only at GetOp boundaries, consecutive matches consumed, continuation after a match, payload 0xab not matched, malformed tail copied, empty result. Symbolic bidirectional equivalence of three function pairs. | Script length is bounded to 4/4/6 bytes; larger sig lengths are not in the cell. | None for the row; bounded domain declared. |
| SCR-099 | **closed (full, bounded)** | `cells/checksig/C-L-w32-checksig-constscriptcode` | `found > 0 && CONST_SCRIPTCODE` in BASE returns SIG_FINDANDDELETE (54) before any encoding check; found=0 and flag-off do not; WITNESS_V0 skips FindAndDelete entirely. One and two matches; needle lengths 1/2/3. | DER/LOW_S/STRICTENC/NULLFAIL and the ECDSA checker are outside the slice; script length bounded to six bytes. | None for the row; row-external checks declared out of scope. |
| SCR-100 | **closed (full, bounded)** | `cells/checksig/C-L-w32-checksig-codesep` | In BASE with CONST_SCRIPTCODE, a parsed OP_CODESEPARATOR is rejected with OP_CODESEPARATOR (53) **whether or not it is executed**; flag-off, unexecuted and WITNESS_V0 cases do not take that path. | Same bounded-domain/abstract-mask caveat as SCR-096/097. | None for the row. |
| SCR-101 | **closed (full, bounded)** | `cells/checksig/C-L-w32-checksig-serialize-scriptcode` | SerializeScriptCode emits CompactSize(6 − nsep) then the script with each **parsed** 1-byte 0xab removed; 0xab inside direct/PUSHDATA1/2/4 payloads is retained; parsed separators at offset 0, mid, tail, twice/thrice and all-separator are covered. Symbolic bidirectional equivalence. | Six-byte scriptCode; a malformed tail is out of the reachable domain and is abstained with a shared sentinel (see below). | None for the row; the abstention is explicit and does not affect reachable scriptCode. |

All six assigned rows are closed as **bounded C-L cells with full row-branch
coverage**, not as whole-engine equivalence proofs.  No row is left partial or
blocked.

## Cells and key artifacts

Each cell has `spec.md`, `notes.md`, `src/` (C and L source slices, build
script, independent oracle), `alive2/run.sh` + `result.txt` +
`certificate.sha256`, and `saw/run.sh` + `result.txt` + `certificate.sha256`.

| Cell | Functions | Alive2 terminal | SAW terminal |
|---|---|---|---|
| `C-L-w32-checksig-codesep` | `cell_codesep` | `STATUS=alive2-green` (1 correct, 0 incorrect, 0 failed-to-prove, 0 Alive2 errors; 0 loops both legs) | `STATUS=saw-green (20/20 proofs)` |
| `C-L-w32-checksig-findanddelete` | `cell_fad_pl1`, `cell_fad_pl2`, `cell_fad_pl3` | `STATUS=alive2-green` (3 x 1 correct; 0 loops) | `STATUS=saw-green (36/36 proofs)` |
| `C-L-w32-checksig-constscriptcode` | `cell_fadpol_pl1`, `cell_fadpol_pl2`, `cell_fadpol_pl3` | `STATUS=alive2-green` (3 x 1 correct; 0 loops) | `STATUS=saw-green (30/30 proofs)` |
| `C-L-w32-checksig-serialize-scriptcode` | `cell_ser` | `STATUS=alive2-green` (1 correct; 0 loops) | `STATUS=saw-green (26/26 proofs)` |

## Exact commands

From the worktree root:

```bash
spec/equiv/cells/checksig/C-L-w32-checksig-codesep/alive2/run.sh
spec/equiv/cells/checksig/C-L-w32-checksig-codesep/saw/run.sh

spec/equiv/cells/checksig/C-L-w32-checksig-findanddelete/alive2/run.sh
spec/equiv/cells/checksig/C-L-w32-checksig-findanddelete/saw/run.sh

spec/equiv/cells/checksig/C-L-w32-checksig-constscriptcode/alive2/run.sh
spec/equiv/cells/checksig/C-L-w32-checksig-constscriptcode/saw/run.sh

spec/equiv/cells/checksig/C-L-w32-checksig-serialize-scriptcode/alive2/run.sh
spec/equiv/cells/checksig/C-L-w32-checksig-serialize-scriptcode/saw/run.sh
```

The Alive2 lane compiles each source at `-O1 -fno-strict-aliasing
-S -emit-llvm`, extracts the function recursively, checks both extracted
modules with

```bash
/usr/lib/llvm-20/bin/opt -passes='print<loops>' -disable-output <ir>
```

and requires zero `Loop at depth` entries.  It then runs

```bash
/usr/local/bin/alive-tv --fail-src-ub --smt-to=180000 --bidirectional \
  build/<c>.extract.ll build/<l>.extract.ll
```

and records only raw tool output.  `--fail-src-ub` is mandatory here: during
development, uninitialised temporaries and out-of-bounds scalar loads produced
`Source function is always UB`, which is a vacuous pass; the final sources
initialise every observable and use bounded scalar selects.  The
`check_loops.py`-style label-order check used during prototyping was abandoned
in favour of LLVM's real loop analysis because optimised block order can make
a straight-line function look like it has a back-edge.

The SAW lane compiles at `-O0 -fno-strict-aliasing -emit-llvm -c` so the
closed scenarios execute the real branch structure rather than a
constant-folded return.  `src/oracle.py` restates the row semantics
independently, emits the scenarios and expected packed constants, and
`run.sh` runs `saw cell.saw` with `llvm_verify ... [] false <spec> abc` for
both modules.  No `llvm_unsafe_assume_spec` is used.  SAW is a closed-scenario
lane; Alive2 carries the symbolic equivalence claim.

## Certificate verification

Certificates are repo-root relative.  Verified from the worktree root with:

```bash
for c in codesep findanddelete constscriptcode serialize-scriptcode; do
  sha256sum -c spec/equiv/cells/checksig/C-L-w32-checksig-$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/checksig/C-L-w32-checksig-$c/saw/certificate.sha256
done
```

All eight certificates report `OK` for every listed artifact.  `build/` is
gitignored, as in the existing cells; the certificates are verified in the
worktree where the lanes were run.

## Development no-gos (recorded, not claimed as green)

These are the exact failed experiments that led to the final scalar,
unrolled form.  They are not evidence for any row.

1. **Array-indexed FindAndDelete, PL=2, N=4**:

   ```bash
   alive-tv --fail-src-ub --smt-to=180000 --bidirectional f_c_4_2_x.ll f_l_4_2_x.ll
   ```

   Result: `ERROR: Timeout`; `Summary: 0 correct, 0 incorrect,
   1 failed-to-prove, 0 Alive2 errors`.  PL=3, N=6 also timed out
   (`5m01s`, same summary).  Replacing symbolic array indexing with scalar
   byte selection and `always_inline` helpers reduced the same proofs to
   16–17 s (PL=1/2) and 181 s (PL=3), both green.

2. **Two-pass SerializeScriptCode, N=3 and N=4**:

   ```bash
   alive-tv --fail-src-ub --smt-to=120000 --bidirectional ser_c3_x.ll ser_l3_x.ll
   ```

   Result: `ERROR: Timeout`; `1 failed-to-prove transformations` (N=3 after
   3m46s, N=4 after 2m34s).  A one-pass splice plus scalar byte selection
   proved N=3 in 32 s; the final scalar N=6 cell proves in about 61 s.

3. **SAW symbolic recursive Cryptol spec** (prototype): a symbolic
   `findAndDelete` Cryptol spec did not finish within 200 s.  The final SAW
   lane is therefore the documented closed-scenario lane; the symbolic
   equivalence obligation is discharged by Alive2.

4. **Uninitialised temporaries in the first FAD prototype**: Alive2 reported
   `Source function is always UB` (vacuous).  Final sources initialise
   `op`/`nx` and every `Out` byte, and the lane rejects `always UB`/`ERROR`
   lines even if a summary line claims success.

## Caveats and trust notes

- **Bounded source slices.** C legs are line-cited excerpts of pinned Core
  (`interpreter.cpp`, `script.cpp`), not whole `EvalScript`/`VerifyScript`.
  L legs are reviewed transliterations of the cited Lean equations, not
  output of `twin/gen.py`.  Packing, scalar byte selection, the `Out` sink
  and the unrolled step harness are cell code.
- **No crypto/hash claim.** The checksig cells do not call a signature
  checker; signature bytes are uninterpreted serialized-push payload.  The
  serialize cell does not claim anything about the surrounding transaction
  serialization, hash type, or SHA256.
- **fExec abstraction (codesep).** The six-bit mask is an unconstrained
  per-opcode execution trace, which is exactly the predicate the rows name.
  Deriving it from IF/ELSE/ENDIF stack conditions is outside the cell.
- **Serialize malformed tail.** Reachable scriptCode is fully parseable
  (`EvalScript` rejects a malformed push with BAD_OPCODE before CHECKSIG).
  Core's `GetScriptOp` advances past the opcode/length bytes on a truncated
  payload, while Lean's `getOpAt` leaves the index at the failure point; the
  final writer's `it - itBegin` tail is therefore writer-specific on an
  unreachable input.  The cell returns a shared sentinel on a malformed walk
  and claims equivalence only for fully parseable scriptCode.  This is an
  explicit out-of-domain abstention, not a hidden assume and not an SCR-101
  gap.
- **SAW lane scope.** SAW proves closed, oracle-derived scenarios on both
  compiled legs; it is not a second symbolic proof.  Alive2 is the symbolic
  lane.
- **No whole-engine claim.** These cells close the six rows at the declared
  bounded domains and full row-branch coverage.  A whole-engine unbounded
  proof would additionally need the EvalScript loop, stack/altstack, flag and
  op-count state, transaction context, and the ECDSA/hash premises, which are
  outside this task and already covered by the existing trust base/findings.

## Commit

The four cell directories and this report are committed together on
`wave32/17-checksig-096-101`; the branch-head SHA is reported in the task
close-out.  No other files are committed and nothing was pushed.
