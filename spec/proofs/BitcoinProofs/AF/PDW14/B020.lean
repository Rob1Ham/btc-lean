import Bitcoin.Capstone.Merkle
import Bitcoin.Block.Connect

/-! # B020 — PDW14, row BLK-020 (TOP-66).
`Bitcoin.Capstone.Merkle.commitmentGate` (Merkle.lean:174).
S-evidence: `CapstoneCommitmentCor.commitmentGate_forces_binding:120`
(PDW13 4fd8dda F-PDW13 hand-off) — restated on the PDW14 tag.
With SegWit active and witness txs the gate IS `witnessCommitmentOk`:
a witness block MUST bind its tree (validation.cpp:3913-3921, 4177).
The `segwitActive = true` hypothesis is genuinely necessary: the fixed
gate is conditional on activation (`CheckWitnessMalleation(block,
expect_witness_commitment, state)`), and pre-activation it takes the
no-witness fall-through instead of the binding branch. -/

namespace BitcoinProofs.AF.PDW14

open Bitcoin.Data Bitcoin.DataLaws Bitcoin.Consensus Bitcoin.TxValidation
open Bitcoin.Ledger Bitcoin.Conservation
open Bitcoin.Capstone.Pow Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle
open Bitcoin.Block.Connect

@[rule "BLK-020"]
theorem commitmentGate_forces_binding (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (h : anyWitness txs = true) (hseg : segwitActive = true) :
    commitmentGate segwitActive txs cb = witnessCommitmentOk txs cb := by
  subst hseg
  cases ho : witnessCommitmentOutput cb <;>
    simp [commitmentGate, h, ho, witnessCommitmentOk]

/-- **BLK-020 (commitment existence, gate-accepting form)**: post-activation,
if any transaction carries witness data and the commitment gate ACCEPTS
the block, then the coinbase must carry a commitment output and that
output must bind the witness tree. This is the row's "valid commitment
must exist" face, derived from `commitmentGate_forces_binding`;
pre-activation the hypothesis `hseg` is false, so the fall-through
unexpected-witness check applies instead. -/
@[rule "BLK-020"]
theorem commitmentGate_forces_commitment (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (h : anyWitness txs = true) (hseg : segwitActive = true)
    (hgate : commitmentGate segwitActive txs cb = true) :
    (witnessCommitmentOutput cb).isSome = true ∧ witnessCommitmentOk txs cb = true := by
  subst hseg
  cases ho : witnessCommitmentOutput cb with
  | none =>
      have hfalse : commitmentGate true txs cb = false := by
        simp [commitmentGate, h, ho]
      rw [hfalse] at hgate
      simp at hgate
  | some script =>
      simpa [commitmentGate, h, ho] using hgate

end BitcoinProofs.AF.PDW14
