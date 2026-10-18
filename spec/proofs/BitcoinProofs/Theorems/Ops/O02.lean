import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.Ops.O02 — per-opcode semantics: the flow group

O02. Sorry-free per-opcode semantics theorems over
interpreter tier (`Bitcoin.Interpreter.Defs`, `stepBody.dispatchOp`)
for the flow group:

* OP_NOP 0x61, OP_NOP1 0xb0, OP_NOP4..OP_NOP10 0xb3-0xb9
* OP_IF 0x63 / OP_NOTIF 0x64 / OP_ELSE 0x67 / OP_ENDIF 0x68
* OP_VERIFY 0x69, OP_RETURN 0x6a
* OP_VERIF 0x65 / OP_VERNOTIF 0x66 (flow-window residents, dark corner)

Ground truth: interpreter.cpp @ cce32b168 (`EvalScript` switch cases
:529-530 NOP, :605-611 NOP1/4-10, :613-645 IF/NOTIF, :647-653 ELSE,
:655-661 ENDIF, :663-675 VERIFY, :677-681 RETURN, default :1227-1228
BAD_OPCODE) + research/06-script-interpreter.md SCR rows (0x61 :141,
0x63/0x64 :143-144, 0x65 :147, 0x67 :148, 0x68 :149, 0x69 :149,
0x6a :150, 0xb0..0xb9 :220-223). The dispatch level below is reached
exactly when Core's switch runs: `fExec ∨ 0x63 ≤ w ≤ 0x68`
(interpreter.cpp:493 / Defs.lean:794). The gates above it (element
size, opcode budget, disabled table, CODESEPARATOR) are stepBody-level
and pinned by `opReturn_unexecuted_budgetBurns` /
`opNop_unexecuted_budgetBurns`.

Every concrete `*_verdict` example is cross-checked by
a python reference, which transcribes the C++ path literally
(including CastToBool interpreter.cpp:437-444) and prints the same
verdict.

| # | theorem | row | statement (short) | axioms |
|---|---------|-----|-------------------|--------|
| 1 | `opNop_effect` | :141/:529-530 | 0x61: identity on the whole state | (pinned) |
| 2 | `opNopClass_effect` | SCR-071 | 0xb0,0xb3-0xb9: ok st iff ¬DISCOURAGE_UPGRADABLE_NOPS | (pinned) |
| 3 | `opIfNotif_unexecuted` | SCR-060 (dark) | dead IF/NOTIF: vf := false :: vf, stack untouched | (pinned) |
| 4 | `opIfNotif_underflow` | SCR-056 | executed, empty stack → INVALID_STACK_OPERATION | (pinned) |
| 5 | `opIf_effect` | SCR-056 | executed IF: vf := CastToBool top, pop | (pinned) |
| 6 | `opNotif_effect` | SCR-056 | executed NOTIF: vf := ¬CastToBool top, pop | (pinned) |
| 7 | `opIfNotif_minimalIf_tapscript` / `_witnessV0` | SCR-058/059 | bad operand → TAPSCRIPT_MINIMALIF (consensus) / MINIMALIF (policy-gated) | (pinned) |
| 8 | `opElse_empty` / `opElse_toggle` | SCR-061/064 | UNBALANCED / vf-top toggle (any fExec) | (pinned) |
| 9 | `opEndif_empty` / `opEndif_pop` | SCR-062/064 | UNBALANCED / vf pop (any fExec) | (pinned) |
| 10 | `opVerify_underflow` / `_success` / `_false` | SCR-068 | empty→underflow; truthy→pop; falsy→VERIFY | (pinned) |
| 11 | `opReturn_always` | SCR-069 | dispatched RETURN → OP_RETURN error, any fExec | (pinned) |
| 12 | `opReturn_unexecuted_budgetBurns` / `opNop_unexecuted_budgetBurns` | SCR-022 (dark) | dead 0x61/0x6a skipped yet burn one budget unit (BASE) | (pinned) |
| 13 | `opVerifNotif_badOpcode_even_unexecuted` | SCR-065 (dark) | 0x65/0x66: BAD_OPCODE even in dead branches | (pinned) |
| 14 | 20 `*_verdict` examples | — | python3-cross-checked concrete verdicts | (none) |

VERIFIED vs PROPOSED: everything here is VERIFIED against the pinned
C++ (line numbers above) and the python3 mirror; no PROPOSED rows.
No divergence from Core found in this group (no F-O02-* rows).
-/

namespace BitcoinProofs.Theorems.Ops.O02

open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Data Bitcoin.Activation

/-! ## Fixtures (policy/base context, wire-op witnesses, empty state) -/

/-- A context with caller-chosen sig version and policy flags; the
checker is the stub (this opcode group never reaches the checker). -/
def octx (sv : Bitcoin.Crypto.Seam.SigVersion) (pol : PolicyFlags) : Ctx :=
  ⟨{ p2sh := false, dersig := false, cltv := false, csv := false,
     nullDummy := false, witness := false, taproot := false }, pol,
   default, sv, ByteArray.empty, default⟩

/-- `Except` has no core DecidableEq; derive one for the verdict type so
the cross-checked examples can be `decide`-closed (axiom-free). -/
local instance : DecidableEq (Except ExecError State) := fun a b => by
  match a, b with
  | .ok x, .ok y =>
      exact dite (x = y) (fun h => .isTrue (by rw [h]))
        (fun h => .isFalse (fun hh => h (Except.ok.inj hh)))
  | .error x, .error y =>
      exact dite (x = y) (fun h => .isTrue (by rw [h]))
        (fun h => .isFalse (fun hh => h (Except.error.inj hh)))
  | .ok _, .error _ => exact .isFalse (fun hh => by cases hh)
  | .error _, .ok _ => exact .isFalse (fun hh => by cases hh)

/-- Wire-op witness: `dispatchOp` keys everything on the wire byte, so
the AST/next fields are inert for this group. -/
def opw (n : Nat) : WireOp := ⟨.op ⟨n % 256, by omega⟩, n, 1⟩

/-- Literal OP_RETURN wire op (`.op` AST: no push-size gate). -/
def retOp : WireOp := ⟨.op ⟨0x6a, by decide⟩, 0x6a, 1⟩

/-- Literal OP_NOP wire op. -/
def nopOp : WireOp := ⟨.op ⟨0x61, by decide⟩, 0x61, 1⟩

/-- The empty machine state. -/
def st0 : State := ⟨[], [], [], 0, 0, none⟩

/-- Nonempty-lists have positive length (feeds the underflow guards). -/
theorem len_pos {l : List ByteArray} (h : l ≠ []) : 0 < l.length := by
  cases l with
  | nil => exact absurd rfl h
  | cons _ _ => simp

/-! ## OP_NOP (0x61) — interpreter.cpp:529-530, SCR-141 -/

/-- OP_NOP is a total identity transition: no stack effect, no
altstack/cond-stack effect, no failure mode (the empty `break`). -/
theorem opNop_effect (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0x61 fExec st = .ok st := by
  simp [stepBody.dispatchOp]

/-- Dark corner (SCR-022): even an unexecuted OP_NOP burns one unit of
the 201-opcode budget under BASE (0x61 > OP_16; the increment precedes
the fExec check, interpreter.cpp:459-464) — and is then skipped
(:493: 0x61 is outside [OP_IF..OP_ENDIF]). -/
theorem opNop_unexecuted_budgetBurns (ctx : Ctx) (st : State)
    (hsv : ctx.sv = .base) (hvf : ∃ rest, st.vf = false :: rest)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx nopOp st = .ok { st with opCount := st.opCount + 1 } := by
  obtain ⟨rest, hvf⟩ := hvf
  have hf : st.vf.all id = false := by simp [hvf]
  have hd : disabledWire 0x61 = false := by decide
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [this] at hbud ⊢; omega
  simp [stepBody, nopOp, hsv, hf, hd, hb]

/-! ## OP_NOP1 / OP_NOP4..OP_NOP10 (0xb0, 0xb3-0xb9) — :605-611 -/

/-- The upgradable-NOP class: no-op, unless policy
DISCOURAGE_UPGRADABLE_NOPS fails it (SCR-220/223). -/
theorem opNopClass_effect (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (w : Nat) (hw : w = 0xb0 ∨ w = 0xb3 ∨ w = 0xb4 ∨ w = 0xb5 ∨ w = 0xb6 ∨
          w = 0xb7 ∨ w = 0xb8 ∨ w = 0xb9) :
    stepBody.dispatchOp ctx op w fExec st =
      (if ctx.pol.discourageUpgradableNops then
         .error .discourageUpgradableNops else .ok st) := by
  rcases hw with rfl|rfl|rfl|rfl|rfl|rfl|rfl|rfl <;>
    simp [stepBody.dispatchOp]

/-! ## OP_IF / OP_NOTIF (0x63 / 0x64) — :613-645 -/

/-- Dark corner (SCR-143): a dead IF/NOTIF still pushes `false` on the
condition stack but pops NOTHING off the data stack
(interpreter.cpp:617-643: `fValue` stays `false`, `popstack` is inside
`if (fExec)`). -/
theorem opIfNotif_unexecuted (ctx : Ctx) (op : WireOp) (st : State)
    (w : Nat) (hw : w = 0x63 ∨ w = 0x64) :
    stepBody.dispatchOp ctx op w false st =
      .ok { st with vf := false :: st.vf } := by
  rcases hw with rfl|rfl <;> simp [stepBody.dispatchOp]

/-- Executed IF/NOTIF with an empty data stack →
INVALID_STACK_OPERATION (interpreter.cpp:620-621). -/
theorem opIfNotif_underflow (ctx : Ctx) (op : WireOp) (st : State)
    (w : Nat) (hw : w = 0x63 ∨ w = 0x64) (hnil : st.stack = []) :
    stepBody.dispatchOp ctx op w true st = .error .stackUnderflow := by
  rcases hw with rfl|rfl <;> simp [stepBody.dispatchOp, hnil]

/-- Executed OP_IF stack effect: pop the operand, push its CastToBool
on the condition stack (pre: nonempty stack, no MINIMALIF family
trip). Minimal-data boundaries are orthogonal: CastToBool sees the raw
bytes (interpreter.cpp:639-643). -/
theorem opIf_effect (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (hts : ctx.sv ≠ .tapscript)
    (hmv : ctx.sv ≠ .witnessV0 ∨ ctx.pol.minimalIf = false) :
    stepBody.dispatchOp ctx op 0x63 true st =
      .ok { st with vf := castToBool (topAt st.stack 1) :: st.vf,
                    stack := st.stack.tail } := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp only [stepBody.dispatchOp, hts, hlen]
  rcases hmv with hmv | hmv
  · simp [hmv]
  · simp [hmv]

/-- Executed OP_NOTIF: as OP_IF with the pushed condition inverted
(:640-641 `if (opcode == OP_NOTIF) fValue = !fValue;`). -/
theorem opNotif_effect (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (hts : ctx.sv ≠ .tapscript)
    (hmv : ctx.sv ≠ .witnessV0 ∨ ctx.pol.minimalIf = false) :
    stepBody.dispatchOp ctx op 0x64 true st =
      .ok { st with vf := (!(castToBool (topAt st.stack 1))) :: st.vf,
                    stack := st.stack.tail } := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp only [stepBody.dispatchOp, hts, hlen]
  rcases hmv with hmv | hmv
  · simp [hmv]
  · simp [hmv]

/-- Exact MINIMALIF-family precondition (SCR-143/144): a bad operand
(`∅`/`0x01` are the only legal shapes) fails TAPSCRIPT_MINIMALIF under
tapscript (consensus, BIP342) — interpreter.cpp:624-630. -/
theorem opIfNotif_minimalIf_tapscript (ctx : Ctx) (op : WireOp) (st : State)
    (w : Nat) (hw : w = 0x63 ∨ w = 0x64) (hts : ctx.sv = .tapscript)
    (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op w true st = .error .tapscriptMinimalIf := by
  rcases hw with rfl|rfl
  · have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
    simp [stepBody.dispatchOp, hts, hlen, hbad]
  · have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
    simp [stepBody.dispatchOp, hts, hlen, hbad]

/-- Same shape check under WITNESS_V0 is policy-gated (BIP141's
MINIMALIF): only with the flag on does the bad operand fail
(interpreter.cpp:632-637). -/
theorem opIfNotif_minimalIf_witnessV0 (ctx : Ctx) (op : WireOp) (st : State)
    (w : Nat) (hw : w = 0x63 ∨ w = 0x64) (hwv : ctx.sv = .witnessV0)
    (hpol : ctx.pol.minimalIf = true) (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op w true st = .error .minimalIf := by
  rcases hw with rfl|rfl
  · have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
    simp [stepBody.dispatchOp, hwv, hpol, hlen, hbad]
  · have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
    simp [stepBody.dispatchOp, hwv, hpol, hlen, hbad]

/-- BIP342 boundary: with a legal operand (`∅` or `0x01` — stated as
the exact negation of the failure precondition) tapscript IF/NOTIF
succeeds with the CastToBool (NOTIF-inverted) condition. -/
theorem opIfNotif_tapscript_ok (op : WireOp) (st : State)
    (w : Nat) (hw : w = 0x63 ∨ w = 0x64) (hne : st.stack ≠ [])
    (hok : ¬(1 < (topAt st.stack 1).size ∨
             ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1))) :
    stepBody.dispatchOp (octx .tapscript {}) op w true st =
      .ok { st with vf := (if w = 0x64 then (!(castToBool (topAt st.stack 1)))
                           else castToBool (topAt st.stack 1)) :: st.vf,
                    stack := st.stack.tail } := by
  rcases hw with rfl|rfl
  · have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
    simp [stepBody.dispatchOp, hlen, hok]
  · have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
    simp [stepBody.dispatchOp, hlen, hok]

/-! ## OP_ELSE (0x67) / OP_ENDIF (0x68) — :647-653 / :655-661 -/

/-- OP_ELSE on an empty condition stack → UNBALANCED_CONDITIONAL.
Holds for ANY fExec: 0x67 is inside the [OP_IF..OP_ENDIF] window, so
Core runs the case in dead branches too (interpreter.cpp:493). -/
theorem opElse_empty (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0x67 fExec { st with vf := [] } =
      .error .unbalancedConditional := by
  simp [stepBody.dispatchOp]

/-- OP_ELSE effect on the condition stack: toggle the top
(`vfExec.toggle_top`, :652). Data stack and altstack untouched. -/
theorem opElse_toggle (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (v : Bool) (rest : List Bool) :
    stepBody.dispatchOp ctx op 0x67 fExec { st with vf := v :: rest } =
      .ok { st with vf := (!v) :: rest } := by
  simp [stepBody.dispatchOp]

/-- OP_ENDIF on an empty condition stack → UNBALANCED_CONDITIONAL
(:657-658). -/
theorem opEndif_empty (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0x68 fExec { st with vf := [] } =
      .error .unbalancedConditional := by
  simp [stepBody.dispatchOp]

/-- OP_ENDIF effect on the condition stack: pop the innermost
condition (:660). A bare ENDIF hits the same UNBALANCED_CONDITIONAL
as a bare ELSE (SCR-149). -/
theorem opEndif_pop (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (v : Bool) (rest : List Bool) :
    stepBody.dispatchOp ctx op 0x68 fExec { st with vf := v :: rest } =
      .ok { st with vf := rest } := by
  simp [stepBody.dispatchOp]

/-! ## OP_VERIFY (0x69) — :663-675 -/

/-- OP_VERIFY on an empty data stack → INVALID_STACK_OPERATION
(:667-668). -/
theorem opVerify_underflow (ctx : Ctx) (op : WireOp) (st : State)
    (hnil : st.stack = []) :
    stepBody.dispatchOp ctx op 0x69 true st = .error .stackUnderflow := by
  simp [stepBody.dispatchOp, hnil]

/-- OP_VERIFY success shape: truthy top is popped, nothing pushed
((true -- ), :670-671). -/
theorem opVerify_success (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (htruthy : castToBool (topAt st.stack 1) = true) :
    stepBody.dispatchOp ctx op 0x69 true st =
      .ok { st with stack := st.stack.tail } := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody.dispatchOp, hlen, htruthy]

/-- OP_VERIFY failure mode: falsy top (including the ∅ and [0x80]
negative-zero minimal-data boundaries of CastToBool, SCR-057) leaves
the stack unchanged and fails VERIFY (:672-673). -/
theorem opVerify_false (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (hfalsy : castToBool (topAt st.stack 1) = false) :
    stepBody.dispatchOp ctx op 0x69 true st = .error .verifyFailed := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody.dispatchOp, hlen, hfalsy]

/-! ## OP_RETURN (0x6a) — :677-681 -/

/-- Dispatched OP_RETURN always fails with SCRIPT_ERR_OP_RETURN,
regardless of stack, flags, or condition stack (:677-681). -/
theorem opReturn_always (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0x6a fExec st = .error .opReturn := by
  simp [stepBody.dispatchOp]

/-- Dark corner pair (SCR-150 + SCR-022): at the stepBody level an
unexecuted OP_RETURN is SKIPPED (0x6a is outside [OP_IF..OP_ENDIF],
interpreter.cpp:493) — yet it still burns one opcode-budget unit under
BASE, exactly like the executed path (:459-464). -/
theorem opReturn_unexecuted_budgetBurns (ctx : Ctx) (st : State)
    (hsv : ctx.sv = .base) (hvf : ∃ rest, st.vf = false :: rest)
    (hbud : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx retOp st = .ok { st with opCount := st.opCount + 1 } := by
  obtain ⟨rest, hvf⟩ := hvf
  have hf : st.vf.all id = false := by simp [hvf]
  have hd : disabledWire 0x6a = false := by decide
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have : MAX_OPS_PER_SCRIPT = 201 := rfl
    simp only [this] at hbud ⊢; omega
  simp [stepBody, retOp, hsv, hf, hd, hb]

/-! ## OP_VERIF / OP_VERNOTIF (0x65 / 0x66) — default case :1227-1228 -/

/-- Dark corner (SCR-147, classic footgun): OP_VERIF/OP_VERNOTIF have
NO switch case, so they hit `default:` → BAD_OPCODE — and because
0x65/0x66 lie inside [OP_IF..OP_ENDIF], this fires EVEN IN DEAD
BRANCHES (interpreter.cpp:493-505, SCR-065). -/
theorem opVerifNotif_badOpcode_even_unexecuted (ctx : Ctx) (op : WireOp)
    (st : State) (fExec : Bool) (w : Nat) (hw : w = 0x65 ∨ w = 0x66) :
    stepBody.dispatchOp ctx op w fExec st = .error .badOpcode := by
  rcases hw with rfl|rfl <;> simp [stepBody.dispatchOp]

/-! ## Python3-cross-checked concrete verdicts

Each `decide`-checked verdict below is printed verbatim by the python3
transcription of the C++ path. -/

-- OP_NOP executed: [ok stack=[[2], [1]] vf=[]]
example : stepBody.dispatchOp (octx .base {}) (opw 0x61) 0x61 true
    { st0 with stack := [vchTrue, ByteArray.empty.push 2] } =
    .ok { st0 with stack := [vchTrue, ByteArray.empty.push 2] } := by decide

-- OP_NOP10 discouraged: [error DISCOURAGE_UPGRADABLE_NOPS]
example : stepBody.dispatchOp (octx .base { discourageUpgradableNops := true })
    (opw 0xb9) 0xb9 true st0 = .error .discourageUpgradableNops := by decide

-- OP_IF executed [01, x]: [ok stack=[[2]] vf=[True]]
example : stepBody.dispatchOp (octx .base {}) (opw 0x63) 0x63 true
    { st0 with stack := [vchTrue, ByteArray.empty.push 2] } =
    .ok { st0 with stack := [ByteArray.empty.push 2], vf := [true] } := by decide

-- OP_IF executed []: [error INVALID_STACK_OPERATION]
example : stepBody.dispatchOp (octx .base {}) (opw 0x63) 0x63 true st0 =
    .error .stackUnderflow := by decide

-- OP_IF unexecuted: [ok stack=[[1], [2]] vf=[False]] — nothing popped
example : stepBody.dispatchOp (octx .base {}) (opw 0x63) 0x63 false
    { st0 with stack := [vchTrue, ByteArray.empty.push 2] } =
    .ok { st0 with stack := [vchTrue, ByteArray.empty.push 2], vf := [false] } := by decide

-- OP_NOTIF executed [00]: [ok stack=[] vf=[True]]
example : stepBody.dispatchOp (octx .base {}) (opw 0x64) 0x64 true
    { st0 with stack := [vchFalse] } = .ok { st0 with vf := [true] } := by decide

-- OP_NOTIF executed [80] (negative zero): [ok vf=[True]] — CastToBool([80])=false
example : stepBody.dispatchOp (octx .base {}) (opw 0x64) 0x64 true
    { st0 with stack := [ByteArray.empty.push 0x80] } =
    .ok { st0 with vf := [true] } := by decide

-- OP_IF witnessV0+MINIMALIF [02]: [error MINIMALIF]
example : stepBody.dispatchOp
    (octx .witnessV0 { minimalIf := true }) (opw 0x63) 0x63 true
    { st0 with stack := [ByteArray.empty.push 2] } = .error .minimalIf := by decide

-- OP_IF tapscript [02]: [error TAPSCRIPT_MINIMALIF] (consensus shape check)
example : stepBody.dispatchOp (octx .tapscript {}) (opw 0x63) 0x63 true
    { st0 with stack := [ByteArray.empty.push 2] } =
    .error .tapscriptMinimalIf := by decide

-- OP_ELSE [True]: [ok vf=[False]]
example : stepBody.dispatchOp (octx .base {}) (opw 0x67) 0x67 true
    { st0 with vf := [true] } = .ok { st0 with vf := [false] } := by decide

-- OP_ELSE empty cond-stack: [error UNBALANCED_CONDITIONAL]
example : stepBody.dispatchOp (octx .base {}) (opw 0x67) 0x67 true st0 =
    .error .unbalancedConditional := by decide

-- OP_ENDIF [True, False]: [ok vf=[False]]
example : stepBody.dispatchOp (octx .base {}) (opw 0x68) 0x68 true
    { st0 with vf := [true, false] } = .ok { st0 with vf := [false] } := by decide

-- OP_ENDIF empty cond-stack: [error UNBALANCED_CONDITIONAL]
example : stepBody.dispatchOp (octx .base {}) (opw 0x68) 0x68 true st0 =
    .error .unbalancedConditional := by decide

-- OP_VERIFY [01, x]: [ok stack=[[1]]]
example : stepBody.dispatchOp (octx .base {}) (opw 0x69) 0x69 true
    { st0 with stack := [vchTrue, vchTrue] } =
    .ok { st0 with stack := [vchTrue] } := by decide

-- OP_VERIFY [00]: [error VERIFY]
example : stepBody.dispatchOp (octx .base {}) (opw 0x69) 0x69 true
    { st0 with stack := [vchFalse] } = .error .verifyFailed := by decide

-- OP_VERIFY [80] (negative zero): [error VERIFY]
example : stepBody.dispatchOp (octx .base {}) (opw 0x69) 0x69 true
    { st0 with stack := [ByteArray.empty.push 0x80] } =
    .error .verifyFailed := by decide

-- OP_VERIFY []: [error INVALID_STACK_OPERATION]
example : stepBody.dispatchOp (octx .base {}) (opw 0x69) 0x69 true st0 =
    .error .stackUnderflow := by decide

-- OP_RETURN executed: [error OP_RETURN]
example : stepBody.dispatchOp (octx .base {}) (opw 0x6a) 0x6a true
    { st0 with stack := [vchTrue] } = .error .opReturn := by decide

-- OP_RETURN unexecuted: [ok (skipped) stack=[[1]] vf=[]] — 0x6a misses the
-- [OP_IF..OP_ENDIF] window so the switch never runs (stepBody-level skip),
-- yet the BASE opcode budget still burns (SCR-022): opCount 0 -> 1.
example : stepBody (octx .base {}) retOp
    { st0 with stack := [vchTrue], vf := [false] } =
    .ok { st0 with stack := [vchTrue], vf := [false], opCount := 1 } := by decide

-- OP_VERIF unexecuted: [error BAD_OPCODE] — window hit, dead-branch footgun
example : stepBody.dispatchOp (octx .base {}) (opw 0x65) 0x65 false
    { st0 with stack := [vchTrue] } = .error .badOpcode := by decide

-- OP_VERNOTIF executed: [error BAD_OPCODE]
example : stepBody.dispatchOp (octx .base {}) (opw 0x66) 0x66 true
    { st0 with stack := [vchTrue] } = .error .badOpcode := by decide

/-! ## Axiom pins (#guard_msgs-checked: footprints within the sanctioned trio, no sorryAx) -/

/-- info: 'BitcoinProofs.Theorems.Ops.O02.opNop_effect' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opNop_effect
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opNopClass_effect' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opNopClass_effect
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opIfNotif_unexecuted' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opIfNotif_unexecuted
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opIfNotif_underflow' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opIfNotif_underflow
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opIf_effect' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opIf_effect
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opNotif_effect' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opNotif_effect
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opIfNotif_minimalIf_tapscript' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opIfNotif_minimalIf_tapscript
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opIfNotif_minimalIf_witnessV0' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opIfNotif_minimalIf_witnessV0
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opIfNotif_tapscript_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opIfNotif_tapscript_ok
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opElse_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opElse_empty
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opElse_toggle' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opElse_toggle
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opEndif_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opEndif_empty
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opEndif_pop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opEndif_pop
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opVerify_underflow' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opVerify_underflow
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opVerify_success' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opVerify_success
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opVerify_false' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opVerify_false
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opReturn_always' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opReturn_always
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opReturn_unexecuted_budgetBurns' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opReturn_unexecuted_budgetBurns
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opNop_unexecuted_budgetBurns' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opNop_unexecuted_budgetBurns
/-- info: 'BitcoinProofs.Theorems.Ops.O02.opVerifNotif_badOpcode_even_unexecuted' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms opVerifNotif_badOpcode_even_unexecuted

end BitcoinProofs.Theorems.Ops.O02
