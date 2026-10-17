import Bitcoin.Invariants.RC02
import Bitcoin.TxValidation.Interface

/-! # PDW48 — TOP-161..165, BIP113 × BIP68 finality band (part 1)

INV-015 (BIP113 cutoff) and INV-016 (block-level finality quantifier),
with the Core-facing composition: monotonicity of `IsFinalTx` in the
time cutoff. Route B (zero core writes). -/

namespace BitcoinProofs.AF.PDW48

open Bitcoin.Data Bitcoin.DataLaws
open Bitcoin.Invariants.RC02

/-- INV-015: both arms of the BIP113 cutoff switch. -/
@[rule "INV-015"]
theorem bip113Cutoff_switch (csv : Bool) (mtp blockTime : UInt32) :
    bip113Cutoff csv mtp blockTime = if csv then mtp else blockTime := rfl

/-- INV-015: the cutoff never leaves the supplied pair. -/
@[rule "INV-015"]
theorem bip113Cutoff_mem' (csv : Bool) (mtp blockTime : UInt32) :
    bip113Cutoff csv mtp blockTime = mtp ∨
      bip113Cutoff csv mtp blockTime = blockTime :=
  bip113Cutoff_mem csv mtp blockTime

/-- `IsFinalTx` is monotone in the time cutoff (the reason BIP113 can only
make finality stricter: MTP(prev) may be earlier than the block time). -/
theorem isFinalTx_mono_cutoff (tx : Tx) (height c c' : UInt32) (hc : c ≤ c')
    (h : isFinalTx tx height c = true) : isFinalTx tx height c' = true := by
  rw [isFinalTx_iff] at h ⊢
  rcases h with h0 | hlt | hs
  · exact Or.inl h0
  · have hlt' : tx.locktime <
        (if locktimeIsTimeDomain tx.locktime then c' else height) := by
      by_cases hd : locktimeIsTimeDomain tx.locktime = true
      · simp only [hd, ite_true] at hlt ⊢
        exact UInt32.lt_iff_toNat_lt.mpr (by
          have h1 := UInt32.le_iff_toNat_le.mp hc
          have h2 := UInt32.lt_iff_toNat_lt.mp hlt
          omega)
      · have hdf : locktimeIsTimeDomain tx.locktime = false := by
          cases hb : locktimeIsTimeDomain tx.locktime with
          | true => exact absurd hb hd
          | false => rfl
        simp only [hdf] at hlt ⊢
        exact hlt
    exact Or.inr (Or.inl hlt')
  · exact Or.inr (Or.inr hs)

/-- INV-015: BIP113 finality sandwich — a tx final at the (at most as
late) cutoff is final at the block's own time. -/
@[rule "INV-015"]
theorem bip113_cutoff_finality_sandwich (tx : Tx) (height : UInt32) (csv : Bool)
    (mtp blockTime : UInt32) (hle : bip113Cutoff csv mtp blockTime ≤ blockTime)
    (h : isFinalTx tx height (bip113Cutoff csv mtp blockTime) = true) :
    isFinalTx tx height blockTime = true :=
  isFinalTx_mono_cutoff tx height _ blockTime hle h

/-- INV-016: the block gate decomposes at the head transaction. -/
@[rule "INV-016"]
theorem blockAllFinal_cons (t : Tx) (ts : List Tx) (height cutoff : UInt32) :
    blockAllFinal (t :: ts) height cutoff =
      (isFinalTx t height cutoff && blockAllFinal ts height cutoff) := by
  simp [blockAllFinal]

/-- INV-016: all txs final at the BIP113 cutoff ⇒ all final at the block
time (`bad-txns-nonfinal` inner-monotonicity). -/
@[rule "INV-016"]
theorem blockAllFinal_mono_cutoff (txs : List Tx) (height c c' : UInt32) (hc : c ≤ c')
    (h : blockAllFinal txs height c = true) : blockAllFinal txs height c' = true := by
  rw [blockAllFinal_iff] at h ⊢
  intro t ht
  exact isFinalTx_mono_cutoff t height c c' hc (h t ht)

/-- INV-016: one non-final tx poisons the block. -/
@[rule "INV-016"]
theorem blockAllFinal_nonfinal_poisons (txs : List Tx) (height cutoff : UInt32)
    (t : Tx) (ht : t ∈ txs) (hnf : isFinalTx t height cutoff = false) :
    blockAllFinal txs height cutoff = false :=
  blockAllFinal_fail_of_nonfinal txs height cutoff t ht hnf

end BitcoinProofs.AF.PDW48
