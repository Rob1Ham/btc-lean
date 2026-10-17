import Bitcoin.Ledger.HashMap

/-!
# X13 U1 — HashMap-backed UtxoSet instance: scenario tests

Run: `bash spec/Test/Ledger/run_map.sh` (mirrors W12's `run.sh`).

The SAME scenarios W12's `Test/Ledger/Tests.lean` walks (coinbase
insertion, maturity boundary, spend removal / double-spend, OP_RETURN,
BIP30 table) replayed through the HashMap instance (`applyTxStepM` /
`applyBlockM` over `Std.HashMap OutPoint Coin`), plus the transfer
checks pinning `applyBlockL` ≡ `applyBlockM` on every fixture — the
executable face of `applyBlockL_applyBlockM_agree` (proved, not
assumed: both folds land on the same abstract `UtxoSet` view).

Everything is checked at compile time, exactly like W12's harness —
with one D-004-sanctioned deviation: the probes use `native_decide`
(30 uses) instead of `decide`, because `Std.HashMap.get?` reduction
goes through the body-less opaque `mixHash` / `ByteArray.hash` externs,
which the KERNEL cannot unfold — `decide` is stuck by construction.
D-004 explicitly permits `native_decide` "ONLY under test drivers
(`Test/` paths / `Main.lean` harnesses)" — this file is a test driver;
zero uses in core (`Bitcoin/Ledger/HashMap.lean` is decide-free and
sorry-free). Each `native_decide` here audits as the standard
`Lean.ofReduceBool` axiom, confining to Test/ only. NOTE: core Lean
4.35 ships no `DecidableEq (Except ε α)`, so comparisons go through the
`okOf` / `errOf` probes.
-/

namespace Test.Ledger.HashMapTests

open Bitcoin.Ledger Bitcoin.Data Bitcoin.TxValidation

set_option maxRecDepth 100000

/-- Ok-probe: `some v` iff the fold produced `.ok v`. -/
def okOf {α : Type _} (x : Except BlockError α) : Option α :=
  match x with | .ok v => some v | .error _ => none

/-- Error probe: `some e` iff the fold produced `.error e`. -/
def errOf {α : Type _} (x : Except BlockError α) : Option BlockError :=
  match x with | .error e => some e | .ok _ => none

/-! ## Fixtures (byte-identical to W12's Test/Ledger/Tests.lean) -/

/-- The outpoint naming output `k` of `tx` — exactly the key the
`txidPreimageKey`-keyed fold assigns it. -/
def keyOf (tx : Tx) (k : UInt32) : OutPoint := ⟨serTx tx, k⟩

def scr : Script := Script.empty

/-- A 50 BTC coinbase paying one output. -/
def cb : Tx :=
  ⟨1, [⟨OutPoint.null, scr, 0xFFFFFFFF⟩], [⟨5000000000, scr⟩], 0, []⟩

/-- Spending tx: consumes cb's output 0, pays 40 BTC. -/
def s1 : Tx :=
  ⟨1, [⟨keyOf cb 0, scr, 0xFFFFFFFF⟩], [⟨4000000000, scr⟩], 0, []⟩

/-- Second spender of the SAME prevout (double-spend across steps). -/
def s1b : Tx :=
  ⟨1, [⟨keyOf cb 0, scr, 0xFFFFFFFF⟩], [⟨999, scr⟩], 0, []⟩

/-- OP_RETURN burn + a spendable output. -/
def opRet : Script := ⟨ByteArray.empty.push 0x6a⟩

def burnTx : Tx :=
  ⟨1, [⟨keyOf cb 0, scr, 0xFFFFFFFF⟩],
     [⟨1000, opRet⟩, ⟨2000, scr⟩], 0, []⟩

/-- The empty map (genesis UTXO view — validation.cpp:2330-2334). -/
def m0 : UtxoMap := Std.HashMap.emptyWithCapacity 0

/-- The map after connecting `cb` at height 0. -/
def m1 : UtxoMap :=
  match applyTxStepM m0 cb (txidPreimageKey cb) 0 with
  | .ok m => m
  | .error _ => m0

/-- After ALSO connecting `s1` at height 100 (matured). -/
def m2 : UtxoMap :=
  match applyTxStepM m1 s1 (txidPreimageKey s1) 100 with
  | .ok m => m
  | .error _ => m0

/-! ## 1. Coinbase insertion through the map (BLK-110) -/

example : okOf ((applyTxStepM m0 cb (txidPreimageKey cb) 0).map
    (fun m => (m.get? (keyOf cb 0)).map (·.value))) =
  some (some (5000000000 : Int)) := by native_decide

example : okOf ((applyTxStepM m0 cb (txidPreimageKey cb) 0).map
    (fun m => (m.get? (keyOf cb 0)).map (·.isCoinbase))) =
  some (some true) := by native_decide

example : okOf ((applyTxStepM m0 cb (txidPreimageKey cb) 0).map
    (fun m => (m.get? (keyOf cb 0)).map (·.height))) =
  some (some (0 : UInt32)) := by native_decide

-- empty block is a no-op
example : okOf ((applyBlockM m0 (txidPreimageKey ·) [] 5).map
    (fun m => (m.get? (keyOf cb 0)).isSome)) = some false := by native_decide

/-! ## 2. Same-block coinbase spend fails maturity (through the map) -/

example :
    errOf ((applyTxStepM m0 cb (txidPreimageKey cb) 0).bind
      (fun m => applyTxStepM m s1 (txidPreimageKey s1) 0)) =
    some (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by native_decide

/-! ## 3. Maturity boundary through the map (BLK-100 / INV-028):
99 fails, 100 passes -/

example :
    errOf (applyTxStepM m1 s1 (txidPreimageKey s1) 99) =
    some (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by native_decide

example :
    okOf ((applyTxStepM m1 s1 (txidPreimageKey s1) 100).map
      (fun m => (m.get? (keyOf s1 0)).map (·.value))) =
    some (some (4000000000 : Int)) := by native_decide

/-! ## 4. Spend removes the coin; double-spend across steps (INV-027) -/

example : (m2.get? (keyOf cb 0)).isSome = false := by native_decide
example : (m2.get? (keyOf s1 0)).map (·.value) = some (4000000000 : Int) := by native_decide

-- spending a missing prevout
example :
    errOf (applyTxStepM m0 s1 (txidPreimageKey s1) 100) =
    some (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by native_decide

-- second spend of the same prevout, after the first consumed it
example :
    errOf (applyTxStepM m2 s1b (txidPreimageKey s1b) 100) =
    some (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by native_decide

/-! ## 5. OP_RETURN output never enters the set (INV-112) -/

example : scriptUnspendable opRet = true := by native_decide
example : scriptUnspendable scr = false := by native_decide

example :
    okOf ((applyTxStepM m1 burnTx (txidPreimageKey burnTx) 100).map
      (fun m => ((m.get? (keyOf burnTx 0)).isSome,
                 (m.get? (keyOf burnTx 1)).map (·.value)))) =
    some (false, some (2000 : Int)) := by native_decide

/-! ## 6. BIP30 duplicate-coinbase table + fold behavior (BLK-096/097/098) -/

example : bip30Enforced 0 = true := by native_decide
example : bip30Enforced 91842 = false := by native_decide
example : bip30Enforced 91880 = false := by native_decide
example : bip30Enforced 91843 = true := by native_decide
-- FIX D2a (RC SWEEP; 227931 was `= false`): Core 2458-2461 null-ancestor
-- reading ENFORCES at 227931; skip window proper = (227931, 1983702)
example : bip30Enforced 227930 = true := by native_decide
example : bip30Enforced 227931 = true := by native_decide
example : bip30Enforced 227932 = false := by native_decide
example : bip30Enforced 1983701 = false := by native_decide
example : bip30Enforced 1983702 = true := by native_decide

-- D4c-2: the gate is the PRE-BLOCK pristine-view overlap check (Core
-- 2466-2475); m1 already carries cb's output 0. (Intra-block duplicate =
-- Core CheckBlock's bad-txns-duplicate, not BIP30.)
example :
    errOf (applyBlockM m1 (txidPreimageKey ·) [cb] 500) =
    some BlockError.badTxnsBIP30 := by native_decide
example :
    (applyBlockM m0 (txidPreimageKey ·) [cb, cb] 500).isOk = true := by native_decide

-- FIX D2a regression vector, map-tier mirror (RC SWEEP; 227930/227931/227932):
-- h=227931 now trips bad-txns-BIP30 (pre-fix wrong-accepted = the D2a
-- divergence); h=227932 = first window height (elided)
example :
    errOf (applyBlockM m1 (txidPreimageKey ·) [cb] 227930) =
    some BlockError.badTxnsBIP30 := by native_decide
example :
    errOf (applyBlockM m1 (txidPreimageKey ·) [cb] 227931) =
    some BlockError.badTxnsBIP30 := by native_decide
example :
    (applyBlockM m0 (txidPreimageKey ·) [cb, cb] 227932).isOk = true := by native_decide

-- 91842 exemption: allowed, and the NEW coin (height 91842) wins
example :
    okOf ((applyBlockM m0 (txidPreimageKey ·) [cb, cb] 91842).map
      (fun m => (m.get? (keyOf cb 0)).map (·.height))) =
    some (some (91842 : UInt32)) := by native_decide

-- BIP34 window: duplicates impossible by construction → check skipped
example :
    (applyBlockM m0 (txidPreimageKey ·) [cb, cb] 300000).isOk = true := by native_decide

-- window: the gate is elided even on a colliding pristine view
example :
    (applyBlockM m1 (txidPreimageKey ·) [cb] 227932).isOk = true := by native_decide
-- re-enabled at BIP34_IMPLIES_BIP30_LIMIT
example :
    errOf (applyBlockM m1 (txidPreimageKey ·) [cb] 1983702) =
    some BlockError.badTxnsBIP30 := by native_decide

/-! ## 7. TRANSFER: W12's assoc-list scenarios handed through the map
(the executable face of `applyBlockL_applyBlockM_agree`) -/

-- the map built from W12's folded list answers identically on probed keys
example :
    okOf ((applyBlockExec [] [cb] 0).map
        (fun l => Option.map (·.value) ((mapOfL l).get? (keyOf cb 0)))) =
    okOf ((applyBlockM m0 (txidPreimageKey ·) [cb] 0).map
        (fun m => Option.map (·.value) (m.get? (keyOf cb 0)))) := by native_decide

-- the two executable folds surface the same errors
example :
    errOf (applyBlockExec [] [cb, cb] 500) =
    errOf (applyBlockM m0 (txidPreimageKey ·) [cb, cb] 500) := by native_decide

example :
    errOf (applyBlockExec [] [cb, cb] 1983702) =
    errOf (applyBlockM m0 (txidPreimageKey ·) [cb, cb] 1983702) := by native_decide

-- same size after the same block: the reps stay in lockstep
example :
    okOf ((applyBlockExec [] [cb] 0).map (fun l => l.length)) =
    okOf ((applyBlockM m0 (txidPreimageKey ·) [cb] 0).map (fun m => m.size)) := by native_decide

-- the view of the map fold answers like the view of the list fold
example :
    okOf ((applyBlockExec [] [cb] 0).bind
        (fun l => (applyTxStepL l s1 (txidPreimageKey s1) 0).map
        (fun l => Option.map (·.value) (viewOf l (keyOf s1 0))))) =
    okOf ((applyBlockM m0 (txidPreimageKey ·) [cb] 0).bind
        (fun m => (applyTxStepM m s1 (txidPreimageKey s1) 0).map
        (fun m => Option.map (·.value) (m.get? (keyOf s1 0))))) := by native_decide

/-! ## 8. Axiom pins (D2 L3) — the transfer theorem is axiom-clean -/

/-- info: 'Bitcoin.Ledger.applyBlockL_applyBlockM_agree' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Ledger.applyBlockL_applyBlockM_agree

/-- info: 'Bitcoin.Ledger.updateCoinsM_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.Ledger.updateCoinsM_abstract

end Test.Ledger.HashMapTests

/-- `-run` entry: every `example` above is elaborated (and
`native_decide`d) at compile time; reaching the end means all checks
passed. -/
def main : IO Unit := IO.println "X13 HashMap Ledger tests: all checks passed"
