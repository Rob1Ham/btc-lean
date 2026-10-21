# P-CORE-04 / P-CORE-05 — `EvalStep` slicing and span leaves (survey + prototype)

**Task:** wave16B `11-patch-evalstep`
**Base:** PR #29 head `805c804`; Core pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (v32.99)
**Tools actually run:** clang/LLVM **20.1.2**, SAW **1.6** (`68eed5f`), Alive2 **v20.0** (`c0f5434`)
**Status of the prototypes:** **PROPOSED / lane-only.** No cell uses them. No row is claimed green. Nothing is pushed; this is a proposal for the orchestrator.

---

## 1. Verdict

1. **P-CORE-04 is implementable as a mechanical, behavior-preserving source
   refactor and I built it.** On the pinned `src/script/interpreter.cpp` it is
   one hunk, `+816/−738`, that moves the 784-line loop body verbatim into
   `static bool EvalStep(ScriptEvalState&)` and turns `EvalScript`'s dispatch
   loop into a three-line call site. The moved body is **byte-identical after
   de-indentation** (`verify_move.py`, both the pin and the P-CORE-01 lane).
2. **It is differential-equivalent on a focused 12,523-row corpus: zero
   divergences**, with two live negative controls (3 and 169 diverging rows).
   This is *not* the corpus/fuzz evidence the patch policy requires; see §5.
3. **It does not make E5 tractable by itself, and I recommend against shipping
   it as a Core patch in this PR.** The dispatch loop is still symbolic-trip
   (`pc < pend`), and SAW 1.6 only discharged a *constant*-trip loop in a probe;
   a symbolic-trip loop produced no verdict. The step function also still
   contains the three multisig inner loops. A step split without a bound or an
   invariant does not give a whole-function proof.
4. **P-CORE-05 as specified is measured ineffective and should be dropped.**
   The two `ptrtoint`s in `CastToBool` at `-O1` come from
   `std::vector::size()` at the vector boundary, not from the leaf body. The
   span-leaf patch leaves `CastToBool` at 2 `ptrtoint` (`-O1`) and changes the
   module count 559 → **567** (worse), while at `-O0` it changes nothing
   (104 → 104; `CastToBool` was already 0).

The useful artefacts from this task are therefore: (a) a precise, measured
no-go for both designs as E5 unblockers, (b) a behaviour-preserving prototype
and a reusable differential harness, and (c) a concrete proof-side alternative
(LLVM `CodeExtractor` region extraction on the erased lane) as the next
experiment.

---

## 2. What was built

| Artefact | Path |
|---|---|
| P-CORE-04 prototype patch (Core `src/script/interpreter.cpp`, 1 hunk) | `../../patches/proposals/wave16b/11-patch-evalstep/P-CORE-04-evalstep-proposal.patch` |
| P-CORE-05 survey patch (3 files) | `../../patches/proposals/wave16b/11-patch-evalstep/P-CORE-05-span-leaves-proposal.patch` |
| Mechanical generator of the P-CORE-04 TU (tracked transform) | `../../patches/proposals/wave16b/11-patch-evalstep/harness/mk_evalstep.py` |
| Body-move verifier | `.../harness/verify_move.py` |
| Differential driver (Core `EvalScript`, stubbed crypto/checker) | `.../harness/driver.cpp` |
| Deterministic corpus generator (12,523 rows) | `.../harness/gen_corpus.py` |
| End-to-end reproduction | `.../harness/build.sh` |
| IR metrics | `.../harness/ir_metrics.py` |
| Logs and hashes | `logs/`, `SHA256SUMS` |

The P-CORE-04 patch applies cleanly to the pin on its own
(`git apply --check`, verified). It is independent of P-CORE-01/02/03: it does
not use their macros, and the transform also applies to the
P-CORE-01/02/03 patched tree and compiles with all three lane macros
(composed lane, §3.1/§3.3).

## 3. Measured results

### 3.1 IR shape (pin lane, `-O0`, textual LLVM IR)

| Variant | module defines | module invokes | EvalScript instr / blocks / invokes / landingpads | EvalStep instr / blocks / invokes / landingpads |
|---|---:|---:|---|---|
| pin | 1026 | 686 | 3138 / 749 / 336 / 32 | — |
| pin + P-CORE-04 | 1027 | **445** | **357 / 63 / 20 / 8** | **2714 / 448 / 73 / 24** |
| pin + 01/02/03 | 1016 | 683 | (report: 4570 body lines) | — |
| pin + 01/02/03/04 | 1017 | **430** | **224 / 33 / 11 / 1** | **2765 / 472 / 73 / 24** |

`ptrtoint` is unchanged (104 module-wide) in every variant, and both engine
functions contain 0 `ptrtoint`.

The 336 → 20 invoke drop is expected and is the main structural win: LLVM emits
`invoke` only for calls inside a `try` region in the *same* function. The
original body was inside `EvalScript`'s `try`, so every call was an `invoke`;
in the extraction the only `try` is in `EvalScript`, the step call itself is the
`invoke`, and calls inside `EvalStep` are plain calls (except the 73 that need
local cleanups). Exception behaviour is preserved by the caller's invoke/landing
pad; this is covered by the differential's `SCRIPT_ERR_SCRIPTNUM` rows (132
rows) and by the refinement clause O3 in `DESIGN.md`.

### 3.2 Differential (refactor equivalence)

* 12,523 rows; corpus `sha256 79ddae83a856b3370d75c040da35229f443483d84505f86c676eb991e52d7ae1`
* `out-ref.txt` and `out-new.txt` are byte-identical
  (`sha256 ae2b5a6104e1ada74f397e5dd5f63ccfad43e353f28ac415c5289b83a4e10409`).
* Coverage of the result space: 1,825 rows `ok=1`; error codes hit include
  `SCRIPTNUM` (132), `BAD_OPCODE` (1000), `INVALID_STACK_OPERATION` (6709),
  `UNBALANCED_CONDITIONAL` (1196), `MINIMALDATA` (122), `DISABLED_OPCODE`
  (108), `OP_COUNT` (46), `STACK_SIZE` (2), `SIG_DER` (43), `SIG_NULLFAIL`
  (31), `TAPSCRIPT_CHECKMULTISIG` (62), `TAPSCRIPT_EMPTY_PUBKEY` (12),
  `OP_CODESEPARATOR` (5), `MINIMALIF`/`TAPSCRIPT_MINIMALIF` (8/20), plus the
  real 1-of-1 and 1-of-2 multisig rows and the in-loop limit cases
  (MAX_SCRIPT_SIZE 10,000/10,001; MAX_SCRIPT_ELEMENT_SIZE 520/521;
  MAX_STACK_SIZE 1000/1001; MAX_OPS_PER_SCRIPT 201/202) and all 256 single
  opcode bytes under BASE/WITNESS_V0/TAPSCRIPT.
* Negative controls: changing one in-loop error code diverges on **3** rows;
  moving `++opcode_pos` before the step diverges on **169** rows (the
  `CODESEPARATOR`-position lane). The harness is sensitive to loop-carried
  state ordering, not only to opcode semantics.

Evidence: `logs/differential-SUMMARY.txt`, `logs/differential-controls.txt`,
`logs/compile.txt`, `logs/verify-move.txt`.

### 3.3 Tool probes

* Alive2 on the composed lane (`01/02/03/04` + the CORE-IR exception-erasure
  transform + `simplifycfg`): both `EvalScript` and `EvalStep` translate
  (`1 correct, 0 errors`, `--skip-smt`). **Translation only, not a proof.**
  (`logs/alive2-translate-p4-123.txt`)
* Alive2 on the pin+P-CORE-04 lane: `EvalStep` translates; `EvalScript` still
  fails on `load atomic i8, ptr @_ZGVZ...` (`__cxa_guard`), i.e. P-CORE-03 is
  still required. (`logs/alive2-translate-evalstep-pin04.txt`)
* Alive2 `--always-verify --smt-to=60000` on the whole `EvalStep`: **no
  verdict**, killed after 900 s; 282 KB of Alive IR dump, no `Summary` block.
  The whole step (2,714 instructions / 73 invokes before erasure) is too large
  for a single SMT query. (`logs/alive2-always-verify-timeout.txt`)
* SAW 1.6 loop probes: a constant-trip (4) loop **verified**; a symbolic-trip
  loop produced **no verdict** in 90 s. There is no loop-invariant input in this
  SAW/LLVM path. (`logs/saw-loop-constant.txt`, `logs/saw-loop-symbolic.txt`)
* Loop structure (`opt -passes=print<loops>`): `EvalScript` has exactly one
  depth-1 dispatch loop; **`EvalStep` still has three depth-1 loops**, all in
  the `OP_CHECKMULTISIG` family. (`logs/ir-loops-pin04.txt`)

## 4. Refinement obligation (summary; full statement in `DESIGN.md`)

Let a step state be

```
sigma = (pc, pend, pbegincodehash, opcode, vchPushValue, stack, altstack,
         vfExec, nOpCount, opcode_pos, execdata, flags, sigversion, serror,
         script, checker)
```

and `R_pin(sigma)` / `R_step(sigma)` the result of one pinned loop-body
execution / one `EvalStep` call.

* **O1 (per-step equivalence).** `forall sigma. R_step(sigma) = R_pin(sigma)`,
  where equality covers the returned bool, the written `*serror`, every field of
  `sigma'`, and — on the throwing path — the same exception object and the same
  destructor effects. The prototype establishes this *mechanically* for the
  non-throwing path (same text, same state references) and *differentially* for
  a large finite input set; it does not prove it.
* **O2 (loop equivalence).** By induction over iterations using O1, the pinned
  `for` and the new `while` agree, including `++opcode_pos` placement.
* **O3 (exception framing).** The only `try` region remains in `EvalScript`;
  a throw inside `EvalStep` reaches the same handlers with the same
  `scriptnum_error`/catch-all selection. This changes *which frame* runs the
  cleanup landing pads, so it is part of the obligation, not an artefact.
* **O4 (whole function).** `EvalScript_patched = EvalScript_pin`, including the
  post-loop `UNBALANCED_CONDITIONAL` check and `set_success`.
* **O5 (bounded layer, only if a cell uses it).** A counted loop with a
  *concrete* bound `B` is equivalent to the unbounded loop on inputs whose
  dispatch performs at most `B` iterations. For BASE/WITNESS_V0 the bound
  `B = min(script.size(), MAX_SCRIPT_SIZE)` is sound because every successful
  `GetOp` consumes at least one byte; TAPSCRIPT has no static size limit, so a
  per-cell witness-derived bound must be stated instead. A bound that can
  truncate execution is a domain restriction, not an equivalence.

## 5. How this interacts with the Core patch policy

`../../patches/README.md` requires each patch to be minimal/localised,
tracked, differential-tested against the unpatched build on the full corpus
plus fuzz lanes, recorded in results, and upstreamable in principle.

* **Minimal/localised — partly.** Semantically it is one intent
  (`split a function for cell slicing`), one file, one function, no header or
  ABI change, no predicate/error/order change. Textually it is a 784-line move,
  which is not "minimal" by review size.
* **Tracked — yes**, this directory plus the proposal registry entry.
* **Behavior-preserving evidence — partial.** 12,523 focused rows, 0
  divergences, 2 live negative controls. **Not run:** the registry-mandated
  1,258 `script_tests.json` + 500 `sighash.json` + ≥1,000,000-row fuzz lane.
  Status therefore stays **PROPOSED** under the registry's own rule.
* **Explicit in results — n/a**, no cell uses it.
* **Upstreamable in principle — unlikely as-is.** A mechanical 800-line move
  for an external proof tool is hard to justify upstream; the family split
  (layer 2) is even larger. Flag as lane-only.
* **Forbidden list — clean.** No opcode semantics, limits, flag handling,
  error selection or serialization changed; the differential specifically
  checks error precedence and partial stack state on failure.

Interaction with the existing lane: P-CORE-04 is orthogonal to
P-CORE-01/02/03 and composes with them (measured, §3.1/§3.3). It should get its
own `-DBTC_EQUIV_EVALSTEP` macro only if the lane wants the unpatched IR
reproducible from the same tree; the prototype is unguarded because it is a
pure refactor.

## 6. What still blocks E5 after this prototype

1. **Dispatch loop bound** — unchanged: `pc < pend` is symbolic-trip; SAW needs
   either a constant bound per cell (domain-restricted) or an invariant
   mechanism (not available in this SAW/LLVM path).
2. **Multisig inner loops** — `EvalStep` is not loop-free; the `OP_CHECKMULTISIG`
   family has three loops. A family split (layer 2) or a bounded multisig
   treatment is required before *any* step-level SMT proof.
3. **Step size** — even without loops, one `EvalStep` is too large for Alive2
   `--always-verify` (no verdict in 900 s). Per-family or per-opcode leaves are
   needed.
4. **Heap/STL model, `GetScriptOp`, crypto/hash externals, exception policy,
   guard policy** — untouched by P-CORE-04; these remain the E5 blockers listed
   in `findings/e5/E5-RESIDUAL.md` §2.
5. **No green cell.** Nothing here is a proof of the engine.

## 7. Recommendation

1. **Do not promote E5, and do not apply P-CORE-04 to the official lane in this
   PR.** Registry entry stays `design/prototype only`, status PROPOSED.
2. **Next experiment (proof-side, no Core patch):** run LLVM `CodeExtractor` on
   the *loop body region* of the erased `01/02/03` module to obtain an
   `EvalStep(State*)` with an explicit live-out struct. If `CodeExtractor`
   accepts the region (it may bail on EH pads even after erasure), the same
   decomposition is obtained without a source patch, which removes the
   differential/upstream burden. Record the exact bail/accept result either way.
3. **Then split per family** (flow, stack, numeric, hash, checksig,
   multisig) and prove the flow/stack/numeric families with Alive2
   `--always-verify`; defer multisig until its three loops are bounded.
4. **Drop P-CORE-05 as specified.** If `-O1` ever becomes a proof lane, the
   only transform that removes the boundary `ptrtoint` is a span-carrying stack
   (length materialised, no `vector::size()` at the leaf boundary) — a much
   larger refactor, not a leaf overload. The `-O0` lane already has a 0-`ptrtoint`
   `CastToBool` that Alive2 proves.
5. Reuse `harness/driver.cpp` + `gen_corpus.py` for the pending P-CORE-01/02/03
   differential work; it already has a deterministic corpus, error/stack-state
   parity and negative controls.

## 8. Reproduction

```sh
# full differential, from a pristine pin checkout:
CORE_SRC=/path/to/bitcoin-at-cce32b16 \
WORK=/tmp/opencode/wave16b-scratch/11-patch-evalstep-repro \
  spec/equiv/patches/proposals/wave16b/11-patch-evalstep/harness/build.sh
# -> "DIFFERENTIAL: zero divergences over 12523 rows", 3 / 169 control rows
```

Exact tool versions and hashes: `logs/`, `SHA256SUMS`.

## 9. Honest scope

* The prototype is **not** a proof, not a green cell, and not used by any
  ledger row.
* The differential is a **finite, focused** refactor-equivalence lane with
  stubbed crypto/checker externals; it is not the registry corpus/fuzz run and
  does not cover real signatures or real hashes.
* The exception-erasure transform used for the Alive2 probes is
  **domain-restricting** (CORE-IR residual F-TOOL-006); the Alive2 results are
  translation checks only.
* The SAW loop probes are toy functions, not `EvalScript`; they establish tool
  behaviour (constant-trip vs symbolic-trip), not engine properties.
* `Alive2 --always-verify` on `EvalStep`: **not run to completion** (no verdict
  in 900 s). `SAW` on `EvalStep`/`EvalScript`: **not run** — no step spec
  exists yet and the loop has no bound/invariant.
