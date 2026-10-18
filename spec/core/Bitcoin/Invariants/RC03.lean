import Bitcoin.RuleAttr
import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Data.Script
import Bitcoin.Ledger.Utxo
import Bitcoin.TxValidation.Interface
import Bitcoin.Conservation.Interface
import Bitcoin.Block.Connect
import Bitcoin.Block.Sigops

/-!
# Bitcoin.Invariants.RC03 — INV-025..INV-036 acceptance-spine pins (RC03)

B1's §B.3 Money-and-fees + §B.4 sigop-accounting invariant rows. The
faithful executable checks already exist (the transaction-validation module `TxValidation.inputValuesLoop`
/ `checkTxInputs`, the block-validation module `Block.Connect` fee/coinbase gates, the block-validation module
`Block.Sigops` legacy/P2SH counters, the interpreter delta layer `Data.Basic` constants). The block-validation module
(family closed b49e36a) and the transaction-validation module (TXV-A 6b84737) are completed modules; per the
the RC09 rule-closure attr-only precedent, the two def-semantics rows
(INV-035 → `legacySigOpCountTx`, INV-040 → `legacySigOpBudgetOk`) are
A-aliased by attribute in Block/Sigops.lean; the invariant-semantics rows
(INV-025/026/029/031/032/034/036) are pinned with sorry-free theorems
HERE (attributes on RC03's own declarations) plus `decide`/`rfl` value
vectors.

Core pin: v32.99 @ `cce32b168` (tx_verify.cpp:170-220, validation.cpp
:1833-1844/:2540-2545/:2608-2612, policy.cpp:107-160, amount.h:15,26).
-/

namespace Bitcoin.Invariants.RC03

open Bitcoin.Data Bitcoin.Ledger Bitcoin.TxValidation Bitcoin.Conservation
open Bitcoin.Block.Connect Bitcoin.Block.Sigops

/-! ## Shared vector fixtures (minimal 1-in/1-out and 2-in/1-out txs) -/

private def vOut : OutPoint := ⟨ByteArray.empty, 1⟩
private def vCoin (val : Amount) : Coin := ⟨val, 0, false, Script.empty⟩
private def vU (val : Amount) : UtxoSet := fun _ => some (vCoin val)
private def vTx (out : Amount) : Tx :=
  ⟨0, [⟨vOut, Script.empty, 0xFFFFFFFF⟩], [⟨out, Script.empty⟩], 0, []⟩

/-- Two inputs: `MAX_MONEY` then `1` — each in MoneyRange, running sum not. -/
private def vU2 : UtxoSet := fun o =>
  if o.n = 0 then some (vCoin MAX_MONEY) else some (vCoin 1)
private def vTx2 (out : Amount) : Tx :=
  ⟨0, [⟨⟨ByteArray.empty, 0⟩, Script.empty, 0xFFFFFFFF⟩,
      ⟨⟨ByteArray.empty, 1⟩, Script.empty, 0xFFFFFFFF⟩],
    [⟨out, Script.empty⟩], 0, []⟩

/-- Coinbase-shaped tx (single null-prevout input). -/
private def vCbTx (out : Amount) : Tx :=
  ⟨0, [⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩], [⟨out, Script.empty⟩], 0, []⟩

/-- Tx with raw script bytes in the input scriptSig / output scriptPubKey. -/
private def vSigTx (s1 s2 : ByteArray) : Tx :=
  ⟨0, [⟨vOut, ⟨s1⟩, 0xFFFFFFFF⟩], [⟨0, ⟨s2⟩⟩], 0, []⟩

/-! ## INV-034: the money constants (`amount.h:15,26`) -/

/-- `COIN = 10^8` satoshis; `MAX_MONEY = 21·10^6 · COIN` — the two
constants of `consensus/amount.h` every Money-range rule cites. (Defs
live in `Bitcoin.Data.Basic`, the interpreter delta layer; this pin states them against Core's
literals.) -/
@[rule "INV-034"]
theorem coin_constants : COIN = 100000000 ∧ MAX_MONEY = 21000000 * COIN :=
  ⟨rfl, rfl⟩

/-- Value vector (INV-034): 0 and MAX_MONEY are in `MoneyRange`,
MAX_MONEY + 1 is not — the range boundary `amount.h:27`. -/
example : MoneyRange 0 = true ∧ MoneyRange MAX_MONEY = true ∧
    MoneyRange (MAX_MONEY + 1) = false := by decide

/-! ## INV-025: per-input coin value in MoneyRange
(`tx_verify.cpp:190-194`, CVE-2010-5139 lane) -/

/-- If Core's per-coin accumulation loop (`Bitcoin.TxValidation.inputValuesLoop`,
the transaction-validation module's TXV-023) succeeds, every input's coin value was MoneyRange-checked:
the loop's guard `¬ MoneyRange c.value` fires
`bad-txns-inputvalues-outofrange` (tx_verify.cpp:190-194) before the
coin is accumulated. -/
@[rule "INV-025"]
theorem inputValuesLoop_ok_perCoinMoneyRange (u : UtxoSet) (spendHeight : UInt32) :
    ∀ (vin : List TxIn) (acc v : Amount),
      inputValuesLoop u spendHeight vin acc = Except.ok v →
      ∀ i ∈ vin, ∀ c, u i.prevout = some c → MoneyRange c.value = true := by
  intro vin
  induction vin with
  | nil => intro acc v _ i hi; nomatch hi
  | cons t rest ih =>
    intro acc v hok i hi c hu
    simp only [inputValuesLoop] at hok
    cases ht : u t.prevout with
    | none => simp only [ht] at hok; simp at hok
    | some tc =>
      simp only [ht] at hok
      split at hok
      · simp at hok
      · split at hok
        · simp at hok
        · split at hok
          · simp at hok
          · rcases List.mem_cons.mp hi with rfl | hrest
            · rw [ht] at hu; simp_all
            · exact ih (acc + tc.value) v hok i hrest c hu

/-- Value vector (INV-025 negative): a coin worth `MAX_MONEY + 1` is
rejected with `bad-txns-inputvalues-outofrange`. -/
example : checkTxInputs (vTx 600) (vU (MAX_MONEY + 1)) 0 =
    Except.error TxError.badTxnsInputvaluesOutOfRange := by rfl

/-! ## INV-026: the running input sum stays in MoneyRange
(`tx_verify.cpp:191-194`) -/

/-- The loop invariant behind INV-026: starting from an in-range
accumulator, the running input sum is re-checked at every accumulation
(the `¬ MoneyRange (acc + c.value)` guard, tx_verify.cpp:191-194), so an
`ok` verdict's final sum is in MoneyRange. Two individually in-range
coins can jointly overflow — the CVE-2010-5137-style guard. -/
@[rule "INV-026"]
theorem inputValuesLoop_ok_runningSumInRange (u : UtxoSet) (spendHeight : UInt32) :
    ∀ (vin : List TxIn) (acc : Amount), MoneyRange acc = true →
      ∀ v, inputValuesLoop u spendHeight vin acc = Except.ok v →
        MoneyRange v = true := by
  intro vin
  induction vin with
  | nil => intro acc hacc v hok; have hv : v = acc := by
             simpa [inputValuesLoop] using hok.symm
           rw [hv]; exact hacc
  | cons t rest ih =>
    intro acc hacc v hok
    simp only [inputValuesLoop] at hok
    cases ht : u t.prevout with
    | none => simp only [ht] at hok; simp at hok
    | some tc =>
      simp only [ht] at hok
      split at hok
      · simp at hok
      · split at hok
        · simp at hok
        · split at hok
          · simp at hok
          · next hsum =>
              exact ih (acc + tc.value) (by simpa using hsum) v hok

/-- Value vector (INV-026 negative): inputs `MAX_MONEY` and `1` are each
in MoneyRange but the running sum `MAX_MONEY + 1` trips the guard. -/
example : checkTxInputs (vTx2 600) vU2 0 =
    Except.error TxError.badTxnsInputvaluesOutOfRange := by rfl

/-! ## INV-029: value in ≥ value out (`tx_verify.cpp:201-205`) -/

/-- **INV-029** (`bad-txns-in-belowout`, tx_verify.cpp:201-205): if
`checkTxInputs` (the transaction-validation module's TXV-020/023/024/025 composite) returns a fee, the
total input value covers the total output value — conservation's
executable gate. Built directly on the transaction-validation module's sorry-free
`checkTxInputs_ok_conservation` (Interface.lean:887, axioms ⊆
[propext, Classical.choice, Quot.sound]: `totalIn = getValueOut + fee`
with `fee ≥ 0`), i.e. the INV-030 fee leg instantiated at this row. -/
@[rule "INV-029"]
theorem checkTxInputs_ok_valueIn_ge_valueOut (tx : Tx) (u : UtxoSet)
    (spendHeight : UInt32) (fee : Amount)
    (hok : checkTxInputs tx u spendHeight = Except.ok fee) :
    tx.getValueOut ≤ totalIn u tx := by
  rcases checkTxInputs_ok_conservation tx u spendHeight fee hok with ⟨h1, h2⟩
  simp only [Amount] at h1 h2 ⊢
  omega

/-- Value vector (INV-025/026/029 positive): one input of 1000, one
output of 600 — fee 400 accepted. -/
example : checkTxInputs (vTx 600) (vU 1000) 0 = Except.ok 400 := by rfl

/-- Value vector (INV-029 negative): outputs 1500 vs inputs 1000 —
`bad-txns-in-belowout`. -/
example : checkTxInputs (vTx 1500) (vU 1000) 0 =
    Except.error TxError.badTxnsInBelowout := by rfl

/-! ## INV-031: block accumulated fee in MoneyRange
(`validation.cpp:2540-2545`) -/

/-- **INV-031**: inside ConnectBlock's composite (`connectChecks`, the block-validation module),
the accumulated fee of the whole block is re-checked against MoneyRange —
the SUM check, not just the per-tx fees
(`bad-txns-accumulated-fee-outofrange`, validation.cpp:2540-2545). -/
@[rule "INV-031"]
theorem connectChecks_ok_feeAccumInRange (txs : List Tx) (cb : Tx)
    (l : List (OutPoint × Coin)) (kf : Tx → Key) (height cutoff : UInt32)
    (h : connectChecks txs cb l kf height cutoff = true) :
    feeAccumInRange (chainFeesL l kf txs height) = true := by
  simp only [connectChecks, Bool.and_eq_true] at h
  exact h.2.2

/-- Value vector (INV-031): a 100-sat accumulated fee is in range;
`MAX_MONEY + 1` is not. -/
example : feeAccumInRange 100 = true ∧ feeAccumInRange (MAX_MONEY + 1) = false := by
  decide

/-! ## INV-032: the no-inflation rule (`validation.cpp:2608-2612`) -/

/-- **INV-032** (`bad-cb-amount`, THE 51%-inflation rule): a block
passing ConnectBlock's composite pays its coinbase at most the subsidy
plus the accumulated fees — routed through the block-validation module's `cbAmountOk` on the
real fee fold `chainFeesL` (the `.mp`/`Int.add_comm` tail mirrors the block-validation module's
own sorry-free `coinbase_draw_le_subsidy_plus_fees`, Connect.lean:184). -/
@[rule "INV-032"]
theorem connectChecks_ok_noInflation (txs : List Tx) (cb : Tx)
    (l : List (OutPoint × Coin)) (kf : Tx → Key) (height cutoff : UInt32)
    (h : connectChecks txs cb l kf height cutoff = true) :
    cb.getValueOut ≤ blockSubsidy height + chainFeesL l kf txs height := by
  simp only [connectChecks, Bool.and_eq_true] at h
  have hcb := (cbAmountOk_iff cb (chainFeesL l kf txs height) height).mp h.2.1
  rw [Int.add_comm] at hcb
  exact hcb

/-- Value vector (INV-032): at height 0 the subsidy is 50·COIN =
5000000000; a coinbase drawing exactly that passes `cbAmountOk`, one
satoshi more fails. -/
example : cbAmountOk (vCbTx 5000000000) 0 0 = true ∧
    cbAmountOk (vCbTx 5000000001) 0 0 = false := by decide

/-! ## INV-036: P2SH sigop accounting (`policy.cpp:132-160`, BIP16) -/

/-- Fold law: with no P2SH prevout among the coins, the P2SH fold
contributes nothing beyond its accumulator. (Proof in the transaction-validation module's
`foldl_value_sum` idiom: `simp only [List.foldl_cons]` — which also
beta-reduces — then a `cases` on the head's prevout and `show`-forced
branches; the old `rw [List.foldl_cons]` version left a beta-redex that
the accumulator-pattern `rw` could not match.) -/
private theorem p2shFold_zero (u : UtxoSet) :
    ∀ (vin : List TxIn) (acc : Nat),
      (∀ i ∈ vin, ∀ c, u i.prevout = some c → isP2SH c.scriptPubKey = false) →
      vin.foldl (fun a i =>
        a + (match u i.prevout with
             | none => 0
             | some c =>
               if isP2SH c.scriptPubKey then
                 match lastPush i.scriptSig with
                 | none => 0
                 | some r => legacySigOpCountScript ⟨r⟩
               else 0)) acc = acc := by
  intro vin
  induction vin with
  | nil => intro acc _; rfl
  | cons t rest ih =>
    intro acc hmem
    have hmem' : ∀ i ∈ rest, ∀ c, u i.prevout = some c →
        isP2SH c.scriptPubKey = false :=
      fun i hi c hc => hmem i (List.mem_cons_of_mem _ hi) c hc
    simp only [List.foldl_cons]
    cases ht : u t.prevout with
    | none =>
      show List.foldl _ (acc + 0) rest = acc
      rw [Nat.add_zero]
      exact ih acc hmem'
    | some tc =>
      have h0 := hmem t (by simp) tc ht
      show List.foldl _ (acc + (if isP2SH tc.scriptPubKey = true then
              match lastPush t.scriptSig with
              | none => 0
              | some r => legacySigOpCountScript ⟨r⟩
            else 0)) rest = acc
      rw [h0, ite_eq_right (by simp), Nat.add_zero]
      exact ih acc hmem'

/-- **INV-036** (BIP16): `p2shSigOpCount` (the block-validation module) counts accurate sigops
from the redeem script ONLY for inputs whose prevout coin's scriptPubKey
is PayToScriptHash — a tx with no P2SH prevout contributes 0. -/
@[rule "INV-036"]
theorem p2shSigOpCount_zero_of_noP2SH (u : UtxoSet) (tx : Tx)
    (h : ∀ i ∈ tx.vin, ∀ c, u i.prevout = some c → isP2SH c.scriptPubKey = false) :
    p2shSigOpCount u tx = 0 := by
  unfold p2shSigOpCount
  split
  · rfl
  · exact p2shFold_zero u tx.vin 0 h

/-- Value vector (INV-036): a non-P2SH prevout (empty scriptPubKey)
contributes 0; a coinbase tx contributes 0 regardless. -/
example : p2shSigOpCount (vU 1000) (vTx 600) = 0 ∧
    p2shSigOpCount (vU 1000) (vCbTx 600) = 0 := by decide

/-- **INV-036** (the P2SH flag gate, `policy.cpp:132-160` /
`tx_verify.cpp:GetTransactionSigOpCost:149-168`): `GetP2SHSigOpCount` is
only called when `flags & SCRIPT_VERIFY_P2SH` is set. The model's
`txSigOpCost` corresponds to the flag-on arm; this wrapper makes the
caller gate explicit without changing the established definition. -/
def txSigOpCostWithFlag (p2shFlag : Bool) (u : UtxoSet) (tx : Tx) : Nat :=
  WITNESS_SCALE_FACTOR *
      (legacySigOpCountTx tx + (if p2shFlag then p2shSigOpCount u tx else 0)) +
    witnessSigOps u tx

/-- **INV-036** (flag set): the flagged cost is exactly the existing
`txSigOpCost` — the P2SH term is included. -/
@[rule "INV-036"]
theorem txSigOpCostWithFlag_true (u : UtxoSet) (tx : Tx) :
    txSigOpCostWithFlag true u tx = txSigOpCost u tx := by
  unfold txSigOpCostWithFlag txSigOpCost
  rw [if_pos rfl]

/-- **INV-036** (flag clear): without `SCRIPT_VERIFY_P2SH` the P2SH term
is absent — no redeem-script sigops are counted. -/
@[rule "INV-036"]
theorem txSigOpCostWithFlag_false (u : UtxoSet) (tx : Tx) :
    txSigOpCostWithFlag false u tx =
      WITNESS_SCALE_FACTOR * legacySigOpCountTx tx + witnessSigOps u tx := by
  unfold txSigOpCostWithFlag
  rw [if_neg (by decide), Nat.add_zero]

/-- **INV-036** (positive direction): for a non-coinbase single-input tx
whose prevout coin is PayToScriptHash, `p2shSigOpCount` adds exactly the
accurate legacy sigop count of the redeem script carried as the last
scriptSig push — not the flat legacy count of the scriptSig itself. -/
@[rule "INV-036"]
theorem p2shSigOpCount_single_p2sh (u : UtxoSet) (tx : Tx) (i : TxIn)
    (c : Coin) (r : ByteArray)
    (hcb : tx.isCoinBase = false) (hv : tx.vin = [i])
    (hc : u i.prevout = some c) (hp : isP2SH c.scriptPubKey = true)
    (hr : lastPush i.scriptSig = some r) :
    p2shSigOpCount u tx = legacySigOpCountScript ⟨r⟩ := by
  unfold p2shSigOpCount
  rw [hcb, hv]
  simp [hc, hp, hr]

/-! ## INV-035: legacy sigop accounting (`policy.cpp:107-130`) -/

/- **INV-035 = route A** (attribute-only alias): the row's check —
legacy sigop count = `OP_CHECKSIG(≈1)` + `OP_CHECKMULTISIG(k=20)` over
scriptSigs + scriptPubKeys, no accurate parse — is exactly the block-validation module's
`legacySigOpCountTx` (BLK-033, Bitcoin/Block/Sigops.lean), so the tag
`@[rule "INV-035"]` is comma-stacked there (the block-validation module's file: completed module
b49e36a, the RC09 rule-closure attr-only precedent). The broken local
`legacySigOpCountBlock_append` copy (failed only on the `foldl_add_split`
ambiguity — both `Ledger`'s and `Block.Sigops`'s are opened here) was
deleted: the block-validation module's identical sorry-free original carries it. -/

/-- Value vector (INV-035): one `OP_CHECKSIG` (0xad) in the scriptSig
counts 1, one `OP_CHECKMULTISIG` (0xae) in the scriptPubKey counts 20 —
21 total, no accurate parsing. -/
example : legacySigOpCountTx (vSigTx (ByteArray.mk #[0xad]) (ByteArray.mk #[0xae])) = 21 := by
  decide

/-! ## Axiom pins (drift fails the build) -/

/--
info: 'Bitcoin.Invariants.RC03.coin_constants' does not depend on any axioms
-/
#guard_msgs in #print axioms coin_constants

/--
info: 'Bitcoin.Invariants.RC03.inputValuesLoop_ok_perCoinMoneyRange' depends on axioms: [propext]
-/
#guard_msgs in #print axioms inputValuesLoop_ok_perCoinMoneyRange

/--
info: 'Bitcoin.Invariants.RC03.inputValuesLoop_ok_runningSumInRange' depends on axioms: [propext]
-/
#guard_msgs in #print axioms inputValuesLoop_ok_runningSumInRange

/--
info: 'Bitcoin.Invariants.RC03.checkTxInputs_ok_valueIn_ge_valueOut' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in #print axioms checkTxInputs_ok_valueIn_ge_valueOut

/--
info: 'Bitcoin.Invariants.RC03.connectChecks_ok_feeAccumInRange' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms connectChecks_ok_feeAccumInRange

/--
info: 'Bitcoin.Invariants.RC03.connectChecks_ok_noInflation' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms connectChecks_ok_noInflation

/--
info: 'Bitcoin.Invariants.RC03.p2shSigOpCount_zero_of_noP2SH' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms p2shSigOpCount_zero_of_noP2SH

end Bitcoin.Invariants.RC03
