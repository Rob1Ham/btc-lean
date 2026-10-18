import Bitcoin.Capstone.Block
import Bitcoin.Block.Params

/-!
R03 executable regressions for the actual contextual transaction stage and
public serialized-block entry. Stage fixtures use a deterministic ancestor
index to test exact BIP68 boundaries; they do not assert reachable chain
history. The public rejection preserves real block 349992 bytes and its real
parent header, supplied at conditional candidate height 1. Its transaction 33
has nLockTime=349980 and nSequence=0xfffffffe, so ContextualCheckBlock must
reject it as nonfinal before UTXO access. See data/review/r03/provenance.json.
Real block 1 is the public acceptance/coverage control.
-/

namespace Test.Capstone.Finality

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block Bitcoin.Capstone.Context
open Bitcoin.Block.Params Bitcoin.Capstone.Pow Bitcoin.Serialization

private def previous (n : UInt32 := 0) : OutPoint :=
  ⟨List.toByteArray (List.replicate 32 0x33), n⟩

private def coin (height : UInt32) (value : Amount := 10) (ok : Bool := true) : Coin :=
  ⟨value, height, false, scriptOf [if ok then 0x51 else 0x00]⟩

private def spend (sequence : UInt32) (version : Int32 := 2) (n : UInt32 := 0)
    (value : Amount := 9) : Tx :=
  { version := version
    vin := [{ prevout := previous n, scriptSig := Script.empty, sequence := sequence }]
    vout := [{ value := value, scriptPubKey := scriptOf [0x51] }]
    locktime := 0, witness := [] }

private def cb : Tx :=
  { version := 1
    vin := [{ prevout := OutPoint.null, scriptSig := scriptOf [0x01, 0x01], sequence := 0xffffffff }]
    vout := [{ value := 0, scriptPubKey := scriptOf [0x51] }]
    locktime := 0, witness := [] }

private def context (height : UInt32) (step : Nat := 512) : ChainContext :=
  { parentHeight := height.toNat - 1
    headerAt := fun n => if n < height.toNat then
      some { genesisHeader with time := (500000000 + n*step).toUInt32 } else none
    nodeTime := 2000000000 }

private def stageReason (height : UInt32) (txs : List Tx) (view : List (OutPoint × Coin))
    (step : Nat := 512) (missing : Option Nat := none) : String :=
  let base := context height step
  let ctx := { base with headerAt := fun n => if missing == some n then none else base.headerAt n }
  match ctx.headerAt ctx.parentHeight with
  | none => "context-missing-ancestor"
  | some parent =>
    let parentHash := headerHash parent
    let candidate := { parent with time := parent.time + 1, hashPrevBlock := parentHash }
    match resolveExpectedBits ctx height parentHash candidate with
    | .error e => e.reason
    | .ok bits =>
      match checkHeaderContext ctx height parentHash { candidate with bits := bits } with
      | .error e => e.reason
      | .ok facts =>
        match applyContextualBlockTransactions ctx facts height (cb :: txs) view with
        | .ok _ => "ok"
        | .error e => e.reason

private def child (parent : Tx) (sequence : UInt32) : Tx :=
  { spend sequence with vin := [{ prevout := txidKey parent OutPoint.null 0,
                                  scriptSig := Script.empty, sequence := sequence }],
                         vout := [{ value := 8, scriptPubKey := scriptOf [0x51] }] }

private def h : UInt32 := 419328

private def stageChecks : List (String × String × String) :=
  [("height lock first valid block", stageReason h [spend 1] [(previous, coin (h-1))], "ok"),
   ("height lock last invalid block", stageReason h [spend 2] [(previous, coin (h-1))], "bad-txns-nonfinal"),
   ("time lock exact 512-second boundary", stageReason h [spend 0x00400001] [(previous, coin (h-1))], "ok"),
   ("time lock 511-second boundary rejects", stageReason h [spend 0x00400001]
      [(previous, coin (h-1))] 511, "bad-txns-nonfinal"),
   ("version one is exempt", stageReason h [spend 65535 1] [(previous, coin (h-1))], "ok"),
   ("wire ffffffff version is unsigned in pinned Core", stageReason h [spend 65535 (-1)] [(previous, coin (h-1))], "bad-txns-nonfinal"),
   ("before CSV activation is exempt", stageReason (h-1) [spend 65535] [(previous, coin (h-2))], "ok"),
   ("disable bit ignores relative lock", stageReason h [spend 0x8040ffff] [(previous, coin (h-1))], "ok"),
   ("reserved sequence bits are ignored", stageReason h [spend 0x40010001] [(previous, coin (h-1))], "ok"),
   ("same-block height lock zero", stageReason h [spend 0xffffffff, child (spend 0xffffffff) 0]
      [(previous, coin (h-1))], "ok"),
   ("same-block height lock one rejects", stageReason h [spend 0xffffffff, child (spend 0xffffffff) 1]
      [(previous, coin (h-1))], "bad-txns-nonfinal"),
   ("same-block time lock zero", stageReason h [spend 0xffffffff, child (spend 0xffffffff) 0x00400000]
      [(previous, coin (h-1))], "ok"),
   ("same-block time lock one rejects", stageReason h [spend 0xffffffff, child (spend 0xffffffff) 0x00400001]
      [(previous, coin (h-1))], "bad-txns-nonfinal"),
   ("input amounts precede relative finality", stageReason h [spend 2 2 0 11]
      [(previous, coin (h-1))], "bad-txns-in-belowout"),
   ("relative finality precedes script failure", stageReason h [spend 2]
      [(previous, coin (h-1) 10 false)], "bad-txns-nonfinal"),
   ("missing inputs precede relative finality", stageReason h [spend 2] [], "bad-txns-inputs-missingorspent"),
   ("coinbase maturity precedes relative finality", stageReason h [spend 2]
      [(previous, { coin (h-1) with isCoinbase := true })], "bad-txns-premature-spend-of-coinbase"),
   ("time lock missing old window is unavailable", stageReason h [spend 0x00400001]
      [(previous, coin 100)] 512 (some 94), "context-missing-ancestor"),
   ("height lock does not require unused old MTP", stageReason h [spend 1]
      [(previous, coin 100)] 512 (some 94), "ok"),
   ("disabled time input does not require old MTP", stageReason h [spend 0x80400001]
      [(previous, coin 100)] 512 (some 94), "ok"),
   ("version-exempt time input does not require old MTP", stageReason h [spend 0x00400001 1]
      [(previous, coin 100)] 512 (some 94), "ok"),
   ("coin at height zero uses genesis MTP", stageReason h [spend 0x00400001]
      [(previous, coin 0)], "ok"),
   ("context fee accumulation at MAX_MONEY", stageReason h [spend 0xffffffff 2 0 0]
      [(previous, coin (h-1) MAX_MONEY)], "ok"),
   ("context accumulated-fee overflow precedes sequence and script failure", stageReason h
      [spend 0xffffffff 2 0 0, spend 2 2 1 0]
      [(previous 0, coin (h-1) MAX_MONEY), (previous 1, coin (h-1) 1 false)],
      "bad-txns-accumulated-fee-outofrange"),
   ("two inputs cannot truncate an unsatisfied second lock", stageReason h
      [{ spend 1 with vin := (spend 1).vin ++ (spend 2 2 1).vin }]
      [(previous 0, coin (h-1)), (previous 1, coin (h-1))], "bad-txns-nonfinal")]

private def absolute (height mtp time locktime seq : UInt32) : String :=
  toString (blockFinalityAtHeight [{ spend seq with locktime := locktime }] height mtp time)

private def absoluteChecks : List (String × String × String) :=
  [("absolute height equal rejects", absolute h 800000000 900000000 h 0xfffffffe, "false"),
   ("absolute height below accepts", absolute h 800000000 900000000 (h-1) 0xfffffffe, "true"),
   ("absolute lock ignores all-final sequences", absolute h 800000000 900000000 0xffffffff 0xffffffff, "true"),
   ("BIP113 uses parent MTP rather than candidate time", absolute h 800000000 900000000 800000000 0xfffffffe, "false"),
   ("BIP113 time one below MTP accepts", absolute h 800000000 900000000 799999999 0xfffffffe, "true"),
   ("pre-CSV uses candidate time", absolute (h-1) 800000000 900000000 800000000 0xfffffffe, "true")]

private def publicReject : IO String := do
  let raw ← IO.FS.readBinFile "../data/review/r03/block349992.raw"
  let parentRaw ← IO.FS.readBinFile "../data/review/r03/parent349991.header"
  let parent ← match decodeBlockHeader parentRaw with
    | .error _ => throw (IO.userError "fixture parent did not decode")
    | .ok p => pure p
  let ctx : ChainContext := { parentHeight := 0, headerAt := fun n => if n = 0 then some parent else none,
                              nodeTime := 2000000000 }
  match validateBlockInContext raw { height := 1, prevHash := headerHash parent, utxo := [] } ctx with
  | .ok _ => pure "ok"
  | .error e => pure e.reason

def run : IO UInt32 := do
  let rejected ← publicReject
  let raw ← IO.FS.readBinFile "../data/review/r03/block1.raw"
  let ctx : ChainContext := { parentHeight := 0, headerAt := fun n => if n = 0 then some genesisHeader else none,
                              nodeTime := 2000000000 }
  let coverage := match validateBlockInContext raw { height := 1, prevHash := headerHash genesisHeader, utxo := [] } ctx with
    | .error e => e.reason
    | .ok report => toString (report.headerContextChecked && report.absoluteFinalityChecked && report.sequenceLocksChecked)
  let checks := stageChecks ++ absoluteChecks ++
    [("public serialized block enforces absolute finality before UTXOs", rejected, "bad-txns-nonfinal"),
     ("public real block one accepts with finality coverage", coverage, "true")]
  let results ← checks.mapM fun (name, actual, expected) => do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    return ok
  return if results.all id then 0 else 1

end Test.Capstone.Finality

def main : IO UInt32 := Test.Capstone.Finality.run
