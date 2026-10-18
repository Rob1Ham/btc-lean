import Bitcoin.Capstone.Merkle
import BitcoinProofs.AF.PDW13.WitnessCommitmentReserved

/-! # PDW58B.lean — TOP-312: SWT-030 witness commitment value
(PDW58, RC29). Row face for
`Bitcoin.Capstone.Merkle.witnessCommitmentOk` (validation.cpp:
CheckWitnessMalleation:3898-3906 @ cce32b168; BIP141).
Route B: zero core writes. -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Capstone.Merkle Bitcoin.Data Bitcoin.Crypto.Seam.Hash

/-- SWT-030 (no commitment output): the gate fails closed. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_false_of_none (txs : List Tx) (cb : Tx)
    (h : witnessCommitmentOutput cb = none) :
    witnessCommitmentOk txs cb = false := by
  unfold witnessCommitmentOk
  rw [h]

/-- SWT-030 (positive face): the gate is true exactly when the coinbase
carries a commitment output whose bytes 6..38 equal
`SHA256d(witness_merkle_root ‖ reserved 32-byte zero)`. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_some_iff (txs : List Tx) (cb : Tx)
    (script : ByteArray) (h : witnessCommitmentOutput cb = some script) :
    witnessCommitmentOk txs cb = true ↔
      bytesBEq (sha256d (witnessMerkleRoot txs ++ zeroBytes 32))
        (script.extract 6 38) = true := by
  unfold witnessCommitmentOk
  rw [h]

/-- SWT-030 (full characterization): truth of the gate is exactly the
existence of a selected commitment output matching the BIP141 digest. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_iff (txs : List Tx) (cb : Tx) :
    witnessCommitmentOk txs cb = true ↔
      ∃ script, witnessCommitmentOutput cb = some script ∧
        bytesBEq (sha256d (witnessMerkleRoot txs ++ zeroBytes 32))
          (script.extract 6 38) = true := by
  unfold witnessCommitmentOk
  rcases h : witnessCommitmentOutput cb with _ | script
  · simp
  · simp

/-- SWT-030 (byte-form corollary): the commitment compares the double
SHA-256 of the witness root concatenated with the 32-byte reserved value
against the script slice [6,38). -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_committedValue (txs : List Tx) (cb : Tx)
    (script : ByteArray) (h : witnessCommitmentOutput cb = some script)
    (hok : witnessCommitmentOk txs cb = true) :
    bytesBEq (sha256d (witnessMerkleRoot txs ++ zeroBytes 32))
      (script.extract 6 38) = true :=
  (witnessCommitmentOk_some_iff txs cb script h).mp hok

end BitcoinProofs.AF.PDW58
