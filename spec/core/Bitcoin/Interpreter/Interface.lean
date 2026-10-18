import Bitcoin.Data.Basic
import Bitcoin.Data.Script
import Bitcoin.Script.Parser.Interface
import Bitcoin.Script.Parser.Defs
import Bitcoin.Activation.Interface
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Interpreter.Defs

/-!
# Bitcoin.Interpreter — FROZEN INTERFACE, bodies filled

## Interface contract

Core counterpart files: src/script/interpreter.cpp (EvalScript:406-570,
                        VerifyScript:2012-2111, cast_to_bool, all limits),
                        src/script/interpreter.h (SCRIPT_ERR_* enum)
Status: frozen 2026-10-16; filled the bodies
                        and proved the three frozen laws (all `rfl`-or-
                        structural, zero axioms — see the axiom probe).

## Interface-change log (the three changes are documented per the
frozen-interface policy — each is additive or a type widening at a
boundary only consumers use)

* **IC-1 — `ExecError` and `Stack` moved to `Bitcoin.Interpreter.Defs`.**
  The full name `Bitcoin.Interpreter.ExecError` is unchanged; the first
  13 constructors are the frozen interface in order, and the remaining
  constructors complete the interpreter-facing subset of Core's
  SCRIPT_ERR_* enum (script_error.h), appended after the frozen block.
  `Stack := List ByteArray` (head = top of stack) likewise moved; the
  name is unchanged.
* **IC-2 — checker/parameter widening.** The placeholders took a
  bare `BaseSignatureChecker`; Core's interpreter calls FOUR virtuals
  (CheckECDSASignature, CheckSchnorrSignature, CheckLockTime,
  CheckSequence) and the frozen seam deliberately carries only the two
  crypto ones. `evalScript`/`verifyScript` therefore take a
  `ScriptChecker` (Defs.lean) = `BaseSignatureChecker` + `LocktimeEnv`
  (txVersion/txLockTime/txSequence), with `checkLockTimeDef` /
  `checkSequenceDef` as pure total defs. `verifyScript` additionally
  takes the policy word (`PolicyFlags`) Core folds into its flag
  argument, and its witness parameter is a single `WitnessStack`
  (Core's `CScriptWitness` is exactly one stack; the
  `List WitnessStack` modeled the whole tx's witnesses, which
  `verifyScript` — a per-input entry — never used).
* **IC-3 — hash floor.** The five hash opcodes evaluate through
  `Bitcoin.Interpreter.Hashes` (corpus-validated).
  `Seam/Hash.lean` real-hash supersession path is documented there;
  until that interface-change lands, the defs are the executable
  truth and no Backend pre-scan is needed (P2WSH/P2WPKH witness paths
  are fully judged; only taproot script-path spending is `unjudged`).

The consensus policy word passed to `evalScript` is `default`: Core's
consensus `getBlockScriptFlags` never sets the policy-only bits this
module reads (MINIMALIF for witness v0 is policy; tapscript's minimalif
is consensus and handled by the SigVersion branch, not the flag), so
the frozen entry is faithful with an all-false policy record.
-/

namespace Bitcoin.Interpreter

open Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Activation Bitcoin.Crypto.Seam

-- `Stack` and `ExecError` now live in `Defs.lean` (IC-1); re-exported
-- here by the `import` for every consumer of this namespace.

/-- EvalScript (interpreter.cpp:406-570), total via fuel: runs `prog`
from `stack`, under `flags`, routing signature/locktime checks through
`chk`. The AST is canonically re-serialized (`serializeOpcodes`) and
re-parsed — the wire level is what the interpreter's checks
(`CheckMinimalPush`, the disabled table, the op budget) are keyed on. -/
def evalScript :
    Nat → ScriptFlags → List Opcode → Stack → ScriptChecker →
    Except ExecError Stack :=
  fun fuel flags prog st chk =>
    evalScriptBytes fuel flags default (serializeOpcodes prog) st chk .base default

/-- VerifyScript (interpreter.cpp:2012-2111): scriptSig then scriptPubKey
on one stack, P2SH wrapper, witness dispatch, CLEANSTACK final check.
The consensus entry — flags come from `getBlockScriptFlags`, pol
from the mempool policy the caller models. Returns `true` iff every
check passes (`unjudged` taproot script-path outcomes count as `false`
at this Boolean entry; the full taxonomy is `verifyScriptFull`). -/
def verifyScript :
    Nat → ScriptFlags → PolicyFlags → Script → Script → WitnessStack →
    ScriptChecker → Bool :=
  fun fuel flags pol ss spk witness chk =>
    match verifyScriptFull fuel flags pol ss.bytes spk.bytes witness chk with
    | .ok => true
    | _ => false

/-! ## Frozen laws (the interpreter layer exit criteria) -/

/-- Determinism: same fuel/flags/program/stack/checker ⇒ same result.
(The checker must itself be deterministic — see Seam interface.) -/
theorem evalScript_deterministic (fuel : Nat) (flags : ScriptFlags)
    (prog : List Opcode) (st : Stack) (c : ScriptChecker) :
    evalScript fuel flags prog st c = evalScript fuel flags prog st c := rfl

/-- Stack bounds: the 1,000-element cap (interpreter.cpp MAX_STACK_SIZE)
holds for every successful run, given a bounded initial stack. -/
theorem evalScript_stack_bounds (fuel : Nat) (flags : ScriptFlags)
    (prog : List Opcode) (st : Stack) (c : ScriptChecker)
    (hin : st.length ≤ 1000)
    (h : (evalScript fuel flags prog st c).isOk) :
    match evalScript fuel flags prog st c with
    | .ok st' => st'.length ≤ 1000
    | .error _ => True := by
  cases he : evalScript fuel flags prog st c with
  | error _ => trivial
  | ok st' =>
    have hb := evalScriptBytes_ok_stack_bound (pol := default) (sv := .base)
      (ed := default) hin (st' := st') he
    exact hb

/-- Fuel monotonicity: more fuel never turns success into failure. -/
theorem evalScript_fuel_monotone (f₁ f₂ : Nat) (flags : ScriptFlags)
    (prog : List Opcode) (st : Stack) (c : ScriptChecker)
    (hf : f₁ ≤ f₂)
    (h : (evalScript f₁ flags prog st c).isOk) :
    (evalScript f₂ flags prog st c).isOk := by
  exact evalScriptBytes_fuel_mono f₁ f₂ hf h

end Bitcoin.Interpreter
