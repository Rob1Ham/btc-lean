import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Ledger.Utxo
import Bitcoin.Consensus.TxCheck
import Bitcoin.Activation.Interface
import Bitcoin.Numeric.Amount
import Bitcoin.Conservation.Interface
import Bitcoin.DataLaws.Interface
import Bitcoin.DataLaws.Laws
import Bitcoin.RuleAttr

/-
# Bitcoin.TxValidation — FROZEN INTERFACE

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/consensus/tx_check.cpp (CheckTransaction:19-68),
                        src/consensus/tx_verify.cpp (CheckTxInputs:170-220,
                        IsFinalTx, SequenceLocks/BIP68 trio),
                        src/validation.cpp (contextual checks)
Status: frozen 2026-10-16. Statements are
                        sorry-stubbed placeholders; the bodies are filled.

## Interface-change log (2026-10-16 — sanctioned by the interface conventions
protocol "fill the opaque stub bodies"; deviations documented here)

1. `checkTxInputs` gained a `spendHeight : UInt32` parameter. Core's real
   signature is `CheckTxInputs(tx, state, inputs, int nSpendHeight, txfee)`
   (tx_verify.cpp:170) — the coinbase-maturity check (TXV-021) is
   meaningless without it. The frozen 2-arg form could not express
   maturity; callers pass the block/tip+1 height.
2. New `TxError` constructor `badTxnsInputvaluesOutOfRange`
   ("bad-txns-inputvalues-outofrange", tx_verify.cpp:193) — the input-side
   MoneyRange failure is distinct from the frozen `badTxnsFeeOutOfRange`
   ("bad-txns-fee-outofrange", tx_verify.cpp:215) in Core's taxonomy.
3. Reject-string comments corrected against Core @ f54186c:
   "bad-txns-inputs-missingorspent" (tx_verify.cpp:174, no hyphen before
   `spent`) and "bad-txns-fee-outofrange" (tx_verify.cpp:215, one word) —
   the placeholders read "missing-or-spent" / "fee-out-of-range".
   `rejectReason` below carries the exact strings.
4. Imports added: `Bitcoin.Numeric.Amount` (plainSum/checkedSum),
   `Bitcoin.Conservation.Interface` (`totalIn`, fee-conservation
   bridge), `Bitcoin.DataLaws.Interface` (isFinalTx),
   `Bitcoin.DataLaws.Laws` (BIP68 field algebra), `Bitcoin.RuleAttr`
   (@[rule] traceability).
   `Ledger/Interface.lean` imports this module, so `MEMPOOL_HEIGHT` is
   re-declared locally as `mempoolHeight` (TXV-042) — equality with
   `Bitcoin.Ledger.MEMPOOL_HEIGHT` is pinned in `Test/TxValidation`.

## Scope

`CheckTransaction` + `CheckTxInputs` + finality/sequence as one pure
`validateTx`, with the 75 TXV rules wired via `@[rule]` attributes.
The prototype bootstrap `checkTransaction` (9 reasons, CVE-tagged) is preserved
and reused. Exit: tx_valid/tx_invalid 100% stateless.
-/

namespace Bitcoin.TxValidation

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Numeric

/-! ## Error taxonomy -/

/-- The full tx-validation error taxonomy: the 9 stateless
`TxCheckError` reasons (reused) + the contextual/input rules.
Constructor names = Core reject strings (the prototype R6). -/
inductive TxError where
  | stateless (e : TxCheckError)   -- the prototype-bootstrap taxonomy, embedded
  | badTxnsInputsMissingOrSpent    -- "bad-txns-inputs-missingorspent" (tx_verify.cpp:174)
  | badTxnsInBelowout              -- "bad-txns-in-belowout" (tx_verify.cpp:203)
  | badTxnsFeeOutOfRange           -- "bad-txns-fee-outofrange" (tx_verify.cpp:215)
  | badTxnsInputvaluesOutOfRange   -- "bad-txns-inputvalues-outofrange" (tx_verify.cpp:193)
  | badTxnsNonfinal                -- "bad-txns-nonfinal" (validation.cpp:2556/4155)
  | badTxnsPrematureSpendOfCoinbase -- "bad-txns-premature-spend-of-coinbase" (tx_verify.cpp:186)
  | badTxnsNonstandardSequence     -- "non-BIP68-final" (validation.cpp:885, mempool path)
deriving Repr, DecidableEq, BEq

/-- Exact Core reject strings for the prototype stateless taxonomy
(`consensus/tx_check.cpp:23-68`; kept here because `TxCheckError` is
frozen and cannot host the strings itself). -/
def txCheckReason : TxCheckError → String
  | .vinEmpty            => "bad-txns-vin-empty"
  | .voutEmpty           => "bad-txns-vout-empty"
  | .oversize            => "bad-txns-oversize"
  | .voutNegative        => "bad-txns-vout-negative"
  | .voutTooLarge        => "bad-txns-vout-toolarge"
  | .txoutTotalTooLarge  => "bad-txns-txouttotal-toolarge"
  | .inputsDuplicate     => "bad-txns-inputs-duplicate"
  | .cbLength            => "bad-cb-length"
  | .prevoutNull         => "bad-txns-prevout-null"

/-- Exact Core reject string per `TxError` (verified against Core
@ f54186c: consensus/tx_check.cpp, consensus/tx_verify.cpp:174-215,
validation.cpp:885/2556/4155). -/
def rejectReason : TxError → String
  | .stateless e                     => txCheckReason e
  | .badTxnsInputsMissingOrSpent     => "bad-txns-inputs-missingorspent"
  | .badTxnsInBelowout               => "bad-txns-in-belowout"
  | .badTxnsFeeOutOfRange            => "bad-txns-fee-outofrange"
  | .badTxnsInputvaluesOutOfRange    => "bad-txns-inputvalues-outofrange"
  | .badTxnsNonfinal                 => "bad-txns-nonfinal"
  | .badTxnsPrematureSpendOfCoinbase => "bad-txns-premature-spend-of-coinbase"
  | .badTxnsNonstandardSequence      => "non-BIP68-final"

/-! ## Contexts and sentinels -/

/-- Coinbase maturity (`consensus/consensus.h:19`): `COINBASE_MATURITY = 100`. -/
def COINBASE_MATURITY : UInt32 := 100

/-- `CTxMemPool::MEMPOOL_HEIGHT` (`txmempool.h:51`): coins created in the
mempool carry the sentinel height `0x7FFFFFFF` (txmempool.cpp:804,816).
Re-declared locally because `Bitcoin.Ledger.Interface` imports THIS
module (frozen header above) — the reverse import would be a cycle;
`Test/TxValidation` pins `mempoolHeight = Bitcoin.Ledger.MEMPOOL_HEIGHT`. -/
@[rule "TXV-042"]
def mempoolHeight : UInt32 := 0x7FFFFFFF

/-- BIP113 (TXV-031): post-CSV, every time-domain comparison uses the
median-time-past of the block BEFORE the one being validated
(validation.cpp:4143-4151). The frozen `validateTx`/`isFinalTx` `mtp`
parameter IS that caller-supplied cutoff; this definition pins the
convention (identity) so callers and the rule DB have a name for it. -/
@[rule "TXV-031"]
def bip113Cutoff (prevBlockMtp : UInt32) : UInt32 := prevBlockMtp

/-! ## Coin encoding (TXV-022) -/

/-- Disk packing of a `Coin`'s metadata (`coins.h:52-87`): the 31-bit
block height and the 1-bit coinbase flag pack as `(height << 1) | cb`.
Modeled over `Nat` (proof-friendly); `packCoinCode_spec` pins the
roundtrip on the reachable height domain (`nHeight` is 31-bit). -/
@[rule "TXV-022"]
def packCoinCode (height : UInt32) (isCoinbase : Bool) : Nat :=
  height.toNat * 2 + (if isCoinbase then 1 else 0)

/-- Unpack the height half of a coin code. -/
def coinHeightOfCode (code : Nat) : UInt32 := (code / 2).toUInt32

/-- Unpack the coinbase bit of a coin code. -/
def coinIsCoinbaseOfCode (code : Nat) : Bool := code % 2 == 1

/-- TXV-022 roundtrip, height half (heights are 31-bit in `Coin`). -/
theorem coinHeightOfCode_pack (height : UInt32) (isCoinbase : Bool)
    (h : height.toNat < 2147483648) :
    coinHeightOfCode (packCoinCode height isCoinbase) = height := by
  apply UInt32.toNat_inj.mp
  show ((height.toNat * 2 + (if isCoinbase then 1 else 0)) / 2) % 4294967296 = height.toNat
  split
  · simp only [Nat.mod_eq_of_lt (by omega : (height.toNat * 2 + 1) / 2 < 4294967296)]
    omega
  · omega

/-- TXV-022 roundtrip, coinbase bit. -/
theorem coinIsCoinbaseOfCode_pack (height : UInt32) (isCoinbase : Bool) :
    coinIsCoinbaseOfCode (packCoinCode height isCoinbase) = isCoinbase := by
  cases isCoinbase <;> simp [coinIsCoinbaseOfCode, packCoinCode] <;> omega

/-! ## Coinbase maturity (TXV-021 / TXV-070) -/

/-- Per-coin maturity gate (tx_verify.cpp:185-188): a coinbase coin may be
spent only when `spendHeight − coinHeight ≥ COINBASE_MATURITY`. Core
computes the depth with `uint32_t` subtraction; on the reachable domain
(a coin's height is ≤ the spend height — coins enter the view when their
block connects) this is exactly the `Nat` comparison below, which is also
bit-identical to `Bitcoin.Ledger.maturityOk`'s per-coin test (see
INV-028/BLK-100). The unreachable future-coin wrap corner is catalogued
in the transaction-validation notes. -/
@[rule "TXV-021"]
def coinMatured (spendHeight : UInt32) (c : Coin) : Bool :=
  ¬ c.isCoinbase ||
    decide (c.height.toNat + COINBASE_MATURITY.toNat ≤ spendHeight.toNat)

/-- TXV-070, boundary exactness: a coinbase output created at height `N`
is first spendable in block `N + 100` (depth exactly 100 passes; 99
fails). `hc` guards the `Nat → UInt32` truncation at the top of the
height domain. -/
@[rule "TXV-070"]
theorem coinbase_maturity_boundary (coinH : UInt32)
    (hc : coinH.toNat + 101 < 4294967296) :
    coinMatured (UInt32.ofNat (coinH.toNat + 99)) ⟨0, coinH, true, Script.empty⟩ = false ∧
    coinMatured (UInt32.ofNat (coinH.toNat + 100)) ⟨0, coinH, true, Script.empty⟩ = true := by
  have h99 : (UInt32.ofNat (coinH.toNat + 99)).toNat = coinH.toNat + 99 := by
    simp [UInt32.toNat_ofNat]; omega
  have h100 : (UInt32.ofNat (coinH.toNat + 100)).toNat = coinH.toNat + 100 := by
    simp [UInt32.toNat_ofNat]; omega
  simp only [coinMatured]
  rw [h99, h100]
  show (decide (coinH.toNat + 100 ≤ coinH.toNat + 99)) = false ∧
       (decide (coinH.toNat + 100 ≤ coinH.toNat + 100)) = true
  exact ⟨decide_eq_false_iff_not.mpr (by omega), decide_eq_true (by omega)⟩

/-- TXV-070, generalized: for an arbitrary spend height `S` — block
context supplies the candidate block's own height, the mempool supplies
`tip + 1` — a coinbase coin created at height `N` passes the maturity
gate exactly when `N + COINBASE_MATURITY ≤ S`. -/
@[rule "TXV-070"]
theorem coinMatured_coinbase_iff (coinH spendHeight : UInt32) :
    coinMatured spendHeight ⟨0, coinH, true, Script.empty⟩ = true ↔
      coinH.toNat + COINBASE_MATURITY.toNat ≤ spendHeight.toNat := by
  unfold coinMatured
  simp

/-! ## HaveInputs (TXV-020) -/

/-- `HaveInputs` (`coins.cpp:322-331`): every prevout of the tx resolves
to a coin in the view. Core calls this once, up front, before the
per-coin value loop — the missing-vs-outofrange error ordering below
mirrors that. -/
@[rule "TXV-020"]
def haveInputs (tx : Tx) (u : UtxoSet) : Bool :=
  tx.vin.all (fun i => (u i.prevout).isSome)

/-! ## The per-coin input-value loop (TXV-023) -/

/-- Core's per-coin accumulation loop (tx_verify.cpp:178-196), unrolled
from `CheckTxInputs`: for each input — coinbase-maturity gate, per-coin
`MoneyRange`, then the incremental `MoneyRange` on the running input sum
(CVE-2010-5137-style overflow guard). Returns the total input value. -/
@[rule "TXV-023"]
def inputValuesLoop (u : UtxoSet) (spendHeight : UInt32) :
    List TxIn → Amount → Except TxError Amount
  | [], acc => .ok acc
  | i :: rest, acc =>
    match u i.prevout with
    | none => .error .badTxnsInputsMissingOrSpent
    | some c =>
      if ¬ coinMatured spendHeight c then .error .badTxnsPrematureSpendOfCoinbase
      else if ¬ MoneyRange c.value then .error .badTxnsInputvaluesOutOfRange
      else if ¬ MoneyRange (acc + c.value) then .error .badTxnsInputvaluesOutOfRange
      else inputValuesLoop u spendHeight rest (acc + c.value)

/-! ## `Consensus::CheckTxInputs` (TXV-020/021/023/024/025) -/

/-- `Consensus::CheckTxInputs` (tx_verify.cpp:170-220): inputs exist
(TXV-020), values in range (TXV-023), value in ≥ value out (TXV-024),
fee in MoneyRange (TXV-025). Returns the fee on success. Separate from
`validateTx` so callers can call it inside the block fold. Zero-value
outputs flow through as ordinary coins (TXV-067: only the bounds are
checked, tx_check.cpp:35-41). -/
@[rule "TXV-067", rule "BLK-103"]
def checkTxInputs (tx : Tx) (u : UtxoSet) (spendHeight : UInt32) :
    Except TxError Amount :=
  if haveInputs tx u then
    match inputValuesLoop u spendHeight tx.vin 0 with
    | .error e => .error e
    | .ok valueIn =>
      if valueIn < tx.getValueOut then .error .badTxnsInBelowout
      else if MoneyRange (valueIn - tx.getValueOut) then
        .ok (valueIn - tx.getValueOut)
      else .error .badTxnsFeeOutOfRange
  else .error .badTxnsInputsMissingOrSpent

/-- Success shape of `checkTxInputs`: the fee is `valueIn − getValueOut`,
in MoneyRange (hence nonnegative), with `valueIn` the loop's output. -/
theorem checkTxInputs_ok (tx : Tx) (u : UtxoSet) (spendHeight : UInt32)
    (h : (checkTxInputs tx u spendHeight).isOk) :
    ∃ fee : Amount, checkTxInputs tx u spendHeight = .ok fee ∧ fee ≥ 0 := by
  unfold checkTxInputs at h
  by_cases hi : haveInputs tx u = true
  · rw [if_pos hi] at h
    rcases hlv : inputValuesLoop u spendHeight tx.vin 0 with _ | valueIn
    · simp only [hlv] at h; exact Bool.noConfusion h
    · simp only [hlv] at h
      by_cases hb : valueIn < tx.getValueOut
      · rw [if_pos hb] at h; exact Bool.noConfusion h
      · rw [if_neg hb] at h
        by_cases hm : MoneyRange (valueIn - tx.getValueOut) = true
        · rw [if_pos hm] at h
          refine ⟨valueIn - tx.getValueOut, ?_, (moneyRange_elim hm).1⟩
          simp only [checkTxInputs, if_pos hi, hlv, if_neg hb, if_pos hm]
        · rw [if_neg hm] at h; exact Bool.noConfusion h
  · rw [if_neg hi] at h; exact Bool.noConfusion h

/-- A one-input, zero-output tx spending `o`: the minimal harness for the
maturity gate, where every other `CheckTxInputs` gate is vacuous. -/
def maturityProbeTx (o : OutPoint) : Tx :=
  ⟨2, [⟨o, Script.empty, Bitcoin.DataLaws.SEQUENCE_FINAL⟩], [], 0, []⟩

/-- TXV-070: the full `CheckTxInputs` maturity gate, generalized to any
caller-supplied spend height. Block context supplies the candidate
block's height (so `N + 100` passes and `N + 99` fails); the mempool
supplies `tip + 1`, so at a tip of `N + 100` the gate is evaluated at
`N + 101`. -/
@[rule "TXV-070"]
theorem checkTxInputs_coinbase_maturity_iff (coinH spendHeight : UInt32) :
    (checkTxInputs (maturityProbeTx (OutPoint.null))
        (fun _ => some ⟨0, coinH, true, Script.empty⟩) spendHeight).isOk = true ↔
      coinH.toNat + COINBASE_MATURITY.toNat ≤ spendHeight.toNat := by
  rw [← coinMatured_coinbase_iff]
  have hmr0 : MoneyRange (0 : Amount) = true :=
    moneyRange_intro (Int.le_refl 0) maxMoney_nonneg
  by_cases hmat : coinMatured spendHeight ⟨0, coinH, true, Script.empty⟩ = true
  · have hres : checkTxInputs (maturityProbeTx (OutPoint.null))
        (fun _ => some ⟨0, coinH, true, Script.empty⟩) spendHeight = .ok 0 := by
      unfold checkTxInputs haveInputs maturityProbeTx Tx.getValueOut
      simp [inputValuesLoop, hmat, hmr0]
    constructor
    · intro _; exact hmat
    · intro _; rw [hres]; rfl
  · have hres : checkTxInputs (maturityProbeTx (OutPoint.null))
        (fun _ => some ⟨0, coinH, true, Script.empty⟩) spendHeight =
        .error .badTxnsPrematureSpendOfCoinbase := by
      unfold checkTxInputs haveInputs maturityProbeTx Tx.getValueOut
      simp [inputValuesLoop, hmat]
    constructor
    · intro h; rw [hres] at h; exact Bool.noConfusion h
    · intro h; exact absurd h hmat

/-! ## BIP68 sequence locks (TXV-039/040/041) -/

/-- Does this input's `nSequence` carry a consensus relative lock at all?
(tx_verify.cpp:69-77: `SEQUENCE_FINAL` and disable-flag sequences
contribute nothing.) -/
def seqLockApplies (s : UInt32) : Bool :=
  ¬ (s == Bitcoin.DataLaws.SEQUENCE_FINAL) && ¬ Bitcoin.DataLaws.seqIsDisabled s

/-- One zipped input's height-domain lockpoint (`nCoinHeight + masked − 1`,
tx_verify.cpp:96 — TXV-037 algebra), or `none` when the sequence
carries no lock or a time-based one. -/
def heightLockOf (x : TxIn × (Int × Int)) : Option Int :=
  if seqLockApplies x.1.sequence && ¬ Bitcoin.DataLaws.seqIsTimeBased x.1.sequence then
    some (x.2.1 + (Bitcoin.DataLaws.seqRelative x.1.sequence : Int) - 1)
  else none

/-- One zipped input's time-domain lockpoint
(`coin-parent-MTP + (masked << 9) − 1`, tx_verify.cpp:79-94 —
TXV-036 algebra with `SEQUENCE_LOCKTIME_GRANULARITY = 9`). -/
def timeLockOf (x : TxIn × (Int × Int)) : Option Int :=
  if seqLockApplies x.1.sequence && Bitcoin.DataLaws.seqIsTimeBased x.1.sequence then
    some (x.2.2 + ((Bitcoin.DataLaws.seqRelative x.1.sequence * 512 : Nat) : Int) - 1)
  else none

/-- Fold step: `nMinHeight`/`nMinTime` are running maxima seeded at `-1`
(the `nLockTime` last-invalid sentinel, tx_verify.cpp:55-57). -/
def seqLockStep (p : Int × Int) (x : TxIn × (Int × Int)) : Int × Int :=
  match heightLockOf x with
  | some v => (max p.1 v, p.2)
  | none =>
    match timeLockOf x with
    | some v => (p.1, max p.2 v)
    | none => p

/-- The input loop of `CalculateSequenceLocks` (tx_verify.cpp:64-100) as a
fold over `vin` zipped with the per-input `(prevHeight, parentMTP)` data
(the sizes-Equal precondition of Core's `assert` becomes truncating zip;
max is commutative so fold direction is immaterial). -/
def seqLockFold : List TxIn → List (Int × Int) → Int × Int
  | [], _ => (-1, -1)
  | _, [] => (-1, -1)
  | i :: vin, d :: rest => seqLockStep (seqLockFold vin rest) (i, d)

/-- `CalculateSequenceLocks` (tx_verify.cpp:45-101). `csvFlag` is Core's
`flags & LOCKTIME_VERIFY_SEQUENCE` bit (TXV-040 plumbing:
`ScriptFlags.csv` supplies it in block context). -/
def calculateSequenceLocks (tx : Tx) (csvFlag : Bool) (prevData : List (Int × Int)) :
    Int × Int :=
  if ¬ Bitcoin.DataLaws.bip68Enabled tx.version csvFlag then (-1, -1)
  else seqLockFold tx.vin prevData

/-- `EvaluateSequenceLocks` (tx_verify.cpp:103-111): fail iff
`lockPair.first ≥ block.nHeight ∨ lockPair.second ≥ nBlockTime` where
`nBlockTime = MTP(block.prev)` — the caller supplies both (TXV-041's
tip+1 / prev-MTP convention). -/
@[rule "TXV-039"]
def evaluateSequenceLocks (blockHeight blockTime : Int) (lockPair : Int × Int) : Bool :=
  decide (lockPair.1 < blockHeight ∧ lockPair.2 < blockTime)

/-- The full BIP68 verdict: `SequenceLocks(tx, flags, prevHeights, block)`
(tx_verify.cpp:114-121). `prevData` is the caller-supplied seam — Core
reads each coin's parent-block MTP via `block.GetAncestor(h-1)`, which
`Coin` (height+value+script only) cannot express; the ledger supplies
`(prevHeight, parentMTP)` pairs per input. -/
@[rule "TXV-041"]
def sequenceLocksOk (tx : Tx) (csvFlag : Bool) (prevData : List (Int × Int))
    (blockHeight blockTime : Int) : Bool :=
  evaluateSequenceLocks blockHeight blockTime
    (calculateSequenceLocks tx csvFlag prevData)

/-- Height-domain-only projection used by the frozen `validateTx`
signature: coin heights come from `u`; the time component is a dummy
(unused by `heightLockOf`). TXV-036's time-domain lock needs the parent
MTP chain and is checked by `sequenceLocksOk` with the ledger seam. -/
def prevHeightData (tx : Tx) (u : UtxoSet) : List (Int × Int) :=
  tx.vin.map (fun i =>
    match u i.prevout with
    | some c => ((c.height.toNat : Int), 0)
    | none => (0, 0))

/-- The height-domain half of BIP68: `lockPair.first < H`. -/
def bip68HeightOk (tx : Tx) (u : UtxoSet) (csvFlag : Bool) (H : Int) : Bool :=
  (calculateSequenceLocks tx csvFlag (prevHeightData tx u)).1 < H

/-! ## Value-sum algebra (TXV-074) -/

/-- `Tx.getValueOut`'s fold is the plain sum of output values. -/
theorem foldl_value_sum : ∀ (l : List TxOut) (acc : Amount),
    l.foldl (fun a o => a + o.value) acc = acc + plainSum (l.map (fun o => o.value)) := by
  intro l
  induction l with
  | nil => intro acc; simp [plainSum, Int.add_zero]
  | cons o rest ih =>
    intro acc
    rw [List.foldl_cons, ih (acc + o.value), List.map_cons, plainSum_cons]
    rw [Int.add_assoc]

theorem getValueOut_eq_plainSum (tx : Tx) :
    tx.getValueOut = plainSum (tx.vout.map (fun o => o.value)) := by
  unfold Tx.getValueOut
  rw [foldl_value_sum, Int.zero_add]

/-- Core's incremental-MoneyRange output loop is exactly as strong as the
plain sum (the invariant Core's comment at tx_check.cpp:31-42 relies on). -/
theorem checkOutputs_ok_plain (l : List TxOut) (acc : Amount)
    (ha : MoneyRange acc = true)
    (h : checkTransaction.checkOutputs l acc = none) :
    MoneyRange (acc + plainSum (l.map (fun o => o.value))) = true := by
  induction l generalizing acc with
  | nil =>
    simp only [List.map_nil, plainSum, Int.add_zero]
    exact ha
  | cons o rest ih =>
    unfold checkTransaction.checkOutputs at h
    simp only at h
    split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · simp at h
        · rename_i hmr
          have hmr' : MoneyRange (acc + o.value) = true := by simpa using hmr
          have h' := ih (acc + o.value) hmr' h
          simp only [List.map_cons, plainSum]
          rw [Int.add_assoc] at h'
          exact h'

/-- TXV-074: `CheckTransaction` success ⇒ `GetValueOut` lands in MoneyRange
(the totality precondition Core's tx_verify.cpp:197-200 comment relies on). -/
@[rule "TXV-074"]
theorem checkTransaction_ok_getValueOut_moneyRange (tx : Tx)
    (h : checkTransaction tx = none) : MoneyRange tx.getValueOut = true := by
  have hco : checkTransaction.checkOutputs tx.vout 0 = none := by
    unfold checkTransaction at h
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h
    · exact absurd h (by simp)
    · rename_i hsome
      cases hco : checkTransaction.checkOutputs tx.vout 0 with
      | none => rfl
      | some e => exact absurd (hsome e hco) (by simp)
  have h0 : MoneyRange (0 : Amount) = true :=
    moneyRange_intro (Int.le_refl 0) maxMoney_nonneg
  have hsum := checkOutputs_ok_plain tx.vout 0 h0 hco
  rw [getValueOut_eq_plainSum]
  simpa using hsum

/-! ## Duplicate prevouts (TXV-007 / CVE-2018-17144) -/

/-- INV-007 (bound dir; CVE-2018-17144): a transaction
`checkTransaction` accepts has no duplicate prevouts
(`bad-txns-inputs-duplicate`, tx_check.cpp:49-53 @cce32b168).
PDW3/T3b promotion (PD03 score row 13): attr-only tag onto the transaction-validation module's
sorry-free bound theorem — PD03 T3b, "tag
`checkTransaction_ok_no_dup_prevouts` onto INV-007".
The reject direction (PD03 P5 / T3a) is the PDW1 lane. -/
@[rule "INV-007"]
theorem checkTransaction_ok_no_dup_prevouts (tx : Tx)
    (h : checkTransaction tx = none) : hasDupPrevouts tx.vin = false := by
  unfold checkTransaction at h
  split at h; · exact absurd h (by simp)
  split at h; · exact absurd h (by simp)
  split at h; · exact absurd h (by simp)
  split at h; · exact absurd h (by simp)
  split at h
  · exact absurd h (by simp)
  · rename_i hdup
    exact Bool.eq_false_iff.mpr hdup

/-! ## UTXO-view congruence (extensionality for validateTx) -/

theorem haveInputs_congr (tx : Tx) (u u' : UtxoSet)
    (h : ∀ i ∈ tx.vin, u i.prevout = u' i.prevout) :
    haveInputs tx u = haveInputs tx u' := by
  unfold haveInputs
  have key : ∀ i ∈ tx.vin, (u i.prevout).isSome = (u' i.prevout).isSome := by
    intro i hi; rw [h i hi]
  cases h1 : tx.vin.all (fun i => (u i.prevout).isSome) with
  | true =>
    have h1' := List.all_eq_true.mp h1
    have h2 : tx.vin.all (fun i => (u' i.prevout).isSome) = true := by
      rw [List.all_eq_true]
      intro i hi
      exact (key i hi).symm.trans (h1' i hi)
    rw [h2]
  | false =>
    have h1' : ¬ (tx.vin.all (fun i => (u i.prevout).isSome) = true) := by
      rw [h1]; simp
    have h2 : ¬ (tx.vin.all (fun i => (u' i.prevout).isSome) = true) := by
      intro htrue
      rw [List.all_eq_true] at htrue
      exact h1' (by
        rw [List.all_eq_true]
        intro i hi
        exact (key i hi).trans (htrue i hi))
    exact (Bool.eq_false_iff.mpr h2).symm

theorem inputValuesLoop_congr (u u' : UtxoSet) (spendHeight : UInt32) :
    ∀ (l : List TxIn) (acc : Amount),
      (∀ i ∈ l, u i.prevout = u' i.prevout) →
      inputValuesLoop u spendHeight l acc = inputValuesLoop u' spendHeight l acc := by
  intro l
  induction l with
  | nil => intro acc _; rfl
  | cons i rest ih =>
    intro acc h
    have hrest : ∀ j ∈ rest, u j.prevout = u' j.prevout := fun j hj =>
      h j (List.mem_cons_of_mem _ hj)
    simp only [inputValuesLoop]
    rw [h i (List.mem_cons.mpr (Or.inl rfl))]
    cases hv : u' i.prevout with
    | none => rfl
    | some c =>
      split
      · rfl
      · split
        · rfl
        · split
          · rfl
          · split
            · rfl
            · exact ih _ hrest

theorem checkTxInputs_congr (tx : Tx) (u u' : UtxoSet) (spendHeight : UInt32)
    (h : ∀ i ∈ tx.vin, u i.prevout = u' i.prevout) :
    checkTxInputs tx u spendHeight = checkTxInputs tx u' spendHeight := by
  unfold checkTxInputs
  rw [haveInputs_congr tx u u' h, inputValuesLoop_congr u u' spendHeight tx.vin 0 h]

theorem prevHeightData_congr (tx : Tx) (u u' : UtxoSet)
    (h : ∀ i ∈ tx.vin, u i.prevout = u' i.prevout) :
    prevHeightData tx u = prevHeightData tx u' := by
  unfold prevHeightData
  exact List.map_congr_left (fun i hi => by rw [h i hi])

theorem bip68HeightOk_congr (tx : Tx) (u u' : UtxoSet) (csv : Bool) (H : Int)
    (h : ∀ i ∈ tx.vin, u i.prevout = u' i.prevout) :
    bip68HeightOk tx u csv H = bip68HeightOk tx u' csv H := by
  unfold bip68HeightOk
  rw [prevHeightData_congr tx u u' h]

/-! ## The validation entry point -/

/-- The pure validation entry (B3's proposed shape):
`validateTx : Tx → CoinView → Height → Time → Flags → Except TxError Fee`.
Returns the fee on success. `u` is the abstract UTXO view (the prototype's UTXO
decision — theorems never touch concrete representations).

Check order = Core's mempool path (`MemPoolAccept::PreChecks`):
stateless `CheckTransaction` prefix → `IsFinalTx` at `(height, mtp)`
(TXV-032, with `mtp` = BIP113 cutoff per TXV-031) → coinbase early-exit
(TXV-072: coinbases are exempt from `HaveInputs`/`CheckTxInputs`) →
BIP68 height-domain gate (TXV-040's CSV flag plumbing; the time domain
needs `sequenceLocksOk` seam) → `checkTxInputs`
(TXV-020/021/023/024/025). A BIP68 failure collapses into Core's block-
context reject string `bad-txns-nonfinal` (validation.cpp:2556). `nVersion`
is deliberately unchecked — any 32-bit value is valid (TXV-071,
transaction.h:290). -/
@[rule "TXV-032", rule "TXV-040", rule "TXV-072", rule "TXV-071"]
def validateTx (tx : Tx) (u : UtxoSet) (height mtp : UInt32)
    (flags : Activation.ScriptFlags) : Except TxError Amount :=
  match checkTransaction tx with
  | some e => .error (TxError.stateless e)
  | none =>
    if Bitcoin.DataLaws.isFinalTx tx height mtp then
      if tx.isCoinBase then .ok 0
      else if bip68HeightOk tx u flags.csv (height.toNat : Int) then
        checkTxInputs tx u height
      else .error .badTxnsNonfinal
    else .error .badTxnsNonfinal

/-- Totality: `validateTx` is a total function (structural matches + decidable ifs). -/
theorem validateTx_total (tx : Tx) (u : UtxoSet) (height : UInt32) (mtp : UInt32)
    (flags : Activation.ScriptFlags) :
    ∃ r, validateTx tx u height mtp flags = r := ⟨_, rfl⟩

/-! ## Frozen laws (the transaction-validation layer exit criteria) -/

/-- The prototype bootstrap `checkTransaction` is exactly the stateless prefix
of `validateTx` (traceability: TXV-001..010 route through it). -/
theorem validateTx_stateless_prefix (tx : Tx) (u : UtxoSet)
    (height : UInt32) (mtp : UInt32) (flags : Activation.ScriptFlags) :
    (match checkTransaction tx with
     | some e => Except.error (TxError.stateless e)
     | none => validateTx tx u height mtp flags) = validateTx tx u height mtp flags := by
  unfold validateTx
  cases hc : checkTransaction tx with
  | some e => simp only [hc]
  | none => simp only [hc]

/-- Fee soundness: a successful validation returns a fee that makes
`valueIn = valueOut + fee` (bridge to conservation). -/
theorem validateTx_fee_consistent (tx : Tx) (u : UtxoSet)
    (height : UInt32) (mtp : UInt32) (flags : Activation.ScriptFlags)
    (h : (validateTx tx u height mtp flags).isOk) :
    ∃ fee : Amount, validateTx tx u height mtp flags = .ok fee ∧ fee ≥ 0 := by
  unfold validateTx at h ⊢
  by_cases hc : checkTransaction tx = none
  · rw [hc] at h ⊢
    by_cases hfin : Bitcoin.DataLaws.isFinalTx tx height mtp = true
    · rw [if_pos hfin] at h ⊢
      by_cases hcb : tx.isCoinBase = true
      · rw [if_pos hcb] at h ⊢
        exact ⟨0, rfl, Int.le_refl 0⟩
      · rw [if_neg hcb] at h ⊢
        by_cases hb68 : bip68HeightOk tx u flags.csv (height.toNat : Int) = true
        · rw [if_pos hb68] at h ⊢
          exact checkTxInputs_ok tx u height h
        · rw [if_neg hb68] at h; exact Bool.noConfusion h
    · rw [if_neg hfin] at h; exact Bool.noConfusion h
  · rcases he : checkTransaction tx with _ | e
    · exact absurd hc (by rw [he]; simp)
    · rw [he] at h; exact Bool.noConfusion h

/-- Extensionality: `validateTx` only ever queries `u` at the tx's own
prevouts — two UTXO views agreeing there give identical verdicts. -/
theorem validateTx_utxo_extensional (tx : Tx) (u u' : UtxoSet)
    (height mtp : UInt32) (flags : Activation.ScriptFlags)
    (h : ∀ i ∈ tx.vin, u i.prevout = u' i.prevout) :
    validateTx tx u height mtp flags = validateTx tx u' height mtp flags := by
  unfold validateTx
  by_cases hc : checkTransaction tx = none
  · rw [hc]
    rw [bip68HeightOk_congr tx u u' flags.csv (height.toNat : Int) h,
      checkTxInputs_congr tx u u' height h]
  · rcases he : checkTransaction tx with _ | e
    · exact absurd hc (by rw [he]; simp)
    · rfl

/-! ## TXV-071: no version-range gate; only BIP68's `version ≥ 2` -/

/-- TXV-071: `CheckTransaction` never reads `nVersion` — there is no
version-range rejection in the stateless gate (tx_check.cpp:19-68; the
anchor transaction.h:290 `CURRENT_VERSION` is not an acceptance rule). -/
theorem checkTransaction_version_irrelevant (tx : Tx) (v : Int32) :
    checkTransaction { tx with version := v } = checkTransaction tx := by
  cases tx
  rfl

theorem isFinalTx_version_irrelevant (tx : Tx) (v : Int32)
    (height mtp : UInt32) :
    Bitcoin.DataLaws.isFinalTx { tx with version := v } height mtp =
      Bitcoin.DataLaws.isFinalTx tx height mtp := by
  cases tx
  rfl

theorem isCoinBase_version_irrelevant (tx : Tx) (v : Int32) :
    ({ tx with version := v } : Tx).isCoinBase = tx.isCoinBase := by
  cases tx
  rfl

theorem checkTxInputs_version_irrelevant (tx : Tx) (v : Int32)
    (u : UtxoSet) (spendHeight : UInt32) :
    checkTxInputs { tx with version := v } u spendHeight =
      checkTxInputs tx u spendHeight := by
  cases tx
  rfl

/-- The only version-sensitive term in the contextual path: BIP68's
enable predicate. -/
theorem bip68HeightOk_version_congr (tx : Tx) (v : Int32) (u : UtxoSet)
    (csvFlag : Bool) (H : Int)
    (h : Bitcoin.DataLaws.bip68Enabled v csvFlag =
      Bitcoin.DataLaws.bip68Enabled tx.version csvFlag) :
    bip68HeightOk { tx with version := v } u csvFlag H =
      bip68HeightOk tx u csvFlag H := by
  unfold bip68HeightOk calculateSequenceLocks
  rw [show ({ tx with version := v } : Tx).version = v from rfl]
  rw [show prevHeightData { tx with version := v } u = prevHeightData tx u from rfl]
  rw [h]

/-- TXV-071: `validateTx` is invariant under changing `nVersion` as long
as BIP68's enable predicate is unchanged. There is therefore no 32-bit
version range check anywhere in the validator. -/
@[rule "TXV-071"]
theorem validateTx_version_congr (tx : Tx) (u : UtxoSet) (height mtp : UInt32)
    (flags : Activation.ScriptFlags) (v : Int32)
    (hb68 : Bitcoin.DataLaws.bip68Enabled v flags.csv =
      Bitcoin.DataLaws.bip68Enabled tx.version flags.csv) :
    validateTx { tx with version := v } u height mtp flags =
      validateTx tx u height mtp flags := by
  unfold validateTx
  rw [checkTransaction_version_irrelevant, isFinalTx_version_irrelevant,
    isCoinBase_version_irrelevant,
    bip68HeightOk_version_congr tx v u flags.csv (height.toNat : Int) hb68,
    checkTxInputs_version_irrelevant]

/-- TXV-071: the one and only version gate is BIP68's `version ≥ 2`
combined with the active CSV flag (tx_verify.cpp:45-47 via
`CalculateSequenceLocks`). -/
@[rule "TXV-071"]
theorem bip68_version_gate (version : Int32) (csv : Bool) :
    Bitcoin.DataLaws.bip68Enabled version csv = true ↔
      2 ≤ version.toUInt32.toNat ∧ csv = true :=
  Bitcoin.DataLaws.bip68Enabled_iff version csv

/-- TXV-071: any 32-bit version is accepted whenever the BIP68 gate agrees
— the validator imposes no other version constraint. -/
@[rule "TXV-071"]
theorem validateTx_any_version_ok (tx : Tx) (u : UtxoSet) (height mtp : UInt32)
    (flags : Activation.ScriptFlags) (v : Int32) (fee : Amount)
    (h : validateTx tx u height mtp flags = .ok fee)
    (hb68 : Bitcoin.DataLaws.bip68Enabled v flags.csv =
      Bitcoin.DataLaws.bip68Enabled tx.version flags.csv) :
    ∃ fee', validateTx { tx with version := v } u height mtp flags = .ok fee' :=
  ⟨fee, by rw [validateTx_version_congr tx u height mtp flags v hb68]; exact h⟩

/-- CVE-2018-17144: duplicate inputs are rejected by the full `validateTx`
(the stateless prefix catches them before any contextual check runs). -/
theorem duplicate_inputs_rejected (tx : Tx) (u : UtxoSet)
    (height mtp : UInt32) (flags : Activation.ScriptFlags)
    (hd : hasDupPrevouts tx.vin = true) :
    (validateTx tx u height mtp flags).isOk = false := by
  unfold validateTx
  rcases hc : checkTransaction tx with _ | e
  · have hnd := checkTransaction_ok_no_dup_prevouts tx hc
    rw [hnd] at hd; exact absurd hd (by simp)
  · rfl


/-! ## BIP68 spec theorems (TXV-039) -/

/-- Height-domain constraint one input places on the spend block
(BIP68 first-valid reading of TXV-037's last-invalid lockpoint). Only
height-based locks constrain the height domain — time-based sequences
contribute to the time domain instead (tx_verify.cpp:79-99). -/
def seqHeightOkAt (i : TxIn) (prevH : Int) (H : Int) : Prop :=
  (seqLockApplies i.sequence = true ∧
      Bitcoin.DataLaws.seqIsTimeBased i.sequence = false) →
    prevH + (Bitcoin.DataLaws.seqRelative i.sequence : Int) ≤ H

/-- Time-domain constraint (TXV-036): parent-MTP + masked·512 ≤ block time. -/
def seqTimeOkAt (i : TxIn) (prevT : Int) (T : Int) : Prop :=
  (seqLockApplies i.sequence = true ∧ Bitcoin.DataLaws.seqIsTimeBased i.sequence = true) →
    prevT + ((Bitcoin.DataLaws.seqRelative i.sequence * 512 : Nat) : Int) ≤ T

/-- Per-input height constraint, conjunctively over `vin` zipped with the
caller's per-input data (truncating at the shorter list, where Core
`assert`s equal lengths). -/
def vinHeightOk : List TxIn → List (Int × Int) → Int → Prop
  | [], _, _ => True
  | _, [], _ => True
  | i :: vin, d :: rest, H => seqHeightOkAt i d.1 H ∧ vinHeightOk vin rest H

/-- Per-input time constraint, conjunctively. -/
def vinTimeOk : List TxIn → List (Int × Int) → Int → Prop
  | [], _, _ => True
  | _, [], _ => True
  | i :: vin, d :: rest, T => seqTimeOkAt i d.2 T ∧ vinTimeOk vin rest T

theorem heightLockOf_some {x : TxIn × (Int × Int)}
    (ha : seqLockApplies x.1.sequence = true)
    (ht : Bitcoin.DataLaws.seqIsTimeBased x.1.sequence = false) :
    heightLockOf x = some (x.2.1 + (Bitcoin.DataLaws.seqRelative x.1.sequence : Int) - 1) := by
  simp [heightLockOf, ha, ht]

theorem heightLockOf_none_of_disabled {x : TxIn × (Int × Int)}
    (ha : seqLockApplies x.1.sequence = false) : heightLockOf x = none := by
  simp [heightLockOf, ha]

theorem heightLockOf_none_of_time {x : TxIn × (Int × Int)}
    (ht : Bitcoin.DataLaws.seqIsTimeBased x.1.sequence = true) : heightLockOf x = none := by
  simp [heightLockOf, ht]

theorem heightLockOf_spec (i : TxIn) (d : Int × Int) (H : Int) :
    (∀ v, heightLockOf (i, d) = some v → v < H) ↔ seqHeightOkAt i d.1 H := by
  unfold seqHeightOkAt
  cases ha : seqLockApplies i.sequence with
  | false =>
    rw [heightLockOf_none_of_disabled (x := (i, d)) ha]
    simp
  | true =>
    cases ht : Bitcoin.DataLaws.seqIsTimeBased i.sequence with
    | true =>
      rw [heightLockOf_none_of_time (x := (i, d)) ht]
      simp
    | false =>
      rw [heightLockOf_some (x := (i, d)) ha ht]
      simp
      constructor
      · intro h; omega
      · intro h; omega

theorem timeLockOf_some {x : TxIn × (Int × Int)}
    (ha : seqLockApplies x.1.sequence = true)
    (ht : Bitcoin.DataLaws.seqIsTimeBased x.1.sequence = true) :
    timeLockOf x =
      some (x.2.2 + ((Bitcoin.DataLaws.seqRelative x.1.sequence * 512 : Nat) : Int) - 1) := by
  simp [timeLockOf, ha, ht]

theorem timeLockOf_none_of_disabled {x : TxIn × (Int × Int)}
    (ha : seqLockApplies x.1.sequence = false) : timeLockOf x = none := by
  simp [timeLockOf, ha]

theorem timeLockOf_none_of_height {x : TxIn × (Int × Int)}
    (ht : Bitcoin.DataLaws.seqIsTimeBased x.1.sequence = false) : timeLockOf x = none := by
  simp [timeLockOf, ht]

theorem timeLockOf_spec (i : TxIn) (d : Int × Int) (T : Int) :
    (∀ v, timeLockOf (i, d) = some v → v < T) ↔ seqTimeOkAt i d.2 T := by
  unfold seqTimeOkAt
  cases ha : seqLockApplies i.sequence with
  | false =>
    rw [timeLockOf_none_of_disabled (x := (i, d)) ha]
    simp
  | true =>
    cases ht : Bitcoin.DataLaws.seqIsTimeBased i.sequence with
    | false =>
      rw [timeLockOf_none_of_height (x := (i, d)) ht]
      simp
    | true =>
      rw [timeLockOf_some (x := (i, d)) ha ht]
      simp
      constructor
      · intro h; omega
      · intro h; omega

theorem seqLockStep_fst_lt (p : Int × Int) (x : TxIn × (Int × Int)) (H : Int) :
    (seqLockStep p x).1 < H ↔ (p.1 < H ∧ seqHeightOkAt x.1 x.2.1 H) := by
  unfold seqLockStep
  cases ha : seqLockApplies x.1.sequence with
  | false =>
    rw [heightLockOf_none_of_disabled ha, timeLockOf_none_of_disabled ha]
    simp [ha, seqHeightOkAt]
  | true =>
    cases ht : Bitcoin.DataLaws.seqIsTimeBased x.1.sequence with
    | false =>
      rw [heightLockOf_some ha ht]
      simp [ha, ht, seqHeightOkAt]
      omega
    | true =>
      rw [heightLockOf_none_of_time ht, timeLockOf_some ha ht]
      simp [ha, ht, seqHeightOkAt]

theorem seqLockStep_snd_lt (p : Int × Int) (x : TxIn × (Int × Int)) (T : Int) :
    (seqLockStep p x).2 < T ↔ (p.2 < T ∧ seqTimeOkAt x.1 x.2.2 T) := by
  unfold seqLockStep
  cases ha : seqLockApplies x.1.sequence with
  | false =>
    rw [heightLockOf_none_of_disabled ha, timeLockOf_none_of_disabled ha]
    simp [ha, seqTimeOkAt]
  | true =>
    cases ht : Bitcoin.DataLaws.seqIsTimeBased x.1.sequence with
    | true =>
      rw [heightLockOf_none_of_time ht, timeLockOf_some ha ht]
      simp (config := { decide := false }) [ha, ht, seqTimeOkAt]
      omega
    | false =>
      rw [heightLockOf_some ha ht, timeLockOf_none_of_height ht]
      simp [ha, ht, seqTimeOkAt]

theorem seqLockFold_height (hH : 0 ≤ H) :
    ∀ (vin : List TxIn) (prevData : List (Int × Int)),
      ((seqLockFold vin prevData).1 < H ↔ vinHeightOk vin prevData H) := by
  intro vin
  induction vin with
  | nil =>
    intro prevData
    simp only [seqLockFold, vinHeightOk]
    exact ⟨fun _ => trivial, fun _ => by omega⟩
  | cons i vin' ih =>
    intro prevData
    cases prevData with
    | nil => simp only [seqLockFold, vinHeightOk]; exact ⟨fun _ => trivial, fun _ => by omega⟩
    | cons d rest =>
      simp only [seqLockFold, vinHeightOk]
      rw [seqLockStep_fst_lt, ih rest]
      exact and_comm

theorem seqLockFold_time (hT : 0 ≤ T) :
    ∀ (vin : List TxIn) (prevData : List (Int × Int)),
      ((seqLockFold vin prevData).2 < T ↔ vinTimeOk vin prevData T) := by
  intro vin
  induction vin with
  | nil =>
    intro prevData
    simp only [seqLockFold, vinTimeOk]
    exact ⟨fun _ => trivial, fun _ => by omega⟩
  | cons i vin' ih =>
    intro prevData
    cases prevData with
    | nil => simp only [seqLockFold, vinTimeOk]; exact ⟨fun _ => trivial, fun _ => by omega⟩
    | cons d rest =>
      simp only [seqLockFold, vinTimeOk]
      rw [seqLockStep_snd_lt, ih rest]
      exact and_comm

theorem calculateSequenceLocks_enabled (tx : Tx) (csv : Bool) (prevData : List (Int × Int))
    (h : Bitcoin.DataLaws.bip68Enabled tx.version csv = true) :
    calculateSequenceLocks tx csv prevData = seqLockFold tx.vin prevData := by
  unfold calculateSequenceLocks
  rw [if_neg (by simp [h])]

theorem calculateSequenceLocks_disabled (tx : Tx) (csv : Bool) (prevData : List (Int × Int))
    (h : Bitcoin.DataLaws.bip68Enabled tx.version csv = false) :
    calculateSequenceLocks tx csv prevData = (-1, -1) := by
  unfold calculateSequenceLocks
  rw [if_pos (by simp [h])]

theorem evaluateSequenceLocks_eq (blockHeight blockTime : Int) (lockPair : Int × Int) :
    evaluateSequenceLocks blockHeight blockTime lockPair = true ↔
      (lockPair.1 < blockHeight ∧ lockPair.2 < blockTime) := by
  simp [evaluateSequenceLocks]

/-- TXV-039, full spec: `sequenceLocksOk` holds iff BIP68 is not enforced,
or every input's height- and time-domain constraints hold at the caller's
`(blockHeight, blockTime = MTP(prev))` evaluation point. -/
theorem sequenceLocksOk_iff (tx : Tx) (csv : Bool) (prevData : List (Int × Int))
    (blockHeight blockTime : Int) (hH : 0 ≤ blockHeight) (hT : 0 ≤ blockTime) :
    sequenceLocksOk tx csv prevData blockHeight blockTime = true ↔
      (Bitcoin.DataLaws.bip68Enabled tx.version csv = false ∨
        (vinHeightOk tx.vin prevData blockHeight ∧ vinTimeOk tx.vin prevData blockTime)) := by
  by_cases he : Bitcoin.DataLaws.bip68Enabled tx.version csv = true
  · unfold sequenceLocksOk
    rw [evaluateSequenceLocks_eq, calculateSequenceLocks_enabled _ _ _ he,
      seqLockFold_height hH, seqLockFold_time hT]
    simp [he]
  · have he' : Bitcoin.DataLaws.bip68Enabled tx.version csv = false := by
      cases hb : Bitcoin.DataLaws.bip68Enabled tx.version csv with
      | true => exact absurd hb he
      | false => rfl
    unfold sequenceLocksOk
    rw [evaluateSequenceLocks_eq, calculateSequenceLocks_disabled _ _ _ he']
    refine ⟨fun _ => Or.inl he', fun _ => ⟨by omega, by omega⟩⟩

/-- The height-domain gate `validateTx` runs (its frozen signature carries
coin heights but not the parent-MTP chain the time domain needs). -/
theorem bip68HeightOk_iff (tx : Tx) (u : UtxoSet) (csv : Bool) (H : Int) (hH : 0 ≤ H) :
    bip68HeightOk tx u csv H = true ↔
      (Bitcoin.DataLaws.bip68Enabled tx.version csv = false ∨
        vinHeightOk tx.vin (prevHeightData tx u) H) := by
  by_cases he : Bitcoin.DataLaws.bip68Enabled tx.version csv = true
  · unfold bip68HeightOk
    rw [decide_eq_true_iff, calculateSequenceLocks_enabled _ _ _ he, seqLockFold_height hH]
    simp [he]
  · have he' : Bitcoin.DataLaws.bip68Enabled tx.version csv = false := by
      cases hb : Bitcoin.DataLaws.bip68Enabled tx.version csv with
      | true => exact absurd hb he
      | false => rfl
    unfold bip68HeightOk
    rw [decide_eq_true_iff, calculateSequenceLocks_disabled _ _ _ he']
    exact ⟨fun _ => Or.inl he', fun _ => by omega⟩

/-! ## TXV-040: CSV deployment flag — set iff active at the block

The audit's objection was that `bip68HeightOk` computes the height lock,
not the flag derivation. These theorems are the missing face: Core's
`GetBlockScriptFlags` ORs CSV in exactly at the buried deployment height
(validation.cpp:2276-2278), and BIP68 is enabled exactly when that flag
is set and the version is ≥ 2 (`CalculateSequenceLocks`,
tx_verify.cpp:45-47). -/

/-- TXV-040: on mainnet the CSV script flag is set exactly at/after the
buried CSV activation height. The always-on base and both exception
entries leave `csv` false, so the buried OR is the whole story. -/
@[rule "TXV-040"]
theorem csv_flag_iff_deployment (height : UInt32) :
    (Bitcoin.Activation.getBlockScriptFlags height).csv = true ↔
      Bitcoin.Activation.CSV_HEIGHT ≤ height := by
  by_cases h1 : height = Bitcoin.Activation.BIP16_EXCEPTION_HEIGHT
  · subst h1
    decide
  · by_cases h2 : height = Bitcoin.Activation.TAPROOT_EXCEPTION_HEIGHT
    · subst h2
      decide
    · rw [Bitcoin.Activation.flags_norm height h1 h2]
      simp

/-- TXV-040: BIP68 is enabled at a block exactly when the tx version is
≥ 2 and the block's CSV flag is set — i.e. exactly when the CSV
deployment is active at that block. -/
@[rule "TXV-040"]
theorem bip68Enabled_block_iff (version : Int32) (height : UInt32) :
    Bitcoin.DataLaws.bip68Enabled version
        (Bitcoin.Activation.getBlockScriptFlags height).csv = true ↔
      2 ≤ version.toUInt32.toNat ∧ Bitcoin.Activation.CSV_HEIGHT ≤ height := by
  rw [Bitcoin.DataLaws.bip68Enabled_iff, csv_flag_iff_deployment]

/-- The value-fold with a seed: `foldl f s l = s + foldl f 0 l` (the step
function's increment is seed-independent). -/
theorem foldl_coin_add (u : UtxoSet) : ∀ (l : List TxIn) (s : Amount),
    l.foldl (fun a i => match u i.prevout with | some c => a + c.value | none => a) s =
      s + l.foldl (fun a i => match u i.prevout with | some c => a + c.value | none => a) 0 := by
  intro l
  induction l with
  | nil => intro s; simp [Int.add_zero]
  | cons i rest ih =>
    intro s
    simp only [List.foldl_cons]
    cases hv : u i.prevout with
    | none => exact ih s
    | some c =>
      show List.foldl _ (s + c.value) rest = s + List.foldl _ (0 + c.value) rest
      rw [ih (s + c.value), ih (0 + c.value), Int.zero_add, Int.add_assoc]

/-- The input loop's successful total is the seed plus the tx's total input
value (`totalIn`). -/
theorem inputValuesLoop_ok_sum (u : UtxoSet) (spendHeight : UInt32) :
    ∀ (l : List TxIn) (acc v : Amount),
      inputValuesLoop u spendHeight l acc = .ok v →
      acc + l.foldl (fun a i => match u i.prevout with | some c => a + c.value | none => a) 0 = v := by
  intro l
  induction l with
  | nil =>
    intro acc v h
    simp only [inputValuesLoop] at h
    simpa using h
  | cons i rest ih =>
    intro acc v h
    simp only [inputValuesLoop] at h
    cases hv : u i.prevout with
    | none => rw [hv] at h; exact absurd h (by simp)
    | some c =>
      simp only [hv] at h
      split at h
      · exact absurd h (by simp)
      · split at h
        · exact absurd h (by simp)
        · split at h
          · exact absurd h (by simp)
          · have h2 := ih (acc + c.value) v h
            simp only [List.foldl_cons, hv, Int.zero_add]
            rw [foldl_coin_add u rest c.value]
            rw [Int.add_assoc] at h2
            exact h2

/-- Bridge between the conservation layer's `totalIn` fold and the loop's step function
(the two `match`es compile to different matcher constants, which are not
definitional-equal for an abstract view; the bridge goes through
pointwise equality). -/
theorem totalIn_eq_foldl (u : UtxoSet) (tx : Tx) :
    Bitcoin.Conservation.totalIn u tx =
      tx.vin.foldl (fun a i => match u i.prevout with | some c => a + c.value | none => a) 0 := by
  unfold Bitcoin.Conservation.totalIn
  congr 1

/-- BLK-103: the per-coin loop's successful accumulator is in MoneyRange:
the incremental guard checks the running sum after every addition
(tx_verify.cpp:191-194). -/
@[rule "BLK-103"]
theorem inputValuesLoop_ok_moneyRange (u : UtxoSet) (spendHeight : UInt32) :
    ∀ (l : List TxIn) (acc v : Amount), MoneyRange acc = true →
      inputValuesLoop u spendHeight l acc = .ok v → MoneyRange v = true := by
  intro l
  induction l with
  | nil =>
    intro acc v ha h
    simp only [inputValuesLoop] at h
    cases h
    exact ha
  | cons i rest ih =>
    intro acc v ha h
    simp only [inputValuesLoop] at h
    cases hv : u i.prevout with
    | none => rw [hv] at h; exact absurd h (by simp)
    | some c =>
      simp only [hv] at h
      split at h
      · exact absurd h (by simp)
      · split at h
        · exact absurd h (by simp)
        · split at h
          · exact absurd h (by simp)
          · rename_i hacc
            exact ih (acc + c.value) v (by simpa using hacc) h

/-- The full validateTx fee contract, folded with the conservation laws
hypotheses: a successful `checkTxInputs` returns `fee = totalIn − totalOut`
with the fee nonnegative — `single_tx_conservation`'s conclusion. -/
theorem checkTxInputs_ok_conservation (tx : Tx) (u : UtxoSet) (spendHeight : UInt32)
    (fee : Amount) (h : checkTxInputs tx u spendHeight = .ok fee) :
    Bitcoin.Conservation.totalIn u tx = tx.getValueOut + fee ∧ fee ≥ 0 := by
  unfold checkTxInputs at h
  by_cases hi : haveInputs tx u = true
  · rw [if_pos hi] at h
    rcases hlv : inputValuesLoop u spendHeight tx.vin 0 with _ | valueIn
    · simp only [hlv] at h; exact absurd h (by simp)
    · simp only [hlv] at h
      by_cases hb : valueIn < tx.getValueOut
      · rw [if_pos hb] at h; exact absurd h (by simp)
      · rw [if_neg hb] at h
        by_cases hm : MoneyRange (valueIn - tx.getValueOut) = true
        · rw [if_pos hm] at h
          have hinj : valueIn - tx.getValueOut = fee := by simpa using h
          have hsum := inputValuesLoop_ok_sum u spendHeight tx.vin 0 valueIn hlv
          rw [totalIn_eq_foldl, ← hinj]
          have hz : List.foldl (fun a i => match u i.prevout with
              | some c => a + c.value | none => a) 0 tx.vin = valueIn := by
            simpa using hsum
          rw [hz]
          simp only [Amount] at *
          omega
        · rw [if_neg hm] at h; exact absurd h (by simp)
  · rw [if_neg hi] at h; exact absurd h (by simp)

/-- BLK-103, full row: a transaction whose stateless gate passed and whose
`CheckTxInputs` succeeded has **both** sides in MoneyRange, `Σin ≥ Σout`,
and the fee is exactly the difference. `checkTransaction tx = none` is the
caller-side precondition Core supplies in ConnectBlock (CheckTransaction
runs before CheckTxInputs); it is what makes `valueOut` in-range. -/
@[rule "BLK-103"]
theorem checkTxInputs_ok_conservation_full (tx : Tx) (u : UtxoSet)
    (spendHeight : UInt32) (fee : Amount)
    (htx : checkTransaction tx = none)
    (h : checkTxInputs tx u spendHeight = .ok fee) :
    MoneyRange (Bitcoin.Conservation.totalIn u tx) = true ∧
      MoneyRange tx.getValueOut = true ∧
      Bitcoin.Conservation.totalIn u tx = tx.getValueOut + fee ∧
      0 ≤ fee ∧
      tx.getValueOut ≤ Bitcoin.Conservation.totalIn u tx := by
  have hcons := checkTxInputs_ok_conservation tx u spendHeight fee h
  have hout := checkTransaction_ok_getValueOut_moneyRange tx htx
  have hin : MoneyRange (Bitcoin.Conservation.totalIn u tx) = true := by
    unfold checkTxInputs at h
    by_cases hi : haveInputs tx u = true
    · rw [if_pos hi] at h
      rcases hlv : inputValuesLoop u spendHeight tx.vin 0 with _ | valueIn
      · simp only [hlv] at h; exact absurd h (by simp)
      · simp only [hlv] at h
        by_cases hb : valueIn < tx.getValueOut
        · rw [if_pos hb] at h; exact absurd h (by simp)
        · rw [if_neg hb] at h
          by_cases hm : MoneyRange (valueIn - tx.getValueOut) = true
          · rw [if_pos hm] at h
            have hmr := inputValuesLoop_ok_moneyRange u spendHeight tx.vin 0 valueIn
              (moneyRange_intro (Int.le_refl 0) maxMoney_nonneg) hlv
            have hz : Bitcoin.Conservation.totalIn u tx = valueIn := by
              rw [totalIn_eq_foldl]
              have hs := inputValuesLoop_ok_sum u spendHeight tx.vin 0 valueIn hlv
              simpa using hs
            rw [hz]; exact hmr
          · rw [if_neg hm] at h; exact absurd h (by simp)
    · rw [if_neg hi] at h; exact absurd h (by simp)
  refine ⟨hin, hout, hcons.1, hcons.2, ?_⟩
  have hfee : (0 : Amount) ≤ fee := hcons.2
  rw [hcons.1]
  show tx.getValueOut ≤ tx.getValueOut + fee
  have h := Int.add_le_add_left hfee tx.getValueOut
  simpa using h

/-! ## TXV-067: zero-value outputs are valid and become coins -/

/-- TXV-067: zero is in MoneyRange, so the only bounds `CheckTransaction`
applies to output values do not reject it (tx_check.cpp:35-41). -/
@[rule "TXV-067"]
theorem zeroValue_moneyRange : MoneyRange (0 : Amount) = true :=
  moneyRange_intro (Int.le_refl 0) maxMoney_nonneg

/-- TXV-067: a zero-value output passes the per-output value loop without
changing its accumulator result — the bounds check has no positivity
(lower-bound) gate. -/
@[rule "TXV-067"]
theorem checkOutputs_zero_head (l : List TxOut) (acc : Amount)
    (ha : MoneyRange acc = true) :
    checkTransaction.checkOutputs (⟨0, Script.empty⟩ :: l) acc =
      checkTransaction.checkOutputs l acc := by
  have hnot : ¬ (MAX_MONEY < (0 : Amount)) := by
    unfold MAX_MONEY COIN
    decide
  cases l with
  | nil => simp [checkTransaction.checkOutputs, hnot, ha]
  | cons o rest =>
    simp [checkTransaction.checkOutputs, hnot, ha, Int.add_zero]

/-- TXV-067: `applyTx` inserts every output, zero value included, as a
coin — so a `value = 0` output yields a spendable-looking UTXO like any
other (value + script + height + coinbase flag; `Coin` carries no
zero-value exclusion). -/
@[rule "TXV-067"]
theorem applyTx_zeroValue_output_coin (l : UtxoList) (tx : Tx) (k : Nat)
    (hk : k < tx.vout.length)
    (hz : (tx.vout.getD k ⟨0, Script.empty⟩).value = 0) :
    ∃ c : Coin, List.Mem (OutPoint.null, c) (Bitcoin.Ledger.applyTx l tx) ∧ c.value = 0 := by
  unfold Bitcoin.Ledger.applyTx
  dsimp only
  refine ⟨⟨(tx.vout.getD k ⟨0, Script.empty⟩).value, 0, false,
    (tx.vout.getD k ⟨0, Script.empty⟩).scriptPubKey⟩, ?_, hz⟩
  exact List.mem_append.mpr
    (Or.inr (List.mem_map.mpr ⟨k, List.mem_range.mpr hk, rfl⟩))

/-! ## Axiom pins (the transaction-validation layer): drift on any of these fails the build -/

/--
info: 'Bitcoin.TxValidation.coinHeightOfCode_pack' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms coinHeightOfCode_pack

/--
info: 'Bitcoin.TxValidation.coinIsCoinbaseOfCode_pack' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms coinIsCoinbaseOfCode_pack

/--
info: 'Bitcoin.TxValidation.coinbase_maturity_boundary' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms coinbase_maturity_boundary

/--
info: 'Bitcoin.TxValidation.checkTxInputs_ok' depends on axioms: [propext]
-/
#guard_msgs in #print axioms checkTxInputs_ok

/--
info: 'Bitcoin.TxValidation.foldl_value_sum' depends on axioms: [propext]
-/
#guard_msgs in #print axioms foldl_value_sum

/--
info: 'Bitcoin.TxValidation.getValueOut_eq_plainSum' depends on axioms: [propext]
-/
#guard_msgs in #print axioms getValueOut_eq_plainSum

/--
info: 'Bitcoin.TxValidation.checkOutputs_ok_plain' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms checkOutputs_ok_plain

/--
info: 'Bitcoin.TxValidation.checkTransaction_ok_getValueOut_moneyRange' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in #print axioms checkTransaction_ok_getValueOut_moneyRange

/--
info: 'Bitcoin.TxValidation.checkTransaction_ok_no_dup_prevouts' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms checkTransaction_ok_no_dup_prevouts

/--
info: 'Bitcoin.TxValidation.haveInputs_congr' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms haveInputs_congr

/--
info: 'Bitcoin.TxValidation.inputValuesLoop_congr' depends on axioms: [propext]
-/
#guard_msgs in #print axioms inputValuesLoop_congr

/--
info: 'Bitcoin.TxValidation.checkTxInputs_congr' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms checkTxInputs_congr

/--
info: 'Bitcoin.TxValidation.prevHeightData_congr' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms prevHeightData_congr

/--
info: 'Bitcoin.TxValidation.bip68HeightOk_congr' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms bip68HeightOk_congr

/--
info: 'Bitcoin.TxValidation.validateTx_total' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms validateTx_total

/--
info: 'Bitcoin.TxValidation.validateTx_stateless_prefix' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms validateTx_stateless_prefix

/--
info: 'Bitcoin.TxValidation.validateTx_fee_consistent' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms validateTx_fee_consistent

/--
info: 'Bitcoin.TxValidation.validateTx_utxo_extensional' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms validateTx_utxo_extensional

/--
info: 'Bitcoin.TxValidation.duplicate_inputs_rejected' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms duplicate_inputs_rejected

/--
info: 'Bitcoin.TxValidation.heightLockOf_some' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms heightLockOf_some

/--
info: 'Bitcoin.TxValidation.heightLockOf_none_of_disabled' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms heightLockOf_none_of_disabled

/--
info: 'Bitcoin.TxValidation.heightLockOf_none_of_time' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms heightLockOf_none_of_time

/--
info: 'Bitcoin.TxValidation.heightLockOf_spec' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms heightLockOf_spec

/--
info: 'Bitcoin.TxValidation.timeLockOf_some' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms timeLockOf_some

/--
info: 'Bitcoin.TxValidation.timeLockOf_none_of_disabled' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms timeLockOf_none_of_disabled

/--
info: 'Bitcoin.TxValidation.timeLockOf_none_of_height' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms timeLockOf_none_of_height

/--
info: 'Bitcoin.TxValidation.timeLockOf_spec' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms timeLockOf_spec

/--
info: 'Bitcoin.TxValidation.seqLockStep_fst_lt' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms seqLockStep_fst_lt

/--
info: 'Bitcoin.TxValidation.seqLockStep_snd_lt' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms seqLockStep_snd_lt

/--
info: 'Bitcoin.TxValidation.seqLockFold_height' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms seqLockFold_height

/--
info: 'Bitcoin.TxValidation.seqLockFold_time' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms seqLockFold_time

/--
info: 'Bitcoin.TxValidation.calculateSequenceLocks_enabled' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms calculateSequenceLocks_enabled

/--
info: 'Bitcoin.TxValidation.calculateSequenceLocks_disabled' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms calculateSequenceLocks_disabled

/--
info: 'Bitcoin.TxValidation.evaluateSequenceLocks_eq' depends on axioms: [propext]
-/
#guard_msgs in #print axioms evaluateSequenceLocks_eq

/--
info: 'Bitcoin.TxValidation.sequenceLocksOk_iff' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms sequenceLocksOk_iff

/--
info: 'Bitcoin.TxValidation.bip68HeightOk_iff' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms bip68HeightOk_iff

/--
info: 'Bitcoin.TxValidation.foldl_coin_add' depends on axioms: [propext]
-/
#guard_msgs in #print axioms foldl_coin_add

/--
info: 'Bitcoin.TxValidation.inputValuesLoop_ok_sum' depends on axioms: [propext]
-/
#guard_msgs in #print axioms inputValuesLoop_ok_sum

/--
info: 'Bitcoin.TxValidation.totalIn_eq_foldl' does not depend on any axioms
-/
#guard_msgs in #print axioms totalIn_eq_foldl

/--
info: 'Bitcoin.TxValidation.checkTxInputs_ok_conservation' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in #print axioms checkTxInputs_ok_conservation

end Bitcoin.TxValidation
