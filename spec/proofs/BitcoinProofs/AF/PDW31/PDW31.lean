import Mathlib
import Bitcoin.Block.Pow

/-! # PDW31.lean

Twelve sorry-free promotion theorems over five claimed rules.yaml
rows:

* **BLK-043** `nextWorkRequired` (Block/Pow.lean:163) →
  `nextWorkRequired_retarget_boundary` (pow.cpp:56-59 retarget arm:
  boundary ⇒ = some (calculateNextWorkRequired …); the
  "retarget iff (height+1) mod 2016 == 0" gate-law — the copy arm
  = PDW12/BLK-042 `nextWorkRequired_nonboundary_const`, re-proved
  here as `_copy_nonboundary` for the row-face) plus the two
  min-difficulty branches that run first on testnet/regtest:
  `_nonboundary_minDifficulty_slow` (pow.cpp:28-35 → powLimit) and
  `_nonboundary_minDifficulty_fast` (pow.cpp:36-49 → walk-back).
* **BLK-045** `calculateNextWorkRequired` (Block/Pow.lean:123) →
  `calculateNextWorkRequired_clamp_low` + `_clamp_high` +
  `_clamp_mid` (pow.cpp:28-44: actualTimespan clamped to
  [T/4, 4T], T = 1209600 s).
* **BLK-048** `calculateNextWorkRequired` →
  `calculateNextWorkRequired_capped_target` (pow.cpp:81-82: the
  pre-encoding new target is capped at powLimit — min-face +
  never-exceeds bound) + `calculateNextWorkRequired_encoded_capped`
  (the same cap survives the `GetCompact` re-encode:
  `compactTarget (getCompact t) ≤ t` for `t < 2^256`) +
  `calculateNextWorkRequired_copy_noRetarget` (BLK-049 bypass
  companion).
* **BLK-051** `permittedDifficultyTransition` (Block/Pow.lean:190)
  → `permittedDifficultyTransition_nonboundary` (pow.cpp:118-134
  non-boundary arm: bits constant within a period —
  accept ↔ oldBits = newBits).
* **BLK-056** `medianTimePast` (Block/Pow.lean:231) →
  `medianTimePast_eleven_some` + `medianTimePast_congr` +
  `medianTimePast_none` (chain.h:233-244: 11-present ⇒ defined;
  median depends only on the h−10..h window; empty ⇒ none). The
  module-private `sortBy` is unnameable at this layer, so the
  exact sorted-median value is not statable outside `core`.

Route B (PDW11/PDW12/PDW16 pattern): zero core writes, theorems
over the exact core gates, tags `@[rule "row"]` ride these decls.
The module is deliberately NOT imported by the `BitcoinProofs`
root (PDW5/PDW12-AF isolation pattern) — own-target built,
outside `core/**`. -/

namespace BitcoinProofs.AF.PDW31

open Bitcoin.Block.Pow

/-! ## BLK-043 — `nextWorkRequired` (pow.cpp:20-59): retarget iff
`(height+1) % interval == 0`; else copy prev nBits (pow.cpp:74-80).

Boundary arm (pow.cpp:56-59): at a retarget boundary, with both
the last node and the window anchor `interval−1` below it
resolved, the result IS `calculateNextWorkRequired` (Base-BIP94
via `lastBits`/`firstBits`; powLimit cap + [T/4,4T] clamp live
inside, BLK-045/048). Mainnet copy-arm (pow.cpp:74-80,
`fPowAllowMinDifficultyBlocks = false`: non-boundary ⇒ copy
`last.bits`) — the row's "else copy" face = PDW12/BLK-042
`nextWorkRequired_nonboundary_const` re-proved in-PDW-ns.  On a
min-difficulty chain the pow.cpp:28-49 branch runs FIRST: slow blocks
get powLimit and fast blocks walk back; the two `_minDifficulty_*`
theorems below pin those arms so the unqualified "else copy" reading
is not claimed for testnet/regtest. -/

@[rule "BLK-043"]
theorem nextWorkRequired_retarget_boundary
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32)
    (last first : IndexNode)
    (hget : get lastHeight = some last)
    (hb : (lastHeight + 1) % difficultyAdjustmentInterval P = 0)
    (hfirst : get (lastHeight - (difficultyAdjustmentInterval P - 1))
      = some first) :
    nextWorkRequired P get lastHeight newTime
      = some (calculateNextWorkRequired P last.bits last.time
          first.time first.bits) := by
  simp only [nextWorkRequired, hget, hb, hfirst]
  simp

@[rule "BLK-043"]
theorem nextWorkRequired_copy_nonboundary
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : (lastHeight + 1) % difficultyAdjustmentInterval P ≠ 0)
    (hmin : P.fPowAllowMinDifficultyBlocks = false) :
    nextWorkRequired P get lastHeight newTime = some last.bits := by
  simp only [nextWorkRequired, hget]
  split
  case isTrue hcond =>
    rw [hmin]
    split
    · next hmin' => exact absurd hmin' (by simp)
    · rfl
  case isFalse hb => exact absurd hnb (by simpa using hb)

/-- **BLK-043** min-difficulty branch (pow.cpp:28-35): on a chain with
`fPowAllowMinDifficultyBlocks`, a non-boundary block more than
`2 × nPowTargetSpacing` after its parent is assigned the compact
`powLimit` form.  This branch runs BEFORE the retarget/copy arm, so the
row's unqualified "else copy prev nBits" is false on min-difficulty
chains. -/
@[rule "BLK-043"]
theorem nextWorkRequired_nonboundary_minDifficulty_slow
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : (lastHeight + 1) % difficultyAdjustmentInterval P ≠ 0)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hslow : newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime
      = some (getCompact P.powLimit) := by
  simp only [nextWorkRequired, hget]
  split
  case isTrue hcond => rfl
  case isFalse hb => exact absurd hnb (by simpa using hb)

/-- **BLK-043** min-difficulty branch (pow.cpp:36-49): when the block is
not slow, the non-boundary min-difficulty chain still walks back over
prior min-difficulty blocks (`minDiffWalkBack`) instead of copying the
immediate parent's nBits. -/
@[rule "BLK-043"]
theorem nextWorkRequired_nonboundary_minDifficulty_fast
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : (lastHeight + 1) % difficultyAdjustmentInterval P ≠ 0)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hfast : ¬ newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime
      = minDiffWalkBack P get lastHeight := by
  simp only [nextWorkRequired, hget]
  split
  case isTrue hcond => rfl
  case isFalse hb => exact absurd hnb (by simpa using hb)

/-! ## BLK-045 — `calculateNextWorkRequired` clamp law
(pow.cpp:28-44): actualTimespan = lastTime − firstTime, clamped
to [T/4, 4T], T = `powTargetTimespan` (1209600 s mainnet).

Three faces of the clamp `if`-ladder, stated as plain-Prop guard
hypotheses (low / high / mid); the `actual` let is resolved by the
branch-law rewrite, and the BIP94 base split is discharged by a
`by_cases` on `enforceBIP94`. -/

@[rule "BLK-045"]
theorem calculateNextWorkRequired_clamp_low
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hlow : (lastTime.toNat - firstTime.toNat : Int)
      < ((P.powTargetTimespan / 4 : Nat) : Int)) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = if P.fPowNoRetargeting then lastBits
        else getCompact (min (Bitcoin.Chain.compactTarget (if P.enforceBIP94
            then firstBits else lastBits)
              * (((P.powTargetTimespan / 4 : Nat) : Int)).toNat
          / P.powTargetTimespan) P.powLimit) := by
  unfold calculateNextWorkRequired
  simp only [ite_eq_left hlow]
  by_cases h : P.enforceBIP94 = true <;> simp_all

@[rule "BLK-045"]
theorem calculateNextWorkRequired_clamp_high
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hhigh : (lastTime.toNat - firstTime.toNat : Int)
      > ((P.powTargetTimespan * 4 : Nat) : Int)) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = if P.fPowNoRetargeting then lastBits
        else getCompact (min (Bitcoin.Chain.compactTarget (if P.enforceBIP94
            then firstBits else lastBits)
              * (((P.powTargetTimespan * 4 : Nat) : Int)).toNat
          / P.powTargetTimespan) P.powLimit) := by
  unfold calculateNextWorkRequired
  have hnot : ¬ ((lastTime.toNat - firstTime.toNat : Int)
      < ((P.powTargetTimespan / 4 : Nat) : Int)) := by omega
  simp only [ite_eq_right hnot, ite_eq_left hhigh]
  by_cases h : P.enforceBIP94 = true <;> simp_all

@[rule "BLK-045"]
theorem calculateNextWorkRequired_clamp_mid
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hge : ¬ ((lastTime.toNat - firstTime.toNat : Int)
      < ((P.powTargetTimespan / 4 : Nat) : Int)))
    (hle : ¬ ((lastTime.toNat - firstTime.toNat : Int)
      > ((P.powTargetTimespan * 4 : Nat) : Int))) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = if P.fPowNoRetargeting then lastBits
        else getCompact (min (Bitcoin.Chain.compactTarget (if P.enforceBIP94
            then firstBits else lastBits)
              * (((lastTime.toNat - firstTime.toNat : Int))).toNat
          / P.powTargetTimespan) P.powLimit) := by
  unfold calculateNextWorkRequired
  simp only [ite_eq_right hge, ite_eq_right hle]
  by_cases h : P.enforceBIP94 = true <;> simp_all

/-! ## BLK-048 — `calculateNextWorkRequired` powLimit cap
(pow.cpp:81-82): `bnNew > powLimit ⇒ bnNew = powLimit` — the new
target never exceeds powLimit.

Capped face (retargeting on): the result is `getCompact (min pre
powLimit)` for a pre-cap target `pre`, hence `min pre powLimit ≤
powLimit` — the never-exceeds bound. Companion copy face (BLK-049
`fPowNoRetargeting`): the retarget is bypassed and the result IS
`lastBits`. -/

@[rule "BLK-048"]
theorem calculateNextWorkRequired_capped_target
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false) :
    ∃ pre : Nat, calculateNextWorkRequired P lastBits lastTime
        firstTime firstBits
      = getCompact (min pre P.powLimit)
      ∧ min pre P.powLimit ≤ P.powLimit := by
  unfold calculateNextWorkRequired
  rw [ite_eq_right (by simp [hnr])]
  exact ⟨_, rfl, Nat.min_le_right _ _⟩

@[rule "BLK-048"]
theorem calculateNextWorkRequired_copy_noRetarget
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = true) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = lastBits := by
  unfold calculateNextWorkRequired
  rw [ite_eq_left hnr]

/-! ## BLK-051 — `permittedDifficultyTransition` non-boundary arm
(pow.cpp:118-134): nBits constant within a period — away from a
retarget boundary (and off the min-difficulty chains), a
transition is permitted ↔ the bits are unchanged. -/

@[rule "BLK-051"]
theorem permittedDifficultyTransition_nonboundary
    (P : PowParams) (height : Nat) (oldBits newBits : UInt32)
    (hmin : P.fPowAllowMinDifficultyBlocks = false)
    (hnb : height % difficultyAdjustmentInterval P ≠ 0) :
    permittedDifficultyTransition P height oldBits newBits = true
      ↔ oldBits = newBits := by
  unfold permittedDifficultyTransition
  rw [ite_eq_right (by simp [hmin])]
  rw [ite_eq_right (by simp [hnb])]
  simp

/-! ## BLK-056 — `medianTimePast` (chain.h:233-244): MTP = the
median of the last ≤11 block times (h itself down to h−10, missing
heights skipped). The private in-module `sortBy` is not nameable
outside `Bitcoin.Block.Pow`, so the promotion states the window
laws that do not mention it:

* eleven-present ⇒ the result is `some _` (Core's chain walk never
  hits the empty-window arm at depth ≥ 10);
* **window-determined**: the median depends only on the 11 times
  `h−10..h` — two `get` functions agreeing there have equal MTP;
* empty window (no height in `h−10..h` resolves) ⇒ `none`. -/

private theorem fm_aux (get : Nat → Option UInt32) (h : Nat)
    (v : Nat → UInt32) (l : List Nat)
    (hl : ∀ i ∈ l, h ≥ i ∧ get (h - i) = some (v (h - i))) :
    l.filterMap (fun i => if h ≥ i then get (h - i) else none)
      = l.map (fun i => v (h - i)) := by
  induction l with
  | nil => rfl
  | cons a r ih =>
    have ha : h ≥ a ∧ get (h - a) = some (v (h - a)) := hl a (by simp)
    have hr : ∀ i ∈ r, h ≥ i ∧ get (h - i) = some (v (h - i)) :=
      fun i hi => hl i (by simp [hi])
    simp [ha.1, ha.2, ih hr]

private theorem fm_congr (get get' : Nat → Option UInt32) (h : Nat)
    (l : List Nat)
    (hwin : ∀ i, i ≤ 10 → get (h - i) = get' (h - i))
    (hl : ∀ i ∈ l, i ≤ 10) :
    l.filterMap (fun i => if h ≥ i then get (h - i) else none)
      = l.filterMap (fun i => if h ≥ i then get' (h - i) else none) := by
  induction l with
  | nil => rfl
  | cons a r ih =>
    have ha : get (h - a) = get' (h - a) := hwin a (hl a (by simp))
    have hr : ∀ i ∈ r, i ≤ 10 := fun i hi => hl i (by simp [hi])
    simp only [List.filterMap_cons]
    by_cases hge : h ≥ a
    · simp [hge, ha, ih hr]
    · simp [hge, ih hr]

@[rule "BLK-056"]
theorem medianTimePast_eleven_some
    (get : Nat → Option UInt32) (h : Nat) (v : Nat → UInt32)
    (hh : h ≥ 10)
    (hget : ∀ i, i ≤ 10 → get (h - i) = some (v (h - i))) :
    ∃ t, medianTimePast get h = some t := by
  unfold medianTimePast
  have hfm : (List.range 11).filterMap
      (fun i => if h ≥ i then get (h - i) else none)
    = (List.range 11).map (fun i => v (h - i)) :=
    fm_aux get h v _ (fun i hi =>
      ⟨Nat.le_trans (Nat.lt_succ_iff.mp (List.mem_range.mp hi)) hh,
       hget i (Nat.lt_succ_iff.mp (List.mem_range.mp hi))⟩)
  rw [hfm]
  simp

@[rule "BLK-056"]
theorem medianTimePast_congr
    (get get' : Nat → Option UInt32) (h : Nat)
    (hwin : ∀ i, i ≤ 10 → get (h - i) = get' (h - i)) :
    medianTimePast get h = medianTimePast get' h := by
  unfold medianTimePast
  have hfm := fm_congr get get' h (List.range 11) hwin
    (fun i hi => Nat.lt_succ_iff.mp (List.mem_range.mp hi))
  rw [hfm]

@[rule "BLK-056"]
theorem medianTimePast_none
    (get : Nat → Option UInt32) (h : Nat)
    (hnone : ∀ i, i ≤ 10 → get (h - i) = none) :
    medianTimePast get h = none := by
  unfold medianTimePast
  have hfm : (List.range 11).filterMap
      (fun i => if h ≥ i then get (h - i) else none) = [] := by
    rw [List.filterMap_eq_nil_iff]
    intro a ha
    have ha10 : a ≤ 10 := Nat.lt_succ_iff.mp (List.mem_range.mp ha)
    by_cases hge : h ≥ a
    · simp [hge, hnone a ha10]
    · simp [hge]
  simp [hfm]

/-! ## BLK-048 (encoded face) — the `GetCompact` re-encode does not
exceed its input, so the powLimit cap survives `nBits` encoding.

The existing `calculateNextWorkRequired_capped_target` only bounds the
pre-encoding target `min pre powLimit`. The row's "new target" is the
decoded `nBits` (`compactTarget` of the returned `getCompact …`). Here
`compactTarget (getCompact t) ≤ t` is proved for every `t < 2^256`
(compact form: three significant bytes + 8-bit size), then applied to
`min pre powLimit`. Mainnet powLimit is `2^224 - 2^208 < 2^256`, so
the side condition is met by the consensus parameters. -/

private def encSize (t : Nat) : Nat := (bitLen t + 7)/8
private def encLow (t : Nat) : Nat :=
  if encSize t ≤ 3 then (t % 2^64) * 256^(3 - encSize t)
  else (t / 256^(encSize t - 3)) % 2^64
private def encPair (t : Nat) : Nat × Nat :=
  if encLow t &&& 0x00800000 ≠ 0 then (encLow t >>> 8, encSize t + 1)
  else (encLow t, encSize t)
private def encMant (t : Nat) : Nat := (encPair t).1
private def encExp (t : Nat) : Nat := (encPair t).2

private theorem getCompact_eq_enc (t : Nat) :
    getCompact t = ((((encMant t &&& 0x007fffff) ||| (encExp t <<< 24)) : Nat).toUInt32) := by
  unfold getCompact encMant encExp encPair encLow encSize
  rfl

private theorem bitLen_eq_log2_succ {t : Nat} (h : t ≠ 0) :
    bitLen t = Nat.log2 t + 1 := by
  cases t with
  | zero => contradiction
  | succ k => rfl

private theorem bitLen_le_of_lt_two_pow {t k : Nat} (ht : t < 2^k) :
    bitLen t ≤ k := by
  cases t with
  | zero => simp [bitLen]
  | succ m =>
    rw [bitLen_eq_log2_succ (Nat.succ_ne_zero m)]
    have h := (Nat.log2_lt (Nat.succ_ne_zero m)).mpr ht
    omega

private theorem bits_size (m sz : Nat) (hm : m < 2^23) (hs : sz < 2^8) :
    (((((m ||| (sz <<< 24)) : Nat).toUInt32) >>> 24).toUInt8.toNat) = sz := by
  have hm24 : m < 2^24 := by omega
  have hval : m ||| (sz <<< 24) < 2^32 := by
    apply Nat.or_lt_two_pow
    · omega
    · rw [Nat.shiftLeft_eq]; nlinarith [Nat.two_pow_pos (24:Nat)]
  have hb : ((((m ||| (sz <<< 24)) : Nat).toUInt32)).toNat = (m ||| (sz <<< 24)) := by
    rw [Nat.toUInt32_eq, UInt32.toNat_ofNat', Nat.mod_eq_of_lt hval]
  rw [UInt32.toNat_toUInt8, UInt32.toNat_shiftRight, hb]
  have h24 : (24 : UInt32).toNat % 32 = 24 := by decide
  rw [h24, Nat.shiftRight_eq_div_pow]
  have hor : m ||| (sz <<< 24) = (sz <<< 24) + m := by
    rw [Nat.or_comm, Nat.shiftLeft_add_eq_or_of_lt hm24]
  rw [hor, Nat.shiftLeft_eq]
  omega

private theorem bits_word (m sz : Nat) (hm : m < 2^23) (hs : sz < 2^8) :
    (((((m ||| (sz <<< 24)) : Nat).toUInt32) &&& 0x007fffff).toNat) = m := by
  have hm24 : m < 2^24 := by omega
  have hval : m ||| (sz <<< 24) < 2^32 := by
    apply Nat.or_lt_two_pow
    · omega
    · rw [Nat.shiftLeft_eq]; nlinarith [Nat.two_pow_pos (24:Nat)]
  have hb : ((((m ||| (sz <<< 24)) : Nat).toUInt32)).toNat = (m ||| (sz <<< 24)) := by
    rw [Nat.toUInt32_eq, UInt32.toNat_ofNat', Nat.mod_eq_of_lt hval]
  rw [UInt32.toNat_and, hb]
  have hfm : (0x007fffff : UInt32).toNat = 2^23 - 1 := by decide
  rw [hfm, Nat.and_two_pow_sub_one_eq_mod]
  have hor : m ||| (sz <<< 24) = (sz <<< 24) + m := by
    rw [Nat.or_comm, Nat.shiftLeft_add_eq_or_of_lt hm24]
  rw [hor, Nat.shiftLeft_eq]
  have hdvd : 2^23 ∣ sz * 2^24 := by
    refine ⟨sz * 2, ?_⟩
    rw [show (2:Nat)^24 = 2^23 * 2 by norm_num]
    ring
  rw [Nat.add_mod, Nat.mod_eq_of_lt hm]
  have hz : (sz * 2^24) % 2^23 = 0 := Nat.mod_eq_zero_of_dvd hdvd
  rw [hz, Nat.zero_add, Nat.mod_eq_of_lt hm]

private theorem encExp_lt (t : Nat) (ht : t < 2^256) : encExp t < 2^8 := by
  have hbl := bitLen_le_of_lt_two_pow ht
  unfold encExp encPair encLow encSize
  split <;> split <;> omega

private theorem getCompact_size (t : Nat) (ht : t < 2^256) :
    (((getCompact t >>> 24).toUInt8.toNat)) = encExp t := by
  rw [getCompact_eq_enc]
  exact bits_size _ _ (Nat.and_lt_two_pow _ (by decide)) (encExp_lt t ht)

private theorem getCompact_word (t : Nat) (ht : t < 2^256) :
    (((getCompact t &&& 0x007fffff).toNat)) = encMant t &&& 0x007fffff := by
  rw [getCompact_eq_enc]
  exact bits_word _ _ (Nat.and_lt_two_pow _ (by decide)) (encExp_lt t ht)

private theorem compactTarget_getCompact_eq (t : Nat) (ht : t < 2^256) :
    Bitcoin.Chain.compactTarget (getCompact t) =
      (if encExp t ≤ 3 then (encMant t &&& 0x007fffff) >>> (8*(3 - encExp t))
       else (encMant t &&& 0x007fffff) <<< (8*(encExp t - 3))) := by
  unfold Bitcoin.Chain.compactTarget
  rw [getCompact_size t ht, getCompact_word t ht]

private theorem lt_two_pow_of_and_two_pow_eq_zero {x : Nat} (hx : x < 2^24)
    (h : x &&& 0x00800000 = 0) : x < 2^23 := by
  rw [show (0x00800000 : Nat) = 2^23 by norm_num] at h
  by_contra hge
  have hle : 2^23 ≤ x := Nat.le_of_not_lt hge
  have ht : (x &&& 2^23).testBit 23 = false := by rw [h]; simp
  rw [Nat.testBit_and, Nat.testBit_two_pow_self] at ht
  simp at ht
  have hx' : x < 2^(23+1) := by norm_num at hx ⊢; exact hx
  have hbit : x.testBit 23 = true :=
    Nat.testBit_of_two_pow_le_and_two_pow_add_one_gt hle hx'
  rw [hbit] at ht
  contradiction

private theorem compactTarget_getCompact_le_of_lt_pos (t : Nat) (h0 : t ≠ 0)
    (ht : t < 2^256) : Bitcoin.Chain.compactTarget (getCompact t) ≤ t := by
  rw [compactTarget_getCompact_eq t ht]
  have hbl : bitLen t = Nat.log2 t + 1 := bitLen_eq_log2_succ h0
  have hlog_le : 2^(Nat.log2 t) ≤ t := Nat.log2_self_le h0
  have hlog_lt : t < 2^(Nat.log2 t + 1) := Nat.lt_log2_self
  have hpow_hi : t < 2^(bitLen t) := by simpa [hbl] using hlog_lt
  have hbl_le : bitLen t ≤ 256 := bitLen_le_of_lt_two_pow ht
  have hbl_ge : 1 ≤ bitLen t := by omega
  set s := encSize t with hsdef
  have hs_ge1 : 1 ≤ s := by rw [hsdef]; unfold encSize; omega
  have hs_le : s ≤ 32 := by rw [hsdef]; unfold encSize; omega
  have hn_le : bitLen t ≤ 8*s := by rw [hsdef]; unfold encSize; omega
  have hn_gt : 8*(s-1) < bitLen t := by rw [hsdef]; unfold encSize; omega
  have ht_lt_256s : t < 256^s := by
    calc t < 2^(bitLen t) := hpow_hi
      _ ≤ 2^(8*s) := Nat.pow_le_pow_right (by norm_num) hn_le
      _ = 256^s := by rw [show (256:Nat) = 2^8 by norm_num, ← Nat.pow_mul]
  by_cases hs3 : s ≤ 3
  · have ht_lt_2_24 : t < 2^24 := by
      calc t < 256^s := ht_lt_256s
        _ ≤ 256^3 := Nat.pow_le_pow_right (by norm_num) hs3
        _ = 2^24 := by norm_num
    have ht_mod : t % 2^64 = t := Nat.mod_eq_of_lt (by omega)
    have hlow_eq : encLow t = t * 256^(3-s) := by
      unfold encLow; rw [if_pos hs3, ht_mod]
    by_cases hbump : encLow t &&& 0x00800000 ≠ 0
    · have hmant : encMant t = encLow t >>> 8 := by
        unfold encMant encPair; rw [if_pos hbump]
      have hexp : encExp t = s + 1 := by
        unfold encExp encPair; rw [if_pos hbump]
      interval_cases s
      · -- s=1
        rw [hmant, hexp, hlow_eq]
        norm_num
        simp only [Nat.shiftRight_eq_div_pow]
        norm_num
        have hmlt : t * 65536 / 256 < 2^23 := by omega
        have hmask : (t * 65536 / 256) &&& 8388607 = t * 65536 / 256 := by
          rw [show (8388607:Nat) = 2^23 - 1 by norm_num]
          exact Nat.and_two_pow_sub_one_of_lt_two_pow hmlt
        rw [hmask]
        omega
      · -- s=2
        rw [hmant, hexp, hlow_eq]
        norm_num
        simp only [Nat.shiftRight_eq_div_pow]
        norm_num
        have hmlt : t < 2^23 := by omega
        have hmask : t &&& 8388607 = t := by
          rw [show (8388607:Nat) = 2^23 - 1 by norm_num]
          exact Nat.and_two_pow_sub_one_of_lt_two_pow hmlt
        rw [hmask]
      · -- s=3
        rw [hmant, hexp, hlow_eq]
        norm_num
        simp only [Nat.shiftRight_eq_div_pow, Nat.shiftLeft_eq]
        norm_num
        have hmlt : t / 256 < 2^23 := by omega
        have hmask : (t / 256) &&& 8388607 = t / 256 := by
          rw [show (8388607:Nat) = 2^23 - 1 by norm_num]
          exact Nat.and_two_pow_sub_one_of_lt_two_pow hmlt
        rw [hmask]
        omega
    · have hmant : encMant t = encLow t := by
        unfold encMant encPair; rw [if_neg hbump]
      have hexp : encExp t = s := by
        unfold encExp encPair; rw [if_neg hbump]
      rw [hmant, hexp, hlow_eq]
      rw [ite_eq_left hs3]
      have hlowlt : t * 256^(3-s) < 2^23 := by
        apply lt_two_pow_of_and_two_pow_eq_zero
        · calc t * 256^(3-s) < 256^s * 256^(3-s) := by
                exact Nat.mul_lt_mul_of_pos_right ht_lt_256s (Nat.pow_pos (by norm_num))
            _ = 256^3 := by
                rw [← Nat.pow_add]; congr; omega
            _ = 2^24 := by norm_num
        · rw [← hlow_eq]; exact not_not.mp hbump
      have hmask : t * 256^(3-s) &&& 0x007fffff = t * 256^(3-s) := by
        rw [show (0x007fffff : Nat) = 2^23 - 1 by norm_num]
        exact Nat.and_two_pow_sub_one_of_lt_two_pow hlowlt
      rw [hmask, Nat.shiftRight_eq_div_pow]
      have hdiv : t * 256^(3-s) / 2^(8*(3-s)) = t := by
        rw [show (2:Nat)^(8*(3-s)) = 256^(3-s) by
          rw [show (256:Nat) = 2^8 by norm_num, ← Nat.pow_mul]]
        exact Nat.mul_div_left t (Nat.pow_pos (by norm_num))
      rw [hdiv]
  · have hs4 : 4 ≤ s := by omega
    have hq_lt_24 : t / 256^(s-3) < 2^24 := by
      rw [Nat.div_lt_iff_lt_mul (Nat.pow_pos (by norm_num))]
      calc t < 256^s := ht_lt_256s
        _ = 256^3 * 256^(s-3) := by rw [← Nat.pow_add]; congr; omega
        _ = 2^24 * 256^(s-3) := by norm_num
    have hlow_eq : encLow t = t / 256^(s-3) := by
      unfold encLow; rw [if_neg hs3, Nat.mod_eq_of_lt]
      exact lt_of_lt_of_le hq_lt_24 (by norm_num)
    by_cases hbump : encLow t &&& 0x00800000 ≠ 0
    · have hmant : encMant t = encLow t >>> 8 := by
        unfold encMant encPair; rw [if_pos hbump]
      have hexp : encExp t = s + 1 := by
        unfold encExp encPair; rw [if_pos hbump]
      rw [hmant, hexp, hlow_eq]
      rw [ite_eq_right (by omega)]
      simp only [Nat.shiftRight_eq_div_pow, Nat.shiftLeft_eq]
      norm_num
      have hmlt : t / 256^(s-3) / 256 < 2^23 := by omega
      have hmask : (t / 256^(s-3) / 256) &&& 8388607 = t / 256^(s-3) / 256 := by
        rw [show (8388607:Nat) = 2^23 - 1 by norm_num]
        exact Nat.and_two_pow_sub_one_of_lt_two_pow hmlt
      rw [hmask]
      have hdiv : t / 256^(s-3) / 256 = t / 256^(s-2) := by
        rw [Nat.div_div_eq_div_mul]
        rw [show s - 2 = (s - 3) + 1 by omega, Nat.pow_succ]
      rw [hdiv]
      have hexp8 : (2:Nat)^(8*(s-2)) = 256^(s-2) := by
        rw [show (256:Nat)=2^8 by norm_num, ← Nat.pow_mul]
      rw [hexp8]
      exact Nat.div_mul_le_self t (256^(s-2))
    · have hmant : encMant t = encLow t := by
        unfold encMant encPair; rw [if_neg hbump]
      have hexp : encExp t = s := by
        unfold encExp encPair; rw [if_neg hbump]
      rw [hmant, hexp, hlow_eq]
      rw [ite_eq_right (by omega)]
      simp only [Nat.shiftLeft_eq]
      have hqlowlt : t / 256^(s-3) < 2^23 := by
        apply lt_two_pow_of_and_two_pow_eq_zero hq_lt_24
        rw [← hlow_eq]; exact not_not.mp hbump
      have hmask : (t / 256^(s-3)) &&& 8388607 = t / 256^(s-3) := by
        rw [show (8388607:Nat) = 2^23 - 1 by norm_num]
        exact Nat.and_two_pow_sub_one_of_lt_two_pow hqlowlt
      rw [hmask]
      have hexp8 : (2:Nat)^(8*(s-3)) = 256^(s-3) := by
        rw [show (256:Nat)=2^8 by norm_num, ← Nat.pow_mul]
      rw [hexp8]
      exact Nat.div_mul_le_self t (256^(s-3))

private theorem compactTarget_getCompact_le_of_lt (t : Nat) (ht : t < 2^256) :
    Bitcoin.Chain.compactTarget (getCompact t) ≤ t := by
  by_cases h0 : t = 0
  · subst t; decide
  · exact compactTarget_getCompact_le_of_lt_pos t h0 ht

/-- Mainnet's `powLimit` satisfies the round-trip domain side
condition (`2^224 - 1 < 2^256`). -/
theorem mainnetParams_powLimit_lt_two_pow_256 :
    mainnetParams.powLimit < 2^256 := by
  unfold mainnetParams powLimitMainnet
  decide

@[rule "BLK-048"]
theorem calculateNextWorkRequired_encoded_capped
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false)
    (hL : P.powLimit < 2^256) :
    Bitcoin.Chain.compactTarget
        (calculateNextWorkRequired P lastBits lastTime
          firstTime firstBits) ≤ P.powLimit := by
  unfold calculateNextWorkRequired
  rw [ite_eq_right (by simp [hnr])]
  exact le_trans
    (compactTarget_getCompact_le_of_lt (min _ P.powLimit)
      (lt_of_le_of_lt (Nat.min_le_right _ _) hL))
    (Nat.min_le_right _ _)

end BitcoinProofs.AF.PDW31
