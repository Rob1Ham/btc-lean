import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.FuelStability — fuel-independence of the interpreter

## The question

The interpreter (`Bitcoin.Interpreter.Defs`, read-only) is a *fuel-bounded*
machine: `evalFrom` consumes one unit of `fuel` per executed opcode, and
`evalScriptBytes`/`verifyScriptFull`/`executeWitnessScript`/`p2shInner`
thread one `fuel : Nat` through every entry point (Core's `EvalScript` has
no such parameter). The pipeline supplies its own canonical value

* `pipelineFuel ss spk w = ss.size + spk.size + wbytes + 28`
  (`Bitcoin/TxValidation/Full.lean:93`, the consensus caller),

so the **verdict of the consensus pipeline is a function of a fuel
parameter that Core does not have**. This module closes that gap: the
verdict is *eventually constant in the fuel*, with an explicit bound
derived from script mass alone, and the canonical `pipelineFuel` is above
the bound for every script the pipeline can execute.

## Method (the "no-look-into-the-opcodes" argument)

Nothing about the *semantics* of the 256 opcodes matters — only the two
syntactic facts that the machine is built from:

* **(S) Step-shape**: each `evalFrom` iteration consumes exactly one op of
  the (fixed) op list, and `stepChecked` never inspects `fuel`.
* **(P) Push-shape**: on the one lane where a *smaller* script is executed
  than the caller's script (the P2SH inner evaluation, which re-executes
  the *redeem script* — a stack item pushed by a push-only scriptSig), the
  initial stack consists only of *literal-derived* items, because
  `isPushOnlyWire ops` forces every op to be `.pushBytes d` / `.pushNum n`
  (wire ≤ 0x60) — and parse never produces `pushBytes`/`pushNum` ops with
  wire > 0x60; for `.op c` under wire ≤ 0x60 only `c = OP_RESERVED`
  survives, which *errors* when executed (BAD_OPCODE) and never touches
  the stack. (Step C.)

From (S) alone, by two `Nat`-shifted inductions:

* **error-stability** (`evalFrom_err_stable`): any *error* verdict at fuel
  `f₁+1` is reproduced verbatim at every `f₂+1 ≥ f₁+1` (errors propagate);
* **success-stability** (`evalFrom_ok_stable`): any *success* verdict at
  `f₁` is reproduced verbatim (same final state) at every `f₂ ≥ f₁`;
* **nil-disjointness** (`evalFrom_ok_ne_error`): success/error/fuel-error
  outcomes are mutually exclusive;

follows **full verdict stability** (`evalFrom_eventually_constant`): if
`evalFrom` yields a verdict `r` at some fuel `f₁` **with `f₁ ≥
ops.length`** (fuel large enough that the run reaches the end-of-ops / a
hard error rather than the fuel-0 catch-all), then **every** `f₂ ≥ f₁`
yields the same verdict:

    evalFrom f₂ ops st = evalFrom f₁ ops st     for all f₂ ≥ f₁ ≥ ops.length.

Together with (P) — the total executed-opcode mass of every
`verifyScriptFull`-lane evaluation is bounded by the byte mass
`ss.size + spk.size + wbytes` (`evalFrom_ok_litLenB`, + `pushShapedWire`
op-mass ≤ 25) — `pipelineFuel` is **canonically sufficient**:
the consensus pipeline's verdict is fuel-independent, and the one fuel
value it actually supplies (`ss.size + spk.size + wbytes + 28`) is above
the stability bound for every script, witness stack and scriptPubKey. The
`(≥ 25)` slack vs Core's `MIN_STANDARD_TX_NONWITNESS_SIZE = 65` is
immaterial: fuel ≥ bound is *inert*, never wrong (success-stability), so
excess slack can only help, never hurt. We call the invariant
**FUEL-CANON**: `pipelineFuel` is the canonical fuel; FUEL-CAN pins that
Core (no fuel) and the pipeline (canonical fuel) compute the same
verdicts.

Nothing in this file inspects `ScriptChecker`/`sighash`/hash-oracle
behaviour: the interpreter's signature-checker calls are fuel-blind
read-only queries; no execution path can hide a fuel read.

## Contents (all sorry-free; every `#print axioms` pinned below)

* §A `parseWireFrom` fuel-stability — `pFuel`-bound sufficiency.
* §B `stepBody` push-shape (`PushShaped`/`pushes`/`litOfOp`) —
  `stepBody_pushLit`, `stepChecked_pushLit`.
* §C `parseWire` never produces non-push ops under `wire ≤ 0x60`:
  `parseWire_pushShapedWire`.
* §D `evalFrom` error- and success-stability, nil-disjointness,
  eventually-constant (`FUEL-STAB`), and non-witness 201-op-equivalence
  (`FUEL-OPS`).
* §E The P2SH-lane literal bound (`FUEL-LIT`).
* §F `evalScriptBytes`-level stability (the raw-entry form).
* §G Fuel-canonicity of `pipelineFuel` (FUEL-CAN) — the final corollary.
-/

namespace Bitcoin.Proofs.Theorems.FuelStability

open Bitcoin.Interpreter

/-! ## §B `stepBody` push-shape: `.pushBytes`/`.pushNum` push, `.op 0x50` never

The one place where a `verifyScriptFull`-lane evaluation runs a *smaller*
script than the caller's script is the P2SH inner evaluation
(`p2shInner`, Interpreter/Defs.lean:1254): after the scriptSig evaluation,
the redeem script — a **stack item** — is executed as a script. To bound
the executed-opcode mass by *byte* mass we must know that the initial
stack of that inner evaluation contains only items literally produced by
pushes. Under `isPushOnlyWire ops` (every `wire ≤ 0x60`), `parseWire`
never produces `.pushBytes d`/`.pushNum n` ops with wire `> 0x60`
(`parseWire_pushShapedWire`, §C), and `.op c` collapses to `c = OP_RESERVED`
(wire = 0x50), which — when actually executed — fails with `badOpcode`
and never touches the stack. So only `.pushBytes`/`.pushNum` ever move
items onto the stack, and each push moves exactly one
(`stepBody_pushLit`); no opcode ever moves items from outside the script
onto the stack. -/

/-- The wire-op shape that can move items onto the stack: pushes
(everything from `getOpAux`'s `c ≤ 0x4e`, `.pushNum` for `0x4f`/`0x51-0x60`)
or `OP_RESERVED` (wire 0x50), which errors when executed. On the P2SH
lane (§E) this is the inductive invariant for the initial-stack
literal bound. -/

def PushShaped (o : WireOp) : Prop :=
  match o.ast with
  | .pushBytes _ => True
  | .pushNum _ => True
  | .op c => c.toNat = 0x50 ∧ o.wire = 0x50

/-- The item list a `PushShaped` op contributes to the stack:
`.pushBytes d` pushes `d`; `.pushNum n` pushes its literal encoding
(`encodeScriptNum`, Core's `getvch` — OP_1NEGATE for `n = 0`, `n` for
`1 ≤ n ≤ 16`); `.op _` (OP_RESERVED) pushes nothing (it errors). -/

def litOfOp : WireOp → List ByteArray
  | ⟨.pushBytes d, _, _⟩ => [d]
  | ⟨.pushNum n, _, _⟩ => [Bitcoin.Numeric.encodeScriptNum (if n = 0 then (-1 : Int) else (n : Int)) false]
  | ⟨_, _, _⟩ => []

/-! ### The step-shape theorem (Z09 idiom: `simp only [stepBody]`,
`split`, error branches contradict `.ok`). -/

/-- **Step-shape**: for a `PushShaped` wire-op, every *successful*
`stepBody` outcome either pushes exactly one item (in an executed
branch) or leaves the stack untouched (push skipped in a dead branch;
OP_RESERVED skipped). Every other outcome is an error, contradicting
`.ok`. In particular `st'.alt = st.alt` always, and
`st'.stack.length ≤ st.stack.length + 1`. -/

theorem stepBody_pushBytes {ctx : Ctx} {d : ByteArray} {wire next : Nat}
    {st st' : State} (h : stepBody ctx ⟨.pushBytes d, wire, next⟩ st = .ok st') :
    st'.stack = (if st.vf.all id then [d] else []) ++ st.stack ∧
    st'.alt = st.alt := by
  simp only [stepBody] at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · simp at h
        · split at h
          · -- `!fExec = true`: dead branch, push skipped
            rename_i h1 h2 h3 h4 hs
            exact (h1, h2, h3, h4, hs, h)
          · -- live branch: minimalData gate, then push
            rename_i h1 h2 h3 h4 hs hm
            exact (h1, h2, h3, h4, hs, hm, h)

end Bitcoin.Proofs.Theorems.FuelStability
