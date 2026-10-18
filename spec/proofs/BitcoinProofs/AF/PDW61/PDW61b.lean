import Bitcoin.Capstone.Block
import Bitcoin.DataLaws.Laws
import Bitcoin.Interpreter.Defs

/-! # PDW61b — TOP-326..330 row faces (claim v3)

BLK-030 / TXV-071 in this file; SCR-046/062/064 appended after direct-lean
pass 1. Route B: zero core writes. Pins ⊆ [propext, Classical.choice,
Quot.sound]. -/

open Bitcoin.Data Bitcoin.Ledger

namespace BitcoinProofs.AF.PDW61

/-! ## BLK-030 — the stateless gate inside the pipeline -/

/-- One successful pipeline step passed `CheckTransaction`. -/
theorem applyTx_ok_stateless (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l l' : List (OutPoint × Coin)) (a b : Nat)
    (h : Bitcoin.Capstone.Block.applyTx height tx txIdx l = .ok (l', a, b)) :
    Bitcoin.Consensus.checkTransaction tx = none := by
  rw [Bitcoin.Capstone.Block.applyTx_unfold] at h
  simp only [] at h
  split at h
  · nomatch h
  · rename_i heqN
    exact heqN

/-- **BLK-030**: a successful `applyTxs` fold sent every tx through the
stateless `checkTransaction` gate (validateBlock's step 5). -/
@[rule "BLK-030"]
theorem applyTxs_ok_stateless (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat)
      (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      Bitcoin.Capstone.Block.applyTxs height txs i l okN unjN =
        .ok (l', okN', unjN') →
      ∀ tx ∈ txs, Bitcoin.Consensus.checkTransaction tx = none := by
  intro txs
  induction txs with
  | nil => intro _ _ _ _ _ _ _ _ tx ht; cases ht
  | cons u rest ih =>
      intro i okN unjN l l' okN' unjN' h tx ht
      unfold Bitcoin.Capstone.Block.applyTxs at h
      cases hap : Bitcoin.Capstone.Block.applyTx height u i l with
      | error e => rw [hap] at h; simp at h
      | ok p =>
          obtain ⟨l₁, a, b⟩ := p
          rw [hap] at h
          rcases List.mem_cons.mp ht with heq | hmem
          · rw [heq]
            exact applyTx_ok_stateless height u i l l₁ a b hap
          · exact ih (i + 1) (okN + a) (unjN + b) l₁ l' okN' unjN' h tx hmem

/-! ## TXV-071 — version is unconstrained; BIP68 only from wire ≥ 2 -/

/-- **TXV-071**: the only version-sensitive gate is BIP68's wire-value
enable condition (`version.toUInt32 ≥ 2`), conjoined with the CSV flag. -/
@[rule "TXV-071"]
theorem bip68_enabled_iff (v : Int32) (f : Bool) :
    Bitcoin.DataLaws.bip68Enabled v f = true ↔
      2 ≤ v.toUInt32.toNat ∧ f = true :=
  Bitcoin.DataLaws.bip68Enabled_iff v f

/-- **TXV-071**: version 1 is always exempt from BIP68, flag or not. -/
@[rule "TXV-071"]
theorem bip68_v1_exempt (f : Bool) :
    Bitcoin.DataLaws.bip68Enabled 1 f = false := by
  cases hb : Bitcoin.DataLaws.bip68Enabled 1 f with
  | false => rfl
  | true =>
      have h := (bip68_enabled_iff 1 f).mp hb
      have h1 : (1 : Int32).toUInt32.toNat = 1 := by decide
      omega

/-- **TXV-071**: the wire value 0xFFFFFFFF (scaffold `Int32` −1) enables
BIP68 when the CSV flag is on — Core compares the unsigned wire version. -/
@[rule "TXV-071"]
theorem bip68_wire_max_on :
    Bitcoin.DataLaws.bip68Enabled (-1) true = true := by decide

/-! ## SCR-046 — OP_0 / OP_1..OP_16 pushes -/

open Bitcoin.Interpreter

/-- Wire bytes ≤ OP_16 are outside the disabled table. -/
theorem disabledWire_small (w : Nat) (h : w ≤ 0x60) : disabledWire w = false := by
  have hmem : ¬(w ∈ [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
      0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99]) := by
    simp only [List.mem_cons, List.not_mem_nil, or_false]
    omega
  simp only [disabledWire, hmem]
  rfl

/-- **SCR-046**: OP_N (1..16) pushes exactly the minimal one-byte value,
and never counts toward the 201-op budget. -/
@[rule "SCR-046"]
theorem step_opN_row (ctx : Ctx) (st : State) (nx : Nat) (n : Nat)
    (hn1 : 0 < n) (hn16 : n ≤ 16) (hvf : st.vf.all id = true) :
    stepBody ctx { ast := .pushNum n, wire := 0x50 + n, next := nx } st =
    .ok { st with stack := Bitcoin.Numeric.encodeScriptNum n false :: st.stack,
                  opCount := st.opCount } := by
  have hz : ¬ ((n : Nat) = 0) := by omega
  have hb : ¬ ((0x60 : Nat) < 0x50 + n) := by omega
  have hwab : ¬ ((0x50 + n : Nat) = 0xab) := by omega
  have hdis : disabledWire (0x50 + n) = false := disabledWire_small _ (by omega)
  simp [stepBody, hvf, hz, hb, hwab, hdis]

/-- **SCR-046**: OP_0 pushes the empty vector, budget unchanged. -/
@[rule "SCR-046"]
theorem step_op0_row (ctx : Ctx) (st : State) (nx : Nat)
    (hvf : st.vf.all id = true) :
    stepBody ctx { ast := .pushBytes ByteArray.empty, wire := 0, next := nx } st =
    .ok { st with stack := ByteArray.empty :: st.stack, opCount := st.opCount } := by
  simp [stepBody, hvf, disabledWire, checkMinimalPush]

/-! ## SCR-062 / SCR-064 — OP_ENDIF flow checks -/

/-- **SCR-062**: OP_ENDIF with an empty conditional stack fails with
UNBALANCED_CONDITIONAL (dispatch level, any fExec). -/
@[rule "SCR-062"]
theorem opEndif_empty_row (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0x68 fExec { st with vf := [] } =
      .error .unbalancedConditional := by
  simp [stepBody.dispatchOp]

/-- **SCR-064**: OP_ENDIF pops exactly one conditional frame. -/
@[rule "SCR-064"]
theorem opEndif_pop_row (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (v : Bool) (rest : List Bool) :
    stepBody.dispatchOp ctx op 0x68 fExec { st with vf := v :: rest } =
      .ok { st with vf := rest } := by
  simp [stepBody.dispatchOp]

end BitcoinProofs.AF.PDW61
