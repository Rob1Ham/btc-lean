import Bitcoin.Block.Pow
import Bitcoin.Capstone.Pow
import Bitcoin.TxValidation.Interface
import Bitcoin.Ledger.Utxo

/-!
# Explicit parent-chain context for capstone validation

`headerAt` is the ancestor lookup of the caller's already validated parent
chain, analogous to Core's CBlockIndex::GetAncestor. Like the supplied UTXO
view, it is input state; this module does not revalidate the entire past chain.
The tip is bound to the replay state's parent hash. Every requested ancestor
must exist: sparse caches cannot silently shorten an MTP window. Node time is
an explicit signed integer in seconds, rather than the candidate timestamp.

This interface is mainnet-specific. Network-specific activation schedules and
PoW parameters must not be silently mixed into its caller-provided history.
-/

namespace Bitcoin.Capstone.Context

open Bitcoin.Chain Bitcoin.Data Bitcoin.Block.Pow Bitcoin.Capstone.Pow

structure ChainContext where
  parentHeight : Nat
  headerAt : Nat → Option BlockHeader
  nodeTime : Int

/-- Missing/inconsistent input context is distinct from a consensus rejection. -/
inductive ContextError where
  | heightMismatch
  | parentMismatch
  | missingAncestor (height : Nat)
  | missingCoin
  | badDiffbits
  | timeTooOld
  | timeTooNew
deriving Repr, DecidableEq

def ContextError.reason : ContextError → String
  | .heightMismatch => "context-height-mismatch"
  | .parentMismatch => "context-parent-mismatch"
  | .missingAncestor _ => "context-missing-ancestor"
  | .missingCoin => "context-missing-coin"
  | .badDiffbits => "bad-diffbits"
  | .timeTooOld => "time-too-old"
  | .timeTooNew => "time-too-new"

theorem ContextError.reason_nonempty (e : ContextError) : e.reason ≠ "" := by
  cases e <;> simp only [ContextError.reason] <;> decide

/-- The missing-data errors describe unavailable validation, not invalid blocks. -/
def ContextError.isUnavailable : ContextError → Bool
  | .heightMismatch | .parentMismatch | .missingAncestor _ | .missingCoin => true
  | _ => false

def ancestor (ctx : ChainContext) (height : Nat) : Except ContextError BlockHeader :=
  if height > ctx.parentHeight then .error (.missingAncestor height)
  else match ctx.headerAt height with
    | none => .error (.missingAncestor height)
    | some h => .ok h

/-- Require the complete Core window of min(height+1, 11) headers. -/
def requireMtpWindow (ctx : ChainContext) : Nat → Nat → Except ContextError Unit
  | 0, _ => .ok ()
  | fuel+1, height => do
    let _ ← ancestor ctx height
    if height = 0 then pure () else requireMtpWindow ctx fuel (height-1)

/-- The existing upper-median implementation is used only after all required
heights resolve. Missing ancestors never become zeros or a shorter window. -/
def medianTimePastStrict (ctx : ChainContext) (height : Nat) :
    Except ContextError UInt32 := do
  requireMtpWindow ctx 11 height
  match medianTimePast (fun n => (ctx.headerAt n).map (·.time)) height with
  | none => .error (.missingAncestor height)
  | some mtp => .ok mtp

structure HeaderFacts where
  expectedBits : UInt32
  parentMtp : UInt32
deriving Repr, DecidableEq

/-- Resolve actual parent context and expected mainnet nBits. The signed
Core height domain is checked before converting or adding a UInt32 height. -/
def resolveExpectedBits (ctx : ChainContext) (height : UInt32) (parentHash : ByteArray)
    (header : BlockHeader) : Except ContextError UInt32 := do
  if ctx.parentHeight ≥ 2147483647 || height.toNat != ctx.parentHeight + 1 then
    throw ContextError.heightMismatch
  let parent ← ancestor ctx ctx.parentHeight
  if !bytesBEq (headerHash parent) parentHash then throw ContextError.parentMismatch
  let getIndex := fun n => (ctx.headerAt n).map (fun h => ({ bits := h.bits, time := h.time } : IndexNode))
  let expected ← match nextWorkRequired mainnetParams getIndex ctx.parentHeight header.time with
    | none => .error (.missingAncestor (ctx.parentHeight - (difficultyAdjustmentInterval mainnetParams - 1)))
    | some bits => .ok bits
  pure expected

/-- Core ContextualCheckBlockHeader: expected nBits, strict parent MTP,
then the node-clock future bound. Version gates follow in the caller. -/
def checkHeaderContext (ctx : ChainContext) (height : UInt32) (parentHash : ByteArray)
    (header : BlockHeader) : Except ContextError HeaderFacts := do
  let expected ← resolveExpectedBits ctx height parentHash header
  if header.bits != expected then throw ContextError.badDiffbits
  let mtp ← medianTimePastStrict ctx ctx.parentHeight
  if !timeNotTooOld header.time mtp then throw ContextError.timeTooOld
  if !((header.time.toNat : Int) ≤ ctx.nodeTime + 7200) then throw ContextError.timeTooNew
  pure ⟨expected, mtp⟩

/-- BIP113 uses the parent's actual MTP after CSV, candidate time before it. -/
@[rule "BLK-067"]
def finalityCutoffAtHeight (height parentMtp blockTime : UInt32) : UInt32 :=
  if Bitcoin.Activation.CSV_HEIGHT ≤ height then parentMtp else blockTime

/-- All transactions, including the coinbase, must satisfy IsFinalTx. -/
@[rule "BLK-068"]
def blockFinalityAtHeight (txs : List Tx) (height parentMtp blockTime : UInt32) : Bool :=
  txs.all (fun tx => Bitcoin.DataLaws.isFinalTx tx height
    (finalityCutoffAtHeight height parentMtp blockTime))

/-- Build exactly one BIP68 datum per input against the CURRENT view.
Only an enabled time-domain input reads coin-parent MTP, at max(h-1,0).
For height/disabled inputs the time field is unused by CalculateSequenceLocks;
we carry the already-resolved block-parent MTP rather than invent historical
zero times or require irrelevant old headers. Missing coins/history fail.
The caller skips this function entirely when BIP68 is not enabled. -/
def sequenceInputData (ctx : ChainContext) (parentMtp : UInt32)
    (u : Bitcoin.Ledger.UtxoSet) : List TxIn → Except ContextError (List (Int × Int))
  | [] => .ok []
  | input :: rest => do
    let coin ← match u input.prevout with
      | none => .error .missingCoin
      | some coin => .ok coin
    let mtp ←
      if Bitcoin.TxValidation.seqLockApplies input.sequence &&
          Bitcoin.DataLaws.seqIsTimeBased input.sequence then
        medianTimePastStrict ctx (coin.height.toNat - 1)
      else pure parentMtp
    let tail ← sequenceInputData ctx parentMtp u rest
    pure (((coin.height.toNat : Int), (mtp.toNat : Int)) :: tail)

end Bitcoin.Capstone.Context
