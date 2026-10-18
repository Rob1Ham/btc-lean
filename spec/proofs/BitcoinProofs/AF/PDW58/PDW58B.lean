import Bitcoin.Capstone.Merkle
import BitcoinProofs.AF.PDW13.WitnessCommitmentReserved

/-! # PDW58B.lean — TOP-312: SWT-030 witness commitment value
(PDW58, review RC29). Row face for
`Bitcoin.Capstone.Merkle.witnessCommitmentOk` (validation.cpp:
CheckWitnessMalleation:3898-3906 @ cce32b168; BIP141).

The gate hashes the ACTUAL coinbase witness reserved value, exactly as
Core writes `hash_witness.Write(witness_stack[0])`; the previous
zero-reserved reading is retained only as `witnessCommitmentOkZero` and
is a special case. Route B: zero core writes. -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Capstone.Merkle Bitcoin.Data Bitcoin.Crypto.Seam.Hash

/-- SWT-030 (no commitment output): the gate fails closed. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_false_of_none (txs : List Tx) (cb : Tx)
    (h : witnessCommitmentOutput cb = none) :
    witnessCommitmentOk txs cb = false := by
  simp [witnessCommitmentOk, h]

/-- SWT-030 (no valid reserved value): a coinbase whose witness is not
exactly one 32-byte item also fails closed, independently of the
commitment output. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_false_of_no_reserved (txs : List Tx) (cb : Tx)
    (h : witnessReservedValue cb = none) :
    witnessCommitmentOk txs cb = false := by
  simp [witnessCommitmentOk, h]

/-- SWT-030 (positive face): with a selected commitment output and a
32-byte reserved value, the gate is true exactly when the coinbase
commits to `SHA256d(witness_merkle_root ‖ reserved)`. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_some_iff (txs : List Tx) (cb : Tx)
    (script reserved : ByteArray)
    (h : witnessCommitmentOutput cb = some script)
    (hr : witnessReservedValue cb = some reserved) :
    witnessCommitmentOk txs cb = true ↔
      bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
        (script.extract 6 38) = true := by
  simp [witnessCommitmentOk, h, hr]

/-- SWT-030 (full characterization): truth of the gate is exactly the
existence of a selected commitment output and a 32-byte reserved value
matching the BIP141 digest over those bytes. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_iff (txs : List Tx) (cb : Tx) :
    witnessCommitmentOk txs cb = true ↔
      ∃ script reserved,
        witnessCommitmentOutput cb = some script ∧
        witnessReservedValue cb = some reserved ∧
        bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
          (script.extract 6 38) = true := by
  unfold witnessCommitmentOk
  rcases ho : witnessCommitmentOutput cb with _ | script
  · simp
  · rcases hr : witnessReservedValue cb with _ | reserved <;> simp [ho, hr]

/-- SWT-030 (byte-form corollary): the commitment compares the double
SHA-256 of the witness root concatenated with the actual reserved value
against the script slice [6,38). -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_committedValue (txs : List Tx) (cb : Tx)
    (script reserved : ByteArray)
    (h : witnessCommitmentOutput cb = some script)
    (hr : witnessReservedValue cb = some reserved)
    (hok : witnessCommitmentOk txs cb = true) :
    bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
      (script.extract 6 38) = true :=
  (witnessCommitmentOk_some_iff txs cb script reserved h hr).mp hok

/-- SWT-030 regression: a non-zero reserved value changes the committed
digest input. This is the direct statement that the gate is not blind to
the coinbase witness item (the audit finding); the two digests are
definitionally over different byte strings. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_uses_reserved (txs : List Tx) (cb : Tx)
    (script reserved : ByteArray)
    (h : witnessCommitmentOutput cb = some script)
    (hr : witnessReservedValue cb = some reserved) :
    witnessCommitmentOk txs cb =
      bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
        (script.extract 6 38) := by
  simp [witnessCommitmentOk, h, hr]

end BitcoinProofs.AF.PDW58
