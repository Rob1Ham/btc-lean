import Bitcoin.Capstone.Block
import Bitcoin.Block.Pow
import Bitcoin.Block.Connect
import Bitcoin.Block.Index
import Bitcoin.Block.Params

/-!
# BitcoinProofs.ErrMap.E03.BlockTaxonomy — error-taxonomy completeness:
block/chain level

Ground truth: Bitcoin Core v32.99 @ `cce32b168` (DECISIONS.md D-001),
`src/consensus/validation.h` + `src/validation.cpp`. Full mapping table
(site → result → reject string → rules.yaml row → our repo home) is
below; unmapped paths are filed as F-E03-001..005.

Three layers, all sorry-free:

1. **Mode machine** — Core's `ValidationState` `ModeState` triad
   (consensus/validation.h:100–131): `M_VALID/M_INVALID/M_ERROR`,
   `Invalid()` sticky under `M_ERROR`. Modeled here for the first time
   (repo grep: no `M_ERROR`/`FatalError` modeling existed — F-E03-002).
2. **Path enumeration** — 34 failure sites of the block/chain pipeline
   (`BlkPath`), each with its `BlockValidationResult` and exact Core
   reject string. `resultOf_complete`: the only `UNSET`/runtime paths are
   `inconclusiveNotBestPrevBlk` (validation.cpp:4493), `diskWriteError`
   (4383), `fatalChainError` (2138) — the F-E03 gaps.
3. **Traceability** — `failureRow` (kernel-checked `@[rule]` bindings to
   BLK rows) and `ourHome` (the repo declaration implementing the path).
-/

namespace BitcoinProofs.ErrMap.E03

open Bitcoin.Capstone.Block Bitcoin.Block.Pow Bitcoin.Block.Connect
open Bitcoin.Block.Index Bitcoin.Block.Params Bitcoin.TxValidation

/-! ## §1  ValidationState mode machine (consensus/validation.h:100–131) -/

/-- The `ModeState` triad of Core's `ValidationState` template. -/
inductive BlockMode | valid | invalid | error
deriving DecidableEq, Repr

/-- Core `Invalid(result, reason, debug)`: sets `M_INVALID` **unless** the
state is already `M_ERROR` — errors are sticky (validation.h:110–115). -/
def BlockMode.invalidStep : BlockMode → BlockMode
  | .error => .error
  | _      => .invalid

/-- Core `Error(reason)`: forces `M_ERROR` unconditionally (h:118–123). -/
def BlockMode.errorStep : BlockMode → BlockMode := fun _ => .error

/-- Error-stickiness (validation.h:112): `Invalid()` never yields
`M_VALID` — it either moves to `M_INVALID`, or the state was already in
the sticky `M_ERROR` mode. -/
theorem BlockMode.invalidStep_not_valid :
    ∀ m : BlockMode, m.invalidStep ≠ .valid ∨ m = .error := by
  intro m
  cases m with
  | valid => exact Or.inl (by simp [BlockMode.invalidStep])
  | invalid => exact Or.inl (by simp [BlockMode.invalidStep])
  | error => exact Or.inr rfl

/-- The three mode predicates `IsValid/IsInvalid/IsError` are exclusive. -/
theorem BlockMode.modes_exclusive :
    (BlockMode.valid ≠ BlockMode.invalid) ∧
    (BlockMode.invalid ≠ BlockMode.error) ∧
    (BlockMode.valid ≠ BlockMode.error) :=
  ⟨BlockMode.noConfusion, BlockMode.noConfusion, BlockMode.noConfusion⟩

/-! ## §2  The 34 block/chain-level failure paths (validation.cpp @ cce32b168) -/

/-- `BlockValidationResult` (consensus/validation.h:89–102). -/
inductive BlockResult
  | unset | consensus | cachedInvalid | invalidHeader | mutated
  | missingPrev | invalidPrev | timeFuture | headerLowWork
deriving DecidableEq, Repr

/-- One constructor per failure site. Docstring: `file:line @ cce32b168`,
the reject string, and the `rules.yaml` row(s). Tx-level taxonomies are
embedded exactly as Core embeds them (validation.cpp:2533–2539: "Any
transaction validation failure in ConnectBlock is a block consensus
failure"). -/
inductive BlkPath
  /-- 3840 `high-hash` (CheckBlockHeader PoW) — BLK-039 -/
  | highHash
  /-- 4097 `bad-diffbits` (ContextualCheckBlockHeader) — BLK-042 -/
  | badDiffBits
  /-- 4101 `time-too-old` (vs MTP-11) — BLK-057 -/
  | timeTooOld
  /-- 4110 `time-timewarp-attack` (BIP94, enforce_BIP94, MAX_TIMEWARP=600) — BLK-055 -/
  | timeTimewarpAttack
  /-- 4117 `time-too-new` (+2 h) — BLK-058/BLK-130 -/
  | timeTooNew
  /-- 4124 `bad-version(0x…)` (BIP34/BIP66/BIP65 floors) — BLK-060/061/062 -/
  | badVersion
  /-- 3940 `bad-signet-blksig` (BIP325) — BLK-126 -/
  | badSignetBlkSig
  /-- 3858 `bad-txnmrklroot` (MUTATED) — BLK-010 -/
  | badTxnMerkleRoot
  /-- 3867 `bad-txns-duplicate` (MUTATED, CVE-2012-2459) — BLK-011 -/
  | badTxnsDuplicate
  /-- 3956 `bad-blk-length` (vtx empty / stripped-size ×4) — BLK-022/023/024 -/
  | badBlkLength
  /-- 3960 `bad-cb-missing` — BLK-027 -/
  | badCbMissing
  /-- 3963 `bad-cb-multiple` — BLK-028 -/
  | badCbMultiple
  /-- 3973 CheckTransaction propagation (stateless, 9 reasons) — BLK-030 -/
  | blockTxStateless (e : Bitcoin.Consensus.TxCheckError)
  /-- 3985 `bad-blk-sigops` (legacy ×4, coarse, under-counting) — BLK-034 -/
  | badBlkSigopsOob
  /-- 3895 `bad-witness-nonce-size` (MUTATED) — BLK-018 -/
  | badWitnessNonceSize
  /-- 3907 `bad-witness-merkle-match` (MUTATED) — BLK-017 -/
  | badWitnessMerkleMatch
  /-- 3918 `unexpected-witness` (MUTATED, no commitment) — BLK-019 -/
  | unexpectedWitness
  /-- 4155 `bad-txns-nonfinal` (IsFinalTx, BIP113 cutoff) — BLK-066/067/068 -/
  | badNonfinal
  /-- 4165 `bad-cb-height` (BIP34) — BLK-069 -/
  | badCbHeight
  /-- 4188 `bad-blk-weight` (contextual, post-commitment) — BLK-026 -/
  | badBlkWeight
  /-- 4209 `duplicate-invalid` (CACHED_INVALID) — BLK-120/119 -/
  | duplicateInvalid
  /-- 4225 `prev-blk-not-found` (MISSING_PREV) — BLK-063 -/
  | prevBlkNotFound
  /-- 4230 `bad-prevblk` (INVALID_PREV: parent BLOCK_FAILED_VALID) — BLK-064 -/
  | badPrevBlk
  /-- 4239 `too-little-chainwork` (HEADER_LOW_WORK, min_pow_checked) — BLK-122 -/
  | tooLittleChainwork
  /-- 2470 `bad-txns-BIP30` (ConnectBlock overwrite ban) — BLK-096/097/098 -/
  | badBip30
  /-- 2535 CheckTxInputs propagation — BLK-100/102/103 -/
  | connectInputs (e : Bitcoin.TxValidation.TxError)
  /-- 2542 `bad-txns-accumulated-fee-outofrange` — BLK-091 -/
  | blockFeeOutOfRange
  /-- 2556 `bad-txns-nonfinal` (BIP68 SequenceLocks) — BLK-104 -/
  | nonBip68Final
  /-- 2568 `bad-blk-sigops` (exact sigop cost, ConnectBlock) — BLK-036/035 -/
  | badBlkSigopsCost
  /-- 2588/2616 script-verify failure — SCR rows via BLK-083..088 -/
  | scriptVerifyFailed
  /-- 2610 `bad-cb-amount` — BLK-089/090 -/
  | badCbAmount
  /-- 4493 `inconclusive-not-best-prevblk`, result stays UNSET —
      **no row, no repo constructor → F-E03-001** -/
  | inconclusiveNotBestPrevBlk
  /-- 4383 SaveBlockToDisk `state.Error` (M_ERROR, runtime) —
      **no row → F-E03-002** -/
  | diskWriteError
  /-- 2138 FatalError → `state.Error` (M_ERROR, runtime) —
      **no row → F-E03-002** -/
  | fatalChainError
deriving DecidableEq, Repr

/-- The `BlockValidationResult` Core assigns at each site. -/
def resultOf : BlkPath → BlockResult
  | .highHash                   => .invalidHeader
  | .badDiffBits                => .invalidHeader
  | .timeTooOld                 => .invalidHeader
  | .timeTimewarpAttack         => .invalidHeader
  | .timeTooNew                 => .timeFuture
  | .badVersion                 => .invalidHeader
  | .badSignetBlkSig            => .consensus
  | .badTxnMerkleRoot           => .mutated
  | .badTxnsDuplicate           => .mutated
  | .badBlkLength               => .consensus
  | .badCbMissing               => .consensus
  | .badCbMultiple              => .consensus
  | .blockTxStateless _         => .consensus
  | .badBlkSigopsOob            => .consensus
  | .badWitnessNonceSize        => .mutated
  | .badWitnessMerkleMatch      => .mutated
  | .unexpectedWitness          => .mutated
  | .badNonfinal                => .consensus
  | .badCbHeight                => .consensus
  | .badBlkWeight               => .consensus
  | .duplicateInvalid           => .cachedInvalid
  | .prevBlkNotFound            => .missingPrev
  | .badPrevBlk                 => .invalidPrev
  | .tooLittleChainwork         => .headerLowWork
  | .badBip30                   => .consensus
  | .connectInputs _            => .consensus
  | .blockFeeOutOfRange         => .consensus
  | .nonBip68Final              => .consensus
  | .badBlkSigopsCost           => .consensus
  | .scriptVerifyFailed         => .consensus
  | .badCbAmount                => .consensus
  | .inconclusiveNotBestPrevBlk => .unset
  | .diskWriteError             => .unset
  | .fatalChainError            => .unset

/-- **Taxonomy completeness** (kernel-checked): the only `UNSET`-result
paths are the inconclusive re-check and the two runtime `state.Error`
lanes. Every consensus failure path carries one of the 8 non-unset
`BlockValidationResult` kinds — no orphan result kind. -/
theorem resultOf_complete :
    ∀ p : BlkPath,
      resultOf p ≠ .unset ∨
      p = .inconclusiveNotBestPrevBlk ∨
      p = .diskWriteError ∨ p = .fatalChainError := by
  intro p
  cases p <;> simp [resultOf]

/-- **MUTATED family is exactly these 5 paths** (BLK-012): merkle/witness
data-malleation is never a permanent chain fact. Kernel-checked; repo-side
the merkle pair is `Block.Connect.merkleFailureKind` (BLK-011/012), the
witness trio lives in `Capstone.Block` — noted in F-E03-005. -/
theorem mutated_family :
    ∀ p : BlkPath, resultOf p = .mutated →
      p = .badTxnMerkleRoot ∨ p = .badTxnsDuplicate ∨
      p = .badWitnessNonceSize ∨ p = .badWitnessMerkleMatch ∨
      p = .unexpectedWitness := by
  intro p h
  cases p <;> simp [resultOf] at h ⊢

/-! ## §3  Exact Core reject strings -/

/-- Repo-frozen strings for the stateless `CheckTransaction` taxonomy
(`Bitcoin.TxValidation.txCheckReason`, consensus/tx_check.cpp:23-68). -/
def txCheckReason : Bitcoin.Consensus.TxCheckError → String :=
  Bitcoin.TxValidation.txCheckReason

/-- Repo-frozen strings for the connect-level `CheckTxInputs` taxonomy
(`Bitcoin.TxValidation.rejectReason`, tx_verify.cpp:174-215 + 885/2556/4155). -/
def txErrorReason : Bitcoin.TxValidation.TxError → String :=
  Bitcoin.TxValidation.rejectReason

/-- The literal reject string Core puts in the state at each site. -/
def rejectReason : BlkPath → String
  | .highHash                   => "high-hash"
  | .badDiffBits                => "bad-diffbits"
  | .timeTooOld                 => "time-too-old"
  | .timeTimewarpAttack         => "time-timewarp-attack"
  | .timeTooNew                 => "time-too-new"
  | .badVersion                 => "bad-version(0x%08x)"
  | .badSignetBlkSig            => "bad-signet-blksig"
  | .badTxnMerkleRoot           => "bad-txnmrklroot"
  | .badTxnsDuplicate           => "bad-txns-duplicate"
  | .badBlkLength               => "bad-blk-length"
  | .badCbMissing               => "bad-cb-missing"
  | .badCbMultiple              => "bad-cb-multiple"
  | .badBlkSigopsOob            => "bad-blk-sigops"
  | .badWitnessNonceSize        => "bad-witness-nonce-size"
  | .badWitnessMerkleMatch      => "bad-witness-merkle-match"
  | .unexpectedWitness          => "unexpected-witness"
  | .badNonfinal                => "bad-txns-nonfinal"
  | .badCbHeight                => "bad-cb-height"
  | .badBlkWeight               => "bad-blk-weight"
  | .duplicateInvalid           => "duplicate-invalid"
  | .prevBlkNotFound            => "prev-blk-not-found"
  | .badPrevBlk                 => "bad-prevblk"
  | .tooLittleChainwork         => "too-little-chainwork"
  | .badBip30                   => "bad-txns-BIP30"
  | .blockFeeOutOfRange         => "bad-txns-accumulated-fee-outofrange"
  | .nonBip68Final              => "bad-txns-nonfinal"
  | .badBlkSigopsCost           => "bad-blk-sigops"
  | .badCbAmount                => "bad-cb-amount"
  | .inconclusiveNotBestPrevBlk => "inconclusive-not-best-prevblk"
  | .blockTxStateless e         => txCheckReason e
  | .connectInputs e            => txErrorReason e
  | .scriptVerifyFailed         => "block-script-verify-flag-failed"
  | .diskWriteError             => "failed-to-write-block"
  | .fatalChainError            => "fatal"

theorem reason_high_hash     : rejectReason .highHash = "high-hash" := rfl
theorem reason_bad_diffbits  : rejectReason .badDiffBits = "bad-diffbits" := rfl
theorem reason_timewarp      : rejectReason .timeTimewarpAttack = "time-timewarp-attack" := rfl
theorem reason_time_too_new  : rejectReason .timeTooNew = "time-too-new" := rfl
theorem reason_mrklroot      : rejectReason .badTxnMerkleRoot = "bad-txnmrklroot" := rfl
theorem reason_cve_2012_2459 : rejectReason .badTxnsDuplicate = "bad-txns-duplicate" := rfl
theorem reason_prevblk       : rejectReason .prevBlkNotFound = "prev-blk-not-found" := rfl
theorem reason_bad_prevblk   : rejectReason .badPrevBlk = "bad-prevblk" := rfl
theorem reason_bip30         : rejectReason .badBip30 = "bad-txns-BIP30" := rfl
theorem reason_cb_amount     : rejectReason .badCbAmount = "bad-cb-amount" := rfl
theorem reason_inconclusive  :
    rejectReason .inconclusiveNotBestPrevBlk = "inconclusive-not-best-prevblk" := rfl

/-- The `bad-txns-nonfinal` string is shared by two distinct rules
(BLK-068 block-level finality, 4155; BLK-104 BIP68 sequence locks, 2556) —
F-E03-004: conformance vectors must disambiguate by site, not string. -/
theorem nonfinal_dual_site :
    rejectReason .badNonfinal = rejectReason .nonBip68Final := rfl

/-! ## §4  Traceability: path → rules.yaml row → repo home -/

/-- The `BLK-nnn` row each path maps to (`F-E03-xxx` for the gaps). -/
def failureRow : BlkPath → String
  | .highHash                   => "BLK-039"
  | .badDiffBits                => "BLK-042"
  | .timeTooOld                 => "BLK-057"
  | .timeTimewarpAttack         => "BLK-055"
  | .timeTooNew                 => "BLK-058"
  | .badVersion                 => "BLK-060"
  | .badSignetBlkSig            => "BLK-126"
  | .badTxnMerkleRoot           => "BLK-010"
  | .badTxnsDuplicate           => "BLK-011"
  | .badBlkLength               => "BLK-024"
  | .badCbMissing               => "BLK-027"
  | .badCbMultiple              => "BLK-028"
  | .blockTxStateless _         => "BLK-030"
  | .badBlkSigopsOob            => "BLK-034"
  | .badWitnessNonceSize        => "BLK-018"
  | .badWitnessMerkleMatch      => "BLK-017"
  | .unexpectedWitness          => "BLK-019"
  | .badNonfinal                => "BLK-068"
  | .badCbHeight                => "BLK-069"
  | .badBlkWeight               => "BLK-026"
  | .duplicateInvalid           => "BLK-120"
  | .prevBlkNotFound            => "BLK-063"
  | .badPrevBlk                 => "BLK-064"
  | .tooLittleChainwork         => "BLK-122"
  | .badBip30                   => "BLK-096"
  | .blockFeeOutOfRange         => "BLK-091"
  | .nonBip68Final              => "BLK-104"
  | .badBlkSigopsCost           => "BLK-036"
  | .scriptVerifyFailed         => "BLK-083"
  | .badCbAmount                => "BLK-089"
  | .connectInputs .badTxnsInputsMissingOrSpent     => "BLK-102"
  | .connectInputs .badTxnsInBelowout               => "BLK-103"
  | .connectInputs .badTxnsInputvaluesOutOfRange    => "BLK-103"
  | .connectInputs .badTxnsPrematureSpendOfCoinbase => "BLK-100"
  | .connectInputs _                                => "BLK-102"
  | .inconclusiveNotBestPrevBlk => "F-E03-001"
  | .diskWriteError             => "F-E03-002"
  | .fatalChainError            => "F-E03-002"

@[rule "BLK-039"] theorem row_high_hash      : failureRow .highHash = "BLK-039" := rfl
@[rule "BLK-042"] theorem row_bad_diffbits   : failureRow .badDiffBits = "BLK-042" := rfl
@[rule "BLK-055"] theorem row_bip94_timewarp : failureRow .timeTimewarpAttack = "BLK-055" := rfl
@[rule "BLK-057"] theorem row_time_too_old   : failureRow .timeTooOld = "BLK-057" := rfl
@[rule "BLK-058"] theorem row_time_too_new   : failureRow .timeTooNew = "BLK-058" := rfl
@[rule "BLK-010"] theorem row_mrklroot       : failureRow .badTxnMerkleRoot = "BLK-010" := rfl
@[rule "BLK-011"] theorem row_cve_2012_2459  : failureRow .badTxnsDuplicate = "BLK-011" := rfl
@[rule "BLK-017"] theorem row_wit_commit     : failureRow .badWitnessMerkleMatch = "BLK-017" := rfl
@[rule "BLK-018"] theorem row_wit_nonce      : failureRow .badWitnessNonceSize = "BLK-018" := rfl
@[rule "BLK-019"] theorem row_no_wit         : failureRow .unexpectedWitness = "BLK-019" := rfl
@[rule "BLK-026"] theorem row_weight         : failureRow .badBlkWeight = "BLK-026" := rfl
@[rule "BLK-034"] theorem row_sigops_oob     : failureRow .badBlkSigopsOob = "BLK-034" := rfl
@[rule "BLK-036"] theorem row_sigops_cost    : failureRow .badBlkSigopsCost = "BLK-036" := rfl
@[rule "BLK-063"] theorem row_prev_found     : failureRow .prevBlkNotFound = "BLK-063" := rfl
@[rule "BLK-064"] theorem row_prev_valid     : failureRow .badPrevBlk = "BLK-064" := rfl
@[rule "BLK-068"] theorem row_nonfinal       : failureRow .badNonfinal = "BLK-068" := rfl
@[rule "BLK-069"] theorem row_cb_height      : failureRow .badCbHeight = "BLK-069" := rfl
@[rule "BLK-089"] theorem row_cb_amount      : failureRow .badCbAmount = "BLK-089" := rfl
@[rule "BLK-091"] theorem row_fee_range      : failureRow .blockFeeOutOfRange = "BLK-091" := rfl
@[rule "BLK-096"] theorem row_bip30          : failureRow .badBip30 = "BLK-096" := rfl
@[rule "BLK-100"] theorem row_premature_cb   :
    failureRow (.connectInputs .badTxnsPrematureSpendOfCoinbase) = "BLK-100" := rfl
@[rule "BLK-102"] theorem row_inputs_missing :
    failureRow (.connectInputs .badTxnsInputsMissingOrSpent) = "BLK-102" := rfl
@[rule "BLK-103"] theorem row_in_belowout    :
    failureRow (.connectInputs .badTxnsInBelowout) = "BLK-103" := rfl
@[rule "BLK-104"] theorem row_bip68          : failureRow .nonBip68Final = "BLK-104" := rfl
@[rule "BLK-120"] theorem row_dup_invalid    : failureRow .duplicateInvalid = "BLK-120" := rfl
@[rule "BLK-122"] theorem row_low_work       : failureRow .tooLittleChainwork = "BLK-122" := rfl
@[rule "BLK-126"] theorem row_signet         : failureRow .badSignetBlkSig = "BLK-126" := rfl

/-- The repo declaration that implements each path (audit index;
string-keyed so it stays a doc table — the row bindings above are the
kernel-checked layer). -/
def ourHome : BlkPath → String
  | .highHash                   => "Capstone.Block.CapError.badPow"
  | .badDiffBits                => "Block.Pow.nextWorkRequired"
  | .timeTooOld                 => "Block.Pow.timeNotTooOld"
  | .timeTimewarpAttack         => "Block.Pow.timewarpOk"
  | .timeTooNew                 => "Block.Pow.timeNotTooNew"
  | .badVersion                 => "Capstone.Block.CapError.badVersion"
  | .badSignetBlkSig            => "Block.Params (BLK-126 signet challenge)"
  | .badTxnMerkleRoot           => "Capstone.Block.CapError.badMerkleRoot"
  | .badTxnsDuplicate           => "Block.Connect.merkleFailureKind"
  | .badBlkLength               => "Capstone.Block (BLK-024 stripped size) / .emptyBlock"
  | .badCbMissing               => "Ledger.Interface.BlockError.badCbMissing"
  | .badCbMultiple              => "Ledger.Interface.BlockError.badCbMultiple"
  | .blockTxStateless _         => "Capstone.Block.CapError.txCheck"
  | .badBlkSigopsOob            => "Block.Sigops.legacySigOpBudgetOk"
  | .badWitnessNonceSize        => "Capstone.Block.CapError.badWitnessNonce"
  | .badWitnessMerkleMatch      => "Capstone.Block.CapError.badWitnessCommitment"
  | .unexpectedWitness          => "Capstone.Block.CapError.unexpectedWitness"
  | .badNonfinal                => "Block.Connect.blockFinalityOk"
  | .badCbHeight                => "Capstone.Block.CapError.badCbHeight"
  | .badBlkWeight               => "Capstone.Block.weightOk / CapError.badBlkWeight"
  | .duplicateInvalid           => "Block.Index.submitVerdict"
  | .prevBlkNotFound            => "Block.Params (BLK-063 verdict)"
  | .badPrevBlk                 => "Block.Params (BLK-064 verdict)"
  | .tooLittleChainwork         => "Block.Params.minChainWorkOk"
  | .badBip30                   => "Ledger.Interface.BlockError.badTxnsBIP30"
  | .connectInputs _            => "Capstone.Block.CapError.tx / verifyTxInputs"
  | .blockFeeOutOfRange         => "Block.Connect.feeAccumInRange"
  | .nonBip68Final              => "Block.Connect.blockSequenceLocksOk"
  | .badBlkSigopsCost           => "Block.Sigops.blockSigOpCostOk"
  | .scriptVerifyFailed         => "Capstone.Block.CapError.scriptFail/scriptFalse"
  | .badCbAmount                => "Block.Connect.cbAmountOk"
  | .inconclusiveNotBestPrevBlk => "none — F-E03-001"
  | .diskWriteError             => "none — F-E03-002"
  | .fatalChainError            => "none — F-E03-002"

/-- The gap predicate: no rules.yaml row and no repo constructor. -/
def gap : BlkPath → Bool
  | .inconclusiveNotBestPrevBlk => true
  | .diskWriteError => true
  | .fatalChainError => true
  | _ => false

/-- **Gap completeness** (kernel-checked): exactly the three runtime/
inconclusive paths are unmapped; all 31 rule paths have both a BLK row
and a repo home. -/
theorem gap_iff :
    ∀ p : BlkPath, gap p = true ↔
      p = .inconclusiveNotBestPrevBlk ∨ p = .diskWriteError ∨ p = .fatalChainError := by
  intro p
  cases p <;> simp [gap]

/-- ConnectBlock propagation (validation.cpp:2533–2539): any tx failure
lifts to a block-level `BLOCK_CONSENSUS` failure. -/
def connectWrap : Bitcoin.TxValidation.TxError → BlkPath
  | .stateless e                     => .blockTxStateless e
  | .badTxnsInputsMissingOrSpent     => .connectInputs .badTxnsInputsMissingOrSpent
  | .badTxnsInBelowout               => .connectInputs .badTxnsInBelowout
  | .badTxnsFeeOutOfRange            => .connectInputs .badTxnsFeeOutOfRange
  | .badTxnsInputvaluesOutOfRange    => .connectInputs .badTxnsInputvaluesOutOfRange
  | .badTxnsNonfinal                 => .badNonfinal
  | .badTxnsPrematureSpendOfCoinbase => .connectInputs .badTxnsPrematureSpendOfCoinbase
  | .badTxnsNonstandardSequence      => .nonBip68Final

theorem connectWrap_consensus :
    ∀ e : TxError, resultOf (connectWrap e) = .consensus := by
  intro e
  cases e <;> simp [connectWrap, resultOf]

/-! ## §5  Mode pairing + constants -/

/-- Runtime failures take the sticky `M_ERROR` road (FatalError 2138,
SaveBlockToDisk 4383); all validation failures are `M_INVALID`. -/
def modeOf : BlkPath → BlockMode
  | .diskWriteError | .fatalChainError => .error
  | _ => .invalid

theorem modeOf_runtime_sticky :
    (modeOf .diskWriteError).invalidStep = .error ∧
    (modeOf .fatalChainError).invalidStep = .error := ⟨rfl, rfl⟩

theorem modeOf_validation :
    ∀ p : BlkPath, modeOf p ≠ .error → modeOf p = .invalid := by
  intro p h
  cases p <;> simp [modeOf] at h ⊢

/-- BIP94 guard constant: `consensus.h:35`
`inline constexpr int64_t MAX_TIMEWARP = 600;` — used by
`Block.Pow.timewarpOk` (BLK-055) and the miner-side guard
(node/miner.cpp:58). -/
def MAX_TIMEWARP : Int := 600

theorem timewarp_bound : MAX_TIMEWARP = 600 := rfl

end BitcoinProofs.ErrMap.E03
