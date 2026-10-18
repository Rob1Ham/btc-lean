import Bitcoin.Block.Params

/-!
# Blk122Cor — BLK-122 promotion proof (PDW8, row TOP-39)

PDW8 → PDW8-2 (proof-promotion review 8, continuation after the 06:40
mid-proof death; recovery review 4), 2026-10-17.
Row BLK-122 (mainnet `nMinimumChainWork`,
kernel/chainparams.cpp:141 @cce32b168): headers-first sync does not
index headers below this accumulated work (`too-little-chainwork`,
validation.cpp:4270-4276) — anti-DoS, not consensus: every honest
chain exceeds it by orders of magnitude.

Semantics port (route B): `nMinimumChainWorkMainnet` (Params.lean:293)
is the constant; `minChainWorkOk` (Params.lean:298) is the gate
(`nMinimumChainWorkMainnet ≤ work`, a `decide`). The theorems here
pin the two directions: the accept verdict holds iff the work meets
the minimum, and the `too-little-chainwork` reject verdict (`= false`)
implies the work is strictly below (the reject lane).
`Nat.not_le` (W12 gold). Companion to the core `minChainWorkOk_zero_false`
(Params.lean:300) and `minChainWorkOk_at_limit` (Params.lean:302).
PDW8-2 build evidence: the tree file was clean FIRST-BUILD RC=0
(the W12-gold bare `simp [hc]` herds passed tree-as-is; contrast
Blk063Cor which died with the :53/:54 errors).

Axiom-pinned in-file (D2 L3); zero sorryAx — pin-sets per theorem
(PDW8-2 probe pass): true_iff [propext] (the `simp [hc]`-herd
route), too_little AXIOM-FREE (the `nomatch h`/`Nat.not_le` route);
every pin ⊆ [propext, Classical.choice, Quot.sound] = the charter
trio (sorry_lint G1 class). -/

namespace BitcoinProofs.AF.PDW8

/-- BLK-122 (accept dir): the min-chain-work gate passes iff the
accumulated work meets mainnet's `nMinimumChainWork`. -/
@[rule "BLK-122"]
theorem minChainWorkOk_true_iff (work : Nat) :
    Bitcoin.Block.Params.minChainWorkOk work = true ↔
      Bitcoin.Block.Params.nMinimumChainWorkMainnet ≤ work := by
  rw [Bitcoin.Block.Params.minChainWorkOk]
  by_cases hc : Bitcoin.Block.Params.nMinimumChainWorkMainnet ≤ work
  · simp [hc]
  · simp [hc]

/-- BLK-122 (reject dir, `too-little-chainwork`): a failed gate means
the accumulated work is strictly below the minimum. -/
@[rule "BLK-122"]
theorem minChainWorkOk_too_little (work : Nat)
    (h : Bitcoin.Block.Params.minChainWorkOk work = false) :
    work < Bitcoin.Block.Params.nMinimumChainWorkMainnet := by
  rw [Bitcoin.Block.Params.minChainWorkOk] at h
  by_cases hc : Bitcoin.Block.Params.nMinimumChainWorkMainnet ≤ work
  · rw [decide_eq_true hc] at h; nomatch h
  · exact Nat.not_le.mp hc

/-- BLK-122 (indexing face): the headers-first index decision for a header
whose ancestor chain carries accumulated work `work`. `none` is Core's
"do not index / too-little-chainwork" outcome; `some work` is the indexed
header. This is the shape validation.cpp:4237-4240 (`nChainWork <
nMinimumChainWork` ⇒ `IsInitialBlockDownload` / no indexing) that the row
anchors, expressed over the pinned `minChainWorkOk` gate. -/
@[rule "BLK-122"]
def headerIndexVerdict (work : Nat) : Option Nat :=
  if Bitcoin.Block.Params.minChainWorkOk work = true then some work else none

/-- BLK-122 (reject side): exactly the headers below mainnet's minimum
accumulated work are NOT indexed. Both directions, from the gate iff. -/
@[rule "BLK-122"]
theorem headerIndexVerdict_eq_none_iff (work : Nat) :
    headerIndexVerdict work = none ↔
      work < Bitcoin.Block.Params.nMinimumChainWorkMainnet := by
  unfold headerIndexVerdict
  by_cases h : Bitcoin.Block.Params.minChainWorkOk work = true
  · rw [if_pos h]
    constructor
    · intro hnone; exact absurd hnone (by simp)
    · intro hlt
      have hge := (minChainWorkOk_true_iff work).mp h
      omega
  · have hf : Bitcoin.Block.Params.minChainWorkOk work = false := by
      cases hb : Bitcoin.Block.Params.minChainWorkOk work <;> simp_all
    rw [if_neg h]
    constructor
    · intro _; exact minChainWorkOk_too_little work hf
    · intro _; rfl

/-- BLK-122 (below-minimum directive): a header below the minimum work is
never indexed (the anti-DoS gate, not a consensus validity rule). -/
@[rule "BLK-122"]
theorem headerIndexVerdict_below_not_indexed (work : Nat)
    (h : work < Bitcoin.Block.Params.nMinimumChainWorkMainnet) :
    headerIndexVerdict work = none :=
  (headerIndexVerdict_eq_none_iff work).mpr h

/-- BLK-122 (accept side): a header at or above the minimum is indexed. -/
@[rule "BLK-122"]
theorem headerIndexVerdict_isSome_iff (work : Nat) :
    (headerIndexVerdict work).isSome = true ↔
      Bitcoin.Block.Params.nMinimumChainWorkMainnet ≤ work := by
  unfold headerIndexVerdict
  by_cases h : Bitcoin.Block.Params.minChainWorkOk work = true
  · rw [if_pos h]
    constructor
    · intro _; exact (minChainWorkOk_true_iff work).mp h
    · intro _; rfl
  · have hf : Bitcoin.Block.Params.minChainWorkOk work = false := by
      cases hb : Bitcoin.Block.Params.minChainWorkOk work <;> simp_all
    rw [if_neg h]
    constructor
    · intro hs; exact absurd hs (by simp)
    · intro hge
      have := minChainWorkOk_too_little work hf
      omega

/-! ## BLK-122 — the real header-index decision and GetAntiDoSWorkThreshold

The `headerIndexVerdict` proxy above only projects the work predicate into
an `Option`.  The model below is the actual `AcceptBlockHeader` decision.
Core's `min_pow_checked` is **not** derived from `nMinimumChainWork`
alone: `PeerManagerImpl::GetAntiDoSWorkThreshold`
(net_processing.cpp:2542-2552) is

`max(tip.nChainWork - min(144 * GetBlockProof(*tip), tip.nChainWork),
MinimumChainWork())`,

and a candidate block/header is admitted only when its previous block
exists and `prev.nChainWork + CalculateHeadersWork(candidate)` meets that
threshold (net_processing.cpp:4735-4752).  The headers path applies the
same threshold in `TryLowWorkHeadersSync` (net_processing.cpp:2698-2703)
before calling `ProcessNewBlockHeaders(..., min_pow_checked=true, ...)`.
`headerIndexDecision` is the `BLOCK_HEADER_LOW_WORK` /
`too-little-chainwork` early return at validation.cpp:4237-4240, which
happens **before** `AddToBlockIndex`.

The validity bit is kept separate, so the theorems show the gate is
anti-DoS admission, not a consensus rule.  The separate `headersPresync`
predicate is Core's IBD report (`ReportHeadersPresync`,
validation.cpp:4285-4288) and is not the admission decision. -/

/-- Core's headers pre-sync window: while the best header chain's claimed
work is below `nMinimumChainWork`, `ReportHeadersPresync` reports the
pre-sync phase. -/
@[rule "BLK-122"]
def headersPresync (claimedWork : Nat) : Bool :=
  decide (claimedWork < Bitcoin.Block.Params.nMinimumChainWorkMainnet)

/-- **BLK-122**: `GetAntiDoSWorkThreshold` (net_processing.cpp:2542-2552)
— the near-tip work `tip.nChainWork - min(144 * GetBlockProof(*tip),
tip.nChainWork)`, raised to at least `nMinimumChainWork`. -/
@[rule "BLK-122"]
def antiDosWorkThreshold (tipWork tipBlockWork minimumChainWork : Nat) : Nat :=
  max (tipWork - min (144 * tipBlockWork) tipWork) minimumChainWork

/-- The threshold is never below the configured minimum. -/
theorem antiDosWorkThreshold_ge_minimum (tipWork tipBlockWork
    minimumChainWork : Nat) :
    minimumChainWork ≤ antiDosWorkThreshold tipWork tipBlockWork minimumChainWork :=
  Nat.le_max_right _ _

/-- **BLK-122**: `min_pow_checked` for a candidate whose previous block
has `prevWork` and whose own headers work is `candidateWork` (Core's
`prev_block->nChainWork + CalculateHeadersWork({header})`). -/
@[rule "BLK-122"]
def minPowChecked (prevWork candidateWork tipWork tipBlockWork
    minimumChainWork : Nat) : Bool :=
  decide (antiDosWorkThreshold tipWork tipBlockWork minimumChainWork ≤
    prevWork + candidateWork)

/-- `AcceptBlockHeader`'s indexing outcome (validation.cpp:4237-4240).
`lowWork` is `BLOCK_HEADER_LOW_WORK` / `too-little-chainwork`, returned
before the header reaches `AddToBlockIndex`. -/
@[rule "BLK-122"]
inductive HeaderIndexOutcome where
  | indexed
  | lowWork
deriving DecidableEq, Repr

/-- The `AcceptBlockHeader` branch: `min_pow_checked = false` refuses the
header with `too-little-chainwork`; otherwise it is added to the index. -/
@[rule "BLK-122"]
def acceptHeaderIndex (minPowChecked : Bool) : HeaderIndexOutcome :=
  if minPowChecked then .indexed else .lowWork

/-- The actual per-header decision with Core's near-tip, candidate-work,
and minimum-chainwork inputs. -/
@[rule "BLK-122"]
def headerIndexDecision (prevWork candidateWork tipWork tipBlockWork
    minimumChainWork : Nat) : HeaderIndexOutcome :=
  acceptHeaderIndex
    (minPowChecked prevWork candidateWork tipWork tipBlockWork minimumChainWork)

/-- Below the minimum, the pre-sync flag is closed. -/
@[rule "BLK-122"]
theorem headersPresync_of_below (work : Nat)
    (h : work < Bitcoin.Block.Params.nMinimumChainWorkMainnet) :
    headersPresync work = true := by
  unfold headersPresync
  exact decide_eq_true h

/-- At or above the minimum, the pre-sync flag is open. -/
theorem headersPresync_eq_false_of_ge (work : Nat)
    (h : Bitcoin.Block.Params.nMinimumChainWorkMainnet ≤ work) :
    headersPresync work = false := by
  unfold headersPresync
  exact decide_eq_false (by omega)

/-- **BLK-122** (minimum branch): below `nMinimumChainWork` the candidate
cannot clear the anti-DoS threshold (which is at least the minimum). -/
@[rule "BLK-122"]
theorem minPowChecked_of_below (prevWork candidateWork tipWork tipBlockWork
    minimumChainWork : Nat)
    (h : prevWork + candidateWork < minimumChainWork) :
    minPowChecked prevWork candidateWork tipWork tipBlockWork
      minimumChainWork = false := by
  unfold minPowChecked
  rw [decide_eq_false_iff_not]
  have hth := antiDosWorkThreshold_ge_minimum tipWork tipBlockWork minimumChainWork
  omega

/-- **BLK-122** (near-tip branch): meeting the threshold opens the flag. -/
@[rule "BLK-122"]
theorem minPowChecked_of_ge (prevWork candidateWork tipWork tipBlockWork
    minimumChainWork : Nat)
    (h : antiDosWorkThreshold tipWork tipBlockWork minimumChainWork ≤
      prevWork + candidateWork) :
    minPowChecked prevWork candidateWork tipWork tipBlockWork
      minimumChainWork = true := by
  unfold minPowChecked
  exact decide_eq_true h

/-- **BLK-122**: exact `min_pow_checked` characterization. -/
@[rule "BLK-122"]
theorem minPowChecked_eq_true_iff (prevWork candidateWork tipWork tipBlockWork
    minimumChainWork : Nat) :
    minPowChecked prevWork candidateWork tipWork tipBlockWork
        minimumChainWork = true ↔
      antiDosWorkThreshold tipWork tipBlockWork minimumChainWork ≤
        prevWork + candidateWork := by
  unfold minPowChecked
  exact decide_eq_true_iff

/-- **BLK-122** (reject side): a candidate below `nMinimumChainWork` is not
indexed — `too-little-chainwork`. -/
@[rule "BLK-122"]
theorem headerIndexDecision_below_lowWork (prevWork candidateWork tipWork
    tipBlockWork minimumChainWork : Nat)
    (h : prevWork + candidateWork < minimumChainWork) :
    headerIndexDecision prevWork candidateWork tipWork tipBlockWork
      minimumChainWork = .lowWork := by
  unfold headerIndexDecision acceptHeaderIndex
  rw [minPowChecked_of_below prevWork candidateWork tipWork tipBlockWork
    minimumChainWork h]
  rfl

/-- **BLK-122** (accept side): a candidate meeting the anti-DoS threshold
is added to the block index. -/
@[rule "BLK-122"]
theorem headerIndexDecision_at_or_above_indexed (prevWork candidateWork
    tipWork tipBlockWork minimumChainWork : Nat)
    (h : antiDosWorkThreshold tipWork tipBlockWork minimumChainWork ≤
      prevWork + candidateWork) :
    headerIndexDecision prevWork candidateWork tipWork tipBlockWork
      minimumChainWork = .indexed := by
  unfold headerIndexDecision acceptHeaderIndex
  rw [minPowChecked_of_ge prevWork candidateWork tipWork tipBlockWork
    minimumChainWork h]
  rfl

/-- **BLK-122** (exact decision): low-work refusal is exactly failure to
meet the anti-DoS threshold. -/
@[rule "BLK-122"]
theorem headerIndexDecision_eq_lowWork_iff (prevWork candidateWork tipWork
    tipBlockWork minimumChainWork : Nat) :
    headerIndexDecision prevWork candidateWork tipWork tipBlockWork
        minimumChainWork = .lowWork ↔
      ¬ antiDosWorkThreshold tipWork tipBlockWork minimumChainWork ≤
        prevWork + candidateWork := by
  constructor
  · intro hlow hth
    rw [headerIndexDecision_at_or_above_indexed prevWork candidateWork tipWork
      tipBlockWork minimumChainWork hth] at hlow
    cases hlow
  · intro hnot
    unfold headerIndexDecision acceptHeaderIndex
    have hf : minPowChecked prevWork candidateWork tipWork tipBlockWork
        minimumChainWork = false := by
      cases hb : minPowChecked prevWork candidateWork tipWork tipBlockWork
          minimumChainWork with
      | false => rfl
      | true =>
        exact absurd ((minPowChecked_eq_true_iff _ _ _ _ _).mp hb) hnot
    rw [hf]
    rfl

/-- **BLK-122** (exact decision, accept direction). -/
theorem headerIndexDecision_eq_indexed_iff (prevWork candidateWork tipWork
    tipBlockWork minimumChainWork : Nat) :
    headerIndexDecision prevWork candidateWork tipWork tipBlockWork
        minimumChainWork = .indexed ↔
      antiDosWorkThreshold tipWork tipBlockWork minimumChainWork ≤
        prevWork + candidateWork := by
  constructor
  · intro hidx
    by_cases hth : antiDosWorkThreshold tipWork tipBlockWork minimumChainWork ≤
        prevWork + candidateWork
    · exact hth
    · have hlow : headerIndexDecision prevWork candidateWork tipWork
          tipBlockWork minimumChainWork = .lowWork :=
        (headerIndexDecision_eq_lowWork_iff _ _ _ _ _).mpr hth
      rw [hlow] at hidx
      cases hidx
  · exact headerIndexDecision_at_or_above_indexed prevWork candidateWork tipWork
      tipBlockWork minimumChainWork

/-- A header candidate: its consensus-check result is kept separate from
the anti-DoS work gate. -/
structure HeaderCandidate where
  /-- `CheckBlockHeader` + `ContextualCheckBlockHeader` all passed. -/
  consensusValid : Bool
  /-- Accumulated work of the previous block's chain. -/
  prevWork : Nat
  /-- `CalculateHeadersWork({header})`. -/
  candidateWork : Nat
  /-- Active chain tip work. -/
  tipWork : Nat
  /-- `GetBlockProof(*tip)`. -/
  tipBlockWork : Nat
  /-- `nMinimumChainWork`. -/
  minimumChainWork : Nat

/-- **BLK-122** (anti-DoS, not consensus): a header that passes every
consensus check is still not indexed when it misses the anti-DoS
threshold.  The refused header keeps `consensusValid = true`; only the
`AcceptBlockHeader` admission decision changes. -/
@[rule "BLK-122"]
theorem valid_header_below_not_indexed (h : HeaderCandidate)
    (hv : h.consensusValid = true)
    (hw : antiDosWorkThreshold h.tipWork h.tipBlockWork h.minimumChainWork >
      h.prevWork + h.candidateWork) :
    h.consensusValid = true ∧
      headerIndexDecision h.prevWork h.candidateWork h.tipWork h.tipBlockWork
        h.minimumChainWork = .lowWork :=
  ⟨hv, (headerIndexDecision_eq_lowWork_iff _ _ _ _ _).mpr (Nat.not_le.mpr hw)⟩

/-- **BLK-122** regression (near-tip threshold is stronger than the
minimum): with tip work 1000 and per-tip-block work 1, the threshold is
856 even though the configured minimum is only 10.  A candidate at 800
meets the minimum but fails admission; 900 passes. -/
@[rule "BLK-122"]
theorem antiDosWorkThreshold_nearTip_regression :
    antiDosWorkThreshold 1000 1 10 = 856 ∧
      minPowChecked 0 800 1000 1 10 = false ∧
      minPowChecked 0 900 1000 1 10 = true ∧
      headerIndexDecision 0 800 1000 1 10 = .lowWork := by
  decide

/-- **BLK-122** regression (minimum-chainwork floor): when the near-tip
work is lower than the configured minimum, the threshold is the minimum.
-/
@[rule "BLK-122"]
theorem antiDosWorkThreshold_minimum_regression :
    antiDosWorkThreshold 100 1 1000 = 1000 ∧
      minPowChecked 0 999 100 1 1000 = false ∧
      minPowChecked 0 1000 100 1 1000 = true := by
  decide

/-! ## L3 axiom pins (D2): drift on any of these fails the build.
Both rule-theorems sorry-free; pin-sets (PDW8-2 probe pass):
true_iff [propext] (the `simp [hc]`-herd route), too_little
AXIOM-FREE (the `nomatch h`/`Nat.not_le` route); every pin ⊆
[propext, Classical.choice, Quot.sound] = the charter trio; zero
`sorryAx` (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW8.minChainWorkOk_true_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.minChainWorkOk_true_iff

/-- info: 'BitcoinProofs.AF.PDW8.minChainWorkOk_too_little' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.minChainWorkOk_too_little

#print axioms headerIndexDecision_below_lowWork
#print axioms headerIndexDecision_eq_lowWork_iff
#print axioms valid_header_below_not_indexed

end BitcoinProofs.AF.PDW8
