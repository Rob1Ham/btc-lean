import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Ledger.Utxo

/-!
# Bitcoin.Conservation — FROZEN INTERFACE (W01)

## Ownership block (do not edit outside an interface-change PR)

Owning workstream     : W08 (Conservation / T1 start)
Dependent workstreams : W12 (ledger fold this is stated over),
                        W10 (validateTx supplies the hypotheses),
                        W15 (banks the sorry-free theorems)
Core counterpart files: src/consensus/tx_verify.cpp (CheckTxInputs:170-220
                        — value-in/value-out/fee), src/validation.cpp
                        (ConnectBlock: coinbase subsidy/fee accounting),
                        src/validation.cpp:1833-1844 (GetBlockSubsidy),
                        src/primitives/transaction.cpp (GetValueOut)
Status                : frozen 2026-10-16 by W01. W08 filled the bodies
                        (2026-10-16): all five SORRY[W01] placeholders are
                        gone; theorems below are sorry-free and L3-pinned.
                        One statement fix, sanctioned by charter §5.6
                        (statement fidelity): `single_tx_conservation` as
                        frozen was REFUTABLE (take totalIn=5, totalOut=10,
                        fee=-5: the equation holds, MoneyRange holds, yet
                        fee < 0) — the missing hypothesis is Core's
                        `bad-txns-in-belowout` precondition
                        `totalOut ≤ totalIn` (tx_verify.cpp:202-205),
                        added as `hle`. Everything else byte-identical.

## Scope (C4 portfolio T1)

Fee/sum laws, the subsidy schedule (the 32-epoch subtlety: 50·COIN ≫ 33
= 0 — the last satoshi is mined in epoch 32), and single-tx value
conservation stated **modulo InputAuth** — the one-line abstraction that
decouples T1 from the crypto tower entirely (C4 finding: 31/55 theorems
need zero crypto).
-/

namespace Bitcoin.Conservation

open Bitcoin.Data Bitcoin.Ledger

/-! ## MoneyRange bridge (`consensus/amount.h:27`)

`MoneyRange` is `decide` of the defining conjunction — the Bool test
unfolds exactly to `0 ≤ n ≤ MAX_MONEY`. This bridge is the only lemma
the conservation layer needs about it. (Complements W04's frozen
`Bitcoin.Numeric.moneyRange_iff`; same content, conservation-side name.) -/

theorem moneyRange_eq_true_iff (n : Amount) :
    MoneyRange n = true ↔ (0 ≤ n ∧ n ≤ MAX_MONEY) := by
  simp [MoneyRange]

/-! ## The InputAuth abstraction -/

section InputAuth
-- `InputAuth` — the one-line crypto abstraction (C4): an ARBITRARY
-- predicate on inputs. All T1 conservation theorems quantify over it, so
-- they hold for the real script+sighash semantics (W09/W11/W13) *and* for
-- any weaker/stronger authorization — the crypto tower can land years
-- later without touching these theorems. It is a parameter, not a fixed
-- definition.
variable (InputAuth : TxIn → Prop)

/-- `GetValueOut` (primitives/transaction.cpp): sum of output values.
Already C1-implemented as `Tx.getValueOut`; restated as the conservation
layer's entry point. -/
def totalOut (tx : Tx) : Amount := tx.getValueOut

/-- Total value of the coins spent by `tx` per the UTXO view
(CheckTxInputs' valueIn accumulation, tx_verify.cpp:186-192).
Core sums *after* `HaveInputs` succeeds; here a missing input contributes
0 and the error surfaces through `ConservationError.inputMissing`
(W10 raises it before summing — exactly Core's check order). -/
def totalIn (u : UtxoSet) (tx : Tx) : Amount :=
  tx.vin.foldl (fun acc i =>
    match u i.prevout with
    | some c => acc + c.value
    | none => acc) 0

/-- Missing-input errors surface as `totalIn = 0`-with-error in Core;
the Lean shape keeps the error explicit. -/
inductive ConservationError where
  | badTxnsInBelowout      -- "bad-txns-in-belowout"
  | badTxnsFeeOutOfRange   -- "bad-txns-fee-out-of-range"
  | inputMissing           -- "bad-txns-inputs-missing-or-spent"
deriving Repr, DecidableEq, BEq

/-- The headline theorem (C4 THM-036): if every input is authorized
and every spent coin exists, then value in = value out + fee forces a
non-negative fee. Holds for ANY `InputAuth`.
(W08 fidelity note: requires Core's `bad-txns-in-belowout` precondition
`totalOut ≤ totalIn` as hypothesis `hle`; without it the statement is
refutable — see the ownership block. tx_verify.cpp:202-205.) -/
theorem single_tx_conservation (u : UtxoSet) (tx : Tx) (fee : Amount)
    (hspendable : ∀ i ∈ tx.vin, InputAuth i)
    (hexists : ∀ i ∈ tx.vin, u i.prevout ≠ none)
    (hrange : MoneyRange (totalIn u tx) ∧ MoneyRange (totalOut tx))
    (hle : totalOut tx ≤ totalIn u tx) :
    totalIn u tx = totalOut tx + fee → fee ≥ 0 := by
  intro heq
  -- Substitute the conservation equation into `hle`, then read off the fee:
  -- totalOut ≤ totalIn = totalOut + fee  ⟹  totalOut + 0 ≤ totalOut + fee
  -- ⟹ 0 ≤ fee (tx_verify.cpp:202-216 arithmetic).
  rw [heq] at hle
  have h2 : 0 + totalOut tx ≤ fee + totalOut tx := by
    rw [Int.zero_add, Int.add_comm fee (totalOut tx)]
    exact hle
  exact (Int.add_le_add_iff_right (totalOut tx)).mp h2

/-- Corollary (INV-030 / TXV-025, the "provably unreachable" fee-range
check of tx_verify.cpp:208-216): under the same hypotheses the fee is not
merely non-negative but in full MoneyRange — `0 ≤ fee ≤ MAX_MONEY`.
This is the lemma Core's dead run-time check defends; here it is proven. -/
@[rule "INV-030", rule "TXV-025"]
theorem single_tx_fee_in_range (u : UtxoSet) (tx : Tx) (fee : Amount)
    (hexists : ∀ i ∈ tx.vin, u i.prevout ≠ none)
    (hrange : MoneyRange (totalIn u tx) ∧ MoneyRange (totalOut tx))
    (hle : totalOut tx ≤ totalIn u tx)
    (heq : totalIn u tx = totalOut tx + fee) :
    MoneyRange fee = true := by
  have h0 : 0 ≤ fee := by
    exact single_tx_conservation (InputAuth := fun _ => True) u tx fee
      (fun _ _ => trivial) hexists hrange hle heq
  obtain ⟨hI1, hI2⟩ := (moneyRange_eq_true_iff (totalIn u tx)).mp hrange.1
  obtain ⟨hO1, _⟩ := (moneyRange_eq_true_iff (totalOut tx)).mp hrange.2
  -- fee ≤ totalIn (the inputs cover the fee), hence fee ≤ MAX_MONEY:
  have hleI : fee ≤ totalIn u tx := by
    calc fee = 0 + fee := (Int.zero_add fee).symm
      _ ≤ totalOut tx + fee := Int.add_le_add_right hO1 fee
      _ = totalIn u tx := heq.symm
  have h1 : fee ≤ MAX_MONEY := Int.le_trans hleI hI2
  exact (moneyRange_eq_true_iff fee).mpr ⟨h0, h1⟩

end InputAuth

/-! ## Subsidy schedule -/

/-- Halvings at `height` (210,000-block epochs; `nSubsidyHalvingInterval`). -/
def halvingsAt (height : UInt32) : Nat := (height.toNat / 210000)

/-- `GetBlockSubsidy` (validation.cpp:1833-1844): `50·COIN >> halvings`,
with Core's two subtleties: `>> 64` guard, and the fact that 50·COIN ≫ 33 = 0
— epoch 32 pays the last satoshi (C4-verified). The `min · 64` division form
is exactly Core's early-return guard: for halvings ≥ 64 the shift saturates
and the quotient is 0, matching `if (halvings >= 64) return 0`. -/
@[rule "INV-033", rule "BLK-090"]
def blockSubsidy (height : UInt32) : Amount :=
  ((5000000000 / 2 ^ (min (halvingsAt height) 64) : Nat) : Amount)

/-- The 32-epoch subtlety (C4 probe-verified): from halving 33 on, the
subsidy is exactly 0 — Core's shift has exhausted the 50·COIN mantissa. -/
theorem subsidy_epoch33_zero (height : UInt32) (h : 33 ≤ halvingsAt height) :
    blockSubsidy height = 0 := by
  have hmin : 33 ≤ min (halvingsAt height) 64 := by omega
  have hpow : (2 : Nat) ^ 33 ≤ 2 ^ (min (halvingsAt height) 64) := by
    exact Nat.pow_le_pow_right (by decide) hmin
  have h33 : (2 : Nat) ^ 33 = 8589934592 := by decide
  have hlt : (5000000000 : Nat) < 2 ^ (min (halvingsAt height) 64) := by omega
  show ((5000000000 / 2 ^ (min (halvingsAt height) 64) : Nat) : Amount) = 0
  rw [Nat.div_eq_of_lt hlt]
  rfl

/-- The last-satoshi epoch pays exactly 1 satoshi. -/
theorem subsidy_epoch32_one (height : UInt32) (h : halvingsAt height = 32) :
    blockSubsidy height = 1 := by
  show ((5000000000 / 2 ^ (min (halvingsAt height) 64) : Nat) : Amount) = 1
  rw [h]
  rfl

/-- **INV-033**, theorem face for the schedule: `GetBlockSubsidy` is
`50·COIN >> halvings` for `halvings < 64`, and `0` once the BIP42 guard
`halvings ≥ 64` fires (validation.cpp:1833-1844 @cce32b168).  The
definition `blockSubsidy` is written in division form; this theorem is
the shift-form statement the row checks. -/
@[rule "INV-033"]
theorem blockSubsidy_eq_shift (height : UInt32) :
    blockSubsidy height =
      (if halvingsAt height < 64
       then (((5000000000 >>> halvingsAt height) : Nat) : Amount)
       else 0) := by
  unfold blockSubsidy
  by_cases h : halvingsAt height < 64
  · rw [if_pos h, Nat.min_eq_left (Nat.le_of_lt h), Nat.shiftRight_eq_div_pow]
  · rw [if_neg h, Nat.min_eq_right (by omega : 64 ≤ halvingsAt height)]
    exact congrArg Int.ofNat
      (Nat.div_eq_of_lt (by decide : (5000000000 : Nat) < 2 ^ 64))

/-- **INV-033**, with the row's `50·COIN` mantissa made explicit. -/
@[rule "INV-033"]
theorem blockSubsidy_eq_shift_coin (height : UInt32) :
    blockSubsidy height =
      (if halvingsAt height < 64
       then ((((50 * COIN).toNat >>> halvingsAt height) : Nat) : Amount)
       else 0) := by
  rw [blockSubsidy_eq_shift]
  have hcoin : (50 * COIN).toNat = 5000000000 := by decide
  rw [hcoin]

/-- **INV-033**: the BIP42 tail — once `halvings ≥ 64`, the subsidy is
exactly zero (Core's early return). -/
@[rule "INV-033"]
theorem blockSubsidy_zero_ge64 (height : UInt32)
    (h : 64 ≤ halvingsAt height) : blockSubsidy height = 0 := by
  rw [blockSubsidy_eq_shift, if_neg (by omega)]

/-! ## L3 axiom pins (D2): drift on any of these fails the build -/

/--
info: 'Bitcoin.Conservation.subsidy_epoch33_zero' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in #print axioms Bitcoin.Conservation.subsidy_epoch33_zero

/--
info: 'Bitcoin.Conservation.subsidy_epoch32_one' does not depend on any axioms
-/
#guard_msgs in #print axioms Bitcoin.Conservation.subsidy_epoch32_one

/--
info: 'Bitcoin.Conservation.single_tx_conservation' depends on axioms: [propext]
-/
#guard_msgs in #print axioms Bitcoin.Conservation.single_tx_conservation

/--
info: 'Bitcoin.Conservation.single_tx_fee_in_range' depends on axioms: [propext]
-/
#guard_msgs in #print axioms Bitcoin.Conservation.single_tx_fee_in_range

end Bitcoin.Conservation
