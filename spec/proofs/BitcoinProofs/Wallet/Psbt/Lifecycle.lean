import BitcoinProofs.Wallet.Psbt.RoundTrip

/-!
# PSBT v0 — lifecycle and ownership laws

This module complements `Bitcoin.Wallet.Psbt.Laws` with the lifecycle
facts used by the round-trip proof and by callers that finalize and
extract a PSBT:

* the exact field projections of `fillTxIn` / `fillTx` (scriptSig,
  prevout, sequence, witness stacks, counts);
* the witness and scriptSig of an extracted transaction;
* that extraction depends only on the unsigned transaction and the
  input maps — the global xpub/unknown fields and the output maps are
  irrelevant, which is the ownership boundary of `FinalizeAndExtractPSBT`
  (`src/psbt.cpp:818-836`);
* the fields that `finalizeInput` removes and those it preserves.

## What is NOT claimed

`extract` is not claimed to produce a consensus-valid transaction: no
signature is verified and no fee/script policy is applied.  These are
structural laws about the model's data flow, matching the module
docstrings in `Bitcoin.Wallet.Psbt.Model`.
-/

namespace BitcoinProofs.Wallet.Psbt

open Bitcoin.Data
open Bitcoin.Serialization
open Bitcoin.Wallet.Psbt

/-! ## Field projections of finalization -/

/-- `fillTxIn` writes exactly the finalized scriptSig (or the unsigned
one when no final scriptSig is present). -/
theorem fillTxIn_scriptSig (ti : TxIn) (i : PsbtInput) :
    (fillTxIn ti i).scriptSig.bytes
      = i.finalScriptSig.getD ti.scriptSig.bytes := rfl

/-- `fillTxIn` preserves the outpoint. -/
theorem fillTxIn_prevout (ti : TxIn) (i : PsbtInput) :
    (fillTxIn ti i).prevout = ti.prevout := rfl

/-- `fillTxIn` preserves the sequence number. -/
theorem fillTxIn_sequence (ti : TxIn) (i : PsbtInput) :
    (fillTxIn ti i).sequence = ti.sequence := rfl

/-- `fillTxIn` changes only the scriptSig. -/
theorem fillTxIn_eq (ti : TxIn) (i : PsbtInput) :
    fillTxIn ti i
      = { ti with scriptSig := ⟨i.finalScriptSig.getD ti.scriptSig.bytes⟩ } := rfl

/-! ## Field projections of extraction -/

/-- The extracted transaction has one witness stack per input map. -/
theorem fillTx_witness (tx : Tx) (ins : List PsbtInput) :
    (fillTx tx ins).witness
      = ins.map (fun i => i.finalScriptWitness.getD []) := rfl

/-- The extracted transaction's witness list has the input-map length. -/
theorem fillTx_witness_length (tx : Tx) (ins : List PsbtInput) :
    (fillTx tx ins).witness.length = ins.length := by
  rw [fillTx_witness, List.length_map]

/-- `fillTx` keeps the smaller of the input count and the input-map
count (it zips them). -/
theorem fillTx_vin_length (tx : Tx) (ins : List PsbtInput) :
    (fillTx tx ins).vin.length = min tx.vin.length ins.length := by
  simp [fillTx, List.length_zipWith]

/-- `fillTx` keeps the number of outputs. -/
theorem fillTx_vout_length (tx : Tx) (ins : List PsbtInput) :
    (fillTx tx ins).vout.length = tx.vout.length := rfl

/-- The version of an extracted transaction is the unsigned version. -/
theorem extract_version (p : Psbt) (tx : Tx) (h : extract p = some tx) :
    tx.version = p.global.unsignedTx.version := by
  unfold extract at h
  split at h
  · simp only [Option.some.injEq] at h
    subst h
    rfl
  · simp at h

/-- The locktime of an extracted transaction is the unsigned locktime. -/
theorem extract_locktime (p : Psbt) (tx : Tx) (h : extract p = some tx) :
    tx.locktime = p.global.unsignedTx.locktime := by
  unfold extract at h
  split at h
  · simp only [Option.some.injEq] at h
    subst h
    rfl
  · simp at h

/-- The witness stacks of an extracted transaction are exactly the
input maps' finalized witness stacks. -/
theorem extract_witness (p : Psbt) (tx : Tx) (h : extract p = some tx) :
    tx.witness = p.inputs.map (fun i => i.finalScriptWitness.getD []) := by
  unfold extract at h
  split at h
  · simp only [Option.some.injEq] at h
    subst h
    exact fillTx_witness _ _
  · simp at h

/-- The prevouts of an extracted transaction are the unsigned prevouts,
provided the input-map count matches (as `WellFormed` requires). -/
theorem extract_prevouts (p : Psbt) (tx : Tx) (h : extract p = some tx)
    (hlen : p.inputs.length = p.global.unsignedTx.vin.length) :
    tx.vin.map (fun i => i.prevout)
      = p.global.unsignedTx.vin.map (fun i => i.prevout) := by
  have := extract_preserves_unsigned p tx h hlen
  exact this.2.2.2

/-- The outputs of an extracted transaction are the unsigned outputs. -/
theorem extract_vout (p : Psbt) (tx : Tx) (h : extract p = some tx) :
    tx.vout = p.global.unsignedTx.vout := by
  unfold extract at h
  split at h
  · simp only [Option.some.injEq] at h
    subst h
    rfl
  · simp at h

/-! ## Ownership: what extraction depends on -/

/-- Extraction depends on the unsigned transaction and the input maps
only.  The global xpub/unknown lists and the output maps never influence
the result. -/
theorem extract_irrel_global_outputs (tx : Tx) (xp : List XpubEntry)
    (gu : List RawKV) (xp' : List XpubEntry) (gu' : List RawKV)
    (ins : List PsbtInput) (outs outs' : List PsbtOutput) :
    extract { global := ⟨tx, xp, gu⟩, inputs := ins, outputs := outs }
      = extract { global := ⟨tx, xp', gu'⟩, inputs := ins, outputs := outs' } := rfl

/-- Extraction depends only on the unsigned transaction and the input
maps: two PSBTs with the same unsigned transaction and the same input
maps have the same extraction result. -/
theorem extract_irrel_other_fields (g g' : Global) (ins : List PsbtInput)
    (outs outs' : List PsbtOutput) (h : g.unsignedTx = g'.unsignedTx) :
    extract { global := g, inputs := ins, outputs := outs }
      = extract { global := g', inputs := ins, outputs := outs' } := by
  obtain ⟨tx, xp, gu⟩ := g
  obtain ⟨tx', xp', gu'⟩ := g'
  simp only at h
  subst h
  rfl

/-- Finalization of one input is independent of the other maps. -/
theorem finalizeInput_local (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) (tx : Tx) (xp : List XpubEntry)
    (gu : List RawKV) (outs : List PsbtOutput) :
    extract { global := ⟨tx, xp, gu⟩, inputs := [finalizeInput i scriptSig witness],
              outputs := outs }
      = extract { global := ⟨tx, xp, gu⟩, inputs := [finalizeInput i scriptSig witness],
                  outputs := [] } := rfl

/-! ## Fields removed and preserved by finalization -/

/-- `finalizeInput` clears every signing field that the writer's
finalized branch suppresses: partial signatures, sighash type, redeem
and witness scripts, BIP 32 derivations, and all taproot signing fields.
(Preimages are preserved by `finalizeInput`; they are not part of
`hasSigningData` and are outside the row modelled by this predicate.) -/
theorem finalizeInput_hasSigningData_false (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) :
    hasSigningData (finalizeInput i scriptSig witness) = false := by
  simp [hasSigningData, finalizeInput]

/-- A finalized input is signed exactly when the supplied final
scriptSig or witness stack is non-empty. -/
theorem finalizeInput_inputSigned (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) :
    inputSigned (finalizeInput i scriptSig witness)
      = (!scriptSig.isEmpty || !witness.isEmpty) := by
  by_cases hs : scriptSig.isEmpty <;> by_cases hw : witness.isEmpty <;>
    simp [inputSigned, finalizeInput, hs, hw]

/-- Finalization preserves both UTXO fields together. -/
theorem finalizeInput_utxos (i : PsbtInput) (scriptSig : ByteArray)
    (witness : List ByteArray) :
    (finalizeInput i scriptSig witness).nonWitnessUtxo = i.nonWitnessUtxo
      ∧ (finalizeInput i scriptSig witness).witnessUtxo = i.witnessUtxo :=
  ⟨rfl, rfl⟩

/-- Finalization preserves the unsigned transaction's input count after
`fillTx` (it only touches a single input map). -/
theorem fillTx_finalizeInput_vin_length (tx : Tx) (i : PsbtInput)
    (scriptSig : ByteArray) (witness : List ByteArray) (ins : List PsbtInput)
    (h : tx.vin.length ≤ (finalizeInput i scriptSig witness :: ins).length) :
    (fillTx tx (finalizeInput i scriptSig witness :: ins)).vin.length
      = tx.vin.length := by
  rw [fillTx_vin_length]
  omega

end BitcoinProofs.Wallet.Psbt
