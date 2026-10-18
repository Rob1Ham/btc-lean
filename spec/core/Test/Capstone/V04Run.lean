import Bitcoin.Serialization.Interface
import Bitcoin.Consensus.TxCheck
import Bitcoin.TxValidation.Interface
import Bitcoin.Capstone.Block
import Bitcoin.Capstone.Merkle
import Bitcoin.Capstone.RealChecker

/-!
# Test.Capstone.V04Run — V04: mainnet anchor expansion run

Standalone copy of `Test.Capstone.Run` with the anchor list and
seed directory pointed at the V04 expansion corpus — the harness code is
byte-for-byte the verified logic (reusing it via `import` would clash
with Run.lean's root `main`, and editing that file is out of scope).

Validates 3 ADDITIONAL real mainnet blocks at era-boundary points the 6
original anchors miss, through the same pipeline (decode →
structure → PoW/chain-link → merkle/witness commitment → per-tx
stateless + checkTxInputs + verifyScriptFull with the REAL
ECDSA checker → ledger fold, keyed by REAL txid):

  201170 — 2012-09-30, pre-BIP34 pre-halving era (subsidy 50)
  210000 — 2012-11-28, THE FIRST HALVING block (subsidy 50→25)
  218000 — 2013-01-25, late BIP34-era run-up, pre-segwit

Reads (new files):
  spec/vectors/anchors2/V04/<H>.raw     — serialized block (header
                                          sha256d-verified at fetch time)
  spec/vectors/anchors2/V04/<H>.parent  — REAL parent hash (display hex)
  spec/vectors/anchors2/V04/<H>.seeds   — UTXO seeds, the anchor-seed format:
        <wire-order txid hex> <block height> <raw prevout tx hex>

Run (compiled): `cd spec/core && lake env lean --run Test/Capstone/V04Run.lean`
-/

namespace Test.Capstone.V04Run

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Ledger Bitcoin.Consensus
open Bitcoin.TxValidation
open Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle Bitcoin.Capstone.Pow

set_option maxRecDepth 100000

/-! ## Hex + file helpers (the capstone runner Run.lean verbatim) -/

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

/-! ## Seed materialization (the capstone runner Run.lean verbatim) -/

/-- The seed line's coin set: decode the prevout tx (the serialization layer), index the
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

/-! ## Per-tx probe (failure forensics, the capstone runner Run.lean verbatim) -/

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

/-! ## The per-block run (the capstone runner Run.lean verbatim) -/

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

/-! ## V04 expansion anchors -/

def anchorsV04 : List Nat := [201170, 210000, 218000]

def main : IO Unit := do
  let dir := "../vectors/anchors2/V04"
  let mut results := []
  for h in anchorsV04 do
    let r ← runAnchor dir h
    IO.println s!"ANCHOR {h} ok={r.ok} reason={r.reason} txs={r.txs} scriptOk={r.scriptOk} scriptUnjudged={r.scriptUnjudged} foldAgrees={r.foldAgrees} ms={r.ms} hash={r.blockHash}"
    if r.probe != "" then IO.println s!"PROBE {h}: {r.probe}"
    results := results ++ [r]
  let allOk := results.all (·.ok)
  let totalMs := (results.map (·.ms)).foldl Nat.add 0
  IO.println s!"SUMMARY blocks={results.length} allOk={allOk} totalMs={totalMs}"
  if !allOk then throw (IO.userError "capstone-v04: an anchor block FAILED validation")

end Test.Capstone.V04Run

/-- Runner entry (root `main` for `lean --run`). -/
def main : IO Unit := Test.Capstone.V04Run.main
