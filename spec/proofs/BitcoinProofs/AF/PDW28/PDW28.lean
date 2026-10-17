import Bitcoin.Block.Connect
import Bitcoin.Block.Pow

/-! # PDW28 — proof-promotion review RC22 continuation, items TOP-136..140

D-POW / D-CONNECT continuation of the 268-S-mass c-true head (claim
`7e7517e`, recovered post model-rotation from the glm claim WIP).
Route B (PDW12/PDW16/PDW32 pattern): zero core writes, tags ride MY
theorems, pins ⊆ [propext, Classical.choice, Quot.sound].

* **BLK-023** `vtxCountWeightOk` (Connect.lean:58, CheckBlock:3955):
  the count·4 ≤ MAX_BLOCK_WEIGHT gate iff + the ≤1,000,000 bound +
  absurd-count reject.
* **BLK-040** `powLimitMainnet` (Pow.lean:62): 0xFFFF·256^26 pin.
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

@[rule "BLK-040"]
theorem powLimitMainnet_pin : powLimitMainnet = 0xffff * 256 ^ 26 := by decide

/-- BLK-040 (corrected mainnet proof-of-work limit).  Core
`kernel/chainparams.cpp:126 @cce32b168` pins
`consensus.powLimit = uint256{"00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"}`
(and testnet at :257 has the same value) — the full 224-bit all-ones
target `2^224 - 1`, not the compact `0xffff * 256^26` value in
`powLimitMainnet`.  The old definition is left untouched; this is the
faithful constant the row summary spells out. -/
@[rule "BLK-040"] def powLimitMainnetFull : Nat :=
  0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff

/-- BLK-040 value pin: the corrected constant is exactly Core's literal
`00000000ffff…ff`, i.e. `2^224 - 1`. -/
@[rule "BLK-040"]
theorem powLimitMainnetFull_pin :
    powLimitMainnetFull =
      0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff ∧
    powLimitMainnetFull = 2 ^ 224 - 1 :=
  ⟨rfl, by decide⟩

/-- BLK-040 divergence witness: `powLimitMainnet` (the old compact
constant `0xffff * 256^26`, with 26 trailing zero bytes) is NOT the
mainnet powLimit. -/
theorem powLimitMainnet_not_full :
    powLimitMainnet ≠ powLimitMainnetFull := by decide

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
