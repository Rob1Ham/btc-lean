import Bitcoin.Capstone.Merkle
import Bitcoin.Data.Tx

/-! # WitnessCommitmentReserved — BLK-017 / SWT-030 model repair

Core `CheckWitnessMalleation` (`validation.cpp:3884-3906 @cce32b168`)
reads the coinbase witness reserved value and hashes **that value**, not
a hard-coded zero:

```
const auto& witness_stack{block.vtx[0]->vin[0].scriptWitness.stack};
if (witness_stack.size() != 1 || witness_stack[0].size() != 32) { ... }
uint256 hash_witness = BlockWitnessMerkleRoot(block);
CHash256().Write(hash_witness).Write(witness_stack[0]).Finalize(hash_witness);
if (memcmp(hash_witness.begin(),
           &block.vtx[0]->vout[commitpos].scriptPubKey[6], 32)) { ... }
```

`Bitcoin.Capstone.Merkle.witnessCommitmentOk` now hashes the actual
32-byte item and fails closed unless the coinbase carries exactly one
32-byte witness element.  This module records the model repair: the
definitions below are aliases for the core ones (so the old names used by
this proof suite keep working), and `witnessCommitmentOkReserved_zero`
pins the zero-reserved special case against the retained
`witnessCommitmentOkZero` reference. -/

namespace BitcoinProofs.AF.PDW13

open Bitcoin.Capstone.Merkle Bitcoin.Data Bitcoin.Crypto.Seam.Hash

/-- The coinbase witness reserved value (alias for the core definition):
exactly Core's `witness_stack.size() == 1 && witness_stack[0].size() == 32`
shape.  Every other shape is `none` (the `bad-witness-nonce-size` reject
is the caller's BLK-018 check). -/
abbrev witnessReservedValue : Tx → Option ByteArray :=
  Bitcoin.Capstone.Merkle.witnessReservedValue

/-- The corrected commitment equation (alias for the core definition):
`SHA256d(witness_root ‖ reserved_value) == scriptPubKey[6..38]`, where
`reserved_value` is the actual coinbase witness item. -/
abbrev witnessCommitmentOkReserved : List Tx → Tx → Bool :=
  Bitcoin.Capstone.Merkle.witnessCommitmentOk

/-- BLK-017 / SWT-030: on a selected commitment output and a valid
reserved value, the gate is exactly the Core equation with the actual
reserved bytes (not a zero constant). -/
@[rule "BLK-017", rule "SWT-030"]
theorem witnessCommitmentOkReserved_eq_true (txs : List Tx) (cb : Tx)
    (script reserved : ByteArray)
    (ho : witnessCommitmentOutput cb = some script)
    (hr : witnessReservedValue cb = some reserved) :
    witnessCommitmentOkReserved txs cb =
      bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
        (script.extract 6 38) := by
  simp [witnessCommitmentOkReserved, Bitcoin.Capstone.Merkle.witnessCommitmentOk, ho, hr]

/-- BLK-017 / SWT-030 (full characterization): the corrected gate is
true exactly when the coinbase carries a selected commitment output and
a 32-byte reserved witness item whose hash with the witness root equals
bytes 6..38 of that scriptPubKey. -/
@[rule "BLK-017", rule "SWT-030"]
theorem witnessCommitmentOkReserved_iff (txs : List Tx) (cb : Tx) :
    witnessCommitmentOkReserved txs cb = true ↔
      ∃ script reserved,
        witnessCommitmentOutput cb = some script ∧
        witnessReservedValue cb = some reserved ∧
        bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
          (script.extract 6 38) = true := by
  simp only [witnessCommitmentOkReserved, Bitcoin.Capstone.Merkle.witnessCommitmentOk]
  cases ho : witnessCommitmentOutput cb with
  | none => simp [ho]
  | some script =>
    cases hr : witnessReservedValue cb with
    | none => simp [ho, hr]
    | some reserved => simp [ho, hr]

/-- BLK-017 / SWT-030 (fail-closed): no commitment output or no valid
32-byte reserved value rejects. -/
@[rule "BLK-017", rule "SWT-030"]
theorem witnessCommitmentOkReserved_false (txs : List Tx) (cb : Tx)
    (h : witnessCommitmentOutput cb = none ∨ witnessReservedValue cb = none) :
    witnessCommitmentOkReserved txs cb = false := by
  simp only [witnessCommitmentOkReserved, Bitcoin.Capstone.Merkle.witnessCommitmentOk]
  rcases h with h | h <;> simp [h]

/-- BLK-017 / SWT-030 (compatibility): when the reserved value happens
to be the 32-byte zero `uint256()`, the repaired equation coincides with
the retained zero-reserved reference gate.  The zero constant is
therefore a faithful special case, not the general rule. -/
theorem witnessCommitmentOkReserved_zero (txs : List Tx) (cb : Tx)
    (hr : witnessReservedValue cb = some (zeroBytes 32)) :
    witnessCommitmentOkReserved txs cb = witnessCommitmentOkZero txs cb := by
  simp only [witnessCommitmentOkReserved, Bitcoin.Capstone.Merkle.witnessCommitmentOk,
    Bitcoin.Capstone.Merkle.witnessCommitmentOkZero]
  cases hv : witnessReservedValue cb with
  | none => simp [hv] at hr
  | some reserved =>
    simp only [hv, Option.some.injEq] at hr
    subst hr
    cases ho : witnessCommitmentOutput cb <;> simp [hv, ho]

end BitcoinProofs.AF.PDW13
