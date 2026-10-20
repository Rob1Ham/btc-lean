# Wave 32 — task 04-exec-014-017 (exec-verify SCR-014..017)

**Worktree:** `/tmp/opencode/wave32/04-exec-014-017`
**Branch:** `wave32/04-exec-014-017`, cut from PR head `805c804`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (v32.99)
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Tools:** Alive2 v20.0 (`c0f5434`, LLVM 20.1.2); SAW 1.6 (`68eed5f`); clang/LLVM 20.1.2

## Result

| SCR | status | cell | proved | remains | blocker |
|---|---|---|---|---|---|
| SCR-014 | **full** | `cells/exec-verify/C-L-w32-flags-combo` | `flagsComboOk` for every 64-bit flag word and both CLEANSTACK values: `(!cleanstack \|\| (P2SH && WITNESS)) && (!WITNESS \|\| P2SH)`; C slice ≡ Lean transliteration, both tools symbolic | Core's `assert` firing / NDEBUG behaviour is not modeled (no defined observable); the row's predicate face is fully proved | none for the predicate face |
| SCR-015 | **full** | `cells/exec-verify/C-L-w32-block-flags` | `GetBlockScriptFlags` (validation.cpp:2249-2288) for every 256-bit block hash and every height: normal base P2SH\|WITNESS\|TAPROOT, both exception replacements, fail-closed lookup, and both sides of all four buried heights (363725/388381/419328/481824), mainnet params | the row's trailing "scripts and costs use actual candidate flags" is caller wiring (ConnectBlock/TXV-055), outside core_ref; not claimed | none for the selector; caller wiring is a different row |
| SCR-016 | **full** | `cells/exec-verify/C-L-w32-flag-exceptions` | exact two-entry mainnet exception map over all 256-bit hashes (fail-closed), full height schedules for both exception hashes, and the named blocks' exact words: BIP16 @170060 = `0x0`; taproot @692261 = `0xe15` | nothing for the two named blocks; hash↔height pairs are taken from the Lean module (verified there), not re-derived from headers | none |
| SCR-017 | **partial** | `cells/exec-verify/C-L-w32-fail-propagation` | the VerifyScript failure-propagation combinator for all symbolic engine outcomes, in Core's order: any reached EvalScript/VerifyWitnessProgram failure ⇒ result 0 with that call's error, no success swallow; law face proved to return 1 for every input (both tools) | Core's `EvalScript`/`VerifyWitnessProgram` are abstracted to `(ok\|fail, error)`; path predicates and stack are inputs; `.unjudged` not modeled | E5 residual: undefined `GetScriptOp`, heap allocator, unbounded dispatch loop, exception edges (`findings/e5/E5-RESIDUAL.md`); need an `EvalScript` loop invariant + `GetScriptOp` override (SAW/LLVM 20) or P-CORE-04 `EvalStep` + bounded unrolling |

Totals: 3 full, 1 partial, 0 blocked.

Nothing is claimed about libsecp256k1/SHA/RIPEMD, block headers, block
connection, or whole-node validation. No `llvm_unsafe_assume_spec`, no
hand-written success marker, no Core patch.

## New cells

```
spec/equiv/cells/exec-verify/C-L-w32-flags-combo/
spec/equiv/cells/exec-verify/C-L-w32-block-flags/
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/
spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/
spec/equiv/cells/_tools/w32/            # shared harness (README.md, sources, runners)
```

Each cell has `spec.md`, `notes.md`, `manifest.txt`, `alive2/{run.sh,result.txt,
certificate.sha256}` and `saw/{run.sh,spec.cry,spec.saw,result.txt,certificate.sha256}`.
No existing cell, finding, ledger, contract, pin or result file was edited.

## Tool outcomes (raw, from the committed `result.txt` files)

| Cell | Alive2 | SAW |
|---|---|---|
| `C-L-w32-flags-combo` | 1 symbolic compare, `1 correct transformations`, `0 failed-to-prove`, `0 Alive2 errors` | 2/2 `Proof succeeded!` (C and L) |
| `C-L-w32-block-flags` | 1 symbolic compare, all counters green | 2/2 `Proof succeeded!` |
| `C-L-w32-flag-exceptions` | 5 compares (1 symbolic lookup, 2 symbolic height schedules, 2 closed named blocks), all green | 10/10 `Proof succeeded!` |
| `C-L-w32-fail-propagation` | 2 compares (propagation + law), both symbolic, green | 4/4 `Proof succeeded!` |

All Alive2 runs are symbolic C-vs-L compares of the extracted `-O1` modules
(`build/c_<fn>.ll` vs `build/l_<fn>.ll`); the SAW specs are symbolic over
every argument (`llvm_fresh_var`), not closed witnesses, except the two named
exception blocks in `C-L-w32-flag-exceptions`, which are correctly closed
inputs.

## Exact commands

From the worktree root:

```sh
# reproduce a cell (builds both legs, runs the tool, writes result + certificate)
spec/equiv/cells/exec-verify/C-L-w32-flags-combo/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flags-combo/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-block-flags/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-block-flags/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/saw/run.sh

# verify certificates (repository root, as required)
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flags-combo/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flags-combo/saw/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-block-flags/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-block-flags/saw/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/saw/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/saw/certificate.sha256
```

All eight certificate files verify (every line `OK`). The `build/`
directories are regenerated deterministically by the runners and are
gitignored, as in the existing E1 cells.

## Method notes / honest limits

- **C legs are line-cited slices**, not compiled Core translation units.
  Core headers are not included; flag bits, heights, exception hashes and
  error ordinals are transcribed in `cells/_tools/w32/w32_common.h` with the
  exact pinned source lines. This is the same source-excerpt pattern as
  `cells/control-flow/C-L-nop-return`.
- **L legs are reviewed hand transliterations** of the Lean definitions
  (`Rules.lean:48-50`; `Activation/Flags.lean:69-76,127-128,145-157`;
  `Interpreter/Defs.lean:1363-1420`). `Bitcoin.Activation` has no
  `twin/gen.py` output, so `spec/equiv/README.md` §3's "reviewed
  transliteration" fallback applies and is labelled in every trust note. For
  SCR-015/016 the L representation is deliberately different from C (Bool
  record + Option vs 64-bit bitmask + equality lookup); the Alive2 compare is
  therefore not a compare of identical expressions.
- **SCR-014's assert caveat.** Core encodes the constraint as `assert()`s on
  the VerifyScript success path. The cell proves the predicate they encode
  (the same `flagsComboOk` face the Lean row tags); it makes no claim about
  the assert's UB or NDEBUG behaviour. If a reviewer requires the assert
  statement itself, this row should be demoted to partial — the predicate
  content would not change.
- **SCR-015's application clause.** "Scripts and costs use actual candidate
  flags" names a caller (ConnectBlock, TXV-055), not a branch of
  `GetBlockScriptFlags`. The cell covers the whole `core_ref` function; the
  caller wiring is explicitly not claimed.
- **SCR-017 is partial by construction.** The five engine calls are stubbed
  to their outcomes. This proves the wrapper never swallows a failure and
  preserves Core's error precedence for all outcomes, which is the row's
  propagation claim, but it does not prove that real scripts produce those
  outcomes. Smallest next experiment: SAW `llvm_verify` of `EvalScript` with
  a `GetScriptOp` override and a loop invariant, or P-CORE-04 `EvalStep` plus
  bounded unrolling; the E5 residual documents why the current IR stops
  (`invoke`, `_Znwm`, `GetScriptOp`, unbounded loop).
- **Shared ledger / results untouched**, per the brief; the orchestrator
  integrates and regenerates `equiv-cells.yaml`, `results/` and the census.
