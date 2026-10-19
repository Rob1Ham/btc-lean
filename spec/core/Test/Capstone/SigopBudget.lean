import Bitcoin.Capstone.Block
import Bitcoin.Block.Params

/-! The actual ConnectBlock resource fold, plus public serialized blocks
mined at the unchanged mainnet difficulty-one target. The synthetic blocks
are independent height-one forks of real genesis. Stage fixtures are
conditional states, not claims about the current canonical Bitcoin chain. -/

namespace Test.Capstone.SigopBudget

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block Bitcoin.Capstone.Context
open Bitcoin.Capstone.Pow Bitcoin.Block.Params Bitcoin.Activation Bitcoin.Serialization

private def bytes (xs : List UInt8) : ByteArray := List.toByteArray xs
private def script (xs : List UInt8) : Script := ⟨bytes xs⟩
private def previous : OutPoint := ⟨bytes (List.replicate 32 0x33), 0⟩
private def flags : ScriptFlags := { p2sh := true, witness := true, csv := true }
private def cb (cost : Nat := 0) : Tx :=
  { version := 1
    vin := [{ prevout := OutPoint.null, scriptSig := script [1, 1], sequence := 0xffffffff }]
    vout := [{ value := 0, scriptPubKey := script (List.replicate (cost/80) 0xae ++
                                              List.replicate ((cost%80)/4) 0xac) }]
    locktime := 0, witness := [] }
private def redeem : ByteArray := bytes [0, 0x63, 0xac, 0x68, 0x51]
private def p2sh : Script := ⟨bytes [0xa9, 20] ++ Bitcoin.Crypto.Seam.Hash.hash160 redeem ++ bytes [0x87]⟩
private def coin (spk : Script := script [0x51]) (value : Amount := 10)
    (height : UInt32 := 0) : Coin := ⟨value, height, false, spk⟩
private def spend (spk : Script := script [0x51]) (value : Amount := 9) : Tx :=
  { version := 2
    vin := [{ prevout := previous, scriptSig := Script.empty, sequence := 0xffffffff }]
    vout := [{ value := value, scriptPubKey := spk }], locktime := 0, witness := [] }
private def wrongP2sh : Script := ⟨bytes ([0xa9, 20] ++ List.replicate 20 0 ++ [0x87])⟩
private def p2shSpend : Tx :=
  { spend with vin := [{ prevout := previous, scriptSig := ⟨Bitcoin.Script.Parser.pushBytesWire redeem⟩, sequence := 0xffffffff }] }
private def result (txs : List Tx) (l : List (OutPoint × Coin)) (f : ScriptFlags := flags) : String :=
  match applyBlockTransactionsWithSigops none 200 f txs l with
  | .error e => e.reason
  | .ok (_, total) => s!"ok:{total}"

private def child (parent : Tx) : Tx :=
  { p2shSpend with
    vin := [{ prevout := txidKey parent OutPoint.null 0,
              scriptSig := ⟨Bitcoin.Script.Parser.pushBytesWire redeem⟩, sequence := 0xffffffff }]
    vout := [{ value := 8, scriptPubKey := script [0x51] }] }

private def height : UInt32 := 419328
private def relativeResult (sequence : UInt32) : String :=
  let ctx : ChainContext :=
    { parentHeight := height.toNat - 1
      headerAt := fun n => if n < height.toNat then
        some { genesisHeader with time := (500000000 + n*1).toUInt32 } else none
      nodeTime := 2000000000 }
  let parent := (ctx.headerAt ctx.parentHeight).getD genesisHeader
  let candidate := { parent with hashPrevBlock := headerHash parent, time := parent.time+1 }
  match resolveExpectedBits ctx height (headerHash parent) candidate with
  | .error e => e.reason
  | .ok bits =>
    match checkHeaderContext ctx height (headerHash parent) { candidate with bits := bits } with
    | .error e => e.reason
    | .ok facts =>
      let tx := { p2shSpend with
        vin := [{ prevout := previous, scriptSig := ⟨Bitcoin.Script.Parser.pushBytesWire redeem⟩, sequence := sequence }] }
      match applyBlockTransactionsWithSigops (some (ctx, facts)) height flags
          [cb 80000, tx] [(previous, coin p2sh 10 (height-1))] with
      | .error e => e.reason
      | .ok (_, total) => s!"ok:{total}"

private def seededFeeResult : String :=
  match applyTxsWithSigops none 200 flags [p2shSpend] 0
      [(previous, coin p2sh)] 0 0 Bitcoin.Data.MAX_MONEY 80000 with
  | .error e => e.reason
  | .ok _ => "ok"

private def witnessScript : ByteArray := bytes [0, 0x63, 0xac, 0x68, 0x51]
private def witnessCoin : Coin :=
  coin ⟨bytes [0, 32] ++ Bitcoin.Crypto.Seam.sha256 witnessScript⟩
private def witnessSpend : Tx := { spend with witness := [[witnessScript]] }
private def witnessBudget (seed : Nat) : String :=
  match checkSigopTotal none 200 flags witnessSpend [(previous, witnessCoin)] 0 1 seed with
  | .error e => e.reason
  | .ok total => s!"ok:{total}"

private def preludeReason (txs : List Tx) : String :=
  match checkBlockPrelude txs with
  | .error e => e.reason
  | .ok () => "ok"

private def stageChecks : List (String × String × String) :=
  [("CheckBlock exact legacy bound", preludeReason [cb 80000], "ok"),
   ("CheckBlock above legacy bound", preludeReason [cb 80004], "bad-blk-sigops"),
   ("all stateless checks precede legacy bound", preludeReason [cb 80004, { p2shSpend with vout := [] }], "bad-txns-vout-empty"),
   ("coinbase maturity precedes contextual budget", result [cb 80000, p2shSpend]
      [(previous, { coin p2sh 10 101 with isCoinbase := true })], "bad-txns-premature-spend-of-coinbase"),
   ("empty resource fold", result [] [], "ok:0"),
   ("coinbase legacy exact limit", result [cb 80000] [], "ok:80000"),
   ("coinbase legacy above limit", result [cb 80004] [], "bad-blk-sigops"),
   ("coinbase legacy below limit", result [cb 79996] [], "ok:79996"),
   ("P2SH joins cumulative budget", result [cb 80000, p2shSpend] [(previous, coin p2sh)], "bad-blk-sigops"),
   ("P2SH exact cumulative boundary", result [cb 79996, p2shSpend] [(previous, coin p2sh)], "ok:80000"),
   ("P2SH disabled omits its cost", result [cb 80000, p2shSpend] [(previous, coin p2sh)] {}, "ok:80000"),
   ("budget failure precedes script failure", result [cb 80000, p2shSpend]
      [(previous, coin wrongP2sh)], "bad-blk-sigops"),
   ("within budget reaches script failure", result [cb 79996, p2shSpend]
      [(previous, coin wrongP2sh)], "script-verify-error"),
   ("input values precede sigop cost", result [cb 80000, { p2shSpend with vout := [{ value := 11, scriptPubKey := script [0x51] }] }]
      [(previous, coin p2sh)], "bad-txns-in-belowout"),
   ("missing input precedes sigop cost", result [cb 80000, p2shSpend] [],
      "bad-txns-inputs-missingorspent"),
   ("stateless checks precede resource cost", result [cb 80000, { spend with vout := [] }]
      [(previous, coin)], "bad-txns-vout-empty"),
   ("accumulated fee range precedes budget", seededFeeResult, "bad-txns-accumulated-fee-outofrange"),
   ("height BIP68 reaches budget at maturity", relativeResult 1, "bad-blk-sigops"),
   ("height BIP68 precedes budget", relativeResult 2, "bad-txns-nonfinal"),
   ("time BIP68 precedes budget", relativeResult 0x00400001, "bad-txns-nonfinal"),
   ("exempt BIP68 reaches budget", relativeResult 0xffffffff, "bad-blk-sigops"),
   ("same-block spend cost uses created coin", result [cb 80000, spend p2sh, child (spend p2sh)]
      [(previous, coin)], "bad-blk-sigops"),
   ("same-block spend exact boundary", result [cb 79996, spend p2sh, child (spend p2sh)]
      [(previous, coin)], "ok:80000"),
   ("native witness contributes one unit", result [cb 80000, witnessSpend]
      [(previous, witnessCoin)], "bad-blk-sigops"),
   ("valid native witness script executes", result [cb 79996, witnessSpend]
      [(previous, witnessCoin)], "ok:79997"),
   ("one-unit exact boundary", witnessBudget 79999, "ok:80000"),
   ("one-unit above boundary", witnessBudget 80000, "bad-blk-sigops")]

private def context : ChainContext :=
  { parentHeight := 0, headerAt := fun n => if n = 0 then some genesisHeader else none,
    nodeTime := 2000000000 }

private def publicChecks : IO (List (String × String × String)) := do
  let atLimit ← IO.FS.readBinFile "../data/review/sigop-budget/at-limit.raw"
  let over ← IO.FS.readBinFile "../data/review/sigop-budget/over-limit.raw"
  let st : CapState := { height := 1, prevHash := headerHash genesisHeader, utxo := [] }
  let verdict := fun (raw : ByteArray) (contextual : Bool) =>
    match (if contextual then validateBlockInContext raw st context else replayBlockPartial raw st) with
    | .error e => e.reason
    | .ok report => s!"{if report.fullValidation then "ok" else "partial"}:{report.sigOpCost}:{report.sigOpBudgetChecked}"
  let alternateFlags := match decodeBlock atLimit with
    | .error _ => "decode-error"
    | .ok (header, _) =>
      s!"{(candidateScriptFlags 170060 header).p2sh}:{(candidateScriptFlags 692261 header).taproot}"
  return [("public contextual exact limit", verdict atLimit true, "ok:80000:true"),
     ("public contextual above limit", verdict over true, "bad-blk-sigops"),
     ("public replay exact limit", verdict atLimit false, "partial:80000:true"),
     ("public replay above limit", verdict over false, "bad-blk-sigops"),
     ("alternative hashes do not inherit height exceptions", alternateFlags, "true:true")]

def run : IO UInt32 := do
  let checks := stageChecks ++ (← publicChecks)
  let mut failures := 0
  for (name, actual, expected) in checks do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    if !ok then failures := failures + 1
  IO.println s!"sigop-budget checks={checks.length} failures={failures}"
  return if failures == 0 then 0 else 1

end Test.Capstone.SigopBudget

def main : IO UInt32 := Test.Capstone.SigopBudget.run
