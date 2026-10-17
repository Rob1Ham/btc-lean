import Bitcoin.Ledger.Interface

/-!
# W12 test harness — Ledger/UTXO executable fold (S1)

Run: `bash spec/Test/Ledger/run.sh`.

Everything below is a `decide`-checked walk of the executable tier
(`updateCoinsL` / `applyTxStepL` / `applyBlockL`, plus the point-level
`updateCoins` / `applyTxStepU` they abstract). Scenarios:

  1. coinbase insertion (coin present, coinbase bit, connection height);
  2. same-block coinbase spend → `bad-txns-premature-spend-of-coinbase`;
  3. maturity boundary 99 fails / 100 passes (BLK-100 / INV-028);
  4. spend removes the coin; double-spend of one prevout across steps
     → `bad-txns-inputs-missingorspent` (INV-027);
  5. OP_RETURN output never enters the set, sibling output does (INV-112);
  6. BIP30: duplicate coinbase rejected at an enforced height, allowed at
     91842 (new coin wins) and inside the BIP34 window, re-enabled at
     1983702 (BLK-096/097/098);
  7. assoc-list ↔ point agreement on a concrete point.

NOTE: core Lean 4.35 ships no `DecidableEq (Except ε α)`, so every
comparison goes through the `okOf` / `errOf` probes below (Option of a
decidable type) instead of `Except` equality.
-/

open Bitcoin.Ledger Bitcoin.Data Bitcoin.TxValidation

set_option maxRecDepth 100000

/-- Ok-probe: `some v` iff the fold produced `.ok v`. -/
def okOf {α : Type _} (x : Except BlockError α) : Option α :=
  match x with | .ok v => some v | .error _ => none

/-- Error probe: `some e` iff the fold produced `.error e`. -/
def errOf {α : Type _} (x : Except BlockError α) : Option BlockError :=
  match x with | .error e => some e | .ok _ => none

/-! ## Fixtures -/

/-- The outpoint naming output `k` of `tx` — exactly the key the
`txidPreimageKey`-keyed fold assigns it. -/
def keyOf (tx : Tx) (k : UInt32) : OutPoint := ⟨serTx tx, k⟩

def scr : Script := Script.empty

/-- A 50 BTC coinbase paying one output. -/
def cb : Tx :=
  ⟨1, [⟨OutPoint.null, scr, 0xFFFFFFFF⟩], [⟨5000000000, scr⟩], 0, []⟩

/-- Pristine view that ALREADY carries `cb`'s output 0: the D4c-2
pre-block BIP30 gate fires on it (Core 2466-2475 `coins->HaveCoin`). -/
def uSeed : UtxoSet := fun _ => some ⟨0, 0, false, scr⟩

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

/-- The UTXO set after connecting `cb` at height 0 (extracted from the
fold's `.ok`). -/
def u1 : UtxoSet :=
  match applyTxStepU (fun _ => none) cb (txidPreimageKey cb) 0 with
  | .ok u => u
  | .error _ => fun _ => none

/-- After ALSO connecting `s1` at height 100 (matured). -/
def u2 : UtxoSet :=
  match applyTxStepU u1 s1 (txidPreimageKey s1) 100 with
  | .ok u => u
  | .error _ => fun _ => none

/-- Hand-built view with only cb's coin (for direct predicate checks). -/
def ucb : UtxoSet :=
  fun o => if o == keyOf cb 0 then some ⟨5000000000, 0, true, scr⟩ else none

/-! ## 1. Coinbase insertion (BLK-110: a fresh coinbase coin enters the set) -/

example : (u1 (keyOf cb 0)).map (·.value) = some (5000000000 : Int) := by decide
example : (u1 (keyOf cb 0)).map (·.height) = some (0 : UInt32) := by decide
example : (u1 (keyOf cb 0)).map (·.isCoinbase) = some true := by decide
-- the fold agrees with the extracted point
example :
    okOf ((applyBlock (fun _ => none) [cb] 0).map
      (fun u => (u (keyOf cb 0)).map (·.value))) =
    some (some (5000000000 : Int)) := by decide
-- empty block is a no-op on a probed point
example :
    okOf ((applyBlock (fun _ => none) [] 5).map
      (fun u => (u (keyOf cb 0)).isSome)) = some false := by decide

/-! ## 2. Same-block coinbase spend fails maturity -/

-- at height 0 the fresh coinbase coin (height 0) is not spendable
example :
    errOf ((applyBlock (fun _ => none) [cb] 0).bind
      (fun u => applyTxStepU u s1 (txidPreimageKey s1) 0)) =
    some (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by decide

/-! ## 3. Maturity boundary (BLK-100 / INV-028): 99 fails, 100 passes -/

example : maturityOk ucb s1 99 = false := by decide
example : maturityOk ucb s1 100 = true := by decide
example :
    errOf (applyTxStepU u1 s1 (txidPreimageKey s1) 99) =
    some (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by decide
example :
    okOf ((applyTxStepU u1 s1 (txidPreimageKey s1) 100).map
      (fun u => (u (keyOf s1 0)).map (·.value))) = some (some (4000000000 : Int)) := by decide

/-! ## 4. Spend removes the coin; double-spend across steps (INV-027) -/

example : (u2 (keyOf cb 0)).isSome = false := by decide
example : (u2 (keyOf s1 0)).map (·.value) = some (4000000000 : Int) := by decide
-- spending a missing prevout
example :
    errOf (applyTxStepU (fun _ => none) s1 (txidPreimageKey s1) 100) =
    some (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by decide
example : inputsAvailable (fun _ => none) s1 = false := by decide
example : inputsAvailable u1 s1 = true := by decide
-- second spend of the same prevout, after the first consumed it
example :
    errOf (applyTxStepU u2 s1b (txidPreimageKey s1b) 100) =
    some (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by decide

/-! ## 5. OP_RETURN output never enters the set (INV-112) -/

example : scriptUnspendable opRet = true := by decide
example : scriptUnspendable scr = false := by decide
example :
    okOf ((applyTxStepU u1 burnTx (txidPreimageKey burnTx) 100).map
      (fun u => ((u (keyOf burnTx 0)).isSome, (u (keyOf burnTx 1)).map (·.value)))) =
    some (false, some (2000 : Int)) := by decide

/-! ## 6. BIP30 duplicate-coinbase table + fold behavior (BLK-096/097/098) -/

-- predicate table
example : bip30Enforced 0 = true := by decide
example : bip30Enforced 91842 = false := by decide
example : bip30Enforced 91880 = false := by decide
example : bip30Enforced 91843 = true := by decide
-- FIX D2a (RC SWEEP; 227931 was `= false`): Core validation.cpp:2458-2461's
-- null-ancestor reading (`pprev->GetAncestor(BIP34Height)` on the
-- height-227930 parent) ENFORCES BIP30 at 227931 — the skip window proper
-- is (227931, 1983702), 227931 = the LAST BIP30-ON height (F-S04-001 /
-- F-Z05-001 / CV07 D2a)
example : bip30Enforced 227930 = true := by decide
example : bip30Enforced 227931 = true := by decide
example : bip30Enforced 227932 = false := by decide
example : bip30Enforced 1983701 = false := by decide
example : bip30Enforced 1983702 = true := by decide
-- D4c-2: the BIP30 gate is the PRE-BLOCK pristine-view overlap check
-- (Core 2466-2475). A tx re-creating a coin already in the view trips it;
-- an INTRA-BLOCK duplicate is NOT this layer (Core CheckBlock's
-- bad-txns-duplicate), so [cb, cb] on an empty view is ok at the fold.
example :
    errOf (applyBlock uSeed [cb] 500) =
    some BlockError.badTxnsBIP30 := by decide
example : (applyBlock (fun _ => none) [cb, cb] 500).isOk = true := by decide
-- FIX D2a regression vector (RC SWEEP; mission heights 227930/227931/227932):
-- h=227930 BIP30-ON; h=227931 now ALSO BIP30-ON (Core agrees — pre-fix the
-- window elide wrong-ACCEPTED a duplicate-coinbase block here = the D2a
-- divergence); h=227932 = first window height (elided)
example :
    errOf (applyBlock uSeed [cb] 227930) =
    some BlockError.badTxnsBIP30 := by decide
example :
    errOf (applyBlock uSeed [cb] 227931) =
    some BlockError.badTxnsBIP30 := by decide
example :
    (applyBlock (fun _ => none) [cb, cb] 227932).isOk = true := by decide
-- 91842 exemption: allowed, and the NEW coin (height 91842) wins
example :
    okOf ((applyBlock (fun _ => none) [cb, cb] 91842).map
      (fun u => (u (keyOf cb 0)).map (·.height))) = some (some (91842 : UInt32)) := by decide
-- BIP34 window: duplicates impossible by construction → check skipped
example :
    (applyBlock (fun _ => none) [cb, cb] 300000).isOk = true := by decide
-- window: even a colliding pristine view is elided (gate skipped)
example : (applyBlock uSeed [cb] 227932).isOk = true := by decide
-- re-enabled at BIP34_IMPLIES_BIP30_LIMIT
example :
    errOf (applyBlock uSeed [cb] 1983702) =
    some BlockError.badTxnsBIP30 := by decide

/-! ## 7. Executable assoc-list tier agrees with the point tier -/

-- updateCoinsL inserts exactly the keyed coin
example :
    (coinLookup (updateCoinsL [] cb (txidPreimageKey cb) 0) (keyOf cb 0)).map
      (fun c => (c.value, c.height, c.isCoinbase)) =
    some ((5000000000 : Int), (0 : UInt32), true) := by decide
-- applyBlockL yields a one-entry list
example : okOf ((applyBlockExec [] [cb] 0).map (fun l => l.length)) =
    some 1 := by decide
-- … whose view answers exactly like the point fold on the probed point
example :
    okOf ((applyBlockExec [] [cb] 0).map
        (fun l => Option.map (·.value) ((viewOf l) (keyOf cb 0)))) =
    okOf ((applyBlock (fun _ => none) [cb] 0).map
        (fun u => Option.map (·.value) (u (keyOf cb 0)))) := by decide
-- the list fold surfaces the same errors (pre-block gate, seeded view)
example :
    errOf (applyBlockExec [(keyOf cb 0, ⟨0, 0, false, scr⟩)] [cb] 500) =
    some BlockError.badTxnsBIP30 := by decide
example :
    errOf ((applyBlockExec [] [cb] 0).bind
      (fun l => applyTxStepL l s1 (txidPreimageKey s1) 0)) =
    some (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by decide

/-! ## 8. View round-trip: `viewOf` = `coinLookup` on the folded list -/

example :
    okOf ((applyBlockExec [] [cb] 0).map
      (fun l => (coinLookup l (keyOf cb 0)).map (·.value))) =
    some (some (5000000000 : Int)) := by decide

/-! ## 9. Axiom pins (D2 L3) — rule-facing theorem tier -/
/-- info: 'Bitcoin.Ledger.updateCoinsL_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoinsL_abstract
/-- info: 'Bitcoin.Ledger.applyBlock_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlock_abstract
/-- info: 'Bitcoin.Ledger.applyTxStepL_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTxStepL_abstract
/-- info: 'Bitcoin.Ledger.applyBlockL_abstract' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlockL_abstract
/-- info: 'Bitcoin.Ledger.addedCoins_inv' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addedCoins_inv
/-- info: 'Bitcoin.Ledger.addedCoins_mem' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addedCoins_mem
/-- info: 'Bitcoin.Ledger.updateCoins_insert_isSome' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoins_insert_isSome
/-- info: 'Bitcoin.Ledger.addedCoins_lookup_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addedCoins_lookup_eq
/-- info: 'Bitcoin.Ledger.addedCoins_lookup_none_of_unspendable' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms addedCoins_lookup_none_of_unspendable
/-- info: 'Bitcoin.Ledger.updateCoins_spend_gone' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoins_spend_gone
/-- info: 'Bitcoin.Ledger.updateCoins_spend_recreate' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoins_spend_recreate
/-- info: 'Bitcoin.Ledger.applyTxStepU_missing_or_spent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTxStepU_missing_or_spent
/-- info: 'Bitcoin.Ledger.applyTxStepU_premature' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTxStepU_premature
/-- info: 'Bitcoin.Ledger.maturity_boundary' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms maturity_boundary
/-- info: 'Bitcoin.Ledger.emptyUtxo_lookup' does not depend on any axioms -/
#guard_msgs in #print axioms emptyUtxo_lookup
/-- info: 'Bitcoin.Ledger.viewOf_nil' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms viewOf_nil
/-- info: 'Bitcoin.Ledger.genesis_coin_isSome' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms genesis_coin_isSome
/-- info: 'Bitcoin.Ledger.chainFees_nonneg' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms chainFees_nonneg
/-- info: 'Bitcoin.Ledger.applyTxStepU_ok_value' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTxStepU_ok_value
/-- info: 'Bitcoin.Ledger.updateCoins_preserve_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoins_preserve_none
/-- info: 'Bitcoin.Ledger.applyBlockU_preserve_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlockU_preserve_none
/-- info: 'Bitcoin.Ledger.applyBlockU_no_double_spend' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlockU_no_double_spend
/-- info: 'Bitcoin.Ledger.applyBlock_no_double_spend' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlock_no_double_spend
/-- info: 'Bitcoin.Ledger.spentUndo_inv' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms spentUndo_inv
/-- info: 'Bitcoin.Ledger.spentUndo_hit' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms spentUndo_hit
/-- info: 'Bitcoin.Ledger.mem_spentUndo_of_input' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms mem_spentUndo_of_input
/-- info: 'Bitcoin.Ledger.spentUndo_lookup_none_of_any_false' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms spentUndo_lookup_none_of_any_false
/-- info: 'Bitcoin.Ledger.updateCoins_undo' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms updateCoins_undo
/-- info: 'Bitcoin.Ledger.checkTxInputs_ok_haveInputs' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkTxInputs_ok_haveInputs
/-- info: 'Bitcoin.Ledger.getValueOut_nonneg' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms getValueOut_nonneg
/-- info: 'Bitcoin.Ledger.value_nonneg_of_mem_updateCoinsL' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms value_nonneg_of_mem_updateCoinsL
/-- info: 'Bitcoin.Ledger.listTotal_updateCoinsL_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms listTotal_updateCoinsL_le
/-- info: 'Bitcoin.Ledger.listTotal_addedCoins_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms listTotal_addedCoins_le
/-- info: 'Bitcoin.Ledger.chainFees_viewOf' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms chainFees_viewOf
/-- info: 'Bitcoin.Ledger.chainFeesL_le_blockDrawn' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms chainFeesL_le_blockDrawn
/-- info: 'Bitcoin.Ledger.applyBlockL_fees_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyBlockL_fees_le
/-- info: 'Bitcoin.Ledger.listTotal_nonneg' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms listTotal_nonneg
/-- info: 'Bitcoin.Ledger.sumAtL_nonneg' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sumAtL_nonneg


/-- `-run` entry: every `example` above is elaborated (and `decide`d) at
compile time; reaching the end means all checks passed. -/
def main : IO Unit := IO.println "W12 Ledger tests: all decide checks passed"
