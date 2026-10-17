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

`Bitcoin.Capstone.Merkle.witnessCommitmentOk` hashes `zeroBytes 32`
instead.  The old definition is retained unchanged (other rows ride it);
this module adds the faithful `witnessCommitmentOkReserved`, which
hashes the actual 32-byte item, and proves the BLK-017/SWT-030 equations
against it.  `witnessCommitmentOkReserved_zero` proves the two agree
exactly on the zero-reserved special case, so the repair is additive and
does not weaken the existing model. -/

namespace BitcoinProofs.AF.PDW13

open Bitcoin.Capstone.Merkle Bitcoin.Data Bitcoin.Crypto.Seam.Hash

/-- The coinbase witness reserved value, exactly Core's
`witness_stack.size() == 1 && witness_stack[0].size() == 32` shape:
the head witness stack must be the singleton `[nonce]` with
`nonce.size = 32`.  Every other shape is `none` (the
`bad-witness-nonce-size` reject is the caller's BLK-018 check). -/
def witnessReservedValue (cb : Tx) : Option ByteArray :=
  match cb.witness.getD 0 [] with
  | [nonce] => if nonce.size = 32 then some nonce else none
  | _ => none

/-- The corrected commitment equation: `SHA256d(witness_root ‖
reserved_value) == scriptPubKey[6..38]`, where `reserved_value` is the
actual coinbase witness item. -/
def witnessCommitmentOkReserved (txs : List Tx) (cb : Tx) : Bool :=
  match witnessCommitmentOutput cb, witnessReservedValue cb with
  | some script, some reserved =>
      bytesBEq (sha256d (witnessMerkleRoot txs ++ reserved))
        (script.extract 6 38)
  | _, _ => false

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
  unfold witnessCommitmentOkReserved
  rw [ho, hr]

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
  unfold witnessCommitmentOkReserved
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
  unfold witnessCommitmentOkReserved
  rcases h with h | h <;> simp [h]

/-- BLK-017 / SWT-030 (compatibility): when the reserved value happens
to be the 32-byte zero `uint256()`, the repaired equation coincides with
the legacy `witnessCommitmentOk`.  The zero constant is therefore a
faithful special case, not the general rule. -/
theorem witnessCommitmentOkReserved_zero (txs : List Tx) (cb : Tx)
    (hr : witnessReservedValue cb = some (zeroBytes 32)) :
    witnessCommitmentOkReserved txs cb = witnessCommitmentOk txs cb := by
  unfold witnessCommitmentOkReserved witnessCommitmentOk
  rw [hr]
  cases ho : witnessCommitmentOutput cb <;> simp [ho]

end BitcoinProofs.AF.PDW13
