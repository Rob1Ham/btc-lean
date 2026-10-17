import Bitcoin.Wallet.Spend.Laws
import Mathlib.Tactic
import Bitcoin.Wallet.RuleAttr

/-!
# Spend-selection proofs

This file proves the deterministic and arithmetic properties of the two
pure amount-only selection strategies in `Bitcoin.Wallet.Spend.Selection`
(`largestFirst` and `smallestFit`), together with the fee, effective-value
and change consequences that the surrounding `Funding.lean` and `Fee.lean`
model supports.

The claims are deliberately limited to that model:

* Selection is a pure function of the target and the offered amount list;
  there is no RNG, no mutable candidate set and no algorithm parameter
  other than the two modelled constructors.
* A selection that succeeds (the non-negative target is at most the total
  offered value, which is exactly the precondition of the committed
  `largestFirst_valid` / `smallestFit_valid` theorems) covers the target.
* Under the same non-negativity hypothesis, a selection never totals more
  than the offered pool.  `SelectionValid`'s `Subset` predicate alone is
  *not* enough for this bound: it is a membership test, so it admits a
  duplicate selected amount when the pool contains one copy.  The
  counterexample is recorded below; the algorithms do return sublists.
* Effective value is the local derived notion
  `inputValue - requiredFee rate vsize`.  The committed model has no
  effective-value field; `vsize` is the caller-supplied fee-bearing size.
  For a fixed `vsize` the deduction is constant, hence the value is
  monotone in the input amount.
* The fee is the model's ceiling-rounded `requiredFee`.  It equals the
  integer product `fee * vsize / size` only when that product is divisible
  by `size`; without divisibility the model deliberately charges one extra
  satoshi.  The success condition for the fee statement is the change
  branch of `fundWithChange`.
* Change is created exactly when the residual reaches the model's
  `minViableChange`.  It is therefore *iff above dust* only in the
  specialisation where `minViableChange` is the dust threshold.  In
  general, `dust ≤ minViableChange` gives only the forward direction
  (created change is above dust); non-negativity additionally needs
  `0 ≤ minViableChange`.

Core anchors are pinned to `cce32b168` under `build/scratch/btc/core-src`:

* `COutput::effective_value = txout.nValue - fee`, with
  `fee = feerate.GetFee(input_bytes)`:
  `src/wallet/coinselection.h:83-90` and `:116-126`.
* `GetSelectedValue()` sums the selected `txout.nValue`:
  `src/wallet/coinselection.cpp:954-957`.
* `GetChange()` creates change only when the residual reaches
  `min_viable_change`: `src/wallet/coinselection.cpp:1043-1060`; the
  caller inserts the output at `src/wallet/spend.cpp:1259-1271`.
* `min_viable_change = max(change_spend_fee + 1, dust)` and the change
  dust threshold: `src/wallet/spend.cpp:1186-1193` and
  `src/policy/policy.cpp:27-69`.
* `fee_needed = effective_feerate.GetFee(nBytes)`:
  `src/wallet/spend.cpp:1330-1337`; `CFeeRate::GetFee` rounds up at
  `src/policy/feerate.cpp:21-28` / `src/util/feefrac.h:144-175`.
* The selection validity surface (`Subset`, `Covers`, `SelectionValid`)
  is the committed model's, not Core's `SelectionResult` invariant.

What is not modelled or claimed: BnB, SRD, CoinGrinder, knapsack, waste,
ancestor bump fees, maximum selection weight, input/output size
estimation, descriptor/signature interaction, random change position,
the SFFO negative-`to_reduce` overpay branch, and optimality of either
strategy.  The consensus transaction checker remains the authority on
whether a constructed transaction is valid.
-/

namespace BitcoinProofs.Wallet.Spend

open Bitcoin.Wallet.Spend
open Bitcoin.Data

/-! ## Private arithmetic helpers

As in the committed `Bitcoin.Wallet.Spend.Laws`, `omega` does not see
through the reducible abbreviation `Amount` in this toolchain.  These
helpers are stated over `Int` explicitly and then applied to `Amount`
terms by definitional equality. -/

private theorem int_add_nonneg (a b : Int) (ha : 0 ≤ a) (hb : 0 ≤ b) :
    0 ≤ a + b := by omega

private theorem int_le_add_right (a b : Int) (h : 0 ≤ b) : a ≤ a + b := by omega

private theorem int_le_add_left (a b : Int) (h : 0 ≤ a) : b ≤ a + b := by omega

private theorem int_add_le_add_left (a b c : Int) (h : b ≤ c) :
    a + b ≤ a + c := by omega

private theorem int_sub_le_sub_right (a b c : Int) (h : a ≤ b) :
    a - c ≤ b - c := by omega

/-! ## Determinism -/

/-- Run either committed selection strategy.  This proof-side wrapper does
not modify the model; it exists so determinism can be stated once for both
`SelectionAlgorithm` constructors.  Core analogue: the deterministic
candidate loops of `SelectCoins` are out of scope here; only the two pure
amount-only strategies are covered. -/
def runSelection (alg : SelectionAlgorithm) (target : Amount)
    (coins : List Amount) : List Amount :=
  match alg with
  | .largestFirst => largestFirst target coins
  | .smallestFit => smallestFit target coins

@[simp] theorem runSelection_largestFirst (target : Amount)
    (coins : List Amount) :
    runSelection .largestFirst target coins = largestFirst target coins := rfl

@[simp] theorem runSelection_smallestFit (target : Amount)
    (coins : List Amount) :
    runSelection .smallestFit target coins = smallestFit target coins := rfl

/-- Each strategy is a pure Lean function, so it returns the same selected
list every time it is called on the same target and pool.  This is the
model's full determinism claim; it says nothing about Core's RNG-driven
SRD or about wallet iteration order. -/
theorem largestFirst_deterministic (target : Amount)
    (coins : List Amount) :
    largestFirst target coins = largestFirst target coins := rfl

/-- `smallestFit` is deterministic in the same pure-function sense. -/
theorem smallestFit_deterministic (target : Amount)
    (coins : List Amount) :
    smallestFit target coins = smallestFit target coins := rfl

/-- The wrapper over both algorithms is deterministic. -/
theorem runSelection_deterministic (alg : SelectionAlgorithm)
    (target : Amount) (coins : List Amount) :
    runSelection alg target coins = runSelection alg target coins := rfl

/-- Equal algorithm, target and pool give equal selections.  This is the
congruence form of determinism used when a caller has already identified
two inputs extensionally. -/
theorem runSelection_congr {alg₁ alg₂ : SelectionAlgorithm}
    {target₁ target₂ : Amount} {coins₁ coins₂ : List Amount}
    (ha : alg₁ = alg₂) (ht : target₁ = target₂) (hc : coins₁ = coins₂) :
    runSelection alg₁ target₁ coins₁ = runSelection alg₂ target₂ coins₂ := by
  cases ha
  cases ht
  cases hc
  rfl

/-- Largest-first selection is extensional in its arguments. -/
theorem largestFirst_congr {target₁ target₂ : Amount}
    {coins₁ coins₂ : List Amount} (ht : target₁ = target₂)
    (hc : coins₁ = coins₂) :
    largestFirst target₁ coins₁ = largestFirst target₂ coins₂ := by
  cases ht
  cases hc
  rfl

/-- Smallest-fit selection is extensional in its arguments. -/
theorem smallestFit_congr {target₁ target₂ : Amount}
    {coins₁ coins₂ : List Amount} (ht : target₁ = target₂)
    (hc : coins₁ = coins₂) :
    smallestFit target₁ coins₁ = smallestFit target₂ coins₂ := by
  cases ht
  cases hc
  rfl

/-! ## Sum bounds used by the selection properties -/

/-- A list of non-negative amounts has a non-negative sum. -/
theorem total_nonneg_of_forall_nonneg (l : List Amount)
    (h : ∀ a ∈ l, 0 ≤ a) : 0 ≤ total l := by
  induction l with
  | nil => simp [total]
  | cons a as ih =>
      have ha : 0 ≤ a := h a (by simp)
      have has : ∀ x ∈ as, 0 ≤ x := fun x hx => h x (by simp [hx])
      have ih' : 0 ≤ total as := ih has
      simp only [total_cons]
      exact int_add_nonneg a (total as) ha ih'

/-- An amount occurring in a non-negative list is at most the list total.
This supplies the singleton-selection bound for `smallestFit`. -/
theorem le_total_of_mem_of_forall_nonneg (a : Amount) (l : List Amount)
    (ha : a ∈ l) (h : ∀ x ∈ l, 0 ≤ x) : a ≤ total l := by
  induction l with
  | nil => simp at ha
  | cons b bs ih =>
      simp only [total_cons]
      rcases List.mem_cons.mp ha with rfl | ha
      · have hbs : 0 ≤ total bs :=
          total_nonneg_of_forall_nonneg bs
            (fun x hx => h x (by simp [hx]))
        exact int_le_add_right a (total bs) hbs
      · have hb : 0 ≤ b := h b (by simp)
        have hbs : ∀ x ∈ bs, 0 ≤ x := fun x hx => h x (by simp [hx])
        have ih' : a ≤ total bs := ih ha hbs
        exact Int.le_trans ih' (int_le_add_left b (total bs) hb)

/-- `takeUntilCovered` returns a prefix, so under non-negative amounts its
total cannot exceed the total of the pool it drew from. -/
theorem takeUntilCovered_total_le_of_forall_nonneg (target : Amount)
    (coins : List Amount) (h : ∀ a ∈ coins, 0 ≤ a) :
    total (takeUntilCovered target coins) ≤ total coins := by
  induction coins generalizing target with
  | nil => simp [takeUntilCovered, total]
  | cons a rest ih =>
      have ha : 0 ≤ a := h a (by simp)
      have hrest : ∀ x ∈ rest, 0 ≤ x := fun x hx => h x (by simp [hx])
      have hrest_total : 0 ≤ total rest :=
        total_nonneg_of_forall_nonneg rest hrest
      by_cases hcov : target ≤ a
      · simp only [takeUntilCovered, hcov, ite_true, total_cons, total_nil]
        simpa using int_le_add_right a (total rest) hrest_total
      · simp only [takeUntilCovered, hcov, ite_false, total_cons]
        have ih' := ih (target - a) hrest
        exact int_add_le_add_left a (total (takeUntilCovered (target - a) rest))
          (total rest) ih'

/-! ## Value coverage and the available-value bound -/

/-- Any selection satisfying the model's validity predicate covers its
target.  This is the definitional meaning of `Covers`; the substantive
strategy-specific existence statements are the next two theorems. -/
theorem selectionValid_covers {target : Amount} {coins selected : List Amount}
    (h : SelectionValid target coins selected) : target ≤ total selected :=
  h.2

/-- A largest-first call whose pool covers a non-negative target returns a
selection worth at least the target.  Core analogue: the selected value
sum at `src/wallet/coinselection.cpp:954-957`; the greedy order is the
model's own, not BnB. -/
theorem largestFirst_value_ge_target (target : Amount)
    (coins : List Amount) (htarget : 0 ≤ target)
    (hcov : target ≤ total coins) :
    target ≤ total (largestFirst target coins) :=
  (largestFirst_valid target coins htarget hcov).2

/-- A smallest-fit call whose pool covers a non-negative target returns a
selection worth at least the target. -/
theorem smallestFit_value_ge_target (target : Amount)
    (coins : List Amount) (htarget : 0 ≤ target)
    (hcov : target ≤ total coins) :
    target ≤ total (smallestFit target coins) :=
  (smallestFit_valid target coins htarget hcov).2

/-- Either strategy covers the target under the same success precondition. -/
theorem runSelection_value_ge_target (alg : SelectionAlgorithm)
    (target : Amount) (coins : List Amount) (htarget : 0 ≤ target)
    (hcov : target ≤ total coins) :
    target ≤ total (runSelection alg target coins) := by
  cases alg
  · exact largestFirst_value_ge_target target coins htarget hcov
  · exact smallestFit_value_ge_target target coins htarget hcov

/-- Largest-first never selects more value than the offered non-negative
pool.  The proof uses that `takeUntilCovered` is a prefix and that
descending sort preserves the multiset. -/
theorem largestFirst_total_le_available (target : Amount)
    (coins : List Amount) (hcoins : ∀ a ∈ coins, 0 ≤ a) :
    total (largestFirst target coins) ≤ total coins := by
  unfold largestFirst
  have hsort : ∀ a ∈ sortDesc coins, 0 ≤ a :=
    fun a ha => hcoins a ((sortDesc_perm coins).mem_iff.mp ha)
  calc
    total (takeUntilCovered target (sortDesc coins))
        ≤ total (sortDesc coins) :=
      takeUntilCovered_total_le_of_forall_nonneg target (sortDesc coins) hsort
    _ = total coins := total_sortDesc coins

/-- Smallest-fit never selects more value than the offered non-negative
pool.  The singleton branch uses `le_total_of_mem_of_forall_nonneg`; the
accumulating branch uses the prefix bound on the ascending sort. -/
theorem smallestFit_total_le_available (target : Amount)
    (coins : List Amount) (hcoins : ∀ a ∈ coins, 0 ≤ a) :
    total (smallestFit target coins) ≤ total coins := by
  unfold smallestFit
  dsimp only
  have hsort : ∀ a ∈ sortAsc coins, 0 ≤ a :=
    fun a ha => hcoins a ((sortAsc_perm coins).mem_iff.mp ha)
  cases hfind : firstCover target (sortAsc coins) with
  | some a =>
      have hs := firstCover_some hfind
      have hle : a ≤ total (sortAsc coins) :=
        le_total_of_mem_of_forall_nonneg a (sortAsc coins) hs.1 hsort
      rw [← total_sortAsc coins]
      simpa [total] using hle
  | none =>
      calc
        total (takeUntilCovered target (sortAsc coins))
            ≤ total (sortAsc coins) :=
          takeUntilCovered_total_le_of_forall_nonneg target (sortAsc coins) hsort
        _ = total coins := total_sortAsc coins

/-- Either strategy's selected value is bounded by the offered pool under
non-negative amounts.

`SelectionValid` alone does not imply this: with `coins = [1]` and
`selected = [1, 1]`, `Subset` holds (both entries occur in the pool) but
`total selected = 2 > 1 = total coins`.  The model's `Subset` is a
membership predicate, not a multiset/sublist relation; the two concrete
algorithms do return sublists, which is what the preceding two theorems
prove. -/
theorem runSelection_total_le_available (alg : SelectionAlgorithm)
    (target : Amount) (coins : List Amount)
    (hcoins : ∀ a ∈ coins, 0 ≤ a) :
    total (runSelection alg target coins) ≤ total coins := by
  cases alg
  · exact largestFirst_total_le_available target coins hcoins
  · exact smallestFit_total_le_available target coins hcoins

/-! ## Effective value -/

/-- The derived effective value of an input: its amount minus the model's
required fee for a fixed fee-bearing virtual size.  Core computes the same
per-coin quantity as `txout.nValue - fee` where
`fee = feerate.GetFee(input_bytes)`
(`src/wallet/coinselection.h:83-90`, `:116-126`); the committed wallet
model has no effective-value field, so this definition is proof-local.

The fee is held fixed here; the input amount is the only varying
argument.  Nothing is claimed about ancestor bump fees, input-weight
changes, or effective value under a varying size. -/
@[walletRule "WSP-003"]
def effectiveValue (r : FeeRate) (vsize : Nat) (inputValue : Amount) : Amount :=
  inputValue - requiredFee r vsize

/-- Effective value is monotone in the input amount for a fixed fee rate
and fixed virtual size: a larger input amount loses the same fee and thus
keeps a weakly larger effective value.  No well-formedness of `r` is
needed because subtraction of the same integer is order-preserving. -/
theorem effectiveValue_mono (r : FeeRate) (vsize : Nat)
    {a b : Amount} (h : a ≤ b) :
    effectiveValue r vsize a ≤ effectiveValue r vsize b := by
  unfold effectiveValue
  exact int_sub_le_sub_right a b (requiredFee r vsize) h

/-! ## Fee implied by the selected inputs -/

/-- On the change branch of `fundWithChange`, the recorded fee is exactly
the requested `requiredFee r vsize`.  The hypothesis is the model's
success condition: the residual reaches `minViableChange`.  Off that
branch the surplus is thrown to fee, so equality need not hold; the
committed `fundWithChange_fee_ge_needed` is the correct one-sided law
there. -/
theorem fundWithChange_fee_eq_requiredFee (inputs outputs : List Amount)
    (r : FeeRate) (vsize : Nat) (minViableChange : Amount)
    (hsuccess : minViableChange ≤
      total inputs - total outputs - requiredFee r vsize) :
    (fundWithChange inputs outputs (requiredFee r vsize)
      minViableChange).fee = requiredFee r vsize := by
  simp [fundWithChange, hsuccess]

/-- Ceiling division is ordinary integer division when the dividend is an
exact multiple.  The positivity hypothesis is on the natural denominator;
`n` may be any integer, although the wallet uses it only for non-negative
fee products. -/
theorem ceilDiv_eq_div_of_dvd (n : Amount) (d : Nat) (hd : 0 < d)
    (hdiv : (d : Amount) ∣ n) :
    ceilDiv n d = n / (d : Amount) := by
  unfold ceilDiv
  have hd0 : d ≠ 0 := Nat.ne_of_gt hd
  rw [ite_eq_right hd0]
  obtain ⟨k, hk⟩ := hdiv
  have hdI : (d : Amount) ≠ 0 := by exact_mod_cast hd0
  have hnk : n / (d : Amount) = k :=
    Int.ediv_eq_of_eq_mul_right hdI hk
  rw [hnk]
  have hmul : k * (d : Amount) = n := by
    rw [Int.mul_comm]
    exact hk.symm
  have hdIpos : (0 : Amount) < (d : Amount) := by exact_mod_cast hd
  rw [Int.ediv_eq_iff_of_pos hdIpos]
  constructor <;> omega

/-- The model's required fee equals the exact product `fee * vsize / size`
when `size` divides that product.  Without the divisibility hypothesis the
ceiling in `requiredFee` is intentional and may add one satoshi, so no
unconditional equality is claimed. -/
theorem requiredFee_eq_rate_mul_vsize_of_dvd (r : FeeRate) (vsize : Nat)
    (hsize : 0 < r.size)
    (hdvd : (r.size : Amount) ∣ r.fee * (vsize : Amount)) :
    requiredFee r vsize = (r.fee * (vsize : Amount)) / (r.size : Amount) := by
  unfold requiredFee FeeRate.getFee
  exact ceilDiv_eq_div_of_dvd (r.fee * (vsize : Amount)) r.size hsize hdvd

/-- Combining the success condition and exact divisibility: the fee implied
by the selected inputs on the change branch is the rate-times-size integer
product.  This is the precise form of "the fee equals `rate * vsize`" that
the ceiling-rounded model supports. -/
theorem fundWithChange_fee_eq_rate_mul_vsize_of_dvd
    (inputs outputs : List Amount) (r : FeeRate) (vsize : Nat)
    (minViableChange : Amount)
    (hsuccess : minViableChange ≤
      total inputs - total outputs - requiredFee r vsize)
    (hsize : 0 < r.size)
    (hdvd : (r.size : Amount) ∣ r.fee * (vsize : Amount)) :
    (fundWithChange inputs outputs (requiredFee r vsize)
      minViableChange).fee =
      (r.fee * (vsize : Amount)) / (r.size : Amount) := by
  rw [fundWithChange_fee_eq_requiredFee inputs outputs r vsize
    minViableChange hsuccess]
  exact requiredFee_eq_rate_mul_vsize_of_dvd r vsize hsize hdvd

/-! ## Change -/

/-- Change-to-source creates change with exactly the raw residual iff the
residual reaches `minViableChange`.  This is the threshold law behind
Core's `GetChange` (`src/wallet/coinselection.cpp:1043-1060`). -/
theorem fundWithChange_change_eq_some_iff_ge (inputs outputs : List Amount)
    (feeNeeded minViableChange : Amount) :
    (fundWithChange inputs outputs feeNeeded minViableChange).change =
        some (total inputs - total outputs - feeNeeded) ↔
      minViableChange ≤ total inputs - total outputs - feeNeeded := by
  by_cases h : minViableChange ≤ total inputs - total outputs - feeNeeded
  · simp [fundWithChange, h]
  · simp [fundWithChange, h]

/-- When the viable threshold is exactly the dust threshold, change appears
iff the raw residual is above dust.  This is a dust-only specialisation;
Core actually sets `min_viable_change = max(change_spend_fee + 1, dust)`
(`src/wallet/spend.cpp:1186-1193`), so the general model has the
one-directional law below rather than this equivalence. -/
theorem fundWithChange_change_appears_iff_aboveDust
    (inputs outputs : List Amount) (feeNeeded : Amount)
    (r : FeeRate) (txoutSize : Nat) (witnessProgram : Bool) :
    (fundWithChange inputs outputs feeNeeded
        (dustThreshold r txoutSize witnessProgram)).change =
        some (total inputs - total outputs - feeNeeded) ↔
      aboveDust r txoutSize witnessProgram
        (total inputs - total outputs - feeNeeded) := by
  rw [fundWithChange_change_eq_some_iff_ge]
  rfl

/-- If the viable threshold is at least dust, any change that is actually
created is above dust.  This is the forward direction available in the
general Core-shaped model. -/
theorem fundWithChange_change_aboveDust
    (inputs outputs : List Amount) (feeNeeded minViableChange : Amount)
    (r : FeeRate) (txoutSize : Nat) (witnessProgram : Bool)
    (hdust : dustThreshold r txoutSize witnessProgram ≤ minViableChange)
    {c : Amount}
    (hc : (fundWithChange inputs outputs feeNeeded minViableChange).change =
      some c) :
    aboveDust r txoutSize witnessProgram c := by
  have hge : minViableChange ≤ c :=
    Bitcoin.Wallet.Spend.fundWithChange_change_at_least inputs outputs
      feeNeeded minViableChange c hc
  exact Int.le_trans hdust hge

/-- If the viable threshold is non-negative, every created change is
non-negative.  Core's minimum is `max(change_spend_fee + 1, dust)` with
non-negative fee and dust inputs, so this hypothesis is the natural one. -/
theorem fundWithChange_change_nonneg (inputs outputs : List Amount)
    (feeNeeded minViableChange : Amount) (hmin : 0 ≤ minViableChange) :
    (fundWithChange inputs outputs feeNeeded minViableChange).ChangeNonneg :=
  Bitcoin.Wallet.Spend.fundWithChange_change_nonneg inputs outputs
    feeNeeded minViableChange hmin

/-- Combined dust-only statement: with the dust threshold used as the
viable threshold and non-negative dust, change appears iff the residual is
above dust, and any created change is non-negative. -/
theorem fundWithChange_change_iff_aboveDust_and_nonneg
    (inputs outputs : List Amount) (feeNeeded : Amount)
    (r : FeeRate) (txoutSize : Nat) (witnessProgram : Bool)
    (hdust_nonneg : 0 ≤ dustThreshold r txoutSize witnessProgram) :
    (((fundWithChange inputs outputs feeNeeded
          (dustThreshold r txoutSize witnessProgram)).change =
        some (total inputs - total outputs - feeNeeded)) ↔
      aboveDust r txoutSize witnessProgram
        (total inputs - total outputs - feeNeeded)) ∧
    (∀ c, (fundWithChange inputs outputs feeNeeded
          (dustThreshold r txoutSize witnessProgram)).change = some c →
      0 ≤ c) := by
  constructor
  · exact fundWithChange_change_appears_iff_aboveDust inputs outputs
      feeNeeded r txoutSize witnessProgram
  · intro c hc
    exact Bitcoin.Wallet.Spend.fundWithChange_change_nonneg inputs outputs
      feeNeeded (dustThreshold r txoutSize witnessProgram) hdust_nonneg c hc

end BitcoinProofs.Wallet.Spend
