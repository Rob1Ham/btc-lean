# wave65/27 — E5 whole-`EvalScript`, component C1: dispatch-loop control

**Role:** E5-WHOLE-FUNCTION (subagent wave65/27)
**Core pin:** Bitcoin Core v32.99 `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Branch / base:** `wave65/27-e5-whole` @ `76dbfe5e42f8a337e41a7308158b0de078afafd9`
**Date:** 2026-10-21
**Toolchain:** SAW 1.6 (`68eed5f`), clang/LLVM 20.1.2, Lean 4.35.0, z3 4.8.12

## 0. Verdict (read this first)

Two machine-checked results for the **control** component of `EvalScript`, and a
captured, reproducible IR edge for the remaining parser-call bridge.

| artifact | result | where |
|---|---|---|
| SAW against the **real pinned `script.cpp` bitcode**: consumed-byte measure of `GetScriptOp`, 5 exhaustive opcode classes, symbolic payload lengths | **5/5 `Proof succeeded!`**, exit 0 | `saw/parser-measure.saw`, `logs/parser-measure.log` |
| SAW negative control (`2+n` asserted as `1+n`) | `Proof failed.`, exit 2 | `saw/parser-measure-negative.saw`, `logs/parser-measure-negative.log` |
| SAW against the real 4-arg `GetScriptOp` (`pvchRet != nullptr`, the EvalScript call site) | stops at `_Znwm`, exit 2 — **expected**, this is the recorded gap | `saw/parser-ret-gap.saw`, `logs/parser-ret-gap.log` |
| Lean 4, loop-control skeleton: ranking/termination, op-count bound, condition-stack invariant + depth, epilogue `(result, error)` pair | `lean` exit 0, 44 theorems, **no `sorryAx`** | `lean/LoopMeasure.lean`, `logs/lean-check.log` |

**Whole-function refinement of `EvalScript` is NOT proved here.** The Lean file is
a *transcription* of the control skeleton, not a refinement of the pinned LLVM
module (see §5, O-STEP). There is no SCR row, no `make equiv` row, and no
equivalence claim. §6 lists exactly what would have to be discharged next.

## 1. Why this decomposition is the smallest sound one

`EvalScript` (interpreter.cpp:417) = prologue (417–448) + dispatch loop
(449–1235) + epilogue (1236–1248). The loop body is a 700-line opcode `switch`
whose effects on *everything except control state* are per-family.

The control state is exactly

```
pc : const_iterator   (monotone; advanced only by GetScriptOp)
nOpCount : int        (incremented by 1 per opcode > OP_16, plus nKeysCount)
vfExec : ConditionStack (push / pop / toggle, 3 opcodes)
error : ScriptError   (set once, never reset inside the loop)
```

Every opcode body changes at most `vfExec` (by one of the three operations) and
`nOpCount` (by `1 + nKeysCount`); it never touches `pc` except through
`GetScriptOp`. That is what makes **C1 (loop control)** the minimal cut that can
be proved without modelling the value stack, signatures or crypto:

| component | content | status |
|---|---|---|
| **C1** loop control | pc measure, termination, op-count bound, condition-stack invariant/depth, epilogue `(result, error)` | **this cell**: Lean + SAW |
| C2 opcode bodies | stack/altstack effects, `nKeysCount`, signature & crypto semantics | out of scope |
| C3 value stack + heap | `std::vector` model / allocator refinement (B2, B6) | out of scope |
| C4 exceptions + static guards | `invoke`/`landingpad`, `__cxa_guard`, ABI globals (B4, B5) | out of scope |
| C5 refinement | O-STEP: Lean skeleton ⇒ pinned IR loop; O-PVCHRET: parser call bridge | **blocked**, §5 |

A composition theorem therefore has the shape

```
C1 (control)  ∘  C2 (per-opcode body specs, one per family)
              ∘  C3 (stack/heap model)  ∘  C4 (exception/guard policy)
   ⇒  EvalScript refinement, conditional on same-crypto (B7)
```

C1 is done at the model level; C2–C4 are where the remaining E5 work is.

## 2. The obligation table for C1

`Lean` = proved in `lean/LoopMeasure.lean`; `SAW` = proved over the real pinned
IR. Source column cites the pin (`src/script/*`).

| id | obligation | mechanism | source |
|---|---|---|---|
| C1a | a non-empty parse window consumes ≥ 1 byte (ranking premise); failure paths also advance `pc` | Lean + **SAW** (successful classes) | script.cpp:324,338,345,352 |
| C1b | a successful parse never consumes beyond the window | Lean + **SAW** | script.cpp:330–353 |
| C1c | declared push length + 1 ≤ consumed (payload accounting) | Lean + **SAW** | script.cpp:356–359 |
| C1d | loop exits with `pc = pend` or a nonzero error (no other exit) | Lean | interpreter.cpp:449, 455, 462, 1232 |
| C1e | termination: `|script| - pc` strictly decreases | Lean `termination_by` | interpreter.cpp:449 |
| C1f | `nOpCount ≤ MAX_OPS_PER_SCRIPT` (BASE/V0 only) | Lean | interpreter.cpp:462, 1129–1130 |
| C1g | `ConditionStack` representation invariant preserved | Lean | interpreter.cpp:283–331, 613–661 |
| C1g' | `vfExec.size ≤ pc`, hence `≤ |script|`; and `< NO_FALSE` in BASE/V0 (no sentinel/position collision) | Lean | interpreter.cpp:286, 298, 311, 322 |
| C1h | success ⇒ `vfExec` empty | Lean | interpreter.cpp:1245–1246 |
| C1i | success ⇒ `pc = pend` | Lean | interpreter.cpp:449, 1236–1248 |
| C1j | every exit code ∈ {OK, UNKNOWN, BAD_OPCODE, PUSH_SIZE, OP_COUNT, UNBALANCED} | Lean | interpreter.cpp:437, 461, 465, 1236–1248 |
| C1k | BASE/WITNESS_V0 ⇒ `|script| ≤ 10000` | Lean | interpreter.cpp:438, script.h:41 |
| C1k+ | BASE/V0 ⇒ condition depth `< 2^32-1` | Lean | as C1g'/C1k |
| O-STEP | refinement of the Lean `run`/`step` skeleton to the pinned `%336` loop | **blocked** | §5.1 |
| O-PVCHRET | bridge for `GetOp(..., vchPushValue)` = 4-arg `GetScriptOp` with `pvchRet ≠ null` | **blocked** | §5.2 |

Theorem names map 1:1 onto the table (`parse_consumed_pos`, `parse_consumed_le`,
`parse_pushLe`, `run_done_or_error`, the `termination_by` on `run`,
`run_opCount_le`, `run_cond_inv`, `run_cond_depth`, `run_cond_size_lt_NO_FALSE`,
`evalScript_ok_balance`, `evalScript_ok_done`, `evalScript_error_class`,
`base_script_len`).

### 2.1 What the SAW result actually says

`saw/parser-measure.saw` verifies `w65_gso_consumed` (`harness/measure.cpp`) —
a harness that adds **no parser logic**: it builds two real
`CScriptBase::const_iterator` values and calls the real `GetScriptOp` with
`pvchRet = nullptr`, returning `pc' - pc` computed by the real
`const_iterator::operator-`. The harness exists because `const_iterator` is a
one-pointer class (`prevector.h:78`), so SAW's `llvm_elem` needs a concrete index
and cannot state a symbolic post-`pc`; returning the difference as an integer
sidesteps that without changing the parser.

Five claims, exhaustive over the first byte `0..255` of the window:

| class | precondition | postcondition |
|---|---|---|
| direct push | `k ≤ 75` | `ok`, `opcode = k`, consumed `1 + k`, buffer untouched |
| `OP_PUSHDATA1` | — | consumed `2 + n`, `n` symbolic |
| `OP_PUSHDATA2` | `LE16 ≤ 520` | consumed `3 + LE16` |
| `OP_PUSHDATA4` | `LE32 ≤ 520` | consumed `5 + LE32` |
| non-push | `79 ≤ opc` | consumed `1`, `opcode = opc` |

This is the *property* the loop measure needs (Consumed ≥ 1 and the payload
accounting), proved against the **real** compiled function, not the Lean model.
It is not a full `GetScriptOp` functional-correctness spec (the returned payload
bytes for the `pvchRet ≠ null` case are not covered — that is O-PVCHRET).

Negative control: changing `2 + n` to `1 + n` in the PUSHDATA1 postcondition
produces `Proof failed.` (exit 2), so the success is not vacuous.

### 2.2 What the Lean result actually says

`Lean 4.35.0`, core only, no Mathlib. `#print axioms` for all 21 headline
theorems shows only `propext`, `Quot.sound`, and `Classical.choice` where a
classical case split is used — **no `sorryAx`** (full output in
`logs/lean-check.log`).

The definitions are a direct transcription of the pin:

* `parse` = `GetScriptOp` (script.cpp:313–363), including the fact that the
  failing paths have already advanced `pc` (the model returns `consumed`, so a
  failure still moves `pc` forward).
* `Cond` = `(m_stack_size, m_first_false_pos)` with `NO_FALSE = 0xffffffff`;
  `push`/`pop`/`toggle` transcribe interpreter.cpp:296–331.
* `step` = one loop iteration in source order: `GetOp` → BAD_OPCODE →
  `MAX_SCRIPT_ELEMENT_SIZE` → `opCount`/`MAX_OPS_PER_SCRIPT` → body delta →
  condition update. Failure branches set `pc` first, as in the pin.
* `run` is accepted by Lean **only** with `termination_by script.length - s.pc`
  and the `step_pc_gt` decreasing proof, so C1e is not an assertion.
* `finish`/`evalScript` = the epilogue: two `catch` clauses keep the error set
  where the throw was caught, `!vfExec.empty()` ⇒ `UNBALANCED_CONDITIONAL`,
  otherwise `set_success` (interpreter.cpp:1236–1248).

Two honest modelling notes:

1. `condStep` pushes the literal `true` where the pin pushes the stack-derived
   `fValue` (interpreter.cpp:643). Every lemma used here (`Cond.push_inv`,
   `Cond.push_size`) is generic in that boolean, so both branches of `fValue`
   are covered; `all_true`-dependent *execution gating* is not modelled.
2. Depth is bounded **relatively** (`size ≤ pc`), not by a constant: no fixed
   numeric bound survives `push_back`. Combined with C1k this gives the
   sentinel-safety bound C1k+.

## 3. Source of record

Extracted read-only from the pin, not copied from a working tree:

```sh
git -C /tmp/pcore01 show cce32b1:src/script/interpreter.cpp > /tmp/opencode/wave65/27-e5-whole-evidence/src/interpreter.cpp
git -C /tmp/pcore01 show cce32b1:src/script/script.cpp      > /tmp/opencode/wave65/27-e5-whole-evidence/src/script.cpp
git -C /tmp/pcore01 show cce32b1:src/script/script.h        > /tmp/opencode/wave65/27-e5-whole-evidence/src/script.h
```

| file | sha256 |
|---|---|
| `interpreter.cpp` | `57a6f328…` (full value in `SHA256SUMS`) |
| `script.cpp` | `210b1720…` |
| `script.h` | `43e4eb10…` |

Citations used above: `EvalScript` 417; prologue/limits 437–447; loop head 449;
`GetOp` 455; push-size 460; op-count 462; `OP_IF/NOTIF` 613–645 (`push_back` 643);
`OP_ELSE` 647–652 (`toggle_top` 651); `OP_ENDIF` 654–660 (`pop_back` 659);
multisig delta 1129–1130; stack-size 1232–1234; catches 1236–1243; unbalanced
1245–1246; `set_success` 1248. Limits: `script.h:29,32,41,44`.

**TAPSCRIPT asymmetry (real E5 fact):** interpreter.cpp:438 guards the script
size only for BASE/WITNESS_V0, and interpreter.cpp:461–463 skips the op-count
check for TAPSCRIPT. C1f and C1k are therefore stated for BASE/V0 only; a
tapscript trip-count bound has to come from the witness/annex weight budget, not
from `MAX_SCRIPT_SIZE`.

## 4. Build and reproduction

The pinned parser bitcode is reproduced **bit-for-bit** by compiling with a
relative source path inside the pin checkout (an absolute path changes the
`source_filename` and hence the hash):

```sh
cd /tmp/opencode/equiv-work/bitcoin          # clean cce32b1 checkout
CELL=/tmp/opencode/wave65/27-e5-whole/spec/equiv/findings/wave65/27-e5-whole

# 1. real script.cpp TU  -> sha256 657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c src/script/script.cpp -I src -o $CELL/build/script-O0.bc

# 2. harness TU (no parser logic) -> 9f287fb1…
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c $CELL/harness/measure.cpp -I src -o $CELL/build/measure-O0.bc

# 3. linked module -> 1d8b344e…
/usr/lib/llvm-20/bin/llvm-link $CELL/build/script-O0.bc $CELL/build/measure-O0.bc -o $CELL/build/parser-measure.bc

# 4. the 5 parser measure proofs (expect 5x "Proof succeeded!", exit 0)
cd $CELL && saw saw/parser-measure.saw

# 5. negative control (expect "Proof failed.", exit 2)
cd $CELL && saw saw/parser-measure-negative.saw

# 6. the recorded O-PVCHRET edge (expect "_Znwm", "Proof failed.", exit 2)
cd $CELL && saw saw/parser-ret-gap.saw

# 7. Lean (expect exit 0, no errors, no sorryAx)
cd $CELL/lean && lean LoopMeasure.lean
```

`build/` holds the three bitcode artifacts used for the runs above. That
directory is git-ignored (`spec/equiv/.gitignore`), so it is **not** part of the
commit: regenerate it bit-for-bit with commands.md §1. The three expected hashes
are recorded in commands.md and as comments in `SHA256SUMS`.

## 5. The exact remaining E5 blockers

### 5.1 O-STEP — no IR-level loop invariant

The Lean `run` is a transcription, not a refinement. To close the gap one needs
an invariant at the pinned loop header `%336` (`interpreter-O0.ll:4101`,
backedge `:8200`) over `(pc, nOpCount, vfExec, error, stack, altstack)`, plus a
per-iteration simulation relation to `step`. SAW 1.6 has no loop-invariant
mechanism: `llvm_verify` unrolls, so a symbolic `|script|` diverges or times out,
and a timeout is not a proof. The loop body contains 336 `invoke`s and 32
`landingpad`s (B4), 52 statically reachable `ptrtoint`s in vector/iterator/
tinyformat helpers (B6), and three `__cxa_guard`-guarded statics (B5). Any one of
those must be discharged before a symbolic-trip-count proof can even start.

**Next experiment.** Slice the body into the P-CORE-04 `EvalStep` seam and prove
the C1 invariant *against the extracted step relation*, then verify each
per-family step against a SAW spec (C2), keeping the loop invariant in Lean
where induction is available. Fallback (must be labelled bounded): fix `|script|`
and unroll, which yields a family of bounded results, not a theorem.

### 5.2 O-PVCHRET — the EvalScript parser call is the 3-arg `GetOp`

The 5/5 SAW result is for `GetScriptOp(..., pvchRet = nullptr)`, which covers the
four other `GetOp` loops at interpreter.cpp:257, 1288, 1294, 1851. `EvalScript`
calls the **3-arg** member `script.GetOp(pc, opcode, vchPushValue)` at
interpreter.cpp:455, which forwards to `GetScriptOp` with `pvchRet = &vchPushValue`
(script.cpp:313, 356–357). That path executes `pvchRet->assign(pc, pc + nSize)`.

`saw/parser-ret-gap.saw` points the real function at an empty `std::vector` and
reproduces the stop exactly (`logs/parser-ret-gap.log`):

```
Subgoal failed: _Z11GetScriptOpRN9prevectorILj36EhjiE14const_iteratorES1_R10opcodetypePSt6vectorIhSaIhEE internal: error: in _ZNSt15__new_allocatorIhE8allocateEmPKv
Failed to load function handle: _Znwm
Details:
  No implementation or override found for pointer
----------Counterexample----------
  n: 128
...
Proof failed.
```

i.e. the first unresolved edge is the allocator inside `std::vector::assign`, with
a concrete witness (`n = 128`) and not a timeout. The wave16b observation that
`llvm.is.constant.i32` follows `_Znwm` in libstdc++'s
`__new_allocator::allocate` (the `__builtin_constant_p`/`max_size` path) is
consistent with this log; it is reachable only after `_Znwm` is modelled.

**Next experiment.** Discharge one of:

1. a verified SAW override for `std::vector<unsigned char>::assign` on the
   bounded domain `n ≤ 520` with a capacity premise (the only sizes EvalScript
   can request are ≤ 520, script.h:29), pulling in `_Znwm` and the
   `llvm.is.constant.i32` side condition explicitly; or
2. a proved refinement from a `(begin, size, capacity)` span model to the
   `std::vector` layout, with the allocator modelled as a capacity-`C` arena and
   an explicit allocation-failure branch (B2 argues against a "never fails"
   allocator).

### 5.3 The rest of the E5 catalogue (unchanged)

B2 heap/allocator (`_Znwm`, `free`, `realloc`, `malloc`); B4 exception
edges/ABI globals (erasure is domain-restricting, and Alive2 cannot see
`invoke`); B5 `__cxa_guard` statics; B6 `ptrtoint`/STL memory model; B7
crypto/assert externals, so the engine claim stays conditional on same-crypto.
`spec/equiv/findings/e5/E5-RESIDUAL.md` is the source of record for those; this
cell does not change any of their statuses.

## 6. Honest scope statement

* Proved: the C1 obligations in §2, at the model level (Lean, no `sorryAx`) and
  — for the parser increment only — at the **real IR** level (SAW, 5/5).
* Not proved: any refinement from the Lean skeleton to the pinned LLVM module;
  any opcode-body semantics; any heap/exception/guard model; anything about
  TAPSCRIPT limits; whole-function `EvalScript`/`VerifyScript` equivalence.
* The Lean file is explicitly labelled a transcription in its header. Do not
  cite it as an IR refinement or as an SCR/`make equiv` row.
* The SAW parser result is a **measure** lemma (consumed bytes / opcode / ok
  flag), not full functional correctness of `GetScriptOp`.

## 7. Files

```
lean/LoopMeasure.lean              C1 model + 44 theorems, no sorryAx
saw/parser-measure.saw             5/5 over the real pinned script.cpp IR
saw/parser-measure-negative.saw    failing control (2+n vs 1+n)
saw/parser-ret-gap.saw             O-PVCHRET edge, expected to fail at _Znwm
harness/measure.cpp                pc'-pc harness (no parser logic)
build/{script-O0,measure-O0,parser-measure}.bc   pinned/reproducible (git-ignored)
logs/                              raw tool output for every claim above
commands.md                        exact commands, in order
SHA256SUMS                         hashes of every artifact and log
```
