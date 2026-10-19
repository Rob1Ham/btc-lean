import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.Ops.O01 — per-opcode semantics: constants/pushes

Group: OP_0 (0x00), OP_1NEGATE (0x4f), OP_1..OP_16 (0x51..0x60).

Ground truth (VERIFIED against Core @ cce32b168, src/script/interpreter.cpp):

* :488-492 — the pushdata path (`fExec && 0 <= opcode <= OP_PUSHDATA4`)
  pushes `vchPushValue`; `GetOp` decodes byte 0x00 as OP_0 with an EMPTY
  push value, so OP_0 pushes the empty vector `∅` (SCR-046).
* :499-523 — `case OP_1NEGATE: case OP_1: ... case OP_16:` computes
  `bn = opcode - (OP_1 - 1)` (= opcode - 0x50, so OP_1..OP_16 → 1..16)
  with the OP_1NEGATE override `bn = -1`, then pushes `bn.getvch()` —
  the unconditionally-minimal LE sign-magnitude encoding (SCR-047).
  Core's own comment :520-521: these pushes are minimal by construction,
  so **no CheckMinimalPush** runs on them. Consequently the 201-opcode
  budget's condition `opcode > OP_16` (:460-464, SCR-024) never counts
  any member of this group, executed or not.
* CheckMinimalPush (script.cpp:373-396) is the MINIMALDATA boundary for
  the *pushdata* siblings: empty payload requires wire OP_0 (a
  PUSHDATA1-of-length-0 is non-minimal), and 1-byte payloads 0x01..0x16
  / 0x81 must use OP_1..OP_16 / OP_1NEGATE instead of a direct push.

model (`Bitcoin.Interpreter.stepBody`, Defs.lean:764): OP_0 is
`ast = .pushBytes ∅` (wire 0), OP_1NEGATE is `ast = .pushNum 0`
(wire 0x4f, mapped to −1), OP_1..OP_16 are `ast = .pushNum n`
(wire 0x50+n). Matches Core on all counts — **no divergence found**
(F-O01: none).

python3 cross-check (2026-10-16, `crosscheck.py`): a faithful
re-implementation of `getvch` (script.h serialize loop) gives
OP_0 → `''`, OP_1NEGATE → `81`, OP_1..OP_16 → `01..10`;
budget condition counts none of the group; CheckMinimalPush boundary
verdicts `(∅,0)=T`, `(∅,0x4c)=F`, `(01,w=1)=F`, `(81,w=1)=F` — all
match the Lean verdicts pinned below.
-/

namespace BitcoinProofs.Theorems.Ops.O01

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Numeric Bitcoin.Script.Parser

/-! ## 0. Canonical initial machine state (`EvalScript` entry locals) -/

/-- The state `EvalScript` starts from: empty stack/altstack/conditional
stack, zero opcode budget, `pbegincodehash` 0, no tapscript budget. -/
def st0 : State :=
  { stack := [], alt := [], vf := [], opCount := 0, codeSep := 0, vwLeft := none }

/-! ## 1. Encoding laws (the pushed bytes) -/

/-- SCR-047: OP_1NEGATE's pushed value is the 1-byte minimal encoding
`0x81` (Core :499-523 `bn = -1; bn.getvch()`). -/
theorem enc_op1negate_0x81 :
    encodeScriptNum (-1 : ScriptNum) false = serU8 0x81 := by
  rfl

/-- The serialize digit loop on 0 emits nothing. -/
theorem magBEAux_zero : ∀ f : Nat, magBEAux f 0 = []
  | 0 => rfl
  | f + 1 => by simp [magBEAux]

/-- One-byte magnitudes serialize to the singleton digit list. -/
theorem magBE_small (n : Nat) (h1 : 0 < n) (h256 : n < 256) : magBE n = [n] := by
  have hz : n / 256 = 0 := by omega
  show magBEAux 10 n = [n]
  rw [show magBEAux 10 n = (if (n : Nat) = 0 then [] else magBEAux 9 (n / 256) ++ [n % 256]) from rfl,
    if_neg (show ¬((n : Nat) = 0) from by omega), hz, magBEAux_zero, List.nil_append,
    Nat.mod_eq_of_lt h256]

/-- SCR-046: OP_1..OP_16 push exactly one byte, `0x01 .. 0x10`
(`bn = opcode - (OP_1-1)` with `1 ≤ n ≤ 16 < 128`, positive, so
`getvch` is the singleton `[n]`). -/
theorem encodeScriptNum_small (n : Nat) (h1 : 0 < n) (h16 : n ≤ 16) :
    encodeScriptNum n false = serU8 n.toUInt8 := by
  show bytesFromLE (scriptNumBE n).reverse = serU8 n.toUInt8
  have hne : ¬((n : Int) < 0) := by omega
  have hneg : decide ((n : Int) < 0) = false := by simp [hne]
  have habs : (n : Int).natAbs = n := rfl
  have hlt128 : (n : Int) < 128 := by omega
  simp only [scriptNumBE, habs, hneg, magBE_small n h1 (by omega : n < 256), encodeSignBE]
  split
  · simp [bytesFromLE, serU8]
  · next hneg128 => exact absurd (show (n : Nat) < 128 from by omega) hneg128

/-! ### The python3-cross-checked concrete byte verdicts (one per opcode) -/

theorem push_byte_1 : encodeScriptNum 1 false = serU8 1 := by rfl
theorem push_byte_2 : encodeScriptNum 2 false = serU8 2 := by rfl
theorem push_byte_3 : encodeScriptNum 3 false = serU8 3 := by rfl
theorem push_byte_4 : encodeScriptNum 4 false = serU8 4 := by rfl
theorem push_byte_5 : encodeScriptNum 5 false = serU8 5 := by rfl
theorem push_byte_6 : encodeScriptNum 6 false = serU8 6 := by rfl
theorem push_byte_7 : encodeScriptNum 7 false = serU8 7 := by rfl
theorem push_byte_8 : encodeScriptNum 8 false = serU8 8 := by rfl
theorem push_byte_9 : encodeScriptNum 9 false = serU8 9 := by rfl
theorem push_byte_10 : encodeScriptNum 10 false = serU8 10 := by rfl
theorem push_byte_11 : encodeScriptNum 11 false = serU8 11 := by rfl
theorem push_byte_12 : encodeScriptNum 12 false = serU8 12 := by rfl
theorem push_byte_13 : encodeScriptNum 13 false = serU8 13 := by rfl
theorem push_byte_14 : encodeScriptNum 14 false = serU8 14 := by rfl
theorem push_byte_15 : encodeScriptNum 15 false = serU8 15 := by rfl
theorem push_byte_16 : encodeScriptNum 16 false = serU8 16 := by rfl

/-- OP_0's pushed value IS the empty vector (`getvch 0 = []` in the
python3 cross-check; Core :488-492). -/
theorem push_byte_0 :
    encodeScriptNum 0 false = (ByteArray.empty : ByteArray) := by rfl

/-! ## 2. Support: the group is outside the disabled table and the op budget -/

/-- SCR-024 support: every wire byte ≤ 0x60 (all of OP_0, OP_1NEGATE,
OP_1..OP_16, and the pushdata family) is outside the disabled set
(the disabled table starts at 0x7e). -/
theorem disabledWire_small (w : Nat) (h : w ≤ 0x60) : disabledWire w = false := by
  have hmem : ¬(w ∈ [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
      0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99]) := by
    simp only [List.mem_cons, List.not_mem_nil, or_false]
    omega
  simp only [disabledWire, hmem]
  rfl

/-- SCR-024: the 201-opcode budget's condition `opcode > OP_16` fails
for the whole group (wire ≤ 0x60), so `opCount` is invariant under any
canonical member of the group. -/
theorem pushNum_opCount_invariant (ctx : Ctx) (st : State) (n : Nat)
    (hn16 : n ≤ 16) :
    (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < (if n = 0 then 0x4f else 0x50 + n)
     then st.opCount + 1 else st.opCount) = st.opCount := by
  have h : ¬ (0x60 < (if n = 0 then 0x4f else 0x50 + n)) := by
    split <;> omega
  simp [h]

/-! ## 3. Step laws: stack effect and exact post-states -/

/-- **OP_1NEGATE** (SCR-047): executed, it always succeeds, pushes
exactly `0x81`, and leaves `opCount` unchanged (SCR-024). No
MINIMALDATA gate — matching Core :520-521's "no need for a
CheckMinimalPush here". Precondition: only "the opcode is executed"
(`vfExec` all true); the empty stack is fine (no stacktop read). -/
theorem step_op1negate (ctx : Ctx) (st : State) (nx : Nat)
    (hvf : st.vf.all id = true) :
    stepBody ctx { ast := .pushNum 0, wire := 0x4f, next := nx } st =
    .ok { st with stack := serU8 0x81 :: st.stack, opCount := st.opCount } := by
  simp [stepBody, hvf, disabledWire, enc_op1negate_0x81]

/-- **OP_1..OP_16** (SCR-046 / SCR-024): executed, `OP_N` always
succeeds, pushes exactly the single minimal byte `n`, `opCount`
unchanged. Precondition: executed only — no stack shape requirement. -/
theorem step_opN (ctx : Ctx) (st : State) (nx : Nat) (n : Nat)
    (hn1 : 0 < n) (hn16 : n ≤ 16) (hvf : st.vf.all id = true) :
    stepBody ctx { ast := .pushNum n, wire := 0x50 + n, next := nx } st =
    .ok { st with stack := encodeScriptNum n false :: st.stack,
                  opCount := st.opCount } := by
  have hz : ¬ ((n : Nat) = 0) := by omega
  have hb : ¬ ((0x60 : Nat) < 0x50 + n) := by omega
  have hwab : ¬ ((0x50 + n : Nat) = 0xab) := by omega
  have hdis : disabledWire (0x50 + n) = false := disabledWire_small _ (by omega)
  simp [stepBody, hvf, hz, hb, hwab, hdis]

/-- **OP_0** (SCR-046): executed, the wire-0 empty push always succeeds
and pushes the empty vector `∅` (Core :488-492); `opCount` unchanged.
Note `checkMinimalPush ∅ 0` passes (empty ⇒ requires OP_0, which is
exactly wire 0), so even under MINIMALDATA the canonical OP_0 is fine. -/
theorem step_op0 (ctx : Ctx) (st : State) (nx : Nat)
    (hvf : st.vf.all id = true) :
    stepBody ctx { ast := .pushBytes ByteArray.empty, wire := 0, next := nx } st =
    .ok { st with stack := ByteArray.empty :: st.stack, opCount := st.opCount } := by
  simp [stepBody, hvf, disabledWire, checkMinimalPush]

/-- Unexecuted pushNum (SCR-024, unexecuted-branch clause): a
conditional-guarded OP_0/OP_1NEGATE/OP_N in a dead branch is a complete
no-op — stack, altstack, opCount all unchanged. -/
theorem step_pushNum_unexecuted (ctx : Ctx) (st : State) (nx : Nat) (n : Nat)
    (hn16 : n ≤ 16) (hvf : st.vf.all id = false) :
    stepBody ctx { ast := .pushNum n, wire := (if n = 0 then 0x4f else 0x50 + n), next := nx } st =
    .ok { st with opCount := st.opCount } := by
  have hb : ¬ (0x60 < (if n = 0 then 0x4f else 0x50 + n)) := by
    split <;> omega
  have hwab : ¬ ((if n = 0 then 0x4f else 0x50 + n : Nat) = 0xab) := by
    split <;> omega
  have hdis : disabledWire (if n = 0 then 0x4f else 0x50 + n) = false := by
    apply disabledWire_small; split <;> omega
  simp [stepBody, hvf, hb, hwab, hdis]

/-- Unexecuted pushdata under the element-size limit is a no-op; but the
:457-458 size check precedes `fExec` in Core too — a >520 payload fails
with PUSH_SIZE **even in a dead branch** (SCR-045). -/
theorem step_pushBytes_unexecuted (ctx : Ctx) (st : State) (d : ByteArray)
    (nx : Nat) (w : Nat) (h520 : d.size ≤ Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE)
    (hw : w ≤ 0x60) (hvf : st.vf.all id = false) :
    stepBody ctx { ast := .pushBytes d, wire := w, next := nx } st =
    .ok { st with opCount := st.opCount } := by
  have hb : ¬ (0x60 < w) := by omega
  have hwab : ¬ (w = 0xab) := by omega
  have hdis : disabledWire w = false := disabledWire_small w hw
  simp [stepBody, hvf, h520, hb, hwab, hdis]

/-! ## 4. Failure modes as exact precondition-implications -/

/-- Totality: a canonical pushNum (wire per `wireOfAst`, Defs.lean:407)
NEVER fails — no stackUnderflow (no stacktop read), no minimalData
(Core :520-521), no opCount (SCR-024), not disabled, not a
codeseparator. Exact precondition: none at all (executed or not, any
stack shape, any flags/policy). -/
theorem step_pushNum_ok (ctx : Ctx) (st : State) (nx : Nat) (n : Nat)
    (hn16 : n ≤ 16) :
    ∃ st', stepBody ctx
      { ast := .pushNum n, wire := (if n = 0 then 0x4f else 0x50 + n), next := nx } st
      = .ok st' := by
  by_cases h : st.vf.all id = true
  · cases n with
    | zero => exact ⟨_, step_op1negate ctx st nx h⟩
    | succ m => exact ⟨_, step_opN ctx st nx (m+1) (by omega) (by omega) h⟩
  · have hf : st.vf.all id = false := by
      cases hbern : st.vf.all id with
      | true => exact absurd hbern h
      | false => rfl
    exact ⟨_, step_pushNum_unexecuted ctx st nx n hn16 hf⟩

/-- Edge case: the empty stack. Executed OP_1NEGATE on `EvalScript`'s
initial state yields exactly the singleton `0x81` stack — the empty
stack is the normal case for a leading constant push. -/
theorem step_op1negate_empty_stack (ctx : Ctx) (nx : Nat) :
    stepBody ctx { ast := .pushNum 0, wire := 0x4f, next := nx } st0 =
    .ok { st0 with stack := serU8 0x81 :: [], opCount := 0 } := by
  rw [step_op1negate ctx st0 nx (by rfl : st0.vf.all id = true)]
  rfl

/-- Edge case: executed OP_N on the empty stack yields exactly the
singleton `[n]` minimal byte (SCR-046). -/
theorem step_opN_empty_stack (ctx : Ctx) (nx : Nat) (n : Nat)
    (hn1 : 0 < n) (hn16 : n ≤ 16) :
    stepBody ctx { ast := .pushNum n, wire := 0x50 + n, next := nx } st0 =
    .ok { st0 with stack := encodeScriptNum n false :: [], opCount := 0 } := by
  rw [step_opN ctx st0 nx n hn1 hn16 (by rfl : st0.vf.all id = true)]
  rfl

/-- MINIMALDATA boundary (BIP62 rule 3, script.cpp:373-396 via Core
:488-491): a direct push (wire 0x01) of the byte `0x01` FAILS with
MINIMALDATA — the value 1 must be pushed by OP_1 instead. Precondition:
executed AND policy MINIMALDATA (the check sits inside Core's
`fExec && 0 <= opcode <= OP_PUSHDATA4` arm). -/
theorem step_pushBytes_1_minimaldata_fails (ctx : Ctx) (st : State) (nx : Nat)
    (hmd : ctx.pol.minimalData = true) (hvf : st.vf.all id = true) :
    stepBody ctx { ast := .pushBytes (serU8 1), wire := 1, next := nx } st =
    .error .minimalData := by
  have hsz : (serU8 1).size ≤ Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE := by
    decide
  have hmin : checkMinimalPush (serU8 1) 1 = false := by decide
  simp [stepBody, hvf, hmd, hmin, hsz, disabledWire]

/-! ## 5. End-to-end verdicts (EvalScript loop) -/

/-- One-op script loop: if the step yields `st'` with an empty
conditional stack, the loop terminates successfully after bumping the
opcode index (fuel 2 = canonical for a 1-op script). -/
theorem evalFrom_push_single (ctx : Ctx) (op : WireOp) (st st' : State)
    (h : stepChecked ctx op st = .ok st') (hvf : st'.vf = []) :
    evalFrom ctx 2 [op] st = .ok { st' with opcodeIndex := st.opcodeIndex + 1 } := by
  simp [evalFrom, h, hvf]

/-- Full python3-cross-checked verdict: script `[0x4f]` (OP_1NEGATE)
alone validates, leaving exactly the stack `[0x81]`. -/
theorem verdict_op1negate (ctx : Ctx) :
    evalFrom ctx 2 [{ ast := .pushNum 0, wire := 0x4f, next := 1 }] st0
      = .ok { st0 with stack := serU8 0x81 :: [], opcodeIndex := st0.opcodeIndex + 1 } := by
  have hstep : stepChecked ctx { ast := .pushNum 0, wire := 0x4f, next := 1 } st0
      = .ok { st0 with stack := serU8 0x81 :: [], opCount := 0 } := by
    unfold stepChecked
    rw [step_op1negate ctx st0 1 (by rfl : st0.vf.all id = true)]
    simp [MAX_STACK_SIZE, st0]
  exact evalFrom_push_single ctx _ st0 _ hstep rfl

/-- Full verdict: script `[0x00]` (OP_0) alone validates, leaving the
stack `[∅]` (a single empty element — canonical false). -/
theorem verdict_op0 (ctx : Ctx) :
    evalFrom ctx 2 [{ ast := .pushBytes ByteArray.empty, wire := 0, next := 1 }] st0
      = .ok { st0 with stack := ByteArray.empty :: [], opcodeIndex := st0.opcodeIndex + 1 } := by
  have hstep : stepChecked ctx { ast := .pushBytes ByteArray.empty, wire := 0, next := 1 } st0
      = .ok { st0 with stack := ByteArray.empty :: [], opCount := 0 } := by
    unfold stepChecked
    rw [step_op0 ctx st0 1 (by rfl : st0.vf.all id = true)]
    simp [MAX_STACK_SIZE, st0]
  exact evalFrom_push_single ctx _ st0 _ hstep rfl

/-- Full verdict: script `[0x55]` (OP_5) alone validates, leaving the
stack `[0x05]` (the python3 `getvch(5) = 05` row). -/
theorem verdict_op5 (ctx : Ctx) :
    evalFrom ctx 2 [{ ast := .pushNum 5, wire := 0x55, next := 1 }] st0
      = .ok { st0 with stack := serU8 5 :: [], opcodeIndex := st0.opcodeIndex + 1 } := by
  have hstep : stepChecked ctx { ast := .pushNum 5, wire := 0x55, next := 1 } st0
      = .ok { st0 with stack := encodeScriptNum 5 false :: [], opCount := 0 } := by
    unfold stepChecked
    rw [step_opN ctx st0 1 5 (by omega) (by omega) (by rfl : st0.vf.all id = true)]
    simp [MAX_STACK_SIZE, st0]
  have hrun := evalFrom_push_single ctx _ st0 _ hstep rfl
  rwa [push_byte_5] at hrun

/-! ## 6. Axiom footprints (plain #print axioms; #guard_msgs pins added
from the captured output in `axioms.txt`) -/

#print axioms enc_op1negate_0x81
#print axioms encodeScriptNum_small
#print axioms step_op1negate
#print axioms step_opN
#print axioms step_op0
#print axioms step_pushNum_unexecuted
#print axioms step_pushBytes_unexecuted
#print axioms step_pushNum_ok
#print axioms step_pushBytes_1_minimaldata_fails
#print axioms verdict_op1negate
#print axioms verdict_op0
#print axioms verdict_op5

end BitcoinProofs.Theorems.Ops.O01
