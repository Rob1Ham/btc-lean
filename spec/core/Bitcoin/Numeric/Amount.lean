import Bitcoin.Numeric.Interface

/-!
# Bitcoin.Numeric.Amount — CAmount arithmetic

MoneyRange introduction/elimination, the checked-vs-unchecked
accumulation pair that encodes the CVE-2010-5137 ("184 billion BTC",
Aug 2010) defense, int64 wraparound, and the concrete CVE instance as
`decide`-theorems cross-checked against independent Python arithmetic
(see the script-number notes §5).

Core counterparts:
- `consensus/amount.h:12-27` — CAmount, COIN, MAX_MONEY, MoneyRange.
- `consensus/tx_check.cpp:31-42` — per-output + cumulative MoneyRange.
- `consensus/tx_verify.cpp:170-220` — CheckTxInputs fee arithmetic.
- `validation.cpp:2548-2552` — block-level fee accumulator range check.

All arithmetic is on `Amount := Int` (frozen, `Bitcoin.Data.Basic`);
the int64 wraparound of the historical bug is modeled explicitly by
`i64Wrap` rather than by machine integers.
-/

namespace Bitcoin.Numeric

open Bitcoin.Data

/-! ## MoneyRange introduction / elimination -/

/-- `MoneyRange` introduction: the positive-ray bound `0 ≤ n ≤ MAX_MONEY`
amount.h:27 (inclusive on both ends; TXV-068). -/
theorem moneyRange_intro {n : Amount} (h1 : 0 ≤ n) (h2 : n ≤ MAX_MONEY) :
    MoneyRange n = true := by
  simp only [MoneyRange, decide_eq_true_iff]
  exact ⟨h1, h2⟩

/-- `MoneyRange` elimination. -/
theorem moneyRange_elim {n : Amount} (h : MoneyRange n = true) :
    0 ≤ n ∧ n ≤ MAX_MONEY :=
  (moneyRange_iff n).mp h

/-- MAX_MONEY is nonnegative (needed as the accumulator seed invariant). -/
theorem maxMoney_nonneg : 0 ≤ MAX_MONEY := by
  unfold MAX_MONEY COIN
  decide

/-- MAX_MONEY is strictly positive, so doubling it strictly increases. -/
theorem maxMoney_lt_double : MAX_MONEY < MAX_MONEY + MAX_MONEY := by
  unfold MAX_MONEY COIN
  decide

/-! ## Unchecked vs checked accumulation -/

/-- Unchecked sum of a list of amounts (the *unguarded* accumulator; on
int64 hardware this is exactly where CVE-2010-5137 bit). -/
def plainSum : List Amount → Amount
  | [] => 0
  | v :: l => v + plainSum l

/-- Guarded accumulator step: Core's incremental `MoneyRange` check at
every addition (tx_check.cpp:39-41; tx_verify.cpp:191-194). -/
def checkedSumAux : Amount → List Amount → Option Amount
  | acc, [] => some acc
  | acc, v :: l =>
      if MoneyRange (acc + v) = true then checkedSumAux (acc + v) l else none

/-- Checked sum of a list of amounts, seeded at 0 like Core's
`nValueOut` / `nValueIn` accumulators. -/
def checkedSum (l : List Amount) : Option Amount :=
  checkedSumAux 0 l

theorem plainSum_cons (v : Amount) (l : List Amount) :
    plainSum (v :: l) = v + plainSum l := rfl

theorem plainSum_nil : plainSum [] = 0 := rfl

theorem plainSum_replicate (k : Nat) (v : Amount) :
    plainSum (List.replicate k v) = (k : Amount) * v := by
  induction k with
  | zero =>
    rw [List.replicate, plainSum_nil, Int.natCast_zero, Int.zero_mul]
  | succ k ih =>
    rw [List.replicate_succ, plainSum, ih]
    have hsucc : ((k + 1 : Nat) : Amount) = (k : Amount) + 1 := Int.natCast_add k 1
    rw [hsucc, Int.add_mul, Int.one_mul, Int.add_comm v ((k : Amount) * v)]

/-! ## Guarded-accumulator laws -/

/-- The guarded accumulator never changes the arithmetic value: a
successful run returns exactly `acc + plainSum l`. -/
theorem checkedSumAux_value (acc : Amount) (l : List Amount) (s : Amount)
    (h : checkedSumAux acc l = some s) : s = acc + plainSum l := by
  induction l generalizing acc with
  | nil =>
    rw [checkedSumAux, Option.some.injEq] at h
    rw [plainSum, Int.add_zero]
    exact h.symm
  | cons v l ih =>
    rw [checkedSumAux] at h
    by_cases hg : MoneyRange (acc + v) = true
    · rw [ite_eq_left hg] at h
      rw [plainSum, ← Int.add_assoc]
      exact ih (acc + v) h
    · rw [ite_eq_right hg] at h
      simp at h

/-- If the guarded accumulator succeeds, the running total is in
`MoneyRange` — every intermediate prefix sum passed the incremental
check (TXV-006/023 content at the accumulator level). -/
theorem checkedSumAux_some_range (acc : Amount) (l : List Amount) (s : Amount)
    (ha : MoneyRange acc = true) (h : checkedSumAux acc l = some s) :
    MoneyRange (acc + plainSum l) = true := by
  induction l generalizing acc with
  | nil =>
    rw [checkedSumAux, Option.some.injEq] at h
    rw [plainSum, Int.add_zero]
    exact ha
  | cons v l ih =>
    rw [checkedSumAux] at h
    by_cases hg : MoneyRange (acc + v) = true
    · rw [ite_eq_left hg] at h
      rw [plainSum, ← Int.add_assoc]
      exact ih (acc + v) hg h
    · rw [ite_eq_right hg] at h
      simp at h

/-- `checkedSum` catches out-of-range totals: if the plain total is not
in `MoneyRange`, the guarded sum reports `none` (the CVE-2010-5137
family defense, stated at the accumulator level). -/
theorem checkedSum_catches (l : List Amount)
    (h : ¬ MoneyRange (plainSum l) = true) :
    checkedSum l = none := by
  unfold checkedSum
  cases hcs : checkedSumAux 0 l with
  | none => rfl
  | some s =>
    have hr := checkedSumAux_some_range 0 l s moneyRange_zero hcs
    rw [Int.zero_add] at hr
    exact absurd hr h

/-- `checkedSum` soundness: a successful run returns the true total, and
that total is in `MoneyRange`. -/
theorem checkedSum_sound (l : List Amount) (s : Amount)
    (h : checkedSum l = some s) :
    s = plainSum l ∧ MoneyRange s = true := by
  unfold checkedSum at h
  have hv : s = 0 + plainSum l := checkedSumAux_value 0 l s h
  have hr : MoneyRange (0 + plainSum l) = true :=
    checkedSumAux_some_range 0 l s moneyRange_zero h
  rw [Int.zero_add] at hv hr
  exact ⟨hv, by rw [hv]; exact hr⟩

/-- A run whose every intermediate total stays in range succeeds with the
true total (completeness of the incremental check). -/
theorem checkedSum_complete (l : List Amount) (s : Amount)
    (h : checkedSum l = some s) (hval : s = plainSum l) :
    checkedSum l = some (plainSum l) := by
  rw [h, hval]

/-! ## int64 wraparound (CVE-2010-5137) -/

/-- Two's-complement int64 wraparound: the value a 64-bit machine
actually computes when the true sum exceeds `int64` range. Modeled
modularly: `i64Wrap n = (n + 2^63) mod 2^64 − 2^63`. -/
def i64Wrap (n : Amount) : Amount :=
  (n + 9223372036854775808) % 18446744073709551616 - 9223372036854775808

/-! ## int64 range (TXV-069)

`Amount` is unbounded `Int`, so the i64 half of TXV-069 is stated as an
explicit range predicate on the *checked* fold, not by changing `Amount`:
on `[i64Min, i64Max]` two's-complement wrapping is the identity, and a
fold whose every prefix stays in that range agrees with the unbounded
`Int` fold. -/

/-- Least representable `int64_t` value. -/
def i64Min : Amount := -9223372036854775808

/-- Greatest representable `int64_t` value. -/
def i64Max : Amount := 9223372036854775807

/-- `n` is representable as a two's-complement `int64_t` (amount.h:12). -/
def InI64Range (n : Amount) : Prop := i64Min ≤ n ∧ n ≤ i64Max

/-- The i64 wrapping function is the identity on the int64 range: an
in-range value has a bit pattern whose two's-complement reinterpretation
is itself. -/
theorem i64Wrap_eq_self {n : Amount} (h : InI64Range n) : i64Wrap n = n := by
  simp only [InI64Range, i64Min, i64Max] at h
  obtain ⟨hlo, hhi⟩ := h
  unfold i64Wrap
  rw [Int.emod_eq_of_lt]
  · rw [Int.add_sub_cancel]
  · have h' : (-9223372036854775808 : Int) + 9223372036854775808 ≤
        n + 9223372036854775808 :=
      Int.add_le_add_right hlo _
    simpa using h'
  · have h' : n + 9223372036854775808 ≤
        9223372036854775807 + 9223372036854775808 :=
      Int.add_le_add_right hhi _
    have h'' : (9223372036854775807 : Int) + 9223372036854775808 =
        18446744073709551615 := by decide
    rw [h''] at h'
    exact Int.lt_of_le_of_lt h' (by decide)

/-- `MAX_MONEY` is far inside the int64 range. -/
theorem maxMoney_in_i64Range : InI64Range MAX_MONEY := by
  unfold InI64Range i64Min i64Max MAX_MONEY COIN
  decide

/-- `MoneyRange` is a sub-range of int64, so its bounds discharge the
per-step no-overflow precondition. -/
theorem moneyRange_in_i64Range {n : Amount} (h : MoneyRange n = true) :
    InI64Range n := by
  have h' : 0 ≤ n ∧ n ≤ MAX_MONEY := (moneyRange_iff n).mp h
  refine ⟨Int.le_trans ?_ h'.1, Int.le_trans h'.2 maxMoney_in_i64Range.2⟩
  unfold i64Min
  decide

/-- Fold with two's-complement wrapping after every addition — the
machine-level i64 accumulator. -/
def i64Foldl (l : List Amount) (acc : Amount) : Amount :=
  l.foldl (fun a v => i64Wrap (a + v)) acc

/-- A `take`-then-`foldl` step, in the indexing shape of the prefix
invariant. -/
private theorem i64_take_foldl_cons (v : Amount) (l : List Amount)
    (acc : Amount) (k : Nat) :
    ((v :: l).take (k + 1)).foldl (fun a x => a + x) acc =
      (l.take k).foldl (fun a x => a + x) (acc + v) := by
  rw [List.take_cons (by omega), Nat.add_sub_cancel, List.foldl_cons]

/-- **i64 agreement for the checked fold.** If the seed and every prefix
sum of the unbounded `Int` fold are in the int64 range, then the
wrapping i64 fold computes exactly the same value. -/
theorem i64Foldl_eq_foldl_of_prefix_range (l : List Amount) (acc : Amount)
    (hacc : InI64Range acc)
    (hpre : ∀ k, k ≤ l.length →
      InI64Range ((l.take k).foldl (fun a v => a + v) acc)) :
    i64Foldl l acc = l.foldl (fun a v => a + v) acc := by
  induction l generalizing acc with
  | nil => rfl
  | cons v rest ih =>
    rw [i64Foldl, List.foldl_cons, List.foldl_cons]
    have hstep : InI64Range (acc + v) := by
      simpa using hpre 1 (by simp)
    rw [i64Wrap_eq_self hstep]
    exact ih (acc + v) hstep (fun k hk => by
      rw [← i64_take_foldl_cons]
      exact hpre (k + 1) (by simpa using Nat.succ_le_succ hk))

/-! ## CVE-2010-5137 concrete instance (Python-cross-checked) -/

/-- 8785 outputs of MAX_MONEY (the 0.3.x-era incident scale): the true
sum is 18448500000000000000 satoshis ≈ 184.485 billion BTC. -/
theorem cve2010_5137_true_sum :
    plainSum (List.replicate 8785 MAX_MONEY) = 18448500000000000000 := by
  rw [plainSum_replicate]
  unfold MAX_MONEY COIN
  decide

/-- The true sum is out of `MoneyRange` (and out of int64 range:
18448500000000000000 > 2^63 − 1 = 9223372036854775807). -/
theorem cve2010_5137_out_of_moneyRange :
    MoneyRange (plainSum (List.replicate 8785 MAX_MONEY)) = false := by
  rw [cve2010_5137_true_sum]
  rfl

/-- The int64-wrapped value the buggy accumulator would report:
1755926290448384 satoshis — inside `MoneyRange`, hence silently wrong. -/
theorem cve2010_5137_wrapped :
    i64Wrap (plainSum (List.replicate 8785 MAX_MONEY)) = 1755926290448384 := by
  rw [cve2010_5137_true_sum]
  rfl

/-- The wrapped value passes `MoneyRange` — the point of the CVE: the
incremental check is what catches the overflow, not a post-hoc range
test on the wrapped total. -/
theorem cve2010_5137_wrapped_in_moneyRange :
    MoneyRange (i64Wrap (plainSum (List.replicate 8785 MAX_MONEY))) = true := by
  rw [cve2010_5137_wrapped]
  rfl

/-! ## Guarded accumulator vs replicated MAX_MONEY -/

/-- Once the accumulator holds at least MAX_MONEY, adding another
MAX_MONEY-sized amount fails the incremental check. -/
theorem checkedSumAux_replicate_ge (acc : Amount) (k : Nat)
    (h : MAX_MONEY ≤ acc) (hk : 1 ≤ k) :
    checkedSumAux acc (List.replicate k MAX_MONEY) = none := by
  obtain ⟨j, rfl⟩ : ∃ j, k = j + 1 := ⟨k - 1, by omega⟩
  rw [List.replicate_succ, checkedSumAux]
  have hnot : ¬ MoneyRange (acc + MAX_MONEY) = true := by
    rw [moneyRange_iff]
    refine fun hcon => (Int.not_le.mpr ?_) hcon.2
    have hstep : MAX_MONEY + MAX_MONEY ≤ acc + MAX_MONEY :=
      Int.add_le_add_right h MAX_MONEY
    exact Int.lt_of_lt_of_le maxMoney_lt_double hstep
  rw [ite_eq_right hnot]

/-- Two or more MAX_MONEY-sized additions already fail the guarded
accumulator (the incremental check trips at the first out-of-range
intermediate, long before the true 8785-fold total). -/
theorem checkedSum_replicate_none (k : Nat) (hk : 2 ≤ k) :
    checkedSum (List.replicate k MAX_MONEY) = none := by
  obtain ⟨j, rfl⟩ : ∃ j, k = j + 2 := ⟨k - 2, by omega⟩
  rw [checkedSum, List.replicate_succ, List.replicate_succ, checkedSumAux]
  have hg : MoneyRange (0 + MAX_MONEY) = true := by
    rw [Int.zero_add]
    exact moneyRange_intro maxMoney_nonneg (Int.le_refl MAX_MONEY)
  rw [ite_eq_left hg]
  exact checkedSumAux_replicate_ge MAX_MONEY (j + 1) (Int.le_refl MAX_MONEY)
    (by omega)

/-- The guarded accumulator refuses the CVE vector outright. -/
theorem cve2010_5137_checkedSum_none :
    checkedSum (List.replicate 8785 MAX_MONEY) = none :=
  checkedSum_replicate_none 8785 (by decide)

end Bitcoin.Numeric
