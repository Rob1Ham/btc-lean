import BitcoinProofs.Theorems.CapstoneSigops

/-! R05: the ordered witness verdicts, amount independence, and their
connection to the actual public validator. These are symbolic kernel proofs;
the mined conditional fixture and Core function harness are runtime evidence. -/

namespace BitcoinProofs.Theorems.CapstoneWitness

open Bitcoin.Data Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle

@[rule "BLK-018"]
theorem checkWitnessCommitment_nonce_error {active : Bool} {txs : List Tx} {cb : Tx}
    (ha : (active && (witnessCommitmentOutput cb).isSome) = true)
    (hn : commitmentNonceOk cb = false) :
    checkWitnessCommitment active txs cb = .error .badWitnessNonce := by
  simp [checkWitnessCommitment, ha, hn]

@[rule "BLK-017"]
theorem checkWitnessCommitment_hash_error {active : Bool} {txs : List Tx} {cb : Tx}
    (ha : (active && (witnessCommitmentOutput cb).isSome) = true)
    (hn : commitmentNonceOk cb = true) (hh : witnessCommitmentOk txs cb = false) :
    checkWitnessCommitment active txs cb = .error .badWitnessCommitment := by
  simp [checkWitnessCommitment, ha, hn, hh]

@[rule "BLK-019"]
theorem checkWitnessCommitment_unexpected_error {active : Bool} {txs : List Tx} {cb : Tx}
    (ha : (active && (witnessCommitmentOutput cb).isSome) = false)
    (hw : anyWitness txs = true) :
    checkWitnessCommitment active txs cb = .error .unexpectedWitness := by
  simp [checkWitnessCommitment, ha, hw]

/-- Change only output amounts. Script bytes and reserved witness stay fixed. -/
def withOutputValues (cb : Tx) (f : Amount → Amount) : Tx :=
  { cb with vout := cb.vout.map (fun out => { out with value := f out.value }) }

theorem witnessCommitmentOutput_values (cb : Tx) (f : Amount → Amount) :
    witnessCommitmentOutput (withOutputValues cb f) = witnessCommitmentOutput cb := by
  simp only [witnessCommitmentOutput, withOutputValues, List.filter_map,
    Function.comp_def, List.getLast?_map]
  cases (cb.vout.filter (fun out => 38 ≤ out.scriptPubKey.bytes.size &&
    bytesBEq (out.scriptPubKey.bytes.extract 0 6) wcm)).getLast? <;> rfl

/-- Witness validation ignores output values, even negative or excessive
ones. The separate stateless/fee/reward gates enforce monetary validity. -/
theorem checkWitnessCommitment_values (active : Bool) (txs : List Tx)
    (cb : Tx) (f : Amount → Amount) :
    checkWitnessCommitment active txs (withOutputValues cb f) =
      checkWitnessCommitment active txs cb := by
  have nonce : commitmentNonceOk (withOutputValues cb f) = commitmentNonceOk cb := rfl
  have reserved : witnessReservedValue (withOutputValues cb f) = witnessReservedValue cb := rfl
  have binding : witnessCommitmentOk txs (withOutputValues cb f) = witnessCommitmentOk txs cb := by
    unfold witnessCommitmentOk
    rw [witnessCommitmentOutput_values, reserved]
  simp only [checkWitnessCommitment, witnessCommitmentOutput_values, nonce, binding]

/-- Changing the actual first (coinbase) transaction's amounts also leaves
the witness stage invariant: its witness-merkle leaf is always zero. -/
@[rule "BLK-016"]
theorem checkWitnessCommitment_coinbase_values (active : Bool) (rest : List Tx)
    (cb : Tx) (f : Amount → Amount) :
    checkWitnessCommitment active (withOutputValues cb f :: rest) (withOutputValues cb f) =
      checkWitnessCommitment active (cb :: rest) cb := by
  rw [checkWitnessCommitment_values]
  have tree : witnessMerkleRoot (withOutputValues cb f :: rest) =
      witnessMerkleRoot (cb :: rest) := rfl
  have witness : anyWitness (withOutputValues cb f :: rest) = anyWitness (cb :: rest) := rfl
  have binding : witnessCommitmentOk (withOutputValues cb f :: rest) cb =
      witnessCommitmentOk (cb :: rest) cb := by
    unfold witnessCommitmentOk
    rw [tree]
  simp only [checkWitnessCommitment, witness, binding]

/-- Actual public success, including the contextual entry, passed the
same ordered witness stage and its exact Boolean commitment predicate. -/
@[rule "BLK-017", rule "BLK-018", rule "BLK-019", rule "BLK-020"]
theorem validateBlock_witness {raw : ByteArray} {st : CapState}
    {context : Option Bitcoin.Capstone.Context.ChainContext} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    ∃ header txs, Bitcoin.Serialization.decodeBlock raw = .ok (header, txs) ∧
      checkWitnessCommitment (Bitcoin.Activation.SEGWIT_HEIGHT ≤ st.height) txs
        (txs.getD 0 dummyTx) = .ok () ∧
      commitmentGate (Bitcoin.Activation.SEGWIT_HEIGHT ≤ st.height) txs
        (txs.getD 0 dummyTx) = true := by
  obtain ⟨header, txs, _, hd, _, witness, _, _⟩ := CapstoneSigops.validateBlock_sigop_stage h
  exact ⟨header, txs, hd, witness, (checkWitnessCommitment_ok_iff _ _ _).1 witness⟩

/-! Exact dynamic footprints, pinned again during module elaboration. -/

/-- info: 'Bitcoin.Capstone.Merkle.witnessReservedValue_nonce' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Merkle.witnessReservedValue_nonce

/-- info: 'Bitcoin.Capstone.Merkle.witnessCommitmentOk_nonce' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Merkle.witnessCommitmentOk_nonce

/-- info: 'Bitcoin.Capstone.Block.checkWitnessCommitment_ok_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkWitnessCommitment_ok_iff

/-- info: 'Bitcoin.Capstone.Block.checkWitnessCommitment_error' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkWitnessCommitment_error

/-- info: 'BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_nonce_error' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_nonce_error

/-- info: 'BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_hash_error' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_hash_error

/-- info: 'BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_unexpected_error' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_unexpected_error

/-- info: 'BitcoinProofs.Theorems.CapstoneWitness.witnessCommitmentOutput_values' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneWitness.witnessCommitmentOutput_values

/-- info: 'BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_values' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_values

/-- info: 'BitcoinProofs.Theorems.CapstoneWitness.validateBlock_witness' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneWitness.validateBlock_witness

/-- info: 'BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_coinbase_values' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneWitness.checkWitnessCommitment_coinbase_values

end BitcoinProofs.Theorems.CapstoneWitness
