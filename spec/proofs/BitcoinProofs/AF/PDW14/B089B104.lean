import Bitcoin.Capstone.Block
import Bitcoin.Block.Connect

/-! # B089 + B104 — PDW14, rows BLK-089 (TOP-68) + BLK-104 (TOP-70).
`Bitcoin.Block.Connect.cbAmountOk` (Connect.lean:143) +
`blockSequenceLocksOk` (Connect.lean:115). S-evidence: core
`cbAmountOk_iff` (:148) + `blockSequenceLocksOk_all` (:121) /
PD02 Table-1 BT:347 (GenchainCor) + BT:354 (Bip68Coverage) —
restated on the PDW14 tags (+ the P10 fail-lane for BLK-104). -/

namespace BitcoinProofs.AF.PDW14

open Bitcoin.Data Bitcoin.DataLaws Bitcoin.Consensus Bitcoin.TxValidation
open Bitcoin.Ledger Bitcoin.Conservation
open Bitcoin.Capstone.Pow Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle
open Bitcoin.Block.Connect

/-! ## BLK-089: `bad-cb-amount` iff-pin (validation.cpp:2608-2612) —
the coinbase's total output value must not exceed fees + subsidy. -/
@[rule "BLK-089"]
theorem cbAmountOk_iff (cb : Tx) (fees : Amount) (height : UInt32) :
    cbAmountOk cb fees height = true ↔
      cb.getValueOut ≤ fees + blockSubsidy height := by
  simp [cbAmountOk, coinbaseRewardOk]

/-! ## BLK-104: BIP68 block aggregation (validation.cpp:2525-2538) —
per-tx exemption-or-lock ⇒ block gate passes. -/
@[rule "BLK-104"]
theorem blockSequenceLocksOk_all (txs : List Tx) (csvFlag : Bool)
    (prevDataOf : Tx → List (Int × Int)) (blockHeight blockMTP : Int)
    (hall : ∀ t ∈ txs, t.isCoinBase = true ∨
      sequenceLocksOk t csvFlag (prevDataOf t) blockHeight blockMTP = true) :
    blockSequenceLocksOk txs csvFlag prevDataOf blockHeight blockMTP = true := by
  unfold blockSequenceLocksOk
  apply List.all_eq_true.mpr
  intro t tm
  rcases hall t tm with hcb | hok
  · rw [hcb]; rfl
  · simp [hok]

/-! ## BLK-104 reject-lane (P10 two-way): one non-exempt unsatisfied tx
⇒ the block gate fails. -/
@[rule "BLK-104"]
theorem blockSequenceLocksOk_fail (txs : List Tx) (csvFlag : Bool)
    (prevDataOf : Tx → List (Int × Int)) (blockHeight blockMTP : Int)
    (tx : Tx) (htm : tx ∈ txs)
    (hcb : tx.isCoinBase = false) (hc : csvFlag = true)
    (hbad : sequenceLocksOk tx csvFlag (prevDataOf tx) blockHeight blockMTP = false) :
    blockSequenceLocksOk txs csvFlag prevDataOf blockHeight blockMTP = false := by
  unfold blockSequenceLocksOk
  rcases Bool.eq_false_or_eq_true
      (txs.all (fun t => t.isCoinBase || !csvFlag ||
        sequenceLocksOk t csvFlag (prevDataOf t) blockHeight blockMTP)) with h | h
  · exfalso
    have hx := (List.all_eq_true.mp h) tx htm
    rw [hcb, hc] at hx
    simp only [Bool.false_or, Bool.not_true] at hx
    rw [hc] at hbad
    rw [hx] at hbad
    exact Bool.noConfusion hbad
  · exact h

/-- BLK-104: the block gate is exactly the pointwise condition — CSV off,
or every tx either is a coinbase or is BIP68-final against the entry data
of the coins it spends. -/
@[rule "BLK-104"]
theorem blockSequenceLocksOk_iff (txs : List Tx) (csvFlag : Bool)
    (prevDataOf : Tx → List (Int × Int)) (blockHeight blockMTP : Int) :
    blockSequenceLocksOk txs csvFlag prevDataOf blockHeight blockMTP = true ↔
      ∀ t ∈ txs, t.isCoinBase = true ∨ csvFlag = false ∨
        sequenceLocksOk t csvFlag (prevDataOf t) blockHeight blockMTP = true := by
  unfold blockSequenceLocksOk
  rw [List.all_eq_true]
  constructor
  · intro h t ht
    have hx := h t ht
    by_cases hcb : t.isCoinBase = true
    · exact Or.inl hcb
    · have hcb' : t.isCoinBase = false := Bool.eq_false_iff.mpr hcb
      rw [hcb'] at hx
      by_cases hc : csvFlag = true
      · rw [hc] at hx
        simp only [Bool.false_or, Bool.not_true] at hx
        exact Or.inr (Or.inr (by simpa [hc] using hx))
      · exact Or.inr (Or.inl (by cases csvFlag <;> simp_all))
  · intro h t ht
    rcases h t ht with hcb | hc | hok
    · rw [hcb]; rfl
    · simp [hc]
    · rw [hok]; simp

/-- BLK-104, full row: the block gate holds iff every transaction is a
coinbase, or BIP68 is disabled for it, or its spent coins' entry heights
and times satisfy the height- and time-domain sequence locks at the
block's `(height, MTP)`. This composes the block aggregation with
`sequenceLocksOk_iff` (tx_verify.cpp:45-121). -/
@[rule "BLK-104"]
theorem blockSequenceLocksOk_spec (txs : List Tx) (csvFlag : Bool)
    (prevDataOf : Tx → List (Int × Int)) (blockHeight blockMTP : Int)
    (hH : 0 ≤ blockHeight) (hT : 0 ≤ blockMTP) :
    blockSequenceLocksOk txs csvFlag prevDataOf blockHeight blockMTP = true ↔
      ∀ t ∈ txs, t.isCoinBase = true ∨
        Bitcoin.DataLaws.bip68Enabled t.version csvFlag = false ∨
        (vinHeightOk t.vin (prevDataOf t) blockHeight ∧
          vinTimeOk t.vin (prevDataOf t) blockMTP) := by
  rw [blockSequenceLocksOk_iff]
  constructor
  · intro h t ht
    rcases h t ht with hcb | hc | hok
    · exact Or.inl hcb
    · exact Or.inr (Or.inl (by rw [hc]; simp [Bitcoin.DataLaws.bip68Enabled]))
    · rcases (sequenceLocksOk_iff t csvFlag (prevDataOf t) blockHeight blockMTP hH hT).mp hok
        with hdis | hspec
      · exact Or.inr (Or.inl hdis)
      · exact Or.inr (Or.inr hspec)
  · intro h t ht
    rcases h t ht with hcb | hdis | hspec
    · exact Or.inl hcb
    · exact Or.inr (Or.inr
        ((sequenceLocksOk_iff t csvFlag (prevDataOf t) blockHeight blockMTP hH hT).mpr
          (Or.inl hdis)))
    · exact Or.inr (Or.inr
        ((sequenceLocksOk_iff t csvFlag (prevDataOf t) blockHeight blockMTP hH hT).mpr
          (Or.inr hspec)))

/-- BLK-104: the ConnectBlock composition (validation.cpp:2378-2630; the
BIP68 test is at 2525-2538). The block sequence-lock gate is a conjunct
of the connection verdict, so a failing non-exempt tx rejects the block
at connection time — the enforcement locus the audit found unmodelled. -/
def connectBlockChecks (txs : List Tx) (cb : Tx) (l : List (OutPoint × Coin))
    (kf : Tx → Key) (height cutoff : UInt32) (csvFlag : Bool)
    (prevDataOf : Tx → List (Int × Int)) (blockMTP : Int) : Bool :=
  blockSequenceLocksOk txs csvFlag prevDataOf (height.toNat : Int) blockMTP &&
    connectChecks txs cb l kf height cutoff

/-- BLK-104: a failing block sequence-lock gate forces the ConnectBlock
verdict false. -/
@[rule "BLK-104"]
theorem connectBlockChecks_seqLocks_reject (txs : List Tx) (cb : Tx)
    (l : List (OutPoint × Coin)) (kf : Tx → Key) (height cutoff : UInt32)
    (csvFlag : Bool) (prevDataOf : Tx → List (Int × Int)) (blockMTP : Int)
    (h : blockSequenceLocksOk txs csvFlag prevDataOf (height.toNat : Int) blockMTP = false) :
    connectBlockChecks txs cb l kf height cutoff csvFlag prevDataOf blockMTP = false := by
  unfold connectBlockChecks
  rw [h]
  rfl

end BitcoinProofs.AF.PDW14
