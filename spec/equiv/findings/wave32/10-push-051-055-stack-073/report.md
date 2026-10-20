# Wave 32 — task 10, push SCR-051..055 and stack SCR-073

**Worktree:** `/tmp/opencode/wave32/10-push-051-055-stack-073`
**Branch:** `wave32/10-push-051-055-stack-073` (base `805c804`)
**Family:** push-encoding + stack-ops
**Assigned rows:** SCR-051, SCR-052, SCR-053, SCR-054, SCR-055, SCR-073
**Pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`

## Result

Six new cells, all **Alive2-green and SAW-green**, each with raw results and
a `sha256sum -c`-verifiable certificate per leg:

| Cell | Row(s) | `alive2/result.txt` | `saw/result.txt` |
|---|---|---|---|
| `spec/equiv/cells/push-encoding/C-L-w32-witness-program` | SCR-053 | `STATUS=alive2-green` (1 correct, 0 failed, 0 errors) | `STATUS=saw-green` (2 proofs) |
| `spec/equiv/cells/push-encoding/C-L-w32-p2sh-pattern` | SCR-054 | `STATUS=alive2-green` (1 correct, 0 failed, 0 errors) | `STATUS=saw-green` (2 proofs) |
| `spec/equiv/cells/push-encoding/C-L-w32-p2a-anchor` | SCR-055 | `STATUS=alive2-green` (1 correct, 0 failed, 0 errors) | `STATUS=saw-green` (2 proofs) |
| `spec/equiv/cells/push-encoding/C-L-w32-pushonly-opcode` | SCR-052 | `STATUS=alive2-green` (1 correct, 0 failed, 0 errors) | `STATUS=saw-green` (4 proofs) |
| `spec/equiv/cells/push-encoding/C-L-w32-num-decode-minimal` | SCR-051 | `STATUS=alive2-green` (1 correct, 0 failed, 0 errors) | `STATUS=saw-green` (2 proofs) |
| `spec/equiv/cells/stack-ops/C-L-w32-altstack-step` | SCR-073 | `STATUS=alive2-green` (1 correct, 0 failed, 0 errors) | `STATUS=saw-green` (2 proofs) |

All Alive2 runs use `--bidirectional`, so the C and L legs are mutually
refining (`L ⊑ C` and `C ⊑ L`). Each SAW script verifies both legs against
the same independent Cryptol predicate (`Proof succeeded!` twice per leg —
four times for the two pushonly entry points).

**Rows closed at the declared cell scope: SCR-053, SCR-054, SCR-055,
SCR-073.** SCR-051 and SCR-052 are partial; the exact remaining work is
below. No row was relabelled green to hide a gap.

## Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| SCR-051 | **partial** | `push-encoding/C-L-w32-num-decode-minimal` | For every five-byte operand, every length `0..7`, both `fRequireMinimal` values and both `nMaxNumSize` values (4 and 5), the C `CScriptNum` constructor and the twin `decode_num` agree with the independent Cryptol model: over-width and non-minimal (under the flag) return `SCRIPTNUM` (4); otherwise OK with the little-endian sign-magnitude value, including negative zero. | The four handler call sites and their surrounding checks: CLTV/CSV decode ordering versus `NEGATIVE_LOCKTIME` and the locktime/sequence comparison, CHECKMULTISIG key/sig count bounds, and the CHECKSIGADD tapscript number path. | With the activation flag on, the generated twin has no decode handler: `twin/ops_ir.py:49-50` (`OP_CLTV`) and `:59-60` (`OP_CSV`) return `TWIN_INVALID_UNSUPPORTED` (result 3). `CHECKMULTISIG`/`CHECKMULTISIGVERIFY` are listed under `unsupported` in `twin/gen.py:224` (not generated). `OP_CHECKSIGADD_BASE` returns `TWIN_BAD_OPCODE` (`ops_ir.py:67-69`); the tapscript arm is the E4 seam (`twin/gen.py:229`). No L handler exists to compare at handler level. |
| SCR-052 | **partial** | `push-encoding/C-L-w32-pushonly-opcode` | For every wire byte `0x00..0xff` in a script of length 0 or 1, both legs return the same Boolean: empty is push-only; a one-byte script is push-only iff it is `0x00` or in `0x4f..0x60`. This exercises the named boundary exactly, including `OP_RESERVED 0x50` (a push) and `OP_17 0x61` (not a push), plus all one-byte truncated push forms. | A successful multi-op script, a successful `PUSHDATA1/2/4` push whose data is present, and the script-level `all` fold over an arbitrary-length script. | Scope, not a tool rejection: the cell fixes the script to 0/1 bytes. A loop probe (`alive-tv --smt-to=10000` on the scalar symbolic-trip-count loop in `notes.md`) returns `1 correct transformations`, and a mutated twin returns `1 incorrect transformations`, so Alive2 is not the blocker. A full cell still needs the complete `GetOp`/`decode_op` surface over a bounded script buffer plus loop invariant/unroll strategy; that was not attempted here. |
| SCR-053 | **full** | `push-encoding/C-L-w32-witness-program` | For all script sizes `n` (32-bit), all version bytes and all length bytes: `IsWitnessProgram` accepts exactly `n ∈ [4,42] ∧ (v = 0x00 ∨ v ∈ [0x51,0x60]) ∧ plen + 2 = n`. Every edge (size 3/4/42/43, `OP_0`/`OP_1`/`OP_16`/`OP_17`, exact/inexact push length) is symbolic. C is a line-cited excerpt of `script.cpp:250-264`; L calls the generated twin `is_witness_program` verbatim. Both directions via Alive2; both legs match the Cryptol predicate via SAW. | Whole-`VerifyWitnessProgram` integration, version decoding (`SWT-002`), and program-byte extraction are outside this predicate cell. | None at the row's predicate scope. |
| SCR-054 | **full** | `push-encoding/C-L-w32-p2sh-pattern` | For all script lengths `n` and the three bytes read by the rule: `IsPayToScriptHash` accepts exactly `n = 23 ∧ b0 = 0xa9 ∧ b1 = 0x14 ∧ b22 = 0x87`. Sizes 22/23/24 and each byte's equal/different edges are symbolic. C is a line-cited excerpt of `script.cpp:224-231`; L calls the generated twin `is_p2sh` verbatim. Both directions via Alive2; both legs match Cryptol via SAW. | Whole-verify binding and the HASH160 operation itself (the rule is the pattern, not the hash). | None at the row's predicate scope. |
| SCR-055 | **full (predicate level)** | `push-encoding/C-L-w32-p2a-anchor` | For all versions and every `(plen, p0, p1)`: `IsPayToAnchor` accepts exactly `version = 1 ∧ plen = 2 ∧ p0 = 0x4e ∧ p1 = 0x73`, i.e. the serialized `51 02 4e 73` / v1 program `4e73`. Both directions via Alive2; both legs match Cryptol via SAW. | The C-L binding of this predicate into the P2A branch of `VerifyWitnessProgram`, and a generator-produced L leg. The decoding of `51 02 4e 73` into `(v1, 4e73)` is covered by the SCR-053 cell, not re-proved here. | The imperative twin has no anchor helper: `twin/runtime.inc` returns `TWIN_INVALID_UNSUPPORTED` for every witness program, so the L leg is a **reviewed transcription** of `Defs.lean:523-526`, not generated code. This is a trust caveat on the L link, not a gap in the four-conjunct row predicate. |
| SCR-073 | **full (single-step projection)** | `stack-ops/C-L-w32-altstack-step` | For symbolic `nOpCount` (32-bit), `fExec`, wire (`0x6b`/`0x6c`), main/alt depths `0..4` and symbolic top bytes: `++nOpCount > 201` yields `OP_COUNT` (7) before the handler/fExec gate; `nOpCount = 200` still executes; executed `TOALTSTACK` moves the main top (empty ⇒ `INVALID_STACK_OPERATION` 18); executed `FROMALTSTACK` moves the alt top (empty ⇒ `INVALID_ALTSTACK_OPERATION` 19); an unexecuted, budget-surviving step is a no-op. Both directions via Alive2; both legs match the independent Cryptol step model via SAW. | The `EvalScript` loop's decode/index bookkeeping, and the combined `stack.size() + altstack.size() > 1000` guard (unreachable with depths ≤ 4). | None at the row's step scope; this is a single-step projection, stated explicitly in `spec.md`. |

Summary: **4 full, 2 partial, 0 blocked at cell level.** The only
generator/trust caveat on a "full" row is SCR-055's reviewed-transcription L
leg; SCR-051's L decode is also a transcription because the twin's
`mk_leaf.py` bounded copy only reaches two bytes.

## Exact commands and raw outcomes

Run from the repository root
(`/tmp/opencode/wave32/10-push-051-055-stack-073`):

```sh
spec/equiv/cells/push-encoding/C-L-w32-witness-program/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-witness-program/saw/run.sh
spec/equiv/cells/push-encoding/C-L-w32-p2sh-pattern/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-p2sh-pattern/saw/run.sh
spec/equiv/cells/push-encoding/C-L-w32-p2a-anchor/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-p2a-anchor/saw/run.sh
spec/equiv/cells/push-encoding/C-L-w32-pushonly-opcode/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-pushonly-opcode/saw/run.sh
spec/equiv/cells/push-encoding/C-L-w32-num-decode-minimal/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-num-decode-minimal/saw/run.sh
spec/equiv/cells/stack-ops/C-L-w32-altstack-step/alive2/run.sh
spec/equiv/cells/stack-ops/C-L-w32-altstack-step/saw/run.sh
```

Each `alive2/run.sh` rebuilds both legs with the shared
`_tools/w32/build.sh`:

```sh
/usr/bin/clang++-20 -std=c++17 -O2 -fno-strict-aliasing -fno-jump-tables \
  -mllvm -inline-threshold=3000 -I _tools/w32 -I build -I contract \
  -S -emit-llvm -fno-discard-value-names src/c_leaf.cpp -o build/c_leaf.ll
# same for l_leaf.cpp, then for each function in src/fns.txt:
/usr/lib/llvm-20/bin/llvm-extract --func=<fn> --recursive build/<leg>_leaf.ll -o build/<leg>_<fn>.bc
/usr/lib/llvm-20/bin/llvm-dis build/<leg>_<fn>.bc -o build/<leg>_<fn>.ll
```

and then compares each entry point:

```sh
/usr/local/bin/alive-tv --bidirectional --smt-to=60000 \
  build/c_<fn>.ll build/l_<fn>.ll
```

Representative tail (shape identical for all six cells; `cell_wp` shown):

```text
Transformation seems to be correct!

These functions seem to be equivalent!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

Each `saw/run.sh` runs SAW 1.6 (`68eed5f release-1.6`) from `build/` with
`z3`, loading both bitcode legs and verifying each against `cell.cry`:

```text
Verifying cell_wp...
Simulating cell_wp...
Checking proof obligations cell_wp...
Proof succeeded! cell_wp
Verifying cell_wp...
Simulating cell_wp...
Checking proof obligations cell_wp...
Proof succeeded! cell_wp
CELL_W32_WP_SAW_GREEN
STATUS=saw-green
```

`pushonly` proves `cell_po0` and `cell_po1` on both legs (4
`Proof succeeded!` lines); the other cells prove one entry point on both
legs (2 lines). No `^Proof failed` line appears in any result.

Observed wall-clock on the final rerun: 0.7–14 s for the five predicate /
decode Alive2 runs, 92 s for `altstack-step`; SAW 1.6–12 s per cell.

## Certificate verification

From the repository root, after the final rerun of every cell:

```sh
for f in spec/equiv/cells/push-encoding/C-L-w32-*/{alive2,saw}/certificate.sha256 \
         spec/equiv/cells/stack-ops/C-L-w32-altstack-step/{alive2,saw}/certificate.sha256; do
  sha256sum -c "$f"
done
```

```text
push-encoding/C-L-w32-{witness-program,p2sh-pattern,p2a-anchor,num-decode-minimal}/alive2   ok=22 failed=0
push-encoding/C-L-w32-{witness-program,p2sh-pattern,p2a-anchor,num-decode-minimal}/saw     ok=24 failed=0
push-encoding/C-L-w32-pushonly-opcode/alive2                                               ok=22 failed=0
push-encoding/C-L-w32-pushonly-opcode/saw                                                  ok=24 failed=0
stack-ops/C-L-w32-altstack-step/alive2                                                     ok=27 failed=0
stack-ops/C-L-w32-altstack-step/saw                                                        ok=29 failed=0
```

All twelve invocations exit 0 with zero `FAILED` lines. The certificates
hash the shared tool scripts, `mk_leaf.py`, the twin generator/runtime,
`contract/error_kind.h`, the generated `build/twin.cpp`/`build.txt`, the
cell `spec.md`/`notes.md`/`src/*`, and the leg's `result.txt` (SAW also
hashes `build/cell.cry` and `build/cell.saw`). They therefore bind the
result to the exact source and tool inputs.

`build/` is gitignored, as in the existing cells, so a fresh checkout must
run each cell's `alive2/run.sh` once before checking the build-artifact
lines; that script rebuilds and rewrites `result.txt`. The run and
certificate steps above were performed in that order on the final tree.

## What is actually claimed

- **C vs L:** mutual refinement for the full symbolic input space of each
  cell entry point, via `alive-tv --bidirectional`.
- **Both legs vs an independent model:** SAW verifies the C and L bitcode
  separately against the same Cryptol predicate in `src/cell.cry`, which is
  a transcription of the cited Core lines / Lean equations.
- **Not claimed:** whole-`EvalScript`/`VerifyScript` equivalence; the
  `EvalScript` loop or opcode decode outside the single step; script-length
  beyond 1 for SCR-052; the four SCR-051 handler call sites; the P2A
  branch binding in `VerifyWitnessProgram`; the R leg; witness/taproot
  execution beyond the named predicates; or any crypto/hash internals. No
  `llvm_unsafe_assume_spec` or hand-written success marker is used.

## Blockers and smallest next experiments

1. **SCR-051 CLTV/CSV (activation on).** `twin/ops_ir.py:49-50` and
   `:59-60`:
   ```c
   if (!ctx.flags.cltv) return TWIN_OK;
   return TWIN_INVALID_UNSUPPORTED;
   ```
   and the same for `csv`. There is no L body for the decode step, so a
   handler-level cell would be C-only. Smallest next experiment: add a
   bounded twin handler for the CLTV/CSV **decode step only** (no
   transaction comparison), run `python3 twin/gen.py --check` plus the twin
   smoke test, then build the minimality-branch cell. That edits shared twin
   files and belongs to the twin/wave-16B track.

2. **SCR-051 CHECKMULTISIG counts.** `twin/gen.py:224` lists
   `CHECKMULTISIG` and `CHECKMULTISIGVERIFY` as unsupported (result 3); no
   handler is generated. Smallest next experiment: a count-only CMS handler
   whose key/sig-count decode precedes signature checks, then a cell over
   both counts.

3. **SCR-051 CHECKSIGADD number.** `ops_ir.py:67-69` returns
   `TWIN_BAD_OPCODE` under base/witnessV0; `twin/gen.py:229` records the
   tapscript path as the E4 seam. The number decode itself is proved by the
   current cell (cap 4); the tapscript handler is the blocker.

4. **SCR-052 full script loop.** Not a tool limitation: the loop probe in
   `push-encoding/C-L-w32-pushonly-opcode/notes.md` shows Alive2 proving a
   symbolic-trip-count loop and detecting a mutated twin. The missing piece
   is a bounded (e.g. 520-byte) script buffer with symbolic length and the
   full `GetOp`/`decode_op` surface, plus a loop-unroll or invariant
   strategy for tractability. A SAW/Cryptol fold invariant is the
   alternative. This is the smallest next experiment for the row.

5. **SCR-055 L binding.** The L leg is a reviewed transcription
   (`Defs.lean:523-526`), because `twin/runtime.inc` has no anchor helper
   and returns `TWIN_INVALID_UNSUPPORTED` for all witness programs. The
   predicate row is full, but a generator-produced L link and the
   `VerifyWitnessProgram` P2A branch remain. Smallest next experiment: add
   `is_pay_to_anchor` to the twin and generate the L leg, then a branch-level
   cell.

6. **SCR-073 loop/guard residual.** The row's step is fully covered; the
   combined stack-size guard is unreachable at the bounded depths and the
   `EvalScript` loop is out of scope. Smallest next experiment: a
   tape-level multi-step cell once the loop harness exists; not needed for
   the row as written.

## Files added

```text
spec/equiv/cells/_tools/w32/{build.sh,run_alive2.sh,run_saw.sh,certify.sh,w32_common.h}
spec/equiv/cells/push-encoding/C-L-w32-witness-program/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/push-encoding/C-L-w32-p2sh-pattern/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/push-encoding/C-L-w32-p2a-anchor/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/push-encoding/C-L-w32-pushonly-opcode/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/push-encoding/C-L-w32-num-decode-minimal/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/cells/stack-ops/C-L-w32-altstack-step/{spec.md,notes.md,src/...,alive2/...,saw/...}
spec/equiv/findings/wave32/10-push-051-055-stack-073/report.md
```

No shared ledger, results, contract, pin, census, Lean proof, or existing
cell was edited. `make equiv` and the shared ledger updater were not run.
