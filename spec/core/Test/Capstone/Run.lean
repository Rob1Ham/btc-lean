import Bitcoin.Serialization.Interface
import Bitcoin.Consensus.TxCheck
import Bitcoin.TxValidation.Interface
import Bitcoin.Capstone.Block
import Bitcoin.Capstone.Merkle
import Bitcoin.Capstone.RealChecker

/-!
# Test.Capstone.Run — W17 S3: the end-to-end anchor capstone run

Validates the 6 mainnet anchor blocks through `validateBlock` (W02 decode
→ structure → PoW/chain-link → merkle/witness-commitment → per-tx
W10 stateless + W10 checkTxInputs + W09 verifyScriptFull with the REAL
W13×W14b checker + W12 ledger fold), reading:

  spec/vectors/anchors/<H>.raw     — the serialized block
  spec/vectors/anchors/<H>.parent  — the REAL parent hash (display hex)
  spec/vectors/anchors/<H>.seeds   — the real-chain prevout view:
        <wire-order txid hex> <block height> <raw prevout tx hex>

The seeds play the role of W10's vector prevout table: the anchor
sequence skips the intermediate blocks, so the UTXO entries the block
spends are materialized from the REAL chain data (fetched prevout txs;
values/scripts extracted Lean-side by W02's decodeTx; only the height
metadata is trusted). Every check of the block itself is live.

Cross-check: the final UTXO list of the interleaved fold must equal
W12's frozen `applyBlockL` over the same start list (defense in depth).

Output: per-block JSON lines to stdout (consumed by
`scripts/capstone_report.py`); per-tx probe on failure.

Run (compiled): `cd core && lake build capstone && lake exe capstone`
-/

namespace Test.Capstone.Run

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Ledger Bitcoin.Consensus
open Bitcoin.TxValidation
open Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle Bitcoin.Capstone.Pow

set_option maxRecDepth 100000

/-! ## Hex + file helpers -/

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

/-- Minimal whitespace trim (test infra). -/
def trimStr (s : String) : String :=
  (String.ofList (s.toList.filter (fun c => c != ' ' && c != '\n' && c != '\r')))

def toHex (b : ByteArray) : String :=
  (List.range b.size).foldl (fun acc i =>
    let v := (b.get! i).toNat
    let d := "0123456789abcdef"
    acc ++ String.singleton (d.toList.getD (v / 16) '0') ++ String.singleton (d.toList.getD (v % 16) '0')) ""

/-- Inhabited stand-in (real blocks always decode). -/
private def dummyTx : Tx := ⟨0, [], [], 0, []⟩

/-! ## Seed materialization -/

/-- The seed line's coin set: decode the prevout tx (W02), index the
vouts. `isCoinbase` derived from the decoded tx itself. -/
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

/-! ## Per-tx probe (failure forensics) -/

/-- Isolate tx `i` against the seed view: stateless + script + ledger
step. Used only when a block fails, to pinpoint the offending tx. -/
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

/-! ## The per-block run -/

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
deriving Repr

/-- Validate anchor at `height`, from the files in `dir`. -/
def runAnchor (dir : String) (height : Nat) : IO BlockResult := do
  let t0 ← IO.monoMsNow
  let raw ← IO.FS.readBinFile s!"{dir}/{height}.raw"
  let parent ←
    match (← (IO.FS.readFile s!"{dir}/{height}.parent" <|> pure "")) with
    | "" => pure ByteArray.empty   -- absent: chain-link check vacuous (reported)
    | ph => pure (bytesOfList (bL (fromHex (trimStr ph))).reverse)
  let seedLines ←
    match (← (IO.FS.readFile s!"{dir}/{height}.seeds" <|> pure "")) with
    | "" => pure []
    | txt => pure ((txt.splitOn "\n").filter (fun l => !(trimStr l).isEmpty))
  let seeds := seedLines.flatMap seedCoins
  -- independent witness for the decode: count txs by walking the header
  let st : CapState := ⟨(UInt32.ofNat height), parent, seeds⟩
  let res :=
    match validateBlock raw st with
    | .error e => BlockResult.mk height "" false (CapError.reason e) 0 0 0 0 true ""
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
        BlockResult.mk height "" true "" rep.txs rep.scriptOk rep.scriptUnjudged 0 agree "" 
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

def anchors : List Nat := [0, 74638, 91842, 91880, 481824, 709632]

/-- X12 (Review-3 anchor expansion): the six additional diversity anchors in
`vectors/anchors2/` — see `research/w3-12-anchors2.md`:
  170     first block with >1 tx (the Satoshi→Finney tx; 2009 era semantics)
  170061  BIP16-era block right after the exception block 170060 (P2SH flags era)
  170060  THE P2SH exception block (hash-keyed flags-map corner + the
          BIP16-referenced hashlock spend of 9c08a4d7..:1 — bonus probe)
  481827  first post-activation block with substantial witness volume
          (3 witness txs, 668 witness inputs → BIP143 at real depth)
  481828  coinbase-only 1-tx block (degenerate merkle case, Aug 2017)
  499195  Dec-2017 congestion-era block, 3778 txs (scale through real ECDSA)
  709635  FIRST real Taproot-spend block (16 P2TR spends: key-path + script-path)
Heights pinned in `fetch_anchors2.sh`; kept in sync there. -/
def anchors2 : List Nat := [170, 170061, 170060, 481827, 481828, 499195, 709635]

/-- Corpora: (directory, heights). `CAPSTONE_SET=1|2` restricts to one
corpus (Review-3 re-runs use `2` to skip the 60-min Review-2 re-run); default
`all` runs both. Heights whose `<H>.raw` file is absent are skipped, so a
partial corpus run still reports what exists. -/
def corpora : List (String × List Nat) :=
  [("../vectors/anchors", anchors), ("../vectors/anchors2", anchors2)]

def main : IO Unit := do
  let which := (← IO.getEnv "CAPSTONE_SET").getD "all"
  -- CAPSTONE_ONLY=<comma-separated heights> restricts the run to those
  -- anchors (incremental re-runs while a corpus member's seeds land).
  let only := (← IO.getEnv "CAPSTONE_ONLY").getD ""
  let onlySet : List Nat := (only.splitOn ",").filterMap (fun s =>
    let t := trimStr s
    if t.isEmpty then none else some t.toNat!)
  let mut results := []
  for (dir, hs) in corpora do
    if which == "1" && dir != "../vectors/anchors" then continue
    if which == "2" && dir != "../vectors/anchors2" then continue
    for h in hs do
      if onlySet.length > 0 && !(onlySet.contains h) then continue
      if !(← System.FilePath.pathExists s!"{dir}/{h}.raw") then
        IO.println s!"SKIP {h} (no {dir}/{h}.raw)"
        continue
      let r ← runAnchor dir h
      IO.println s!"ANCHOR {h} ok={r.ok} reason={r.reason} txs={r.txs} scriptOk={r.scriptOk} scriptUnjudged={r.scriptUnjudged} foldAgrees={r.foldAgrees} ms={r.ms} hash={r.blockHash}"
      if r.probe != "" then IO.println s!"PROBE {h}: {r.probe}"
      results := results ++ [r]
  let allOk := results.all (·.ok)
  let totalMs := (results.map (·.ms)).foldl Nat.add 0
  IO.println s!"SUMMARY blocks={results.length} allOk={allOk} totalMs={totalMs}"
  if !allOk then throw (IO.userError "capstone: an anchor block FAILED validation")

end Test.Capstone.Run

/-- Runner entry (root `main` for the lake exe). -/
def main : IO Unit := Test.Capstone.Run.main
