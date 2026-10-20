# exec-verify/C-L-w32-fail-propagation

SCR-017, "any EvalScript/VerifyWitnessProgram failure => input invalid"
(interpreter.cpp:2029-2036, 2052-2054, 2080-2082, 2097-2099).

**This cell is partial**: it proves the wrapper seam, not real script
execution. See the blocker section.

## What is proved

`cell_fail_prop` is a faithful slice of VerifyScript's control skeleton in
which the five engine calls are abstracted to `(ok | fail, error)` inputs.
For **every** assignment of five outcomes, five error ordinals, the flag word
and the path/truth predicates, the C and L legs return the same packed
`(result, error)` and that value equals the first-failure model in
`saw/spec.cry`:

* a failing scriptSig EvalScript (e1) or scriptPubKey EvalScript (e2)
  returns result 0 with that call's error, and no later stage runs;
* a failing bare-witness VerifyWitnessProgram (ew1) returns result 0 with its
  error;
* a failing redeemScript EvalScript (e3) or P2SH-witness
  VerifyWitnessProgram (ew2) returns result 0 with its error;
* the EVAL_FALSE, CLEANSTACK and WITNESS_UNEXPECTED tails keep Core's order
  and ordinals; success is the packed `0x100`.

`cell_prop_law` re-derives which calls are reached and checks the verdict:
it returns 1 for every input, i.e. a reachable EvalScript /
VerifyWitnessProgram failure always implies an invalid input. SAW proves
that universal statement on both legs; Alive2 proves C-vs-L on both
functions.

## What is *not* proved (partial coverage)

* That Core's `EvalScript` / `VerifyWitnessProgram` return those outcomes on
  real scripts. That is the E5 residual: undefined `GetScriptOp`, heap
  allocation, the unbounded dispatch loop, exception edges
  (`findings/e5/E5-RESIDUAL.md`).
* `CScript::IsWitnessProgram`, `CScript::IsPayToScriptHash`, the scriptSig
  push-only/exactness checks and the stack/cleanstack contents are inputs
  (their own rows).
* Lean's third `VerifyOutcome` constructor `.unjudged` is an out-of-seam
  outcome and is collapsed/not modeled.

Smallest next experiment toward full coverage: an `EvalScript` model with an
opcode-loop invariant and a `GetScriptOp` override at LLVM 20 (SAW), or the
P-CORE-04 `EvalStep` refactor plus bounded unrolling; until then the row
cannot be discharged over real scripts.

## Exact commands

```sh
spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/saw/run.sh
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-fail-propagation/saw/certificate.sha256
```

## Trust note

C is a line-cited slice with five stubbed calls; L is a reviewed hand
transliteration of `verifyScriptFull`'s match structure
(`spec/core/Bitcoin/Interpreter/Defs.lean:1363-1420`). The stubs are the
abstraction, and they are declared in the spec precondition. No unsafe
assume, no Core patch, no claim about crypto or script semantics.
