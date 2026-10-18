import Bitcoin.Invariants.RC12

/-! # PDW58A.lean — TOP-311: INV-134 BIP113 MTP cutoff gate
(PDW58, RC29). Row face for `Bitcoin.Invariants.RC12.bip113Cutoff`
(validation.cpp:4141-4150 @ cce32b168). Route B: zero core writes. -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Invariants.RC12

/-- INV-134 (active face): once the CSV deployment height is reached, the
finality cutoff is exactly the previous block's median-time-past. -/
@[rule "INV-134"]
theorem bip113Cutoff_mtp_of_active (height blockTime prevMtp : UInt32)
    (h : Bitcoin.Activation.CSV_HEIGHT ≤ height) :
    bip113Cutoff height blockTime prevMtp = prevMtp := by
  unfold bip113Cutoff
  rw [if_pos h]

/-- INV-134 (pre-deployment face): below CSV the cutoff is the block's own
wall-clock time, never the previous MTP. -/
@[rule "INV-134"]
theorem bip113Cutoff_time_of_pre (height blockTime prevMtp : UInt32)
    (h : ¬ Bitcoin.Activation.CSV_HEIGHT ≤ height) :
    bip113Cutoff height blockTime prevMtp = blockTime := by
  unfold bip113Cutoff
  rw [if_neg h]

/-- INV-134 (exact branch characterization): the cutoff is the previous MTP
iff the height is at/above the buried CSV height. -/
@[rule "INV-134"]
theorem bip113Cutoff_eq_mtp_iff (height blockTime prevMtp : UInt32)
    (hne : blockTime ≠ prevMtp) :
    bip113Cutoff height blockTime prevMtp = prevMtp ↔
      Bitcoin.Activation.CSV_HEIGHT ≤ height := by
  constructor
  · intro h
    by_cases ha : Bitcoin.Activation.CSV_HEIGHT ≤ height
    · exact ha
    · rw [bip113Cutoff_time_of_pre height blockTime prevMtp ha] at h
      exact absurd h hne
  · exact bip113Cutoff_mtp_of_active height blockTime prevMtp

/-- INV-134 (boundary pin): activation is inclusive at 419328; the last
pre-CSV block (419327) still uses its own time. -/
@[rule "INV-134"]
theorem bip113Cutoff_boundary :
    bip113Cutoff 419328 1000 900 = 900 ∧
    bip113Cutoff 419327 1000 900 = 1000 := by
  constructor
  · exact bip113Cutoff_mtp_of_active _ _ _ (by decide)
  · exact bip113Cutoff_time_of_pre _ _ _ (by decide)

/-- INV-134 (grid): the three-height cross-check vector. -/
@[rule "INV-134"]
theorem bip113Cutoff_grid :
    bip113Cutoff 419327 1000 900 = 1000 ∧
    bip113Cutoff 419328 1000 900 = 900 ∧
    bip113Cutoff 500000 1000 900 = 900 :=
  bip113Cutoff_vector

end BitcoinProofs.AF.PDW58
