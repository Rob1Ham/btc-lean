import Bitcoin.Numeric.Amount

/-!
# Wallet fee and dust arithmetic

This file models the arithmetic that a wallet needs to turn a requested
fee rate and a transaction size into a fee, and a relay fee rate and an
output size into a dust threshold.  It is deliberately *not* a size
estimator: signed input weights, serialized output sizes, and the
static transaction overhead are explicit parameters supplied by the
caller.

Ground truth: Bitcoin Core @ `cce32b168` (a v21.99 development
snapshot).

* `CFeeRate::GetFee` — `src/policy/feerate.cpp:21-28`, delegating to
  `FeePerVSize::EvaluateFeeUp` (`src/util/feefrac.h:144-175`), whose
  common non-negative branch is exactly `CeilDiv(fee * vsize, size)`
  (`src/util/overflow.h:64-74`).  The integer division rounds up, so a
  non-integral satoshi amount is charged one extra satoshi.
* `CFeeRate` from satoshis per kvB — `src/policy/feerate.h:40-41`.
* Virtual size — `src/policy/policy.cpp:395-398`.
* Dust threshold — `src/policy/policy.cpp:27-64`; the default relay
  rate `DUST_RELAY_TX_FEE = 3000` is `src/policy/policy.h:63-68`.

## What is not modeled

* Negative fee rates.  Core's signed fallback `Div` path
  (`src/util/feefrac.h:165-168`) is not reproduced; the laws below
  assume a well-formed rate (`0 ≤ fee`).
* Fee bumping, ancestor/descendant fees, and `GetTotalBumpFees`
  (`src/wallet/spend.cpp:1337`).
* Any transaction-size estimation.  `CalculateMaximumSignedTxSize`
  (`src/wallet/spend.cpp:152-176`) depends on descriptors and signature
  grinding; here the weight inputs are parameters.
* Unspendable `OP_RETURN` outputs, whose dust threshold Core special
  cases to zero (`src/policy/policy.cpp:43-44`).
* Taproot's lower minimum satisfaction: Core keeps the segwit-v0
  estimate for dust (`src/policy/policy.cpp:50-54`).
-/

namespace Bitcoin.Wallet.Spend

open Bitcoin.Data

/-- A fee rate stored as an exact fraction `fee / size`, mirroring
`CFeeRate`'s internal `FeePerVSize` representation
(`src/policy/feerate.h:40-57`).  `size` is a virtual-byte count, not a
satoshi amount. -/
structure FeeRate where
  /-- Fee numerator in satoshis. -/
  fee : Amount
  /-- Size denominator in virtual bytes. -/
  size : Nat
deriving Repr, DecidableEq

namespace FeeRate

/-- The ordinary wallet constructor: `n` satoshis per 1000 virtual
bytes (`src/policy/feerate.h:40-41`). -/
def ofSatPerKvB (n : Amount) : FeeRate :=
  { fee := n, size := 1000 }

/-- A rate suitable for the rounding-up laws: a positive denominator and
a non-negative fee numerator. -/
def wellFormed (r : FeeRate) : Prop :=
  0 < r.size ∧ 0 ≤ r.fee

end FeeRate

/-- Ceiling division on `Amount := Int`, written in Core's
non-negative form.  For `0 ≤ n` and `0 < d` this is the unsigned
`CeilDiv(n, d)` of `src/util/overflow.h:64-74`:
`n / d + (n % d != 0)`.  A zero denominator yields zero, matching an
empty `FeePerVSize` (`src/policy/feerate.cpp:24`). -/
def ceilDiv (n : Amount) (d : Nat) : Amount :=
  if d = 0 then 0 else (n + (d : Amount) - 1) / (d : Amount)

/-- `CFeeRate::GetFee`: the fee for `vsize` virtual bytes at this rate,
rounded up (`src/policy/feerate.cpp:21-28`,
`src/util/feefrac.h:175`). -/
def FeeRate.getFee (r : FeeRate) (vsize : Nat) : Amount :=
  ceilDiv (r.fee * (vsize : Amount)) r.size

/-- Fee for an already-computed virtual size.  This is the form used by
`fee_needed` in `src/wallet/spend.cpp:1337`. -/
def requiredFee (r : FeeRate) (vsize : Nat) : Amount :=
  r.getFee vsize

/-- The BIP141 witness scale factor (`WITNESS_SCALE_FACTOR = 4`),
used by `GetVirtualTransactionSize`
(`src/policy/policy.cpp:395-398`). -/
def WITNESS_SCALE_FACTOR : Nat := 4

/-- `GetVirtualTransactionSize`: weight rounded up to whole virtual
bytes (`src/policy/policy.cpp:395-398`). -/
def virtualSize (weight : Nat) : Nat :=
  (weight + WITNESS_SCALE_FACTOR - 1) / WITNESS_SCALE_FACTOR

/-- Explicit inputs to a signed-transaction size estimate.

The weights are *supplied*, not guessed.  `staticWeight` covers the
version, locktime, input/output counts and serialized outputs;
`inputWeights` contains one maximum signed input weight per selected
coin; `witnessMarkerFlagWeight` is 2 when at least one input is segwit
and 0 otherwise (`src/wallet/spend.cpp:152-176`). -/
structure VsizeInputs where
  /-- Weight of everything that is not a signed input. -/
  staticWeight : Nat
  /-- Maximum signed weight of each selected input, in input order. -/
  inputWeights : List Nat
  /-- BIP144 marker and flag weight: 2 for a witness transaction. -/
  witnessMarkerFlagWeight : Nat
deriving Repr, DecidableEq

/-- Total estimated transaction weight from explicit per-input and
static weights (`src/wallet/spend.cpp:152-176`). -/
def estimatedWeight (v : VsizeInputs) : Nat :=
  v.staticWeight + v.inputWeights.sum + v.witnessMarkerFlagWeight

/-- Estimated virtual size from explicit weight inputs. -/
def estimatedVsize (v : VsizeInputs) : Nat :=
  virtualSize (estimatedWeight v)

/-- Required fee from a rate and an explicit size estimate. -/
def requiredFeeFromEstimate (r : FeeRate) (v : VsizeInputs) : Amount :=
  requiredFee r (estimatedVsize v)

/-- Default dust relay fee, in satoshis per 1000 virtual bytes
(`src/policy/policy.h:63-68`). -/
def DUST_RELAY_TX_FEE : Amount := 3000

/-- Bytes added to a serialized output when computing dust: the
input-side size of a spend at the segwit-v0 estimate, or the legacy
estimate, exactly as in `src/policy/policy.cpp:55-61`.

For a witness program Core adds `32 + 4 + 1 + (107 / 4) + 4 = 67`;
otherwise it adds `32 + 4 + 1 + 107 + 4 = 148`. -/
def dustSpendSize (witnessProgram : Bool) : Nat :=
  if witnessProgram then
    32 + 4 + 1 + (107 / WITNESS_SCALE_FACTOR) + 4
  else
    32 + 4 + 1 + 107 + 4

/-- Dust threshold for a spendable output: the serialized output size
plus the input-side spend size, charged at the dust relay rate
(`src/policy/policy.cpp:46-64`).  The caller supplies the serialized
`txoutSize`; no serializer is embedded here. -/
def dustThreshold (r : FeeRate) (txoutSize : Nat) (witnessProgram : Bool) : Amount :=
  r.getFee (txoutSize + dustSpendSize witnessProgram)

/-- The smallest change output Core considers viable: at least one
satoshi more than the discard-rate cost of spending it, and at least the
dust threshold (`src/wallet/spend.cpp:1188-1193`). -/
def minViableChange (discardRate : FeeRate) (changeSpendVsize : Nat)
    (changeDust : Amount) : Amount :=
  let spendFee := discardRate.getFee changeSpendVsize
  if spendFee + 1 ≤ changeDust then changeDust else spendFee + 1

/-- `IsDust`: an output is dust when its value is strictly below the
threshold (`src/policy/policy.cpp:66-69`). -/
def isDust (r : FeeRate) (txoutSize : Nat) (witnessProgram : Bool)
    (value : Amount) : Prop :=
  value < dustThreshold r txoutSize witnessProgram

/-- A value is above the dust threshold (the condition Core enforces on
a newly created change output, `src/wallet/spend.cpp:1380-1386`). -/
def aboveDust (r : FeeRate) (txoutSize : Nat) (witnessProgram : Bool)
    (value : Amount) : Prop :=
  dustThreshold r txoutSize witnessProgram ≤ value

end Bitcoin.Wallet.Spend
