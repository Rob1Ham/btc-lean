import Bitcoin.Invariants.RC08

/-! # PDW55 — TOP-271..275: RC08 block-acceptance spine (route B)

Row-face theorems for `Bitcoin/Invariants/RC08.lean`:

* **INV-085** `checkBlockTxs` — the block loop passes iff every tx
  (coinbase included) passes `checkTransaction`; the CVE-2018-17144
  duplicate-input vector is caught as `.inputsDuplicate`.
* **INV-090** `witnessCommitmentMatch` — the BIP141 commitment check with
  the actual reserved value agrees with BLK-017's `witnessCommitmentOk`
  in the 32-byte-zero special case.

Status-debt class (PDW32/PDW35/PDW45 precedent): the RC08 development is
sorry-free in-tree; the DB rows were never flipped. Zero core writes. -/

namespace BitcoinProofs.AF.PDW55

open Bitcoin.Invariants.RC08 Bitcoin.Data Bitcoin.Consensus
open Bitcoin.Capstone.Merkle

/-- INV-085: `CheckBlock`'s per-tx loop passes iff every transaction of
the block passes its own stateless gate (validation.cpp:3967-3976),
including the duplicate-input scan (CVE-2018-17144). -/
@[rule "INV-085"]
theorem checkBlockTxs_none_iff_row (txs : List Tx) :
    checkBlockTxs txs = none ↔ ∀ t ∈ txs, checkTransaction t = none :=
  checkBlockTxs_none_iff txs

/-- INV-085 vector: the duplicate-prevout CVE transaction is rejected by
the block loop with the exact Core reason. -/
theorem checkBlockTxs_dup_row :
    checkBlockTxs [cbOk, dupTx] = some .inputsDuplicate :=
  checkBlockTxs_dup

/-- INV-090: with the 32-byte-zero reserved value, the actual-reserved
BIP141 commitment check reduces exactly to BLK-017's
`witnessCommitmentOk` (validation.cpp:3898-3906). -/
@[rule "INV-090"]
theorem witnessCommitmentMatch_zeroNonce_row (txs : List Tx) (cb : Tx)
    (h : cb.witness.getD 0 [] = [zeroBytes 32]) :
    witnessCommitmentMatch txs cb = witnessCommitmentOk txs cb :=
  witnessCommitmentMatch_zeroNonce txs cb h

/-- INV-090 reject lane: a 31-byte reserved value fails outright. -/
theorem witnessCommitmentMatch_badNonceSize_row (txs : List Tx) (cb : Tx)
    (h : cb.witness.getD 0 [] = [zeroBytes 31]) :
    witnessCommitmentMatch txs cb = false :=
  witnessCommitmentMatch_badNonceSize txs cb h

end BitcoinProofs.AF.PDW55

/-- info: 'BitcoinProofs.AF.PDW55.checkBlockTxs_none_iff_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW55.checkBlockTxs_none_iff_row
/-- info: 'BitcoinProofs.AF.PDW55.witnessCommitmentMatch_zeroNonce_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW55.witnessCommitmentMatch_zeroNonce_row
