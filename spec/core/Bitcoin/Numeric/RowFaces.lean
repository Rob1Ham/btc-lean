import Bitcoin.Numeric.Interface
import Bitcoin.Interpreter.Defs
import Bitcoin.TxValidation.Interface

/-!
# Bitcoin.Numeric.RowFaces — row faces for the numeric layer (DEEP-B)

Companion rows to the DEEP-B consensus rows: `SCR-079` (the width guard
is the *first* CScriptNum gate and maps to `SCRIPT_ERR_SCRIPTNUM`),
`SCR-080` (every default numeric opcode — unary, binary, `OP_WITHIN`,
`OP_PICK`/`OP_ROLL`, `OP_CHECKSIGADD` — decodes at `nMaxNumSize = 4`;
only `OP_CHECKLOCKTIMEVERIFY`/`OP_CHECKSEQUENCEVERIFY` pass 5) and
`TXV-024` (`Σin ≥ Σout`, else `bad-txns-in-belowout`).

Core anchors @`cce32b168` (identical at `cce32b168`):

* `script.h:246-271` — `CScriptNum` ctor: `> nMaxNumSize` clears the
  result and returns false, and *then* `scriptnum_error("CScriptNum
  overflow")` is raised by the caller, before any minimality check.
* `script.h:244,247` — `nMaxNumSize = 4` default.
* `interpreter.cpp:1120,1145,1164,1191` — the `4` arguments at the
  unary / binary / `WITHIN` / `PICK|ROLL` sites; `:1103-1112` — the
  CHECKSIGADD operand decodes at 4.
* `tx_verify.cpp:202-205` — `if (value_in < value_out) return
  state.Invalid(..., "bad-txns-in-belowout")`.
-/

namespace Bitcoin.Numeric

open Bitcoin.Interpreter
open Bitcoin.Data
open Bitcoin.TxValidation

/-! ## SCR-079 — overflow is `SCRIPT_ERR_SCRIPTNUM` -/

/-- SCR-079: an operand wider than the limit yields
`decodeScriptNum = none`, which the interpreter maps to
`SCRIPT_ERR_SCRIPTNUM`. The width check is independent of
`fRequireMinimal` (it precedes it in `script.h:257-261`). -/
@[rule "SCR-079"]
theorem decodeNum_overflow_error (pol : PolicyFlags) (b : ByteArray)
    (h : 4 < b.size) :
    decodeNum pol b 4 = .error .scriptNum := by
  unfold decodeNum
  rw [scriptNum_width_rule b pol.minimalData 4 h]

/-- SCR-079, any explicitly passed limit: the same width guard is what
`nMaxNumSize` means, so passing `k` rejects operands wider than `k`. -/
@[rule "SCR-079"]
theorem decodeNum_width_guard (pol : PolicyFlags) (b : ByteArray) (k : Nat)
    (h : b.size > k) : decodeNum pol b k = .error .scriptNum := by
  unfold decodeNum
  show (match decodeScriptNum b pol.minimalData k with
        | some n => Except.ok n
        | none => Except.error ExecError.scriptNum) = Except.error ExecError.scriptNum
  rw [scriptNum_width_rule b pol.minimalData k h]

/-- A `decodeNum` failure is always `SCRIPT_ERR_SCRIPTNUM` (the caller's
mapping is the only error constructor the decoder can produce). -/
@[rule "SCR-079"]
theorem decodeNum_error_scriptNum (pol : PolicyFlags) (b : ByteArray) (k : Nat)
    (e : ExecError) (h : decodeNum pol b k = .error e) : e = .scriptNum := by
  unfold decodeNum at h
  split at h
  · cases h
  · cases h; rfl

/-- The opcode-budget guard cannot fire. `stepBody` computes
`opCount' = if counts then opCount+1 else opCount`, so this is the exact
side condition for the second `if`. -/
theorem opCount_gate_open (ctx : Ctx) (st : State)
    (h : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT <
        (if ctx.sv = .base ∨ ctx.sv = .witnessV0
          then st.opCount + 1 else st.opCount)) := by
  rintro ⟨hsv, hlt⟩
  rw [if_pos hsv] at hlt
  exact h ⟨hsv, hlt⟩

/-! ## SCR-080 — the default numeric opcodes all use `nMaxNumSize = 4` -/

/-- The unary numeric family (`OP_1ADD`…`OP_0NOTEQUAL`,
interpreter.cpp:1120-1145) rejects a 5-byte operand with
`SCRIPT_ERR_SCRIPTNUM` before doing any arithmetic. -/
@[rule "SCR-080"]
theorem stepBody_unary_overflow
    (ctx : Ctx) (op : WireOp) (st : State) (c : Fin 256) (w : Nat)
    (hast : op.ast = .op c) (hw : op.wire = w)
    (hwf : w = 0x8b ∨ w = 0x8c ∨ w = 0x8f ∨ w = 0x90 ∨ w = 0x91 ∨ w = 0x92)
    (hexec : st.vf.all id = true)
    (hopc : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 0 < st.stack.length)
    (hover : 4 < (topAt st.stack 1).size) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by
    intro hnil; rw [hnil] at hstack; simp at hstack
  rcases hwf with rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp (config := { decide := true }) [stepBody, stepBody.dispatchOp,
      disabledWire, hw, hast, hexec,
      opCount_gate_open ctx st hopc, hne, hstack,
      decodeNum_overflow_error ctx.pol (topAt st.stack 1) hover]

/-- The binary numeric family (`OP_ADD`…`OP_MAX`, `0x93,0x94,0x9a-0xa4`)
rejects a 5-byte left operand. -/
@[rule "SCR-080"]
theorem stepBody_binary_overflow_left
    (ctx : Ctx) (op : WireOp) (st : State) (c : Fin 256) (w : Nat)
    (hast : op.ast = .op c) (hw : op.wire = w)
    (hwf : w = 0x93 ∨ w = 0x94 ∨ w = 0x9a ∨ w = 0x9b ∨ w = 0x9c ∨ w = 0x9d ∨
      w = 0x9e ∨ w = 0x9f ∨ w = 0xa0 ∨ w = 0xa1 ∨ w = 0xa2 ∨ w = 0xa3 ∨ w = 0xa4)
    (hexec : st.vf.all id = true)
    (hopc : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 2 ≤ st.stack.length)
    (hover : 4 < (topAt st.stack 2).size) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by
    intro hnil; rw [hnil] at hstack; simp at hstack
  rcases hwf with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl <;>
    simp (config := { decide := true }) [stepBody, stepBody.dispatchOp,
      disabledWire, hw, hast, hexec,
      opCount_gate_open ctx st hopc, hne, hstack,
      SCRIPT_NUM_DEFAULT_MAX_SIZE,
      decodeNum_overflow_error ctx.pol (topAt st.stack 2) hover]

@[rule "SCR-080"]
theorem stepBody_binary_overflow_right
    (ctx : Ctx) (op : WireOp) (st : State) (c : Fin 256) (w : Nat)
    (hast : op.ast = .op c) (hw : op.wire = w)
    (hwf : w = 0x93 ∨ w = 0x94 ∨ w = 0x9a ∨ w = 0x9b ∨ w = 0x9c ∨ w = 0x9d ∨
      w = 0x9e ∨ w = 0x9f ∨ w = 0xa0 ∨ w = 0xa1 ∨ w = 0xa2 ∨ w = 0xa3 ∨ w = 0xa4)
    (hexec : st.vf.all id = true)
    (hopc : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 2 ≤ st.stack.length)
    (hover : 4 < (topAt st.stack 1).size) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by
    intro hnil; rw [hnil] at hstack; simp at hstack
  rcases hd : decodeNum ctx.pol (topAt st.stack 2) 4 with e | bn1
  · rcases hwf with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
      rfl | rfl | rfl <;>
      simp (config := { decide := true }) [stepBody, stepBody.dispatchOp,
        disabledWire, hw, hast, hexec,
        opCount_gate_open ctx st hopc, hne, hstack, hd,
        decodeNum_error_scriptNum ctx.pol (topAt st.stack 2) 4 e hd]
  · rcases hwf with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
      rfl | rfl | rfl <;>
      simp (config := { decide := true }) [stepBody, stepBody.dispatchOp,
        disabledWire, hw, hast, hexec,
        opCount_gate_open ctx st hopc, hne, hstack, hd,
        decodeNum_overflow_error ctx.pol (topAt st.stack 1) hover]

/-- `OP_WITHIN` (interpreter.cpp:1191) decodes all three operands at 4. -/
@[rule "SCR-080"]
theorem stepBody_within_overflow
    (ctx : Ctx) (op : WireOp) (st : State) (c : Fin 256)
    (hast : op.ast = .op c) (hw : op.wire = 0xa5)
    (hexec : st.vf.all id = true)
    (hopc : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 3 ≤ st.stack.length)
    (hover : 4 < (topAt st.stack 3).size) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by
    intro hnil; rw [hnil] at hstack; simp at hstack
  simp (config := { decide := true }) [stepBody, stepBody.dispatchOp,
    disabledWire, hw, hast, hexec, opCount_gate_open ctx st hopc, hne, hstack,
    decodeNum_overflow_error ctx.pol (topAt st.stack 3) hover]

/-- `OP_PICK`/`OP_ROLL` (interpreter.cpp:1164) decode their depth at 4. -/
@[rule "SCR-080"]
theorem stepBody_pick_roll_overflow
    (ctx : Ctx) (op : WireOp) (st : State) (c : Fin 256) (w : Nat)
    (hast : op.ast = .op c) (hw : op.wire = w)
    (hwf : w = 0x79 ∨ w = 0x7a)
    (hexec : st.vf.all id = true)
    (hopc : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 2 ≤ st.stack.length)
    (hover : 4 < (topAt st.stack 1).size) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by
    intro hnil; rw [hnil] at hstack; simp at hstack
  rcases hwf with rfl | rfl <;>
    simp (config := { decide := true }) [stepBody, stepBody.dispatchOp,
      disabledWire, hw, hast, hexec,
      opCount_gate_open ctx st hopc, hne, hstack,
      decodeNum_overflow_error ctx.pol (topAt st.stack 1) hover]

/-- `OP_CHECKSIGADD` (BIP342, interpreter.cpp:1103-1112): the `num`
operand is the one the 4-byte rule binds first. -/
@[rule "SCR-080"]
theorem checksigAddStep_overflow
    (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sig num pk : ByteArray) (vw : Option Int)
    (hover : 4 < num.size) :
    checksigAddStep pol chk ed sig num pk vw = .error .scriptNum := by
  simp [checksigAddStep, decodeNum_overflow_error pol num hover]

/-- In `OP_CHECKSIGADD`-tapscript dispatch the oversized `num` wins over
the signature check (the decode is first), so the step errors
`SCRIPT_ERR_SCRIPTNUM`. -/
@[rule "SCR-080"]
theorem stepBody_checksigadd_overflow
    (ctx : Ctx) (op : WireOp) (st : State) (c : Fin 256)
    (hast : op.ast = .op c) (hw : op.wire = 0xba)
    (hsv : ctx.sv = .tapscript)
    (hexec : st.vf.all id = true)
    (hstack : 3 ≤ st.stack.length)
    (hover : 4 < (topAt st.stack 2).size) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by
    intro hnil; rw [hnil] at hstack; simp at hstack
  simp (config := { decide := true }) [stepBody, stepBody.dispatchOp,
    disabledWire, hw, hast, hsv, hexec, hne, hstack, checksigAddStep,
    decodeNum_overflow_error ctx.pol (topAt st.stack 2) hover]

/-- `inputValuesLoop` never returns `bad-txns-in-belowout` (that verdict
belongs exclusively to the value-conservation gate *after* the loop). -/
theorem inputValuesLoop_error_ne_belowout (u : Bitcoin.Ledger.UtxoSet)
    (spendHeight : UInt32) :
    ∀ (ins : List TxIn) (acc : Amount) (e : TxError),
      inputValuesLoop u spendHeight ins acc = .error e →
        e ≠ .badTxnsInBelowout
  | [], acc, e, h => by simp [inputValuesLoop] at h
  | i :: rest, acc, e, h => by
      simp only [inputValuesLoop] at h
      cases hprev : u i.prevout with
      | none =>
        simp only [hprev] at h
        cases h; intro he; cases he
      | some c =>
        simp only [hprev] at h
        by_cases hm : coinMatured spendHeight c = false
        · simp only [hm, if_true] at h
          cases h; intro he; cases he
        · simp only [hm, if_false] at h
          by_cases hr : MoneyRange c.value = false
          · simp only [hr, if_true] at h
            cases h; intro he; cases he
          · simp only [hr, if_false] at h
            by_cases ha : MoneyRange (acc + c.value) = false
            · simp only [ha, if_true] at h
              cases h; intro he; cases he
            · simp only [ha, if_false] at h
              exact inputValuesLoop_error_ne_belowout u spendHeight rest
                (acc + c.value) e h

/-! ## TXV-024 — input value conservation -/

/-- TXV-024 (gate): once the inputs resolve and the loop returns
`valueIn < getValueOut`, `CheckTxInputs` fails with
`bad-txns-in-belowout`. -/
@[rule "TXV-024"]
theorem checkTxInputs_belowout (tx : Tx) (u : Bitcoin.Ledger.UtxoSet)
    (spendHeight : UInt32) (valueIn : Amount)
    (hi : haveInputs tx u = true)
    (hlv : inputValuesLoop u spendHeight tx.vin 0 = .ok valueIn)
    (hb : valueIn < tx.getValueOut) :
    checkTxInputs tx u spendHeight = .error .badTxnsInBelowout := by
  unfold checkTxInputs
  rw [if_pos hi, hlv]
  simp [hb]

/-- TXV-024 (exactness): `bad-txns-in-belowout` is returned iff the
inputs resolve and the accumulated value is below the output total. -/
@[rule "TXV-024"]
theorem checkTxInputs_belowout_iff (tx : Tx) (u : Bitcoin.Ledger.UtxoSet)
    (spendHeight : UInt32) :
    checkTxInputs tx u spendHeight = .error .badTxnsInBelowout ↔
      haveInputs tx u = true ∧
        ∃ valueIn : Amount,
          inputValuesLoop u spendHeight tx.vin 0 = .ok valueIn ∧
            valueIn < tx.getValueOut := by
  unfold checkTxInputs
  rcases hlv : inputValuesLoop u spendHeight tx.vin 0 with e | valueIn
  · by_cases hi : haveInputs tx u = true
    · simp only [if_pos hi, hlv]
      constructor
      · intro h
        cases h
        exact absurd rfl
          (inputValuesLoop_error_ne_belowout u spendHeight tx.vin 0 _ hlv)
      · intro h
        rcases h with ⟨-, v, hv, -⟩
        cases hv
    · rw [if_neg hi]
      exact ⟨fun h => absurd h (by simp), fun ⟨h, _⟩ => absurd h hi⟩
  · by_cases hi : haveInputs tx u = true
    · simp only [if_pos hi, hlv]
      by_cases hb : valueIn < tx.getValueOut
      · constructor
        · intro _; exact ⟨hi, valueIn, rfl, hb⟩
        · intro _; simp [hb]
      · constructor
        · intro h
          simp only [hb, if_false] at h
          by_cases hm : MoneyRange (valueIn - tx.getValueOut) = true
          · simp only [hm, if_true] at h; cases h
          · simp only [hm, if_false] at h; cases h
        · rintro ⟨-, v, hv, hvlt⟩
          cases hv
          exact absurd hvlt hb
    · rw [if_neg hi]
      exact ⟨fun h => absurd h (by simp), fun ⟨h, _⟩ => absurd h hi⟩

/-- TXV-024 (consequence): on success, the accumulated input value is at
least the output total. -/
@[rule "TXV-024"]
theorem checkTxInputs_ok_valueIn_ge (tx : Tx) (u : Bitcoin.Ledger.UtxoSet)
    (spendHeight : UInt32) (fee valueIn : Amount)
    (h : checkTxInputs tx u spendHeight = .ok fee)
    (hlv : inputValuesLoop u spendHeight tx.vin 0 = .ok valueIn) :
    tx.getValueOut ≤ valueIn := by
  unfold checkTxInputs at h
  by_cases hi : haveInputs tx u = true
  · simp only [if_pos hi, hlv] at h
    by_cases hb : valueIn < tx.getValueOut
    · simp [hb] at h
    · exact Int.not_lt.mp hb
  · rw [if_neg hi] at h; cases h

end Bitcoin.Numeric
