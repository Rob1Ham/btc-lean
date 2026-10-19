import Bitcoin.Serialization.Interface
import Bitcoin.Consensus.TxCheck
import Bitcoin.TxValidation.Interface
import Bitcoin.Capstone.Block
import Bitcoin.Capstone.Merkle
import Bitcoin.Capstone.RealChecker

/-!
# V08Run — support suite: mainnet anchor expansion

anchor expansion for blocks **320000 / 333000 / 340000** (2014-2015
era-boundary points the 6 original anchors miss: pre-BIP66-menu
flexibility era, heavy P2SH/P2PK mix, 1MB-limit blocks).

The validation logic is a verbatim reuse of the capstone runner
`spec/core/Test/Capstone/Run.lean` (`seedCoins`, `probeTx`, `runAnchor`,
`BlockResult` — copied into this NEW file because `Run.lean` fixes the
anchor list and vector dir, and V08 must not edit existing files).
Pipeline per block is unchanged: decode → BLK-022..029 structure →
BLK-060/061/062 version gates → BLK-069 BIP34 → PoW (BLK-037..039) →
chain-link vs the REAL parent hash → merkle (BLK-005..020) + witness
commitment gate → per-tx checkTransaction + checkTxInputs →
per-input verifyScriptFull with the REAL ECDSA checker →
applyTxStepL fold keyed by the REAL txid + foldAgrees cross-check.

Vector dir: `spec/vectors/anchors2/V08/` (the V08 corpus;
other anchors2 subtrees are separate). Files per block: `<H>.raw`, `<H>.hash`, `<H>.parent`,
`<H>.seeds` (format identical to the anchors: `<wire-order txid>
<height> <raw tx hex>`).

Run (compiled, from spec/core/):
  lake env lean -o /tmp/.../v08capstone <this file> && /tmp/.../v08capstone
-/

namespace V08.Run

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Ledger Bitcoin.Consensus
open Bitcoin.TxValidation
open Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle Bitcoin.Capstone.Pow

set_option maxRecDepth 100000

/-! ## Hex + file helpers (verbatim from Test.Capstone.Run) -/

def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

def trimStr (s : String) : String :=
  (String.ofList (s.toList.filter (fun c => c != ' ' && c != '\n' && c != '\r')))

def toHex (b : ByteArray) : String :=
  (List.range b.size).foldl (fun acc i =>
    let v := (b.get! i).toNat
    let d := "0123456789abcdef"
    acc ++ String.singleton (d.toList.getD (v / 16) '0') ++ String.singleton (d.toList.getD (v % 16) '0')) ""

private def dummyTx : Tx := ⟨0, [], [], 0, []⟩

/-! ## Seed materialization (verbatim from Test.Capstone.Run) -/

def seedCoins (line : String) : List (OutPoint × Coin) :=
  match line.splitOn " " with
  | [txidHex, hHex, rawHex] =>
      match decodeTx (fromHex rawHex) with
      | .error _ => []
      | .ok tx =>
          let key := fromHex txidHex
          (List.range tx.vout.length).filterMap (fun k =>
            let o := tx.vout.getD k ⟨0, Script.empty⟩
            if scriptUnspendable o.scriptPubKey then none
            else some (⟨key, UInt32.ofNat k⟩,
                       ⟨o.value, (hHex.toNat!).toUInt32, tx.isCoinBase, o.scriptPubKey⟩))
  | _ => []

/-! ## Per-tx probe (verbatim from Test.Capstone.Run) -/

def probeTx (height : UInt32) (tx : Tx) (i : Nat)
    (l : List (OutPoint × Coin)) : String :=
  match checkTransaction tx with
  | some e => s!"tx#{i}: STATELESS {txCheckReason e}"
  | none =>
    if tx.isCoinBase then s!"tx#{i}: coinbase"
    else
      let scriptRes := verifyTxInputs height tx i l
      let ledRes := applyTxStepL l tx (txidKey tx) height
      match scriptRes, ledRes with
      | .error e, _ => s!"tx#{i}: SCRIPT {CapError.reason e}"
      | _, .error e => s!"tx#{i}: LEDGER {match e with
          | .txError e' => rejectReason e'
          | .badTxnsBIP30 => "bad-txns-BIP30"
          | .badCbMissing => "bad-cb-missing"
          | .badCbMultiple => "bad-cb-multiple"}"
      | .ok _, .ok _ => s!"tx#{i}: ok"

/-! ## The per-block run (verbatim from Test.Capstone.Run) -/

structure BlockResult where
  height : Nat
  blockHash : String
  ok : Bool
  reason : String := ""
  txs : Nat := 0
  scriptOk : Nat := 0
  scriptUnjudged : Nat := 0
  ms : Nat := 0
  foldAgrees : Bool := true
  probe : String := ""
  scriptAdjudication : ScriptAdjudication := .incomplete
  deriving Repr

def runAnchor (dir : String) (height : Nat) : IO BlockResult := do
  let t0 ← IO.monoMsNow
  let raw ← IO.FS.readBinFile s!"{dir}/{height}.raw"
  let parent ←
    match (← (IO.FS.readFile s!"{dir}/{height}.parent" <|> pure "")) with
    | "" => pure ByteArray.empty
    | ph => pure (bytesOfList (bL (fromHex (trimStr ph))).reverse)
  let seedLines ←
    match (← (IO.FS.readFile s!"{dir}/{height}.seeds" <|> pure "")) with
    | "" => pure []
    | txt => pure ((txt.splitOn "\n").filter (fun l => !(trimStr l).isEmpty))
  -- The release seed set can contain outputs created at the candidate height.
  -- Those are not in the pristine pre-block view; pass only earlier coins to
  -- BIP30, the fold, and the per-tx probes. Same-block spends are created by
  -- the fold itself.
  let seeds := (seedLines.flatMap seedCoins).filter (fun (_, c) => c.height.toNat < height)
  let st : CapState := ⟨(UInt32.ofNat height), parent, seeds⟩
  let res : BlockResult :=
    match replayBlockPartial raw st with
    | .error e => { height := height, blockHash := "", ok := false, reason := CapError.reason e }
    | .ok rep =>
        let txsL : List Tx :=
          match decodeBlock raw with
          | Except.error _ => []
          | Except.ok (_, txs) => txs
        let folded := applyBlockL seeds txidKey txsL (UInt32.ofNat height)
        let agree :=
          match folded with
          | .ok l' => bytesBEqList l' rep.state.utxo
          | .error _ => false
        { height := height, blockHash := "",
          ok := rep.scriptAdjudication == .complete && rep.scriptUnjudged == 0 && agree,
          reason := if rep.scriptAdjudication != .complete || rep.scriptUnjudged != 0 then
            "script-data-unavailable" else if !agree then "ledger-fold-mismatch" else "",
          txs := rep.txs, scriptOk := rep.scriptOk, scriptUnjudged := rep.scriptUnjudged,
          foldAgrees := agree, scriptAdjudication := rep.scriptAdjudication }
  let t1 ← IO.monoMsNow
  let hashDisp := match decodeBlock raw with
    | .ok (h, _) => (bL (headerHash h)).reverse
    | .error _ => []
  let probe := if res.ok then "" else
    match decodeBlock raw with
    | .error e => s!"decode: {repr e}"
    | .ok (_, txs) =>
        String.intercalate " | " ((List.range txs.length).take 50 |>.map
          (fun i => probeTx (UInt32.ofNat height) (txs.getD i dummyTx) i seeds))
  pure { res with blockHash := toHex (bytesOfList hashDisp),
                  ms := (t1 - t0), probe := probe }
where
  bytesBEqList : List (OutPoint × Coin) → List (OutPoint × Coin) → Bool
    | [], [] => true
    | (a, ca) :: r, (b, cb) :: r' => (a == b) && (ca == cb) && bytesBEqList r r'
    | _, _ => false

/-! ## V08's anchor set: the 2014-2015 era-boundary expansion -/

def anchors : List Nat := [320000, 333000, 340000]

def main : IO Unit := do
  let dir := "../vectors/anchors2/V08"
  let mut results := []
  for h in anchors do
    let r ← runAnchor dir h
    IO.println s!"ANCHOR {h} replayOk={r.ok} accepted=false reason={r.reason} txs={r.txs} scriptOk={r.scriptOk} scriptUnjudged={r.scriptUnjudged} scriptAdjudication={r.scriptAdjudication.label} foldAgrees={r.foldAgrees} ms={r.ms} hash={r.blockHash}"
    if r.probe != "" then IO.println s!"PROBE {h}: {r.probe}"
    results := results ++ [r]
  let allOk := results.all (·.ok)
  let totalMs := (results.map (·.ms)).foldl Nat.add 0
  IO.println s!"SUMMARY blocks={results.length} allReplayOk={allOk} allAccepted=false totalMs={totalMs}"
  if !allOk then throw (IO.userError "capstone: an anchor block FAILED diagnostic replay")

end V08.Run

/-- Runner entry (root `main` for the compiled exe). -/
def main : IO Unit := V08.Run.main
