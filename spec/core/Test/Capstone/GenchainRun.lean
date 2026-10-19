import Bitcoin.Serialization.Interface
import Bitcoin.Consensus.TxCheck
import Bitcoin.TxValidation.Interface
import Bitcoin.Capstone.Block
import Bitcoin.Capstone.Merkle
import Bitcoin.Capstone.RealChecker

/-!
# Test.Capstone.GenchainRun — G02: synthetic-chain driver

Feeds a synthetic chain (G01's genchain corpus, or the G02 fallback 50-block
coinbase-only chain) through the capstone pipeline
`replayBlockPartial : SerializedBlock → CapState → Except CapError CapReport`,
**threading** the sequential state (height, prevHash, UTXO list) from block
to block — unlike `Test.Capstone.Run`, which validates anchor blocks against
materialized `.seeds` prevout views.

Input: a text file with one serialized-block hex per line, chain order
(genesis first). The initial `CapState` is {height 0, prevHash = block 1's
own header `hashPrevBlock` field, utxo = ∅}.

Output (stdout): one `GBLOCK` line per block (per-block validate ms), a
`PROBE` + `GDIAG` line per failure (first offending tx; per-gate verdicts
over the public gate defs — replayBlockPartial itself untouched), and a final
`GSUMMARY` with wall clock. Exit 0 iff every block validated.

Run: `lake env lean --run Test/Capstone/GenchainRun.lean`
(env: `GENCHAIN_HEX` = blocks.hex path, `GENCHAIN_MAX` = block limit).
-/

namespace Test.Capstone.GenchainRun

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Ledger Bitcoin.Consensus
open Bitcoin.TxValidation
open Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle Bitcoin.Capstone.Pow

set_option maxRecDepth 100000

private def dummyTx : Tx := ⟨0, [], [], 0, []⟩

/-- Test-infra hex decode (whitespace tolerated). -/
def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ' && c != '\r')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexVal a, hexVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc
  hexVal (c : Char) : Option Nat :=
    let n := c.toNat
    if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
    else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
    else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
    else none

/-- UTXO-list equality (capstone state vs the independent ledger-layer fold). -/
def eqUTXO : List (OutPoint × Coin) → List (OutPoint × Coin) → Bool
  | [], [] => true
  | (a, ca) :: r, (b, cb) :: r' => (a == b) && (ca == cb) && eqUTXO r r'
  | _, _ => false

/-- Failure forensics: isolate tx `i` (stateless / script / ledger lane). -/
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

/-- Validate block `idx` (1-based) against threaded state `st`.
Returns (newState?, ok?, foldAgrees?, ms). -/
def runBlock (idx : Nat) (raw : ByteArray) (st : CapState) :
    IO (Option CapState × Bool × Bool × Nat) := do
  let t0 ← IO.monoMsNow
  let decoded := decodeBlock raw
  let res :=
    match replayBlockPartial raw st with
    | .error e => Sum.inl (CapError.reason e)
    | .ok rep =>
        let txsL : List Tx :=
          match decoded with
          | Except.error _ => []
          | Except.ok (_, txs) => txs
        let folded := applyBlockL st.utxo txidKey txsL st.height
        let agree :=
          match folded with
          | .ok l' => eqUTXO l' rep.state.utxo
          | .error _ => false
        Sum.inr (rep, agree)
  let t1 ← IO.monoMsNow
  match res with
  | .inl reason =>
      let probe :=
        match decoded with
        | .error e => s!"decode: {repr e}"
        | .ok (_, txs) =>
            String.intercalate " | " ((List.range txs.length).take 50 |>.map
              (fun i => probeTx st.height (txs.getD i dummyTx) i st.utxo))
      IO.println s!"GBLOCK {idx} ok=false reason={reason} ms={t1 - t0} height={st.height.toNat}"
      IO.println s!"PROBE {idx}: {probe}"
      -- per-gate diagnosis over the public gate defs (replayBlockPartial untouched)
      let diag :=
        match decoded with
        | .error e => s!"decode={repr e}"
        | .ok (h, txs) =>
            let cb := txs.getD 0 dummyTx
            s!"struct={vtxNonempty txs && cbPositionOk txs && cbLengthOk cb && weightOk txs raw.size}"
            ++ s!" ver={versionOk st.height h.version} bip34={bip34Ok st.height cb}"
            ++ s!" target={targetOk h.bits} pow={powOk h}"
            ++ s!" link={h.hashPrevBlock == st.prevHash} merkle={merkleOk h txs}"
            ++ s!" commit={commitmentGate true txs cb}"
      IO.println s!"GDIAG {idx}: {diag}"
      pure (none, false, false, t1 - t0)
  | .inr (rep, agree) =>
      let complete := rep.scriptAdjudication == .complete && rep.scriptUnjudged == 0
      let ok := complete && agree
      let reason := if !complete then "script-data-unavailable"
        else if !agree then "ledger-fold-mismatch" else ""
      IO.println s!"GBLOCK {idx} ok={ok} reason={reason} ms={t1 - t0} txs={rep.txs} scriptOk={rep.scriptOk} scriptUnjudged={rep.scriptUnjudged} scriptAdjudication={rep.scriptAdjudication.label} foldAgrees={agree} height→{rep.state.height.toNat} utxo={rep.state.utxo.length}"
      pure (if ok then some rep.state else none, ok, agree, t1 - t0)

def driverMain : IO Unit := do
  let path ← match (← IO.getEnv "GENCHAIN_HEX") with
    | some p => pure p
    | none => throw (IO.userError "GENCHAIN_HEX not set")
  let maxB := match (← IO.getEnv "GENCHAIN_MAX") with
    | some m => m.toNat?
    | none => none
  let txt ← IO.FS.readFile path
  let lines := (txt.splitOn "\n").filter (fun l => l.length ≥ 160)
  let lines := match maxB with | some m => lines.take m | none => lines
  if lines.isEmpty then throw (IO.userError "no blocks found")
  -- seed the state from block 1's own header prev field (height 0, empty UTXO)
  let st0 : CapState ←
    match decodeBlock (fromHex (lines.getD 0 "")) with
    | .ok (h, _) => pure ⟨0, h.hashPrevBlock, []⟩
    | .error e => throw (IO.userError s!"block 1 decode: {repr e}")
  let wall0 ← IO.monoMsNow
  let mut st := st0
  let mut nOk := 0
  let mut nFold := 0
  let mut nFail := 0
  let mut vms := 0
  let cont := (← IO.getEnv "GENCHAIN_CONTINUE").getD "" == "1"
  let mut stopped := 0
  for i in [1:lines.length + 1] do
    let raw := fromHex (lines.getD (i - 1) "")
    let (stOpt, ok, agree, ms) ← runBlock i raw st
    vms := vms + ms
    if ok then
      st := stOpt.getD st
      nOk := nOk + 1
      if agree then nFold := nFold + 1
    else
      nFail := nFail + 1
      stopped := i
      if !cont then break
  let wall1 ← IO.monoMsNow
  IO.println s!"GSUMMARY blocks={lines.length} ok={nOk} fail={nFail} foldAgrees={nFold} validateMs={vms} wallMs={wall1 - wall0} stoppedAt={stopped}"
  if nFail > 0 then
    throw (IO.userError s!"genchain: block {stopped} FAILED (divergence vs generator)")

end Test.Capstone.GenchainRun

/-- Runner entry (`lean --run`). -/
def main : IO Unit := Test.Capstone.GenchainRun.driverMain
