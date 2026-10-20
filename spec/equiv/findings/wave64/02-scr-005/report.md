# Wave 64 — `02-scr-005` (exec-verify, SCR-005)

**Row:** SCR-005 — "23-byte HASH160 script: re-eval last scriptSig stack
element as subscript", `interpreter.cpp:VerifyScript:2062-2105@cce32b168`.
**Family:** exec-verify. **Task:** advance the subscript re-evaluation
boundary or file the exact residual.
**Worktree:** `/tmp/opencode/wave64/02-scr-005` (branch
`wave64/02-scr-005`).
**Base:** `5946c024546e39f55775bfd9a077b042e3feeef4`.
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`; contract
`f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
**Tools:** Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang 20.1.2,
plus the local Core build at the pin for a concrete differential.

## Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| SCR-005 | **partial** (bounded leaf) | `exec-verify/C-L-w64-p2sh-subscript-leaf` | For a declared 0..2-byte, one-instruction subscript the `EvalScript(pubKey2)` call is no longer a symbolic premise: the call bytes ARE the last scriptSig stack element, the argument stack is `stackCopy` minus that element, the bounded evaluation computes push/CScriptNum/OP_RETURN/BAD_OPCODE outcomes, and Core's two EVAL_FALSE checks (:2083-2086) are applied to the returned stack, including the empty-stack and negative-zero arms. Alive2 + SAW green; a 561,848-input concrete differential against the real built `EvalScript` has 0 mismatches. | the real `EvalScript` body over general scripts, scripts longer than 2 bytes or with more than one instruction, the 201-op/MAX_SCRIPT_SIZE limits, MINIMALDATA, altstack/condition stack, and the P2SH-wrapped witness tail | E5 residual B1-B7 (`findings/e5/E5-RESIDUAL.md`): `GetScriptOp` over arbitrary buffers, heap/allocator, the symbolic dispatch loop, exception edges, `__cxa_guard` statics, `ptrtoint`/STL, crypto/assert externals. Both cell legs are bounded handwritten transcriptions, not a refinement of the pinned IR. |

SCR-005 stays **partial**: the shape predicate and the handoff were already
proved (`C-L-w32-p2sh-23byte`, `C-L-p2sh-handoff`); this cell replaces the
symbolic redeem outcome for an explicit leaf, which is a real advance on the
call/EVAL_FALSE boundary but not a whole-`EvalScript` result. The row is not
promoted.

## Cell

`spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/`

| component | result | certificate |
|---|---|---|
| Alive2 (`--always-verify`, 1 transformation) | `Transformation seems to be correct!`, `STATUS=alive2-green` | `alive2/certificate.sha256` |
| SAW (`abc`, 2 proofs: C and L vs one Cryptol spec) | 2x `Proof succeeded!`, `STATUS=saw-green` | `saw/certificate.sha256` |
| concrete differential vs real Core `EvalScript` | `checked=561848 skipped_out_of_model=1280356 mismatches=0`, `STATUS=core-differential-green` | `concrete/certificate.sha256` |
| mutants (negative controls) | M1 drop `popstack`, M2 read the wrong EVAL_FALSE element: both `MUTANT_CAUGHT`, `STATUS=mutants-caught` | `mutant/result.txt` |

C leg = line-cited Core slice (`GetScriptOp` + one `EvalScript` instruction +
the :2083-2086 checks). L leg = reviewed transliteration of Lean
`parseWire`/`stepBody`/`evalFrom`/`p2shInner` with the Lean `castToBool` form
and the combined `stack = [] ∨ !castToBool` predicate. The legs are
deliberately different programs (switch/phi vs parse record + one-step
evaluator, Core vs Lean CastToBool), so Alive2 is a semantic comparison.

## Exact commands and results

From the repository root of the worktree:

```sh
C=spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf
bash $C/alive2/run.sh      # STATUS=alive2-green
bash $C/saw/run.sh         # STATUS=saw-green, CELL_W64_P2SH_SUBSCRIPT_LEAF_SAW_GREEN
bash $C/concrete/run.sh    # STATUS=core-differential-green
bash $C/mutant/run.sh      # STATUS=mutants-caught
sha256sum -c $C/alive2/certificate.sha256
sha256sum -c $C/saw/certificate.sha256
sha256sum -c $C/concrete/certificate.sha256
```

Raw outcomes:

```
alive2/result.txt:
  Transformation seems to be correct!
  1 correct transformations / 0 incorrect / 0 failed-to-prove / 0 Alive2 errors
  STATUS=alive2-green

saw/result.txt:
  Proof succeeded! cell_p2sh_subscript_leaf
  Proof succeeded! cell_p2sh_subscript_leaf
  CELL_W64_P2SH_SUBSCRIPT_LEAF_SAW_GREEN
  STATUS=saw-green

concrete/result.txt:
  interpreter.cpp sha256 57a6f328c7e6202f499e48366a86eb26e09c8ebb78e92eef7e839207230be333
  script.cpp sha256      210b1720acce295de54c6a08c76b97fa4cfe835f64e0ff7e0730c57ebebb8c55
  checked=561848 skipped_out_of_model=1280356 mismatches=0
  STATUS=core-differential-green

mutant/result.txt:
  MUTANT_CAUGHT=m1_no_popstack
  MUTANT_CAUGHT=m2_wrong_top
  STATUS=mutants-caught
```

The concrete harness calls the real
`EvalScript(stack, CScript(pubKey2), SCRIPT_VERIFY_P2SH, checker,
SigVersion::BASE, execdata, &serror)` from
`/tmp/opencode/core-build/build/lib/libbitcoin_consensus.a` (source hashes
above match the pinned `core-pin` tree), then applies :2083-2086 to the
returned stack. It is a finite differential, not a refinement proof, and the
raw log records the library hashes and the input space.

## Honest scope

- Not proved: the real `EvalScript` body, any script > 2 bytes or with > 1
  instruction, the 201-op count, MAX_SCRIPT_SIZE, MINIMALDATA, altstack /
  condition stack, CLEANSTACK, witness tails.
- E5 residual is unchanged and is the reason the row stays partial. The cell
  contributes a bounded, discriminating, real-Core-anchored statement about
  the call and the EVAL_FALSE checks, nothing wider.
- The HASH160 gate (crypto seam) and the `scriptSig == push(redeemScript)`
  malleability comparison (SCR-012) are not touched.

## Files added

```
spec/equiv/cells/exec-verify/C-L-w64-p2sh-subscript-leaf/
  spec.md, notes.md
  src/{c_cell.cpp,l_cell.cpp,cell.cry,cell.saw}
  alive2/{run.sh,result.txt,certificate.sha256}
  saw/{run.sh,result.txt,certificate.sha256}
  concrete/{diff_core.cpp,run.sh,result.txt,certificate.sha256}
  mutant/{run.sh,result.txt}
spec/equiv/findings/wave64/02-scr-005/report.md
```

No shared file was edited (no `spec/db/equiv-cells.yaml`, rules, ledger,
matrix, `cells/INDEX.md` or `_tools` change). Ledger/matrix registration for
the new cell is left to the integration step.
