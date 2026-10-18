import Bitcoin.Block.Connect
import Bitcoin.Block.Pow

/-! # PDW28 — RC22 continuation, items TOP-136..140

D-POW / D-CONNECT continuation of the 268-S-mass c-true head (claim
`7e7517e`, recovered post model-rotation from the glm claim WIP).
Route B (PDW12/PDW16/PDW32 pattern): zero core writes, tags ride MY
theorems, pins ⊆ [propext, Classical.choice, Quot.sound].

* **BLK-023** `vtxCountWeightOk` (Connect.lean:58, CheckBlock:3955):
  the count·4 ≤ MAX_BLOCK_WEIGHT gate iff + the ≤1,000,000 bound +
  absurd-count reject.
* **BLK-040** `powLimitMainnetFull` (Core chainparams): the all-ones
  `2^224 − 1` mainnet limit, now equal to the live `powLimitMainnet`;
  the distinct genesis target remains `2^224 − 2^208`.
* **BLK-041** `powLimitSignet` (Pow.lean:71) + `powLimitRegtest`
  (Pow.lean:75): signet 0x377ae·256^27 / regtest 2^255−1 pins.
* **BLK-051** `permittedDifficultyTransition` (Pow.lean:189,
  pow.cpp:132-134): in-period nBits-constancy (min-diff OFF) iff.
  YIELDED to PDW31 (TOP-154 landed f23d2fa); proofs kept as
  supplemental evidence, row not re-flipped by PDW28.
* **BLK-052** same def (pow.cpp:91): min-diff ON ⇒ always permitted.
* **BLK-053** `nextWorkRequired` (Pow.lean:162, pow.cpp:96-110):
  testnet min-diff slow gate ⇒ min-difficulty nBits, fast ⇒ walk-back.
-/

namespace BitcoinProofs.AF.PDW28

open Bitcoin.Block.Connect Bitcoin.Block.Pow

/-! ## BLK-023: the vtx-count pre-bound (validation.cpp:3955) -/

@[rule "BLK-023"]
theorem vtxCountWeightOk_eq (txs : List Bitcoin.Data.Tx) :
    vtxCountWeightOk txs = true ↔
      txs.length * 4 ≤ Bitcoin.Consensus.MAX_BLOCK_WEIGHT := by
  simp [vtxCountWeightOk]

/-- BLK-023: the bound fails exactly above 1,000,000 txs (the core
untagged twin `vtxCountWeightOk_iff` :64 restated). -/
theorem vtxCountWeightOk_bound (txs : List Bitcoin.Data.Tx) :
    vtxCountWeightOk txs = true ↔ txs.length ≤ 1_000_000 := by
  rw [vtxCountWeightOk_eq]
  unfold Bitcoin.Consensus.MAX_BLOCK_WEIGHT
  omega

/-- BLK-023 reject face: an absurd tx count is rejected. -/
theorem vtxCountWeightOk_reject (txs : List Bitcoin.Data.Tx)
    (h : 1_000_000 < txs.length) : vtxCountWeightOk txs = false := by
  cases hv : vtxCountWeightOk txs with
  | false => rfl
  | true =>
    rw [vtxCountWeightOk_bound] at hv
    omega

/-! ## BLK-040/041: the powLimit constant pins (chainparams.cpp) -/

/-- BLK-040: the live mainnet parameter is Core's full 224-bit limit. -/
theorem powLimitMainnet_pin : powLimitMainnet = 2 ^ 224 - 1 := by decide

/-- The distinct genesis target is the rounded difficulty-one magnitude. -/
theorem genesis_target_value :
    Bitcoin.Chain.compactTarget 0x1d00ffff = 2 ^ 224 - 2 ^ 208 := by decide

/-- Genesis nBits encodes difficulty one, not the full network limit. -/
theorem genesisBits_target_pin :
    Bitcoin.Chain.compactTarget 0x1d00ffff = 0xffff * 256 ^ 26 := by decide

/-- BLK-040: exact Core chainparams.cpp:126 full-limit literal. The live
core parameter is linked to this previously proof-local constant below. -/
@[rule "BLK-040"] def powLimitMainnetFull : Nat :=
  0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff

@[rule "BLK-040"]
theorem powLimitMainnetFull_pin :
    powLimitMainnetFull =
      0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff ∧
    powLimitMainnetFull = 2 ^ 224 - 1 :=
  ⟨rfl, by decide⟩

/-- Exact gap between the full limit and the rounded genesis target. -/
theorem powLimitMainnetFull_sub_genesis :
    powLimitMainnetFull - Bitcoin.Chain.compactTarget 0x1d00ffff = 2 ^ 208 - 1 := by decide

/-- The live retarget parameter now uses the full value pinned by the row. -/
theorem powLimitMainnet_eq_full : powLimitMainnet = powLimitMainnetFull := rfl

@[rule "BLK-041"]
theorem powLimitSignet_pin : powLimitSignet = 0x377ae * 256 ^ 27 := by decide

/-- BLK-041 companion: the same row covers regtest's 0x7fffff… limit. -/
theorem powLimitRegtest_pin : powLimitRegtest = 2 ^ 255 - 1 := by decide

/-! ## BLK-051/052: permitted difficulty transitions (pow.cpp:91-134) -/

/-- BLK-051 (pow.cpp:132-134): with the testnet min-difficulty rule OFF
and off a period boundary, the transition requires constant nBits. -/
@[rule "BLK-051"]
theorem permitted_nonboundary_eq (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32)
    (hmin : P.fPowAllowMinDifficultyBlocks = false)
    (hb : height % difficultyAdjustmentInterval P ≠ 0) :
    permittedDifficultyTransition P height oldBits newBits = (oldBits == newBits) := by
  unfold permittedDifficultyTransition
  rw [ite_eq_right (by simp [hmin])]
  rw [ite_eq_right (by simpa using hb)]

/-- BLK-051 reject face: changed nBits in-period is not permitted. -/
theorem permitted_mismatch_reject (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32)
    (hmin : P.fPowAllowMinDifficultyBlocks = false)
    (hb : height % difficultyAdjustmentInterval P ≠ 0)
    (hne : oldBits ≠ newBits) :
    permittedDifficultyTransition P height oldBits newBits = false := by
  rw [permitted_nonboundary_eq P height oldBits newBits hmin hb]
  simp [hne]

/-- BLK-052 (pow.cpp:91): the min-difficulty rule permits ANY transition. -/
@[rule "BLK-052"]
theorem permitted_mindiff_true (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32) (h : P.fPowAllowMinDifficultyBlocks = true) :
    permittedDifficultyTransition P height oldBits newBits = true := by
  simp [permittedDifficultyTransition, h]

/-! ## BLK-053: the testnet min-difficulty retarget (pow.cpp:96-110) -/

/-- BLK-053 slow face: off a period boundary, min-diff ON and a block
time > 2×spacing past the parent force the min-difficulty nBits. -/
@[rule "BLK-053"]
theorem nextWorkRequired_minDiff_slow (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hg : get lastHeight = some last)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hb : (lastHeight + 1) % difficultyAdjustmentInterval P ≠ 0)
    (hslow : newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime = some (getCompact P.powLimit) := by
  simp [nextWorkRequired, hg, hmin, hb, hslow]

/-- BLK-053 fast face: otherwise the walk-back supplies the nBits. -/
theorem nextWorkRequired_minDiff_fast (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hg : get lastHeight = some last)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hb : (lastHeight + 1) % difficultyAdjustmentInterval P ≠ 0)
    (hfast : ¬ newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime = minDiffWalkBack P get lastHeight := by
  simp [nextWorkRequired, hg, hmin, hb, hfast]
