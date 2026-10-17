import Bitcoin.Wallet.Spend.Funding

/-!
# Deterministic, branch-and-bound-free coin selection

Core's wallet offers several selection algorithms: Branch and Bound
(`SelectCoinsBnB`, `src/wallet/coinselection.cpp:115`), Single Random
Draw (`SelectCoinsSRD`, `src/wallet/coinselection.cpp:610`), CoinGrinder
(`src/wallet/coinselection.cpp:399`), and the legacy knapsack fallback
(`src/wallet/coinselection.cpp:726`).  **Branch and Bound is not modeled
here.**  Neither are SRD, CoinGrinder, knapsack, effective values,
ancestor bump fees, waste, or the maximum-selection-weight guard.

This file provides two pure amount-only strategies that are useful as
executable specifications and as baselines:

* `largestFirst` — sort the available amounts largest-first, then take
  coins until the target is covered.
* `smallestFit` — take the smallest single coin that already covers the
  target; if none does, accumulate the smallest coins until covered.

Both are deterministic and neither uses randomness.  They operate on
amounts, so two coins of equal amount are interchangeable here.  The
validity predicate below checks exactly two things: the selected amounts
come from the offered pool, and they cover the target.  It says nothing
about optimality, waste, or weight.

Core references for the target notion: `selection_target` is recipients
plus non-input fees (`src/wallet/spend.cpp:1195-1197`), and the selected
value is summed over the selected coins
(`src/wallet/coinselection.cpp:954-957`).  The change residual itself is
modeled in `Funding.lean`, not here.
-/

namespace Bitcoin.Wallet.Spend

open Bitcoin.Data

/-- Which pure strategy produced a selection.  Core's `BNB`, `SRD`, `CG`
and `KNAPSACK` enum values (`src/wallet/coinselection.h:311-318`) are
deliberately absent until those algorithms are modeled. -/
inductive SelectionAlgorithm where
  /-- Descending-amount greedy cover. -/
  | largestFirst
  /-- Smallest single covering coin, else ascending greedy cover. -/
  | smallestFit
deriving Repr, DecidableEq

/-- Insert an amount into a descending list.  A plain structurally
recursive insertion sort is used instead of an opaque library sort so
that the worked examples reduce by kernel computation. -/
def insertDesc (a : Amount) : List Amount → List Amount
  | [] => [a]
  | b :: bs => if a ≥ b then a :: b :: bs else b :: insertDesc a bs

/-- Sort amounts in descending order. -/
def sortDesc : List Amount → List Amount
  | [] => []
  | a :: as => insertDesc a (sortDesc as)

/-- Insert an amount into an ascending list. -/
def insertAsc (a : Amount) : List Amount → List Amount
  | [] => [a]
  | b :: bs => if a ≤ b then a :: b :: bs else b :: insertAsc a bs

/-- Sort amounts in ascending order. -/
def sortAsc : List Amount → List Amount
  | [] => []
  | a :: as => insertAsc a (sortAsc as)

/-- Take amounts from the front until the remaining target is covered.
If the pool is exhausted first, the result is the whole pool. -/
def takeUntilCovered (target : Amount) : List Amount → List Amount
  | [] => []
  | a :: rest =>
      if target ≤ a then [a]
      else a :: takeUntilCovered (target - a) rest

/-- Largest-first selection: descending order, then take until covered.
This is a greedy cover, not Core's BnB search. -/
def largestFirst (target : Amount) (coins : List Amount) : List Amount :=
  takeUntilCovered target (sortDesc coins)

/-- The first amount in the list that covers `target`, if any. -/
def firstCover (target : Amount) : List Amount → Option Amount
  | [] => none
  | a :: rest => if target ≤ a then some a else firstCover target rest

/-- Smallest-fit selection.  If some single coin covers the target, take
the smallest such coin (the first in ascending order).  Otherwise take
the ascending prefix that first covers the target.  This is a
deterministic heuristic, not an optimal-subset algorithm. -/
def smallestFit (target : Amount) (coins : List Amount) : List Amount :=
  let asc := sortAsc coins
  match firstCover target asc with
  | some a => [a]
  | none => takeUntilCovered target asc

/-- Every selected amount is an amount that was offered. -/
def Subset (selected coins : List Amount) : Prop :=
  ∀ a ∈ selected, a ∈ coins

/-- The selected amounts cover the target. -/
def Covers (target : Amount) (selected : List Amount) : Prop :=
  target ≤ total selected

/-- Selection validity: no invented value, and enough value to meet the
target.  Minimality, waste, weight and fee-rate optimality are explicitly
outside this predicate. -/
def SelectionValid (target : Amount) (coins selected : List Amount) : Prop :=
  Subset selected coins ∧ Covers target selected

/-- A selection together with the target and the strategy that produced
it. -/
structure Selection where
  /-- The amount the selection must cover. -/
  target : Amount
  /-- The selected input amounts. -/
  selected : List Amount
  /-- The strategy that produced the selection. -/
  algorithm : SelectionAlgorithm
deriving Repr, DecidableEq

/-- The selection satisfies the basic validity predicate. -/
def Selection.Valid (s : Selection) (coins : List Amount) : Prop :=
  SelectionValid s.target coins s.selected

end Bitcoin.Wallet.Spend
