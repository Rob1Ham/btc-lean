import Bitcoin.Consensus.TxCheck
import Bitcoin.Interpreter.Defs

/-! # PDW66b — TOP-351..355 lane: CVE / witness-resource / coinbase band

Second PDW66 lane (concurrent same-name claim 1a4571f took INV-103/088/139/
BLK-031/TXV-021; this lane keeps INV-006/SWT-010/TXV-010/SWT-064/SWT-065).
-/

namespace BitcoinProofs.AF.PDW66b

open Bitcoin.Data Bitcoin.Consensus Bitcoin.Interpreter Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion)

/-- INV-006: accepted output loop ⇒ every value in range and the running
accumulated sum stays in money range. -/
@[rule "INV-006"]
theorem checkOutputs_ok_bounds (outs : List TxOut) (acc : Amount)
    (hacc : MoneyRange acc = true)
    (h : checkTransaction.checkOutputs outs acc = none) :
    (∀ o ∈ outs, 0 ≤ o.value ∧ o.value ≤ MAX_MONEY) ∧
      MoneyRange (outs.foldl (fun a o => a + o.value) acc) = true := by
  induction outs generalizing acc with
  | nil => simpa [checkTransaction.checkOutputs] using hacc
  | cons o rest ih =>
    simp only [checkTransaction.checkOutputs] at h
    by_cases hneg : o.value < 0
    · simp [hneg] at h
    · by_cases hbig : MAX_MONEY < o.value
      · simp [hneg, hbig] at h
      · by_cases hacc' : MoneyRange (acc + o.value) = true
        · simp [hneg, hbig, hacc'] at h
          obtain ⟨hall, hsum⟩ := ih (acc + o.value) hacc' h
          refine ⟨?_, ?_⟩
          · intro x hx
            rcases List.mem_cons.mp hx with rfl | hx
            · exact ⟨Int.le_of_not_gt hneg, Int.le_of_not_gt hbig⟩
            · exact hall x hx
          · simpa [List.foldl] using hsum
        · simp [hneg, hbig, hacc'] at h

/-- TXV-010: coinbase exactly for a singleton null-prevout input. -/
@[rule "TXV-010"]
theorem isCoinBase_iff (tx : Tx) :
    tx.isCoinBase = true ↔ ∃ i, tx.vin = [i] ∧ i.prevout.isNull = true := by
  cases h : tx.vin with
  | nil => simp [Tx.isCoinBase, h]
  | cons i rest =>
    cases rest with
    | nil => simp [Tx.isCoinBase, h]
    | cons j rest => simp [Tx.isCoinBase, h]

/-- SWT-010: outside TAPSCRIPT, a >520-byte witness item fails with
`PUSH_SIZE` before evaluation. -/
@[rule "SWT-010"]
theorem executeWitnessScript_item_too_large
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (sv : SigVersion) (hsv : sv ≠ .tapscript)
    (hany : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk sv = .fail .pushSize := by
  unfold executeWitnessScript
  simp [hsv, hany, executeWitnessScript.runExec]

end BitcoinProofs.AF.PDW66b
