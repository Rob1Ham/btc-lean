import Bitcoin.TxValidation.Interface
import Bitcoin.Invariants.RC08

/-! # PDW70B.lean — TOP-374..375: D-TXV / D-RC08 row faces
(TXV-023/INV-086). Claim `d6e28e7`. Route B: zero core writes.
TXV-021 (PDW66) and TXV-032 (PDW63) are yielded to concurrent claims;
INV-086 takes the last slot. -/

namespace BitcoinProofs.AF.PDW70

open Bitcoin.TxValidation Bitcoin.Data Bitcoin.Ledger

/-- **TXV-023**: a successful input loop returns seed plus the total input
value (the CVE-2010-5137 running-sum guard never fires). -/
@[rule "TXV-023"]
theorem inputValuesLoop_ok_sum_row (u : UtxoSet) (spendHeight : UInt32)
    (l : List TxIn) (acc v : Amount)
    (h : inputValuesLoop u spendHeight l acc = .ok v) :
    acc + l.foldl (fun a i => match u i.prevout with | some c => a + c.value | none => a) 0 = v :=
  inputValuesLoop_ok_sum u spendHeight l acc v h

/-- **TXV-023**: a missing/spent prevout fails closed before any value
accumulation (`bad-txns-inputs-missingorspent`). -/
@[rule "TXV-023"]
theorem inputValuesLoop_missing_row (u : UtxoSet) (spendHeight : UInt32)
    (i : TxIn) (rest : List TxIn) (acc : Amount)
    (h : u i.prevout = none) :
    inputValuesLoop u spendHeight (i :: rest) acc =
      .error .badTxnsInputsMissingOrSpent := by
  simp [inputValuesLoop, h]

/-- **INV-086**: off signet (`signet_blocks = false`) the solution check is
skipped and the block verdict always passes (BIP325, validation.cpp:3939). -/
@[rule "INV-086"]
theorem signetBlockOk_skip_row (fCheckPOW solutionOk : Bool) :
    Bitcoin.Invariants.RC08.signetBlockOk false fCheckPOW solutionOk = true :=
  Bitcoin.Invariants.RC08.signetBlockOk_skip fCheckPOW solutionOk

/-- **INV-086**: on signet with POW checked the gate is exactly the
solution verdict (`bad-signet-blksig`). -/
@[rule "INV-086"]
theorem signetBlockOk_gate_row (solutionOk : Bool) :
    (Bitcoin.Invariants.RC08.signetBlockOk true true solutionOk = true) ↔
      (solutionOk = true) :=
  Bitcoin.Invariants.RC08.signetBlockOk_gate solutionOk

/-- **INV-086**: the full parameter gate — the signet solution check is
enforced iff the chain has `signet_blocks` set AND POW is being checked
(`validation.cpp:3939`); otherwise the verdict passes. This covers the
off-signet skip, the `fCheckPOW = false` skip, and the `bad-signet-blksig`
gate in one statement. -/
@[rule "INV-086"]
theorem signetBlockOk_param_gate_row (signetBlocks fCheckPOW solutionOk : Bool) :
    Bitcoin.Invariants.RC08.signetBlockOk signetBlocks fCheckPOW solutionOk = true
      ↔ (signetBlocks = false ∨ fCheckPOW = false ∨ solutionOk = true) := by
  unfold Bitcoin.Invariants.RC08.signetBlockOk
  cases signetBlocks <;> cases fCheckPOW <;> cases solutionOk <;> simp

end BitcoinProofs.AF.PDW70

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/
#print axioms BitcoinProofs.AF.PDW70.inputValuesLoop_ok_sum_row
#print axioms BitcoinProofs.AF.PDW70.inputValuesLoop_missing_row
#print axioms BitcoinProofs.AF.PDW70.signetBlockOk_skip_row
#print axioms BitcoinProofs.AF.PDW70.signetBlockOk_gate_row
#print axioms BitcoinProofs.AF.PDW70.signetBlockOk_param_gate_row
