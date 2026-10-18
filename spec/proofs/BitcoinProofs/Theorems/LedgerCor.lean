import Bitcoin.Consensus.TxCheck
import Bitcoin.Data.Basic
import Bitcoin.DataLaws.Laws
import Bitcoin.DataLaws.Interface
import Bitcoin.Ledger.Utxo
import BitcoinProofs.Conservation.Thms

/-!
# BitcoinProofs.Theorems.LedgerCor

correctness theorems over the frozen consensus-check layer
(`Bitcoin.Consensus.TxCheck`, C1) and conservation machinery.

**Post-repair (LEDGER, F-G3-01 then F-TS04-001):** `checkTransaction`'s
oversize branch has oscillated between the stripped-size test and the
full BIP141 weight. It is now (F-TS04-001, tx_check.cpp:27-29) Core's
stripped-size gate `txStrippedWeightL tx > MAX_BLOCK_WEIGHT`, i.e.
`4 · serTxSize tx > MAX_BLOCK_WEIGHT`, reusing the same numeric
predicate as the originals. Repair: every rewrite that peels the
oversize branch targets `txStrippedWeightL`, and
`checkTransaction_none_basic`'s no-witness × 4 bound is exactly the
negation of that gate (no arithmetic bridge needed). Statements are
unchanged (statement fidelity). `Bitcoin.DataLaws.Interface` remains
imported for the size laws used by sibling modules. Axiom pins
unchanged.

Portfolio rows carried here:

* **THM-006** — `totalOut_moneyRange_of_checkTransaction` /
  `totalOut_le_MAX_of_checkTransaction`: a transaction that passes
  `CheckTransaction` has every output value and the output *total* in
  `MoneyRange` (tx_check.cpp:36-41; CVE-2010-5139 defense).
* **THM-012a** — `checkTransaction_none_basic`: passing the stateless
  check implies non-empty vin/vout and the block-weight bound
  (tx_check.cpp:24-33).
* **TXV-007** — `checkTransaction_none_noDup`: passing implies no
  duplicate prevouts (CVE-2018-17144 duplicate-input defense,
  tx_check.cpp:56).
* **THM-012b** — `checkTransaction_none_noNullPrevout`: a passing
  non-coinbase transaction has no null prevouts (tx_check.cpp:66-67).
* **THM-037 (arithmetic tier)** — `block_conservation_arith`: per-tx
  conservation inequalities compose additively over a block's tx
  sequence. NOTE: the full per-block coinbase-surplus statement needs
  `applyBlock` fold (not landed); this is the arithmetic core,
  deduplicated against by construction (can reuse these fold
  lemmas directly).
* `supplyAt_checkpoints` — named, axiom-pinned versions of the supply
  boundary values Test decides anonymously (dedup: same `supplyAt`
  model, no new definitions).

No mathlib import; proofs use induction/rewriting, `decide` only on
closed numerals.
-/

namespace BitcoinProofs.Theorems.LedgerCor

open Bitcoin.Consensus Bitcoin.Data Bitcoin.DataLaws Bitcoin.Numeric Bitcoin.Ledger
open Bitcoin.Conservation (totalOut)
open BitcoinProofs.Conservation

/-! ## THM-006: the checkOutputs accumulation invariant -/

/-- The accumulation invariant of the output loop (tx_check.cpp:36-41):
if the loop starting from a MoneyRange accumulator returns `none`, the
final accumulator (the output total) is in MoneyRange. Proof: induction
on the output list, generalizing the accumulator. -/
theorem checkOutputs_none_total_moneyRange : ∀ (outs : List TxOut) (acc : Amount),
    MoneyRange acc = true →
    checkTransaction.checkOutputs outs acc = none →
    MoneyRange (outs.foldl (fun a o => a + o.value) acc) = true := by
  intro outs
  induction outs with
  | nil => intro acc hacc _; exact hacc
  | cons o rest ih =>
    intro acc hacc h
    rw [List.foldl_cons]
    simp only [checkTransaction.checkOutputs] at h
    by_cases hv1 : o.value < 0
    · rw [ite_eq_left hv1] at h; simp at h
    · rw [ite_eq_right hv1] at h
      by_cases hv2 : o.value > MAX_MONEY
      · rw [ite_eq_left hv2] at h; simp at h
      · rw [ite_eq_right hv2] at h
        by_cases hm : MoneyRange (acc + o.value) = true
        · rw [ite_eq_right (fun hnn : ¬(MoneyRange (acc + o.value) = true) => hnn hm)] at h
          exact ih (acc + o.value) hm h
        · rw [ite_eq_left hm] at h; simp at h

/-- Every individual output value is in MoneyRange when the loop passes
(tx_check.cpp:37-38: the per-output `bad-txns-vout-negative` /
`bad-txns-vout-toolarge` guards). -/
theorem checkOutputs_none_moneyRange : ∀ (outs : List TxOut) (acc : Amount),
    checkTransaction.checkOutputs outs acc = none →
    ∀ o ∈ outs, MoneyRange o.value = true := by
  intro outs
  induction outs with
  | nil => intro _ _ o ho; exact absurd ho (by simp)
  | cons o rest ih =>
    intro acc h o'' ho
    simp only [checkTransaction.checkOutputs] at h
    by_cases heq : o'' = o
    · subst heq
      by_cases hv1 : o''.value < 0
      · rw [ite_eq_left hv1] at h; simp at h
      · rw [ite_eq_right hv1] at h
        by_cases hv2 : o''.value > MAX_MONEY
        · rw [ite_eq_left hv2] at h; simp at h
        · rw [ite_eq_right hv2] at h
          by_cases hm : MoneyRange (acc + o''.value) = true
          · rw [ite_eq_right (fun hnn : ¬(MoneyRange (acc + o''.value) = true) => hnn hm)] at h
            have h1 : (0 : Int) ≤ (o''.value : Int) := Int.not_lt.mp hv1
            have h2 : (o''.value : Int) ≤ MAX_MONEY := Int.not_lt.mp hv2
            exact (moneyRange_iff o''.value).mpr ⟨h1, h2⟩
          · rw [ite_eq_left hm] at h; simp at h
    · by_cases hv1 : o.value < 0
      · rw [ite_eq_left hv1] at h; simp at h
      · rw [ite_eq_right hv1] at h
        by_cases hv2 : o.value > MAX_MONEY
        · rw [ite_eq_left hv2] at h; simp at h
        · rw [ite_eq_right hv2] at h
          by_cases hm : MoneyRange (acc + o.value) = true
          · rw [ite_eq_right (fun hnn : ¬(MoneyRange (acc + o.value) = true) => hnn hm)] at h
            exact ih (acc + o.value) h o''
              (by rw [List.mem_cons] at ho; exact ho.resolve_left heq)
          · rw [ite_eq_left hm] at h; simp at h

/-- The checkOutputs bridge through `CheckTransaction`'s if-chain:
passing the transaction check means the output loop returned `none`. -/
private theorem checkOutputs_none_of_checkTransaction (tx : Tx)
    (h : checkTransaction tx = none) :
    checkTransaction.checkOutputs tx.vout 0 = none := by
  rw [checkTransaction] at h
  by_cases hv : tx.vin.isEmpty = true
  · rw [ite_eq_left hv] at h; simp at h
  · rw [ite_eq_right hv] at h
    by_cases hvo : tx.vout.isEmpty = true
    · rw [ite_eq_left hvo] at h; simp at h
    · rw [ite_eq_right hvo] at h
      by_cases hs : Bitcoin.Consensus.txStrippedWeightL tx > Bitcoin.Consensus.MAX_BLOCK_WEIGHT
      · rw [ite_eq_left hs] at h; simp at h
      · rw [ite_eq_right hs] at h
        split at h
        · simp at h
        · rename_i hco
          cases hco' : checkTransaction.checkOutputs tx.vout 0 with
          | none => rfl
          | some e => exact absurd hco' (hco e)

/-- **THM-006** — a transaction that passes `CheckTransaction` has its
total output value in `MoneyRange` (tx_check.cpp:36-41). -/
theorem totalOut_moneyRange_of_checkTransaction (tx : Tx)
    (h : checkTransaction tx = none) :
    MoneyRange (totalOut tx) = true := by
  have hbridge := checkOutputs_none_of_checkTransaction tx h
  rw [totalOut_eq_fold]
  exact checkOutputs_none_total_moneyRange tx.vout 0 (by decide) hbridge

/-- **THM-006 (corollary)** — the output total is bounded by `MAX_MONEY`
(the CVE-2010-5139 overflow bound, tx_check.cpp:39-41). -/
theorem totalOut_le_MAX_of_checkTransaction (tx : Tx)
    (h : checkTransaction tx = none) : totalOut tx ≤ MAX_MONEY :=
  (moneyRange_iff (totalOut tx)).mp (totalOut_moneyRange_of_checkTransaction tx h) |>.2

/-! ## THM-012a: basic structural facts from `CheckTransaction = none` -/

/-- **THM-012a** — a transaction passing the stateless check has
non-empty vin and vout, and its (no-witness × 4) size is within the
block-weight bound (tx_check.cpp:24-33). F-TS04-001 repair: the
oversize gate is Core's stripped-size test `txStrippedWeightL tx =
4 · serTxSize tx > MAX_BLOCK_WEIGHT`; the stated no-witness × 4
bound is precisely that gate's negation. Statement unchanged
(statement fidelity). -/
theorem checkTransaction_none_basic (tx : Tx) (h : checkTransaction tx = none) :
    tx.vin ≠ [] ∧ tx.vout ≠ []
    ∧ serTxSize tx * Bitcoin.Consensus.WITNESS_SCALE_FACTOR ≤ Bitcoin.Consensus.MAX_BLOCK_WEIGHT := by
  refine ⟨?_, ?_, ?_⟩
  · intro hv
    rw [checkTransaction, List.isEmpty_iff.mpr hv] at h
    simp at h
  · intro hvo
    rw [checkTransaction, List.isEmpty_iff.mpr hvo] at h
    split at h
    · simp at h
    · simp at h
  · rw [checkTransaction] at h
    by_cases hv : tx.vin.isEmpty = true
    · rw [ite_eq_left hv] at h; simp at h
    · rw [ite_eq_right hv] at h
      by_cases hvo : tx.vout.isEmpty = true
      · rw [ite_eq_left hvo] at h; simp at h
      · rw [ite_eq_right hvo] at h
        by_cases hs : Bitcoin.Consensus.txStrippedWeightL tx > Bitcoin.Consensus.MAX_BLOCK_WEIGHT
        · rw [ite_eq_left hs] at h; simp at h
        · -- F-TS04-001 repair: the stateless oversize gate is Core's
          -- stripped-size test `4 · serTxSize tx > MAX_BLOCK_WEIGHT`
          -- (`txStrippedWeightL`, tx_check.cpp:27-29). The THM-012a
          -- statement is exactly that bound, so the gate's negation
          -- supplies it directly (no weakening, no arithmetic detour).
          have hsle : Bitcoin.Consensus.txStrippedWeightL tx
              ≤ Bitcoin.Consensus.MAX_BLOCK_WEIGHT := Nat.le_of_not_gt hs
          simpa [Bitcoin.Consensus.txStrippedWeightL,
            Bitcoin.Consensus.WITNESS_SCALE_FACTOR] using hsle

/-! ## TXV-007: no duplicate inputs -/

/-- **TXV-007** — a transaction passing the stateless check has no
duplicate prevouts (CVE-2018-17144 duplicate-input defense,
tx_check.cpp:56; the O(n²) pairwise scan Core comments on). -/
theorem checkTransaction_none_noDup (tx : Tx) (h : checkTransaction tx = none) :
    hasDupPrevouts tx.vin = false := by
  rw [checkTransaction] at h
  by_cases hv : tx.vin.isEmpty = true
  · rw [ite_eq_left hv] at h; simp at h
  · rw [ite_eq_right hv] at h
    by_cases hvo : tx.vout.isEmpty = true
    · rw [ite_eq_left hvo] at h; simp at h
    · rw [ite_eq_right hvo] at h
      by_cases hs : Bitcoin.Consensus.txStrippedWeightL tx > Bitcoin.Consensus.MAX_BLOCK_WEIGHT
      · rw [ite_eq_left hs] at h; simp at h
      · rw [ite_eq_right hs] at h
        split at h
        · simp at h
        · by_cases hd : hasDupPrevouts tx.vin = true
          · rw [ite_eq_left hd] at h; simp at h
          · rw [ite_eq_right hd] at h
            simp only [Bool.not_eq_true] at hd
            exact hd

/-! ## THM-012b: no null prevouts off coinbase -/

/-- **THM-012b** — a passing non-coinbase transaction has no null
prevouts (tx_check.cpp:66-67: `bad-txns-prevout-null`). -/
theorem checkTransaction_none_noNullPrevout (tx : Tx)
    (h : checkTransaction tx = none) (hcb : tx.isCoinBase = false) :
    ∀ i ∈ tx.vin, i.prevout.isNull = false := by
  rw [checkTransaction] at h
  by_cases hv : tx.vin.isEmpty = true
  · rw [ite_eq_left hv] at h; simp at h
  · rw [ite_eq_right hv] at h
    by_cases hvo : tx.vout.isEmpty = true
    · rw [ite_eq_left hvo] at h; simp at h
    · rw [ite_eq_right hvo] at h
      by_cases hs : Bitcoin.Consensus.txStrippedWeightL tx > Bitcoin.Consensus.MAX_BLOCK_WEIGHT
      · rw [ite_eq_left hs] at h; simp at h
      · rw [ite_eq_right hs] at h
        split at h
        · simp at h
        · by_cases hd : hasDupPrevouts tx.vin = true
          · rw [ite_eq_left hd] at h; simp at h
          · rw [ite_eq_right hd] at h
            have hcb2 : ¬ (tx.isCoinBase = true) := by simp [hcb]
            rw [ite_eq_right hcb2] at h
            by_cases hany : tx.vin.any (fun i => i.prevout.isNull) = true
            · rw [ite_eq_left hany] at h; simp at h
            · rw [ite_eq_right hany] at h
              intro i hi
              by_cases hz : i.prevout.isNull = true
              · exact absurd (List.any_eq_true.mpr ⟨i, hi, hz⟩) hany
              · simp only [Bool.not_eq_true] at hz
                exact hz

/-! ## THM-037 (arithmetic tier): block-level composition -/

/-- Per-tx output total as a fold (mirrors core `totalOut`'s definitional
shape, kept local so the block fold does not depend on internals). -/
def txTotalOut (tx : Tx) : Amount := tx.vout.foldl (fun a o => a + o.value) 0

/-- Block output total: left fold of per-tx totals. -/
def blockOut (txs : List Tx) : Amount :=
  txs.foldl (fun acc t => acc + txTotalOut t) 0

/-- Block input total: left fold of per-tx `totalInVin` over each
tx's inputs against the UTXO view. -/
def blockIn (u : UtxoSet) (txs : List Tx) : Amount :=
  txs.foldl (fun acc t => acc + totalInVin u t.vin) 0

private theorem intZeroAdd (a : Int) : a = 0 + a := by omega

/-- Translation law for the block output fold (fold-shift pattern). -/
private theorem blockOutFrom_eq : ∀ (ts : List Tx) (x : Amount),
    ts.foldl (fun acc t => acc + txTotalOut t) x = blockOut ts + x := by
  intro ts
  induction ts with
  | nil => intro x; exact intZeroAdd x
  | cons t ts ih =>
    intro x
    have h1 : (t :: ts).foldl (fun acc u => acc + txTotalOut u) x
        = ts.foldl (fun acc u => acc + txTotalOut u) (x + txTotalOut t) := rfl
    have h2 : blockOut (t :: ts) + x
        = ts.foldl (fun acc u => acc + txTotalOut u) (0 + txTotalOut t) + x := rfl
    rw [h1, h2, ih (x + txTotalOut t), ih (0 + txTotalOut t)]
    -- blockOut ts + (x + v) = (blockOut ts + (0 + v)) + x
    have gen : ∀ (a b c : Int), a + (b + c) = (a + (0 + c)) + b := by intros; omega
    exact gen _ _ _

/-- Translation law for the block input fold. -/
private theorem blockInFrom_eq (u : UtxoSet) : ∀ (ts : List Tx) (x : Amount),
    ts.foldl (fun acc t => acc + totalInVin u t.vin) x = blockIn u ts + x := by
  intro ts
  induction ts with
  | nil => intro x; exact intZeroAdd x
  | cons t ts ih =>
    intro x
    have h1 : (t :: ts).foldl (fun acc v => acc + totalInVin u v.vin) x
        = ts.foldl (fun acc v => acc + totalInVin u v.vin) (x + totalInVin u t.vin) := rfl
    have h2 : blockIn u (t :: ts) + x
        = ts.foldl (fun acc v => acc + totalInVin u v.vin) (0 + totalInVin u t.vin) + x := rfl
    rw [h1, h2, ih (x + totalInVin u t.vin), ih (0 + totalInVin u t.vin)]
    have gen : ∀ (a b c : Int), a + (b + c) = (a + (0 + c)) + b := by intros; omega
    exact gen _ _ _

/-- Cons shape of the block folds. -/
theorem blockOut_cons (t : Tx) (ts : List Tx) :
    blockOut (t :: ts) = blockOut ts + txTotalOut t := by
  have h := blockOutFrom_eq ts (0 + txTotalOut t)
  show ts.foldl (fun acc u => acc + txTotalOut u) (0 + txTotalOut t) = _
  rw [h]
  have gen : ∀ (a b : Int), a + (0 + b) = a + b := by intros; omega
  exact gen _ _

theorem blockIn_cons (u : UtxoSet) (t : Tx) (ts : List Tx) :
    blockIn u (t :: ts) = blockIn u ts + totalInVin u t.vin := by
  have h := blockInFrom_eq u ts (0 + totalInVin u t.vin)
  show ts.foldl (fun acc v => acc + totalInVin u v.vin) (0 + totalInVin u t.vin) = _
  rw [h]
  have gen : ∀ (a b : Int), a + (0 + b) = a + b := by intros; omega
  exact gen _ _

/-- **THM-037 (arithmetic tier)** — per-transaction conservation
(`outputs ≤ inputs` against a fixed UTXO view) composes additively over a
block's transaction sequence. The full coinbase-surplus statement
(THM-037, C4) additionally needs `applyBlock` fold; can reuse
`blockOut_cons` / `blockIn_cons` directly (dedup by construction). -/
theorem block_conservation_arith (u : UtxoSet) : ∀ (txs : List Tx),
    (∀ t ∈ txs, txTotalOut t ≤ totalInVin u t.vin) →
    blockOut txs ≤ blockIn u txs := by
  intro txs
  induction txs with
  | nil => intro _; exact Int.le_refl 0
  | cons t ts ih =>
    intro hperm
    have h1 : txTotalOut t ≤ totalInVin u t.vin := hperm t List.mem_cons_self
    have h2 : blockOut ts ≤ blockIn u ts := ih (fun v hv => hperm v (List.mem_cons_of_mem _ hv))
    have h3 := blockOut_cons t ts
    have h4 := blockIn_cons u t ts
    rw [h3, h4]
    have gen : ∀ (a b c d : Int), a ≤ b → c ≤ d → a + c ≤ b + d := by
      intros; intros; omega
    exact gen _ _ _ _ h2 h1

/-! ## Named supply checkpoints (dedup with Test examples) -/

/-- Named, axiom-pinned versions of the supply boundary values that
`Conservation.Test` asserts anonymously: full epoch-0 supply at the
last pre-halving block, first post-halving block, and the terminal cap
(2,099,999,997,690,000 sats, flat from height 6,930,000). -/
theorem supplyAt_checkpoints :
    supplyAt 209999 = 1050000000000000
    ∧ supplyAt 210000 = 1050002500000000
    ∧ supplyAt 6929999 = 2099999997690000
    ∧ supplyAt 6930000 = 2099999997690000
    ∧ supplyAt 6930001 = 2099999997690000 := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> decide

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.LedgerCor.checkOutputs_none_total_moneyRange' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkOutputs_none_total_moneyRange

/-- info: 'BitcoinProofs.Theorems.LedgerCor.checkOutputs_none_moneyRange' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkOutputs_none_moneyRange

/-- info: 'BitcoinProofs.Theorems.LedgerCor.totalOut_moneyRange_of_checkTransaction' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms totalOut_moneyRange_of_checkTransaction

/-- info: 'BitcoinProofs.Theorems.LedgerCor.totalOut_le_MAX_of_checkTransaction' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms totalOut_le_MAX_of_checkTransaction

/-- info: 'BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_basic' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkTransaction_none_basic

/-- info: 'BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_noDup' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkTransaction_none_noDup

/-- info: 'BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_noNullPrevout' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkTransaction_none_noNullPrevout

/-- info: 'BitcoinProofs.Theorems.LedgerCor.block_conservation_arith' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms block_conservation_arith

/-- info: 'BitcoinProofs.Theorems.LedgerCor.blockOut_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms blockOut_cons

/-- info: 'BitcoinProofs.Theorems.LedgerCor.blockIn_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms blockIn_cons

/-- info: 'BitcoinProofs.Theorems.LedgerCor.supplyAt_checkpoints' does not depend on any axioms -/
#guard_msgs in #print axioms supplyAt_checkpoints

end BitcoinProofs.Theorems.LedgerCor
