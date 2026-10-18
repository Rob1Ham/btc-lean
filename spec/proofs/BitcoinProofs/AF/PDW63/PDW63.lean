import Bitcoin.Block.Params
import Bitcoin.Invariants.RC02
import Bitcoin.TxValidation.Full
import Bitcoin.TxValidation.ScriptExecCache
import Bitcoin.Interpreter.Rules

/-! # PDW63 — TOP-336..340 (claim 50cd23d). Tx-validity/wire-canonicality
band: TXV-031 BIP113 cutoff convention, INV-019 sequence type bit,
TXV-061 full-pipeline checker env, TXV-062 script-exec cache laws,
SWT-037 extended tx decode. TXV-012/TXV-034/SWT-067 found proven by
PDW60/PDW67 at flip time; TXV-032 yielded to PDW70 (swap recorded). Route B, zero core writes. -/

namespace BitcoinProofs.AF.PDW63

open Bitcoin.DataLaws

/-- **TXV-031**: the BIP113 cutoff is the caller-supplied previous-block
MTP, unchanged (validation.cpp:4143-4151 convention pin). -/
@[rule "TXV-031"]
theorem bip113Cutoff_row (prevBlockMtp : UInt32) :
    Bitcoin.TxValidation.bip113Cutoff prevBlockMtp = prevBlockMtp := rfl

/-- **TXV-031** (full cutoff rule, validation.cpp:ContextualCheckBlock
:4143-4151): the finality time cutoff is the parent block's MTP once CSV
is active and the block's own time before activation. Composes the
caller-convention identity pin `TxValidation.bip113Cutoff` with RC02's
INV-015 selection `RC02.bip113Cutoff`. -/
@[rule "TXV-031"]
theorem bip113Cutoff_selection_row (csvActive : Bool) (prevBlockMtp blockTime : UInt32) :
    Bitcoin.TxValidation.bip113Cutoff
      (Bitcoin.Invariants.RC02.bip113Cutoff csvActive prevBlockMtp blockTime) =
      if csvActive then prevBlockMtp else blockTime := by
  cases csvActive <;> rfl

/-- **TXV-031**: the two arms as separate implications — post-CSV the
cutoff is `MTP(prev block)`, pre-CSV it is the block time. -/
@[rule "TXV-031"]
theorem bip113Cutoff_arms_row (prevBlockMtp blockTime : UInt32) :
    Bitcoin.TxValidation.bip113Cutoff
        (Bitcoin.Invariants.RC02.bip113Cutoff true prevBlockMtp blockTime) = prevBlockMtp ∧
      Bitcoin.TxValidation.bip113Cutoff
        (Bitcoin.Invariants.RC02.bip113Cutoff false prevBlockMtp blockTime) = blockTime :=
  ⟨rfl, rfl⟩

/-- **INV-019**: time-based ⇔ bit 22 of nSequence set. -/
@[rule "INV-019"]
theorem seqIsTimeBased_row (s : UInt32) :
    seqIsTimeBased s = true ↔ s.toNat.testBit 22 = true :=
  seqIsTimeBased_iff s

/-- **INV-019** (full BIP68 time-lock formula, tx_verify.cpp:79-94): for a
non-disabled, type-flagged sequence the time-domain lockpoint is
`MTP(coin-block's parent) + (nSequence & 0xffff)·512 − 1`. The masked
value is `seqRelative` and 512 is `2^SEQUENCE_LOCKTIME_GRANULARITY`. -/
@[rule "INV-019"]
theorem seqTimeLock_formula_row (i : Bitcoin.Data.TxIn) (prevH mtp : Int)
    (hlock : Bitcoin.TxValidation.seqLockApplies i.sequence = true)
    (htime : seqIsTimeBased i.sequence = true) :
    Bitcoin.TxValidation.timeLockOf (i, (prevH, mtp)) =
      some (mtp + ((seqRelative i.sequence * 512 : Nat) : Int) - 1) :=
  Bitcoin.TxValidation.timeLockOf_some hlock htime

/-- **INV-019**: the masked sequence really is `nSequence & 0xffff`
(transaction.h:105, `SEQUENCE_LOCKTIME_MASK`). -/
@[rule "INV-019"]
theorem seqRelative_mask_row (s : UInt32) :
    seqRelative s = s.toNat % 65536 :=
  seqRelative_eq_mod s

/-- **INV-019**: 512 seconds is exactly `2^9`, the BIP68 granularity
(transaction.h:107-115). -/
@[rule "INV-019"]
theorem seqTimeGranularity_row :
    (512 : Nat) = 2 ^ SEQUENCE_LOCKTIME_GRANULARITY :=
  seqTimeGranularity_pow

/-- **INV-019**: type-flag bit selects the 512-second domain. -/
@[rule "INV-019"]
theorem seqIsTimeBased_flag_row :
    seqIsTimeBased 0x00400000 = true ∧ seqIsTimeBased 0 = false := by
  decide

/-- **TXV-061**: the full-pipeline checker's locktime env is exactly the
tx's version/locktime and the input's sequence. -/
@[rule "TXV-061"]
theorem txCheckerFor_env_row (tx : Bitcoin.Data.Tx) (nIn : Nat)
    (amount : Option Bitcoin.Data.Amount) :
    (Bitcoin.TxValidation.Full.txCheckerFor tx nIn amount).env =
      { txVersion := tx.version
        txLockTime := tx.locktime
        txSequence := (tx.vin.getD nIn Bitcoin.Capstone.RealChecker.dummyTxIn).sequence } := rfl

/-- **TXV-062**: a cache hit accepts without executing and leaves the
cache unchanged. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_hit_row
    (c : Bitcoin.TxValidation.ScriptExecCache.ScriptExecCache)
    (k : Bitcoin.TxValidation.ScriptExecCache.ScriptExecCacheKey)
    (exec : Bitcoin.TxValidation.ScriptExecCache.ScriptExecCacheKey → Option Bool)
    (store pv : Bool)
    (hhit : Bitcoin.TxValidation.ScriptExecCache.cacheContains c k = true) :
    Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached c k exec store pv
      = (some true, c) :=
  Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_hit c k exec store pv hhit

/-- **TXV-062**: the deferring (`pvChecks`) miss arm returns true without
storing — verdict-transparent. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_defers_row
    (c : Bitcoin.TxValidation.ScriptExecCache.ScriptExecCache)
    (k : Bitcoin.TxValidation.ScriptExecCache.ScriptExecCacheKey)
    (exec : Bitcoin.TxValidation.ScriptExecCache.ScriptExecCacheKey → Option Bool)
    (store pv : Bool)
    (hmiss : Bitcoin.TxValidation.ScriptExecCache.cacheContains c k = false)
    (hpv : pv = true) :
    Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached c k exec store pv
        = (some true, c) ∧
      (Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached c k exec store pv).2 = c :=
  Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_miss_defers c k exec store pv hmiss hpv

/-- **SCR-031**: on the tapscript path, away from OP_SUCCESSx, the BIP342
initial-stack gate runs before EvalScript: >1000 items ⇒ STACK_SIZE. -/
@[rule "SCR-031"]
theorem executeWitnessScript_stackgate_row (fuel : Nat) (items : List ByteArray)
    (vwSer : Int) (exec : ByteArray) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : Bitcoin.Interpreter.PolicyFlags) (chk : Bitcoin.Interpreter.ScriptChecker)
    (hscan : Bitcoin.Interpreter.opSuccessScan exec = false)
    (hmany : Bitcoin.Interpreter.MAX_STACK_SIZE < items.length) :
    Bitcoin.Interpreter.executeWitnessScript fuel items vwSer exec flags pol chk
        Bitcoin.Crypto.Seam.SigVersion.tapscript
      = Bitcoin.Interpreter.VerifyOutcome.fail .stackSize :=
  Bitcoin.Interpreter.executeWitnessScript_tapscript_stackgate
    fuel items vwSer exec flags pol chk hscan hmany

/-- **TXV-001**: empty `vin` ⇒ `bad-txns-vin-empty`. -/
@[rule "TXV-001"]
theorem checkTransaction_vinEmpty_row (tx : Bitcoin.Data.Tx) (h : tx.vin = []) :
    Bitcoin.Consensus.checkTransaction tx
      = some Bitcoin.Consensus.TxCheckError.vinEmpty := by
  unfold Bitcoin.Consensus.checkTransaction
  rw [h]
  rfl

/-- **TXV-002**: non-empty `vin` + empty `vout` ⇒ `bad-txns-vout-empty`
(gate 1 passed first). -/
@[rule "TXV-002"]
theorem checkTransaction_voutEmpty_row (tx : Bitcoin.Data.Tx)
    (hvin : tx.vin ≠ []) (h : tx.vout = []) :
    Bitcoin.Consensus.checkTransaction tx
      = some Bitcoin.Consensus.TxCheckError.voutEmpty := by
  unfold Bitcoin.Consensus.checkTransaction
  rw [h]
  split
  · next h1 => simp at h1; exact absurd h1 hvin
  · next _ =>
    split
    · rfl
    · next h2 => exact absurd (by simp) h2

/-- **INV-148**: no assumevalid option ⇒ never skip script checks. -/
@[rule "INV-148"]
theorem assumevalidSkipped_none_row (inputHeight : Nat) (guard : Bool) :
    Bitcoin.Block.Params.assumevalidSkipped none inputHeight guard = false :=
  Bitcoin.Block.Params.assumevalidSkipped_none inputHeight guard

/-- **INV-148**: at or above the assumevalid ancestor ⇒ checks enforced. -/
@[rule "INV-148"]
theorem assumevalidSkipped_atOrAbove_row (a h : Nat) (hle : a ≤ h) :
    Bitcoin.Block.Params.assumevalidSkipped (some a) h true = false :=
  Bitcoin.Block.Params.assumevalidSkipped_at_or_above a h true hle

/-- **INV-148** (full modeled gate, validation.cpp:2344-2400): the script
checks are skipped exactly when an assumevalid height is configured, the
input sits strictly below it, and the 2-week equivalent-time guard holds.
`none` (trust option absent) never skips; at/above the ancestor never
skips. -/
@[rule "INV-148"]
theorem assumevalidSkipped_iff_row (av : Option Nat) (h : Nat) (g : Bool) :
    Bitcoin.Block.Params.assumevalidSkipped av h g = true ↔
      ∃ a, av = some a ∧ h < a ∧ g = true := by
  cases av with
  | none => simp [Bitcoin.Block.Params.assumevalidSkipped]
  | some a =>
    simp only [Bitcoin.Block.Params.assumevalidSkipped, Option.map_some,
      Option.getD_some]
    by_cases hlt : h < a
    · rw [if_pos hlt]
      constructor
      · intro hg
        exact ⟨a, rfl, hlt, hg⟩
      · rintro ⟨a', ha', hlt', hg⟩
        simp only [Option.some.injEq] at ha'
        subst ha'
        exact hg
    · rw [if_neg hlt]
      constructor
      · intro hf
        exact absurd hf (by simp)
      · rintro ⟨a', ha', hlt', hg⟩
        simp only [Option.some.injEq] at ha'
        subst ha'
        exact absurd hlt' hlt

/-- **INV-148**: below the ancestor but failing the 2-week eq-time guard ⇒
checks still enforced. -/
@[rule "INV-148"]
theorem assumevalidSkipped_belowNoGuard_row (a h : Nat) (hlt : h < a) :
    Bitcoin.Block.Params.assumevalidSkipped (some a) h false = false :=
  Bitcoin.Block.Params.assumevalidSkipped_below_no_guard a h hlt

end BitcoinProofs.AF.PDW63

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/
/-- info: 'BitcoinProofs.AF.PDW63.bip113Cutoff_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.bip113Cutoff_row
/-- info: 'BitcoinProofs.AF.PDW63.seqIsTimeBased_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.seqIsTimeBased_row
/-- info: 'BitcoinProofs.AF.PDW63.seqIsTimeBased_flag_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.seqIsTimeBased_flag_row
/-- info: 'BitcoinProofs.AF.PDW63.txCheckerFor_env_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.txCheckerFor_env_row
/-- info: 'BitcoinProofs.AF.PDW63.checkInputScriptsCached_hit_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.checkInputScriptsCached_hit_row
/-- info: 'BitcoinProofs.AF.PDW63.checkInputScriptsCached_defers_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.checkInputScriptsCached_defers_row
/-- info: 'BitcoinProofs.AF.PDW63.executeWitnessScript_stackgate_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.executeWitnessScript_stackgate_row

/-- info: 'BitcoinProofs.AF.PDW63.checkTransaction_vinEmpty_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.checkTransaction_vinEmpty_row
/-- info: 'BitcoinProofs.AF.PDW63.checkTransaction_voutEmpty_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.checkTransaction_voutEmpty_row
/-- info: 'BitcoinProofs.AF.PDW63.assumevalidSkipped_none_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.assumevalidSkipped_none_row
/-- info: 'BitcoinProofs.AF.PDW63.assumevalidSkipped_atOrAbove_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.assumevalidSkipped_atOrAbove_row
/-- info: 'BitcoinProofs.AF.PDW63.assumevalidSkipped_belowNoGuard_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63.assumevalidSkipped_belowNoGuard_row
