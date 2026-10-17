import Bitcoin.Capstone.Merkle

/-! # PDW76.lean — TOP-401..405, Capstone/Merkle witness-commitment residue

Route B row faces (zero core writes): BLK-013, SWT-029, SWT-041, INV-092.
SWT-031 lives in `PDW76b.lean` (kept under the per-turn Lean budget). -/

namespace BitcoinProofs.AF.PDW76
open Bitcoin.Capstone.Merkle
open Bitcoin.Crypto.Seam.Hash (sha256d)
open Bitcoin.Data
open Bitcoin.Serialization (hasWitness encodeTx)

/-! ## BLK-013 — empty leaf vector ⇒ 32-zero null root -/

@[rule "BLK-013"]
theorem merkleRootOf_nil : merkleRootOf ([] : List ByteArray) = zeroBytes 32 := rfl

@[rule "BLK-013"]
theorem merkleRootOf_single (a : ByteArray) : merkleRootOf [a] = a := rfl

/-! ## SWT-029 — the `6a24aa21a9ed` template selects the commitment -/

@[rule "SWT-029"]
theorem witnessCommitmentOutput_some_spec {tx : Tx} {s : ByteArray}
    (h : witnessCommitmentOutput tx = some s) :
    ∃ o ∈ tx.vout,
      38 ≤ o.scriptPubKey.bytes.size ∧
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm = true ∧
      o.scriptPubKey.bytes = s := by
  unfold witnessCommitmentOutput at h
  cases hg : (tx.vout.filter (fun o =>
      38 ≤ o.scriptPubKey.bytes.size &&
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).getLast? with
  | none => simp [hg] at h
  | some o =>
    simp [hg] at h
    obtain ⟨ys, hys⟩ := List.getLast?_eq_some_iff.mp hg
    have hmem : o ∈ tx.vout.filter (fun o =>
        38 ≤ o.scriptPubKey.bytes.size &&
        bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm) := by
      rw [hys]; simp
    rw [List.mem_filter] at hmem
    obtain ⟨hvout, hpred⟩ := hmem
    simp only [Bool.and_eq_true] at hpred
    obtain ⟨hsize, hpfx⟩ := hpred
    exact ⟨o, hvout, by simpa using hsize, hpfx, h⟩

/-! ## SWT-041 — txid/wtxid split -/

@[rule "SWT-041"]
theorem wtxidOf_noWitness {tx : Tx} (h : hasWitness tx = false) :
    wtxidOf tx = txidOf tx := by
  simp [wtxidOf, txidOf, h]

@[rule "SWT-041"]
theorem wtxidOf_hasWitness {tx : Tx} (h : hasWitness tx = true) :
    wtxidOf tx = sha256d (encodeTx tx) := by
  simp [wtxidOf, h]

/-- **REM-10 — the full txid/wtxid split in one conclusion.**

The audit noted `wtxidOf_noWitness` alone does not carry the
with-witness half. This theorem states BOTH halves for an arbitrary
`tx`, together with the no-witness collapse:
`txid = SHA256d(ser)` and, when a witness is present,
`wtxid = SHA256d(ser with witness)`, else `wtxid = txid`. -/
@[rule "SWT-041"]
theorem txid_wtxid_split (tx : Tx) :
    txidOf tx = sha256d (serTx tx) ∧
    (hasWitness tx = true → wtxidOf tx = sha256d (encodeTx tx)) ∧
    (hasWitness tx = false → wtxidOf tx = txidOf tx) := by
  refine ⟨rfl, ?_, ?_⟩
  · intro h
    simp [wtxidOf, h]
  · intro h
    simp [wtxidOf, txidOf, h]

/-! ## INV-092 — witness-tree leaves -/

@[rule "INV-092"]
theorem witnessLeaves_cons (cb : Tx) (rest : List Tx) :
    witnessLeaves (cb :: rest) = zeroBytes 32 :: rest.map wtxidOf := rfl

@[rule "INV-092"]
theorem witnessLeaves_length (txs : List Tx) :
    (witnessLeaves txs).length = txs.length := by
  cases txs with
  | nil => rfl
  | cons cb rest => simp [witnessLeaves]

end BitcoinProofs.AF.PDW76

/-! ## Axiom pins (subset of [propext, Classical.choice, Quot.sound]) -/

/-- info: 'BitcoinProofs.AF.PDW76.merkleRootOf_nil' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.merkleRootOf_nil

/-- info: 'BitcoinProofs.AF.PDW76.merkleRootOf_single' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.merkleRootOf_single

/-- info: 'BitcoinProofs.AF.PDW76.witnessCommitmentOutput_some_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.witnessCommitmentOutput_some_spec

/-- info: 'BitcoinProofs.AF.PDW76.wtxidOf_noWitness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.wtxidOf_noWitness

/-- info: 'BitcoinProofs.AF.PDW76.wtxidOf_hasWitness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.wtxidOf_hasWitness

/-- info: 'BitcoinProofs.AF.PDW76.witnessLeaves_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.witnessLeaves_cons

/-- info: 'BitcoinProofs.AF.PDW76.witnessLeaves_length' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.witnessLeaves_length

