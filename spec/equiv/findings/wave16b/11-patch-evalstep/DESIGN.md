# P-CORE-04 design — `EvalStep` slicing, explicit state, bounded refinement

**Status:** prototype implemented and differential-tested; **PROPOSED**, not
used by any cell. **Verdict:** behaviour-preserving and mechanical, but *not
sufficient* to make E5 tractable; see §6 and the task `README.md` §7.

Pin lines below are the pinned upstream lines (`cce32b16`), not post-patch.

---

## 1. Target

* `src/script/interpreter.cpp:417-1249` — 7-arg `EvalScript` (body 4,637 IR
  lines at `-O0`).
* Dispatch loop `:449-1234`; opcode switch `:494-1229`.
* The loop mutates: `pc`, `pbegincodehash`, `opcode`, `vchPushValue`, `stack`,
  `altstack`, `vfExec` (`ConditionStack`), `nOpCount`, `opcode_pos`,
  `execdata`; it reads `script`, `flags`, `sigversion`, `fRequireMinimal`,
  `checker`, `serror`, and four function-local constants (`bnZero`, `bnOne`,
  `vchFalse`, `vchTrue`).

## 2. Prototype structure

Generated mechanically by `harness/mk_evalstep.py`; the moved body is
byte-identical after indentation normalisation (`harness/verify_move.py`).

```cpp
namespace {

struct ScriptEvalState {
    // parameter-bound, read-only context
    const CScript& script;
    const BaseSignatureChecker& checker;
    const script_verify_flags flags;      // by value (immutable scalar)
    const SigVersion sigversion;          // by value
    ScriptError* serror;                  // pointer copied, never reassigned
    ScriptExecutionData& execdata;

    // mutable machine state carried across steps
    std::vector<valtype>& stack;
    std::vector<valtype>& altstack;
    ConditionStack& vfExec;
    CScript::const_iterator& pc;
    CScript::const_iterator pend;         // by value (immutable)
    CScript::const_iterator& pbegincodehash;
    opcodetype& opcode;                   // loop-carried scratch
    valtype& vchPushValue;                // loop-carried scratch
    int& nOpCount;
    bool fRequireMinimal;
    uint32_t& opcode_pos;

    // read-only constants owned by EvalScript (function-local statics);
    // passed by reference so their one-time init point is unchanged and this
    // patch does not subsume P-CORE-03.
    const CScriptNum& bnZero;
    const CScriptNum& bnOne;
    const valtype& vchFalse;
    const valtype& vchTrue;
};

static bool EvalStep(ScriptEvalState& st)
{
    const CScript& script = st.script;          // 21 name aliases so the
    ...                                         // moved body is unchanged
    const valtype& vchTrue = st.vchTrue;

    /* 784 lines: exactly the pinned loop body */
    return true;
}

} // namespace

bool EvalScript(...)
{
    /* unchanged statics, assert, locals, size check, execdata init */
    ScriptEvalState s{script, checker, flags, sigversion, serror, execdata,
                       stack, altstack, vfExec, pc, pend, pbegincodehash,
                       opcode, vchPushValue, nOpCount, fRequireMinimal,
                       opcode_pos, bnZero, bnOne, vchFalse, vchTrue};
    try {
        for (; pc < pend; ++opcode_pos) {
            if (!EvalStep(s)) return false;
        }
    }
    catch (const scriptnum_error&) { return set_error(serror, SCRIPT_ERR_SCRIPTNUM); }
    catch (...)                    { return set_error(serror, SCRIPT_ERR_UNKNOWN_ERROR); }
    if (!vfExec.empty()) return set_error(serror, SCRIPT_ERR_UNBALANCED_CONDITIONAL);
    return set_success(serror);
}
```

Design choices, and why they are the minimal ones:

* **References, not copies.** Every mutable field is a reference to the
  `EvalScript` local of the same name. This preserves the exact object
  lifetimes, the exact destructor order on return/throw, and the exact
  `++opcode_pos` placement (the `for` header is untouched).
* **`opcode`/`vchPushValue` stay loop-carried.** They are reassigned by
  `script.GetOp` every iteration, so a step-local would also be observable-
  equivalent, but keeping them in the state avoids relying on `GetOp`'s
  clear-first behaviour and keeps the state complete.
* **The four constants are passed by reference.** Moving them into the state
  by value or re-declaring them inside `EvalStep` would change the one-time
  static-initialisation point (a P-CORE-03 concern). This patch deliberately
  does not touch it.
* **No macro guard.** The patch is a pure refactor; if the lane build wants
  the unpatched IR reproducible from the same tree, guard the new namespace
  block and the loop variant with `-DBTC_EQUIV_EVALSTEP`. Not needed for the
  prototype.
* **No switch split.** Layer 2 (per-family helpers) is intentionally *not* in
  this patch; it multiplies the textual diff and is only worth doing after the
  step is proved useful (see §6).

## 3. Patch size

| Metric | Value |
|---|---|
| Files changed | 1 (`src/script/interpreter.cpp`), no headers, no ABI |
| Hunks | 1 |
| Diffstat | `+816 / −738` |
| Moved loop body | **784 lines, byte-identical** after de-indent (`verify_move.py`) |
| Semantic additions | state struct (~47 lines incl. comments), 21 alias lines, `ScriptEvalState` init (4), loop wrapper (3), `return true;` (1) ≈ **78 lines** |
| Affected functions | `EvalScript` (7-arg) only; new `internal` `EvalStep` + `ScriptEvalState` in an anonymous namespace |
| Other TUs | none |

The diff is large *textually* because it is a move; the semantic delta is the
78 wrapper lines. `git apply --check` passes on the unmodified pin.

## 4. Refinement obligation

Notation: a state `sigma` is the 21-tuple of fields above. `R_pin(sigma)` is
the result of executing the pinned loop body once from `sigma`;
`R_step(sigma)` is the result of `EvalStep(state(sigma))`. A result is
`OK(sigma')` or `FAIL(e)` where `e` is either `(serror = code)` or a thrown
exception.

**O1 — per-step equivalence.**
`∀σ. R_step(σ) = R_pin(σ)`. Equality includes:
(a) the returned bool; (b) `*serror`; (c) every component of `σ'`
(`pc`, `pbegincodehash`, `opcode`, `vchPushValue`, `stack`, `altstack`,
`vfExec`, `nOpCount`, `opcode_pos`, `execdata`); (d) on the exception path, the
exception object and the sequence of destructor effects.

Status: *mechanically true by construction* for the text (same statements, same
objects), *differentially tested* on 12,523 rows, **not proved**.

**O2 — loop equivalence.** By induction on the number of iterations using O1,
`for (; pc < pend; ++opcode_pos) { body }` and
`for (; pc < pend; ++opcode_pos) { if (!EvalStep(s)) return false; }` agree:
`return false` occurs exactly on the old `return false` paths (every
`return set_error(...)` and the two `EvalChecksig` failures), and the increment
still happens iff the body fell through the stack-size check.

**O3 — exception framing.** The only `try` region is in `EvalScript`. The step
call is an `invoke` whose unwind edge goes to the same two handlers; a throw
inside `EvalStep` therefore reaches the same `catch` clause and sets the same
`serror`. The difference is *which frame's* cleanup landing pads run
(`EvalStep` now owns the cleanup for its case-local objects). That is part of
the obligation and is exercised by the differential's 132 `SCRIPTNUM` rows and
the underflow/`at()` rows. A whole-program proof would need a small
exception-semantics lemma for this frame change.

**O4 — whole function.** `EvalScript_patched(args) = EvalScript_pin(args)` for
all arguments, including the post-loop `vfExec` check and `set_success`.

**O5 — bounded layer (only for a bounded cell; not in the patch).** A counted
driver

```cpp
for (unsigned steps = 0; steps < B; ++steps) { if (pc >= pend) break; ... }
```

with a **concrete** `B` is equivalent to the unbounded loop iff the dispatch
performs at most `B` iterations. Sound bound for BASE/WITNESS_V0:
`B = min(script.size(), MAX_SCRIPT_SIZE)` because every successful `GetOp`
consumes ≥ 1 byte and the unpushed script is limited to 10,000 bytes. For
TAPSCRIPT the 10,000-byte check is not applied in `EvalScript`; a bound must
come from the witness/validation-weight budget and must be stated per cell.
A bound that can truncate execution is a **domain restriction**, not an
equivalence, and must be labelled as such.

## 5. Tool-facing consequences (measured)

* `ptrtoint` unchanged; both functions have 0.
* `EvalScript` invokes 336 → 20 (pin lane), landing pads 32 → 8; module
  invokes 686 → 445. Reason: calls inside a `try` are `invoke`s; the try is now
  only around the step call.
* `EvalStep` is loop-free **except** for the multisig family: three depth-1
  loops at `OP_CHECKMULTISIG` (`for k < nSigsCount`, the
  `while (fSuccess && nSigsCount > 0)` matcher, and the NULLFAIL
  `while (i-- > 1)` cleanup). Bounds are ≤ `MAX_PUBKEYS_PER_MULTISIG` = 20 but
  symbolic.
* Alive2 translates `EvalStep` and the composed `EvalScript` after exception
  erasure; `--always-verify` over the whole step produced **no verdict in
  900 s** (too large for one SMT query).
* SAW 1.6 discharged a constant-trip loop but not a symbolic-trip loop
  (90 s, no verdict). So a step function alone does not unlock SAW: the loop
  needs a concrete bound or an invariant.

## 6. Why this does not unblock E5 by itself

1. The dispatch loop stays symbolic-trip. P-CORE-04 gives a *unit*, not a
   *bound* and not an *invariant*.
2. The step unit is still too large for SMT and still contains the multisig
   loops.
3. The E5 blockers independent of slicing (heap/STL, `GetScriptOp`,
   crypto/hash, exception policy, guard policy) are untouched.

The step is a necessary substrate for later work, not a sufficient condition.

## 7. Layer 2 (not implemented): family split

After the mechanical extraction is accepted, split `EvalStep` on `opcode` into
`EvalFlowStep`, `EvalStackStep`, `EvalNumericStep`, `EvalHashStep`,
`EvalChecksigStep`, `EvalMultisigStep`, `EvalLocktimeStep` — same state struct,
same predicates and order, a `switch` dispatch at the top. Recommended only if
a cell actually targets one family. Multisig stays last because its three inner
loops need their own bounds (`nKeysCount`, `nSigsCount` ≤ 20).

## 8. Proof-side alternative (recommended next experiment)

Use LLVM's **`CodeExtractor`** on the *loop-body region* of the erased
`01/02/03` module:

* region = blocks dominated by the loop header, excluding the header/latch;
* live-ins become the state struct, live-outs become the returned struct;
* output = `EvalStep(State*)` derived purely in IR, **no Core source change**,
  no patch-policy differential burden on Core, and reproducible as a tracked
  transform script.

Open question to test first: `CodeExtractor` bails on regions containing
`invoke`/`landingpad`. The CORE-IR erasure transform removes both (measured:
430 invokes → 0, 202 landing pads → 0), so the experiment is: run
`CodeExtractor` on the erased module and record accept/bail with the exact
message. If it accepts, the decomposition is obtained without touching Core
and P-CORE-04 can be reclassified as a *proof-side derivation* rather than a
patch. If it bails, the reason will name the remaining IR feature to remove.

## 9. Core patch policy checklist

| Rule | Status |
|---|---|
| Minimal/localised (one intent) | semantic yes; textual no (784-line move) |
| Tracked | yes (this directory + proposal registry) |
| Differential vs unpatched, full corpus + fuzz | **not run** (focused 12,523-row lane only) |
| Explicit in results | n/a (no cell uses it) |
| Upstreamable in principle | no as-is; lane-only |
| Forbidden changes | none (no semantics/limits/flags/errors/serialization) |
