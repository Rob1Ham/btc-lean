import Bitcoin.Wallet.Spend.Fee

/-!
# Wallet funding arithmetic

Funding is the step after coin selection: given the selected input
amounts, the requested recipient amounts, and the fee that the final
signed transaction will need, decide how much change (if any) to create
and, for subtract-fee-from-outputs (SFFO) transactions, how much to
deduct from each recipient.

This is an arithmetic model of the relevant fragment of
`CreateTransactionInternal` (`src/wallet/spend.cpp:1089-1105` and
`:1255-1400`).  It deliberately ignores selection policy: the caller
supplies the already-selected inputs and the already-computed fee.

## Modes modeled

* **Change-to-source** (`fundWithChange`): the selected inputs pay the
  recipients and the fee; any surplus at or above `minViableChange` is
  returned to the wallet as a change output.  Core's
  `SelectionResult::GetChange` computes the same residual
  (`src/wallet/coinselection.cpp:1043-1060`), and
  `src/wallet/spend.cpp:1259-1271` inserts the change output.
* **Subtract fee from outputs** (`fundSubtractFee`): the fee is split
  equally over the flagged recipients, with the first flagged recipient
  paying the remainder (`src/wallet/spend.cpp:1357-1394`).  Change is
  computed *before* the deduction, as in Core's `m_use_effective =
  false` branch (`src/wallet/coinselection.cpp:1051-1053`).

## What is not modeled

* Coin selection itself, including effective values, waste, BnB, SRD and
  knapsack.  See `Selection.lean`.
* Transaction-size estimation.  The fee is an explicit parameter.
* Random change position (`src/wallet/spend.cpp:1262-1268`) and output
  shuffling: outputs are kept in caller order; change is appended.
* Change-target randomization (`GenerateChangeTarget`,
  `src/wallet/spend.cpp:1186`).
* The signed negative `to_reduce` overpay branch.  Core permits
  `fee_needed < current_fee`, so `to_reduce` at `src/wallet/spend.cpp:1359`
  may be negative and increase recipient outputs.  The laws below cover
  the ordinary `0 ≤ to_reduce` case; the function still evaluates for
  negative values but no non-negativity law is claimed there.
* Dust checks: the model exposes the resulting outputs and the `change`
  field; `Laws.lean` states the dust law under an explicit
  `minViableChange ≥ dustThreshold` hypothesis.  Core performs the
  per-output `IsDust` check at `src/wallet/spend.cpp:1379-1386`.
-/

namespace Bitcoin.Wallet.Spend

open Bitcoin.Data

/-- Sum of a list of amounts.  This is the wallet-side analogue of
`CAmount` accumulators (`SelectionResult::GetSelectedValue`,
`src/wallet/coinselection.cpp:954-957`). -/
def total (l : List Amount) : Amount :=
  l.foldr (fun a acc => a + acc) 0

/-- Number of `true` entries in a flag list; the `k` in Core's equal
split `to_reduce / outputs_to_subtract_fee_from`
(`src/wallet/spend.cpp:1371-1376`). -/
def countTrue : List Bool → Nat
  | [] => 0
  | true :: rest => countTrue rest + 1
  | false :: rest => countTrue rest

/-- Equal split of `fee` over `k` recipients, with the remainder going
to the first one.  This is exactly Core's two-step subtraction:
`fee / k` from every flagged output and `fee % k` from the first
(`src/wallet/spend.cpp:1371-1376`).  Written as
`fee - k * (fee / k)` for the first share, which equals
`fee / k + fee % k` for `0 ≤ fee` and `0 < k`. -/
def feeShares (fee : Amount) : Nat → List Amount
  | 0 => []
  | k + 1 =>
      let q := fee / ((k + 1 : Nat) : Amount)
      (fee - (k : Amount) * q) :: List.replicate k q

/-- Apply precomputed per-recipient deductions.  A `true` flag consumes
the next share; a `false` flag leaves the output unchanged and does not
consume a share.  When the flags are exhausted, remaining outputs
(notably an appended change output) are left untouched. -/
def assignShares : List Amount → List Bool → List Amount → List Amount
  | [], _, _ => []
  | o :: os, [], _ => o :: assignShares os [] []
  | o :: os, true :: fs, s :: ss => (o - s) :: assignShares os fs ss
  | o :: os, true :: fs, [] => o :: assignShares os fs []
  | o :: os, false :: fs, ss => o :: assignShares os fs ss

/-- Subtract `fee` from the flagged outputs using Core's equal split.
`flags` correspond to the original recipient outputs; any change output
appended by the caller is not flagged and is not reduced. -/
def subtractFeeFromOutputs (outputs : List Amount) (flags : List Bool)
    (fee : Amount) : List Amount :=
  assignShares outputs flags (feeShares fee (countTrue flags))

/-- The result of a funding computation: the input amounts, the final
output amounts (recipients plus change, in caller order), the fee
actually paid, and the change output if one was created. -/
structure Funded where
  /-- Selected input amounts. -/
  inputs : List Amount
  /-- Final output amounts, including change when present. -/
  outputs : List Amount
  /-- Fee paid, `total inputs - total outputs`. -/
  fee : Amount
  /-- Change amount, `none` when no change output was created. -/
  change : Option Amount
deriving Repr, DecidableEq

namespace Funded

/-- Total selected input value. -/
def totalIn (f : Funded) : Amount := total f.inputs

/-- Total output value. -/
def totalOut (f : Funded) : Amount := total f.outputs

/-- Value conservation: inputs equal outputs plus fee. -/
def Conserves (f : Funded) : Prop :=
  f.totalIn = f.totalOut + f.fee

/-- The fee is non-negative. -/
def FeeNonneg (f : Funded) : Prop :=
  0 ≤ f.fee

/-- Every output amount is non-negative (Core rejects negative outputs
before signing; `src/consensus/tx_check.cpp:31-42`). -/
def AllOutputsNonneg (f : Funded) : Prop :=
  ∀ a ∈ f.outputs, 0 ≤ a

/-- If change exists, it is non-negative. -/
def ChangeNonneg (f : Funded) : Prop :=
  ∀ c, f.change = some c → 0 ≤ c

/-- If change exists, it is at least `minViable`. -/
def ChangeAtLeast (f : Funded) (minViable : Amount) : Prop :=
  ∀ c, f.change = some c → minViable ≤ c

/-- If change exists, it is not below a dust threshold. -/
def NoDustChange (f : Funded) (dust : Amount) : Prop :=
  ∀ c, f.change = some c → dust ≤ c

/-- If change exists, it is at least `minViable` and at least `dust`. -/
def ChangePolicy (f : Funded) (minViable dust : Amount) : Prop :=
  ∀ c, f.change = some c → minViable ≤ c ∧ dust ≤ c

end Funded

/-- Change-to-source funding: the surplus of inputs over outputs and the
required fee is returned as change when it reaches `minViableChange`;
otherwise no change output is created and the entire surplus becomes
fee.  This mirrors `SelectionResult::GetChange`
(`src/wallet/coinselection.cpp:1043-1060`) and the insertion decision at
`src/wallet/spend.cpp:1259-1271`. -/
def fundWithChange (inputs outputs : List Amount) (feeNeeded minViableChange : Amount) :
    Funded :=
  let raw := total inputs - total outputs - feeNeeded
  if minViableChange ≤ raw then
    { inputs := inputs
      outputs := outputs ++ [raw]
      fee := feeNeeded
      change := some raw }
  else
    { inputs := inputs
      outputs := outputs
      fee := total inputs - total outputs
      change := none }

/-- Subtract-fee-from-outputs funding.  Change is first computed without
reserving the fee (`src/wallet/coinselection.cpp:1051-1053`), then
`to_reduce = feeNeeded - currentFee` is distributed over the flagged
recipients (`src/wallet/spend.cpp:1357-1394`).  The resulting fee is
exactly `feeNeeded`; any excess thrown to fee when no change output is
created is accounted for in `currentFee`, exactly as in Core. -/
def fundSubtractFee (inputs outputs : List Amount) (flags : List Bool)
    (feeNeeded minViableChange : Amount) : Funded :=
  let raw := total inputs - total outputs
  let madeChange := minViableChange ≤ raw
  let preliminary := if madeChange then outputs ++ [raw] else outputs
  let changeAmount := if madeChange then some raw else none
  let currentFee := total inputs - total preliminary
  let toReduce := feeNeeded - currentFee
  { inputs := inputs
    outputs := subtractFeeFromOutputs preliminary flags toReduce
    fee := feeNeeded
    change := changeAmount }

end Bitcoin.Wallet.Spend
