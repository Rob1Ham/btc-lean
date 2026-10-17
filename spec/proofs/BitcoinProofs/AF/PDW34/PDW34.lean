import Bitcoin.Serialization.Interface
import Bitcoin.SigHash.Digest
import Bitcoin.Consensus.TxCheck

/-! # PDW34.lean — proof-promotion review RC27, items TOP-166..170
(PDW34, 2026-10-17). Claim 4307fe1.

BIP144 witness-framing band of `Bitcoin/Serialization/Interface.lean`
(`UnserializeTransaction`, primitives/transaction.h:201-239) plus the
BIP143 SHA256d digest seam pin in `Bitcoin/SigHash/Digest.lean`.

Route B (PDW27-SCR-103 / PDW32 precedent): zero core writes, proofs-side
row-face theorems only, pins ⊆ [propext, Classical.choice, Quot.sound].

Witness records below are the minimal well-formed skeleton
`version=1 ‖ 00 ‖ flag ‖ vin=[] ‖ vout=[]` (the counts are canonical
CompactSize 0); the trailing `X` is arbitrary, so the reject lanes hold
for every suffix — the decoder never gets to read it. -/

namespace BitcoinProofs.AF.PDW34

open Bitcoin.Serialization Bitcoin.Data

/-! ## SWT-038: dummy 0x00 marker then 0x01 flag -/

/-- SWT-038 (transaction.h:217-229): a witness tx is encoded as
`version ‖ 0x00 0x01 ‖ vin ‖ vout ‖ witness ‖ locktime` — the dummy
CompactSize-0 marker followed by flag 0x01. -/
@[rule "SWT-038"]
theorem encTxL_witness_marker_flag (tx : Bitcoin.Data.Tx)
    (h : hasWitness tx = true) :
    encTxL tx = encU32L tx.version.toUInt32 ++ [0x00, 0x01]
      ++ encCSL tx.vin.length ++ tx.vin.flatMap (fun i => bL (serTxIn i))
      ++ encCSL tx.vout.length ++ tx.vout.flatMap (fun o => bL (serTxOut o))
      ++ encStacksL tx ++ encU32L tx.locktime := by
  simp [encTxL, h]

/-! ## SWT-039 / SWT-040 / TXV-016: the flag byte failure lanes -/

/-- SWT-039 (transaction.h:234-238): flag 0x01 with every witness stack
empty is the superfluous-witness serialization error. -/
@[rule "SWT-039"]
theorem decTxCore_flag_one_superfluous (X : Bytes) :
    decTxCore ([1, 0, 0, 0, 0, 1, 0, 0] ++ X) = .error .superfluousWitness := by
  simp [decTxCore, decU32L, decCS, decU8L, decVinL, decN]

/-- SWT-040: an even flag byte other than 0/1 carries a future-flag bit
⇒ `.unknownFlag` (the witness path is not even entered). -/
@[rule "SWT-040"]
theorem decTxCore_flag_even_unknown (f : UInt8) (X : Bytes)
    (hf : f.toNat % 2 = 0) (h0 : f ≠ 0) :
    decTxCore ([1, 0, 0, 0, 0] ++ [f, 0, 0] ++ X) = .error .unknownFlag := by
  simp [decTxCore, decU32L, decCS, decU8L, decVinL, decN, hf, h0,
    show f ≠ 1 from by intro h; subst h; simp at hf]

/-- SWT-040 partner: an odd flag > 1 parses the (all-empty) witness
record first and is rejected as superfluous (transaction.h:234-238). -/
theorem decTxCore_flag_odd_superfluous (f : UInt8) (X : Bytes)
    (hf : f.toNat % 2 = 1) :
    decTxCore ([1, 0, 0, 0, 0] ++ [f, 0, 0] ++ X) = .error .superfluousWitness := by
  have h0 : f ≠ 0 := by intro h; subst h; simp at hf
  simp [decTxCore, decU32L, decCS, decU8L, decVinL, decN, hf, h0]

/-- TXV-016: every flag byte outside {0,1} is a hard decode failure
(future witness flags are hardforks, transaction.h:231-239). -/
@[rule "TXV-016"]
theorem decTxCore_flag_not_one_error (f : UInt8) (X : Bytes)
    (h0 : f ≠ 0) (_h1 : f ≠ 1) :
    ∃ e, decTxCore ([1, 0, 0, 0, 0] ++ [f, 0, 0] ++ X) = .error e := by
  by_cases hp : f.toNat % 2 = 1
  · exact ⟨.superfluousWitness, decTxCore_flag_odd_superfluous f X hp⟩
  · have he : f.toNat % 2 = 0 := by
      have hlt : f.toNat % 2 < 2 := Nat.mod_lt _ (by decide)
      omega
    exact ⟨.unknownFlag, decTxCore_flag_even_unknown f X he h0⟩

/-! ## SWT-052: BIP143 digest and sub-hashes are SHA256d -/

/-- SWT-052 (HashWriter::GetHash, hash.h:82-87): `dshaL` is exactly the
seam double-SHA256 of the list-vehicle preimage. -/
@[rule "SWT-052"]
theorem dshaL_is_sha256d (l : Bytes) :
    Bitcoin.SigHash.dshaL l = Bitcoin.Crypto.Seam.sha256d (bytesOfList l) := rfl

/-- The consensus digest is fixed-width: 32 bytes. -/
theorem dshaL_size (l : Bytes) : (Bitcoin.SigHash.dshaL l).size = 32 := by
  unfold Bitcoin.SigHash.dshaL
  exact Bitcoin.Crypto.Seam.sha256d_size _

/-- BIP143 digest in range is the SHA256d of the 10-field preimage. -/
theorem signatureHashBip143_dshaL (tx : Bitcoin.Data.Tx) (nIn : Nat)
    (scriptCode : Bytes) (ht : UInt32) (amount : Amount)
    (h : nIn < tx.vin.length) :
    Bitcoin.SigHash.signatureHashBip143Impl tx nIn scriptCode ht amount =
      Bitcoin.SigHash.dshaL (Bitcoin.SigHash.bip143MsgL tx nIn scriptCode ht amount) := by
  simp [Bitcoin.SigHash.signatureHashBip143Impl, Nat.not_le.mpr h]

/-- BIP143 `hashPrevouts` outside ANYONECANPAY is a SHA256d sub-hash. -/
theorem hashPrevoutsL_dshaL (tx : Bitcoin.Data.Tx) (ht : UInt32)
    (h : Bitcoin.SigHash.htAcp ht = false) :
    Bitcoin.SigHash.hashPrevoutsL tx ht =
      bL (Bitcoin.SigHash.dshaL
        (tx.vin.foldl (fun acc i => acc ++ Bitcoin.SigHash.serOutpointL i.prevout) [])) := by
  simp [Bitcoin.SigHash.hashPrevoutsL, h]

/-! ## BLK-032: the 4M stripped-size bound (`bad-txns-oversize`) -/

/-- BLK-032 (`tx_check.cpp:27-29` CheckTransaction @cce32b168): the stateless
oversize gate is the STRIPPED transaction size times `WITNESS_SCALE_FACTOR`
(witness data and the BIP144 marker/flag are excluded —
`GetSerializeSize(TX_NO_WITNESS(tx)) * 4`). This restates the old
`txWeightL` face against the current `txStrippedWeightL` gate (F-TS04
segwit repair); the BIP141 `txWeightL` metric is not what this check reads. -/
@[rule "BLK-032"]
theorem checkTransaction_none_weight (tx : Bitcoin.Data.Tx)
    (h : Bitcoin.Consensus.checkTransaction tx = none) :
    Bitcoin.Consensus.txStrippedWeightL tx ≤ Bitcoin.Consensus.MAX_BLOCK_WEIGHT := by
  unfold Bitcoin.Consensus.checkTransaction at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · by_cases hw : Bitcoin.Consensus.MAX_BLOCK_WEIGHT < Bitcoin.Consensus.txStrippedWeightL tx
      · simp [hw] at h
      · omega

/-- BLK-032 row face: a statelessly-accepted transaction has
`stripped_size × 4 ≤ 4,000,000` (`bad-txns-oversize` gate). -/
@[rule "BLK-032"]
theorem checkTransaction_none_stripped_size (tx : Bitcoin.Data.Tx)
    (h : Bitcoin.Consensus.checkTransaction tx = none) :
    Bitcoin.Data.serTxSize tx * 4 ≤ 4000000 := by
  have h' := checkTransaction_none_weight tx h
  simpa [Bitcoin.Consensus.txStrippedWeightL, Bitcoin.Consensus.MAX_BLOCK_WEIGHT,
    Bitcoin.Consensus.WITNESS_SCALE_FACTOR] using h'

/-- BLK-032 reject lane: an over-STRIPPED-weight tx (with non-empty vin/vout,
so the earlier checks do not pre-empt it) is exactly `bad-txns-oversize`. -/
@[rule "BLK-032"]
theorem checkTransaction_oversize (tx : Bitcoin.Data.Tx)
    (hv : tx.vin ≠ []) (hvo : tx.vout ≠ [])
    (h : Bitcoin.Consensus.MAX_BLOCK_WEIGHT < Bitcoin.Consensus.txStrippedWeightL tx) :
    Bitcoin.Consensus.checkTransaction tx = some .oversize := by
  unfold Bitcoin.Consensus.checkTransaction
  simp [hv, hvo, h]

/-! ## SWT-039: every all-empty witness stack set is superfluous -/

/-- An empty witness stack is the single zero CompactSize count byte. -/
theorem decStackL_empty (r : Bytes) :
    decStackL ((0x00 : UInt8) :: r) = .ok ([], r) := by
  simp [decStackL, decCS_zero, decN]

/-- SWT-039 (transaction.h:229-232): a flag-`0x01` extended serialization
whose `vin.length` witness stacks are ALL empty is rejected with
`superfluousWitness`, for arbitrary `vin`/`vout` counts, version and
locktime — not merely the fixed vin=0/vout=0 header of
`decTxCore_flag_one_superfluous`. The witness region is the canonical
BIP144 encoding of `vin.length` empty stacks. -/
@[rule "SWT-039"]
theorem decTxCore_flag_one_all_stacks_empty
    (v lt : UInt32) (vin : List TxIn) (vout : List TxOut) (rest : Bytes)
    (hvin : ∀ i ∈ vin, i.prevout.hash.size = 32 ∧
      i.scriptSig.bytes.size ≤ Bitcoin.Serialization.MAX_SIZE)
    (hvout : ∀ o ∈ vout, o.scriptPubKey.bytes.size ≤ Bitcoin.Serialization.MAX_SIZE
      ∧ 0 ≤ o.value ∧ o.value < 9223372036854775808)
    (hvc : vin.length ≤ Bitcoin.Serialization.MAX_SIZE)
    (hvoc : vout.length ≤ Bitcoin.Serialization.MAX_SIZE) :
    decTxCore (encU32L v ++ ((0x00 : UInt8) :: (0x01 : UInt8) ::
      (encCSL vin.length ++ (vin.flatMap (fun i => bL (serTxIn i))
      ++ (encCSL vout.length ++ (vout.flatMap (fun o => bL (serTxOut o))
      ++ ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
      ++ (encU32L lt ++ rest)))))))) = .error .superfluousWitness := by
  have hstack : ∀ s ∈ (List.replicate vin.length ([] : List ByteArray)),
      ∀ r : Bytes, decStackL (encStackL s ++ r) = .ok (s, r) := by
    intro s hs r
    have hs' : s = [] := by
      simpa using (List.eq_of_mem_replicate hs)
    subst hs'
    rw [show encStackL ([] : List ByteArray) = [(0x00 : UInt8)] by rfl]
    exact decStackL_empty r
  have hw : decN decStackL vin.length
      ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
        ++ (encU32L lt ++ rest))
      = .ok (List.replicate vin.length [], (encU32L lt ++ rest)) := by
    simpa using (decN_enc (List.replicate vin.length ([] : List ByteArray)) hstack
      (encU32L lt ++ rest))
  unfold decTxCore
  simp only [decU32L_encU32L, bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU8L_cons]
  simp only [bindE_ok]
  rw [if_neg (by decide : ¬ ((0x01 : UInt8) = 0))]
  have hvinD : decVinL (encCSL vin.length ++ (vin.flatMap (fun i => bL (serTxIn i))
      ++ (encCSL vout.length ++ (vout.flatMap (fun o => bL (serTxOut o))
      ++ ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
      ++ (encU32L lt ++ rest))))))
      = .ok (vin, (encCSL vout.length ++ (vout.flatMap (fun o => bL (serTxOut o))
      ++ ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
      ++ (encU32L lt ++ rest))))) := by
    simp only [decVinL]
    rw [decCS_encCSL _ hvc]
    simp only [bindE_ok]
    exact decN_enc vin (fun i hi r => decTxInL_enc i r (hvin i hi).1 (hvin i hi).2) _
  rw [hvinD]
  simp only [bindE_ok]
  have hvoutD : decCS (encCSL vout.length ++ (vout.flatMap (fun o => bL (serTxOut o))
      ++ ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
      ++ (encU32L lt ++ rest))))
      = .ok (vout.length, (vout.flatMap (fun o => bL (serTxOut o))
      ++ ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
      ++ (encU32L lt ++ rest)))) :=
    decCS_encCSL _ hvoc _
  rw [hvoutD]
  simp only [bindE_ok]
  have hvoutN : decN decTxOutL vout.length
      (vout.flatMap (fun o => bL (serTxOut o))
        ++ ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
        ++ (encU32L lt ++ rest)))
      = .ok (vout, ((List.replicate vin.length ([] : List ByteArray)).flatMap encStackL
        ++ (encU32L lt ++ rest))) := by
    simpa using (decN_enc vout (fun o ho r =>
      decTxOutL_enc o r (hvout o ho).2.1 (hvout o ho).2.2 (hvout o ho).1) _)
  rw [hvoutN]
  simp only [bindE_ok]
  rw [if_pos (by decide : (0x01 : UInt8).toNat % 2 = 1)]
  rw [hw]
  simp only [bindE_ok]
  rw [if_pos (by simp)]

end BitcoinProofs.AF.PDW34
