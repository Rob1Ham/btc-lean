import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Ledger.Utxo
import Bitcoin.Conservation.Interface

/-!
# BitcoinProofs.Conservation.Thms — W08's T1 theorem tier (sorry-free)

Zero-dependency (imports only the `core` package; mathlib is NOT needed for
any theorem here, so this file also builds where mathlib resolution is slow).

## The InputAuth abstraction — what we are NOT assuming

`InputAuth` (as frozen in `Bitcoin.Conservation`) is an *arbitrary predicate*
`TxIn → Prop`; every conservation theorem is ∀-quantified over it. Reading:

    InputAuth i  ≈  "the signature checker accepts input i"

We are NOT assuming:

* anything about signatures, hashes, ECDSA or Schnorr — the crypto tower
  (W13 seam / W14 curve) plugs in **under** this abstraction by
  instantiating `InputAuth := fun i => VerifyScript ... i ...`;
* that `InputAuth` is decidable, deterministic, sound, or complete;
* that the inputs exist — existence is the separate `hexists` hypothesis
  (Core checks it first, `HaveInputs`, coins.cpp:322-331, error
  `bad-txns-inputs-missingorspent` = `ConservationError.inputMissing`).

The theorems hold for `InputAuth := fun _ => True` (no authorization at all)
and for the real `VerifyScript`-backed predicate alike; this is C4's finding
that 31/55 portfolio theorems need zero crypto.

## Theorem map (C4 portfolio IDs)

| C4 ID    | theorem here                        | status |
|----------|-------------------------------------|--------|
| THM-005  | `MAX_MONEY_lt_int64_max`            | VERIFIED |
| THM-015  | `subsidy_le_max`                    | VERIFIED |
| THM-016  | `subsidyNat_zero_ge33` + core's `subsidy_epoch32_one/_epoch33_zero` | VERIFIED |
| THM-036  | core's `single_tx_conservation` (+ `single_tx_fee_in_range`) | VERIFIED |
| THM-038  | `coinbaseAmountOk` + `reward_moneyRange` + `coinbase_cap_exact` | VERIFIED (arithmetic tier) |
| THM-039  | `totalIssuance_exact`/`_le_cap`/`issuance_flat`/`issuance_mono` | VERIFIED (schedule tier) |
| THM-040  | `supplyAt` + `supplyAt_le_cap`      | VERIFIED (schedule tier) |
| rules INV-030/TXV-025 | `fee_moneyRange`, `moneyRange_add` | VERIFIED |

Block-level conservation (C4 THM-037) and the chain-level cap over W12's
`applyBlock` fold are W12/W15 deliverables — deliberately NOT stated here
(see the W08 report, "handed to W12"); no `sorry` is carried for them.

## Lean-toolchain note (W08 finding, keep for future reviews)

`omega` in Lean 4.34.1 cannot process facts/goals whose `HAdd`/`Eq`/literal
applications carry the `Amount` abbrev (=`Int`) as their type argument — it
fails with "No usable constraints found" even on trivially true statements,
and `rw` with `Int` lemmas on `Amount`-α terms fails (instance-keyed
matching). Every `Amount`-level arithmetic step below is therefore discharged
by a helper stated over plain `Int` atoms (where `omega` works) and
instantiated at `Amount` atoms via term-mode `exact` (full defeq there,
because `Amount` is an `abbrev` for `Int`).
-/

namespace BitcoinProofs.Conservation

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Conservation

/-! ## Int arithmetic helpers (the omega-bridge, see module note) -/

/-- Addition of non-negative `Int`s is non-negative. -/
private theorem intAddNonneg (a b : Int) (ha : 0 ≤ a) (hb : 0 ≤ b) : 0 ≤ a + b := by
  omega

/-- The fee identity: a fee consistent with `in = out + fee` over `out ≤ in`
is non-negative (tx_verify.cpp:202-216 arithmetic). -/
theorem intFeeNonneg (x y f : Int) (hle : y ≤ x) (heq : x = y + f) : 0 ≤ f := by
  omega

/-- The full fee-range law over plain `Int`: `0 ≤ f ≤ x` given
`0 ≤ y ≤ x = y + f`. -/
theorem intFeeRange (x y f : Int) (hx1 : 0 ≤ x) (hx2 : x ≤ 2100000000000000)
    (hy1 : 0 ≤ y) (hle : y ≤ x) (heq : x = y + f) : 0 ≤ f ∧ f ≤ 2100000000000000 := by
  omega

/-- Monotonicity of `Int` addition (omega-bridge form). -/
private theorem intAddMono (a b c : Int) (h : a ≤ b) : a + c ≤ b + c := by
  omega

/-! ### The omega-bridge alphabet

Tiny `Int`-atom identities used all over the file (each one `omega`);
instantiated at `Amount` atoms via term-mode `exact`. -/

private theorem intEqAddZero (a : Int) : a = a + 0 := by omega

private theorem intZeroAddEq (a : Int) : a = 0 + a := by omega

private theorem intAddZeroL (a c : Int) : a + (0 + c) = a + c := by omega

private theorem intFromEqShift (a b c : Int) : a + (b + c) = (a + (0 + c)) + b := by omega

private theorem intAppendShift (a b c : Int) : (a + b) + c = (a + c) + b := by omega

private theorem intSumNonneg (a b : Int) (ha : 0 ≤ a) (hb : 0 ≤ b) : 0 ≤ a + (0 + b) := by
  omega

private theorem intCoverSelf (a b : Int) (hb : 0 ≤ b) : a ≤ b + (0 + a) := by
  omega

private theorem intCoverOther (a b c : Int) (hab : a ≤ b) (hc : 0 ≤ c) : a ≤ b + (0 + c) := by
  omega

/-! ## MoneyRange laws (CVE-2010-5137/5139 defense lemmas) -/

/-- `MoneyRange` is closed under addition that stays under `MAX_MONEY`
(the incremental-check pattern of tx_check.cpp:39-41 / tx_verify.cpp:191-194). -/
theorem moneyRange_add (a b : Amount) (ha : MoneyRange a = true) (hb : MoneyRange b = true)
    (h : a + b ≤ MAX_MONEY) : MoneyRange (a + b) = true := by
  obtain ⟨ha1, _⟩ := (moneyRange_eq_true_iff a).mp ha
  obtain ⟨hb1, _⟩ := (moneyRange_eq_true_iff b).mp hb
  exact (moneyRange_eq_true_iff (a + b)).mpr ⟨intAddNonneg a b ha1 hb1, h⟩

/-- The fee law (TXV-025): if `in ≥ out` and both are in MoneyRange then
`fee = in − out` is in MoneyRange — the invariant Core's final check
(tx_verify.cpp:208-216) "provably" needs. -/
theorem fee_moneyRange (vi vo : Amount) (hvi : MoneyRange vi = true)
    (hvo : MoneyRange vo = true) (hle : vo ≤ vi) : MoneyRange (vi - vo) = true := by
  obtain ⟨hvi1, hvi2⟩ := (moneyRange_eq_true_iff vi).mp hvi
  obtain ⟨hvo1, _⟩ := (moneyRange_eq_true_iff vo).mp hvo
  have gen : ∀ (a b : Int), a = b + (a - b) := by intros; omega
  have h := intFeeRange vi vo (vi - vo) hvi1 hvi2 hvo1 hle (gen vi vo)
  exact (moneyRange_eq_true_iff (vi - vo)).mpr h

/-- `MAX_MONEY` is positive and fits int64 (Core's amount.h comment:
the constant is consensus-critical; THM-005). -/
theorem MAX_MONEY_pos : 0 < MAX_MONEY := by decide

theorem MAX_MONEY_lt_int64_max : MAX_MONEY < 9223372036854775807 := by decide

/-! ## Input-side sums (`totalIn`, tx_verify.cpp:186-192) -/

/-- The value one input contributes to `totalIn`: the spent coin's value,
or 0 when the prevout is missing (Core errors *before* summing via
`HaveInputs`; the Lean error path is `ConservationError.inputMissing`). -/
def contrib (u : UtxoSet) (i : TxIn) : Amount := ((u i.prevout).map (·.value)).getD 0

/-- `totalIn` depends only on `tx.vin`: it is the left fold of `contrib`
over the input list, started at 0. -/
def totalInVin (u : UtxoSet) (l : List TxIn) : Amount :=
  l.foldl (fun acc i => acc + contrib u i) 0

/-- Core's `totalIn` step (a raw `match` on the prevout) equals the
contrib-fold's step: the `none` branch is `acc` vs `acc + 0`. -/
private theorem step_eq_add (u : UtxoSet) (acc : Amount) (i : TxIn) :
    (match u i.prevout with
     | some c => acc + c.value
     | none => acc) = acc + contrib u i := by
  unfold contrib
  cases h : u i.prevout with
  | some c => rfl
  | none => exact intEqAddZero acc

/-- Translation law: starting the contrib-fold at `x` adds `x` to the result.
(The per-step contributions do not depend on the accumulator.) -/
theorem totalInVinFrom_eq (u : UtxoSet) : ∀ (l : List TxIn) (x : Amount),
    l.foldl (fun acc i => acc + contrib u i) x = totalInVin u l + x := by
  intro l
  induction l with
  | nil => intro x; exact intZeroAddEq x
  | cons i l ih =>
      intro x
      have h1 : (i :: l).foldl (fun acc j => acc + contrib u j) x
          = l.foldl (fun acc j => acc + contrib u j) (x + contrib u i) := rfl
      have h2 : totalInVin u (i :: l) + x
          = l.foldl (fun acc j => acc + contrib u j) (0 + contrib u i) + x := rfl
      rw [h1, h2, ih (x + contrib u i), ih (0 + contrib u i)]
      exact intFromEqShift _ _ _

/-- Cons shape: one more input adds its contribution on the right. -/
theorem totalInVin_cons (u : UtxoSet) (i : TxIn) (l : List TxIn) :
    totalInVin u (i :: l) = totalInVin u l + contrib u i := by
  have h := totalInVinFrom_eq u l (0 + contrib u i)
  show l.foldl (fun acc j => acc + contrib u j) (0 + contrib u i) = _
  rw [h]
  exact intAddZeroL _ _

/-- The main bridge: the frozen core `totalIn` IS the contrib-fold over
`tx.vin` (the `none`-branch mismatch — `acc` vs `acc + 0` — is bridged by
`step_eq_add` + fold induction; it is *not* `rfl`). -/
theorem totalIn_eq (u : UtxoSet) (tx : Tx) : totalIn u tx = totalInVin u tx.vin := by
  have gen : ∀ (l : List TxIn) (acc : Amount),
      l.foldl (fun acc i =>
        match u i.prevout with
        | some c => acc + c.value
        | none => acc) acc
      = l.foldl (fun acc i => acc + contrib u i) acc := by
    intro l
    induction l with
    | nil => intro acc; rfl
    | cons i l ih =>
        intro acc
        rw [List.foldl_cons, List.foldl_cons, step_eq_add, ih]
  unfold totalIn totalInVin
  exact gen tx.vin 0

theorem totalInVin_nil (u : UtxoSet) : totalInVin u [] = 0 := rfl

/-- `totalIn` is additive over concatenating input lists (the shape W12's
`updateCoins` fold needs). -/
theorem totalInVin_append (u : UtxoSet) (a b : List TxIn) :
    totalInVin u (a ++ b) = totalInVin u a + totalInVin u b := by
  induction a with
  | nil => rw [List.nil_append, totalInVin_nil]; exact intZeroAddEq _
  | cons i l ih =>
      rw [List.cons_append, totalInVin_cons, totalInVin_cons, ih]
      exact intAppendShift _ _ _

/-- The input sum is non-negative as soon as every contributed value is
(each spent coin's value is MoneyRange-checked per input, tx_verify.cpp:191). -/
theorem totalInVin_nonneg (u : UtxoSet) : ∀ (l : List TxIn),
    (∀ i ∈ l, 0 ≤ contrib u i) → 0 ≤ totalInVin u l := by
  intro l
  induction l with
  | nil => intro _; exact Int.natCast_nonneg 0
  | cons i l ih =>
      intro h
      have h1 := totalInVinFrom_eq u l (0 + contrib u i)
      have hnn := ih (fun j hj => h j (List.mem_cons_of_mem _ hj))
      show 0 ≤ l.foldl (fun acc j => acc + contrib u j) (0 + contrib u i)
      rw [h1]
      exact intSumNonneg _ _ hnn (h i List.mem_cons_self)

/-- Each spent coin's value is covered by the input sum (the per-coin
lemma W12's UTXO-value bookkeeping needs; CVE-2010-5137 lineage). -/
theorem totalInVin_ge_contrib (u : UtxoSet) : ∀ (l : List TxIn),
    (∀ i ∈ l, 0 ≤ contrib u i) → ∀ (i : TxIn), i ∈ l → contrib u i ≤ totalInVin u l := by
  intro l
  induction l with
  | nil => intro _ i hi; cases hi
  | cons j l ih =>
      intro h i hi
      have h1 := totalInVinFrom_eq u l (0 + contrib u j)
      have hmem : ∀ k ∈ l, 0 ≤ contrib u k := fun k hk => h k (List.mem_cons_of_mem j hk)
      have hnn : 0 ≤ totalInVin u l := totalInVin_nonneg u l hmem
      show contrib u i ≤ l.foldl (fun acc k => acc + contrib u k) (0 + contrib u j)
      rw [h1]
      rcases List.mem_cons.mp hi with rfl | hin
      · exact intCoverSelf _ _ hnn
      · exact intCoverOther _ _ _ (ih hmem i hin) (h j List.mem_cons_self)

/-! ## Output-side sums (`totalOut`, primitives/transaction.cpp) -/

theorem totalOut_eq_fold (tx : Tx) : totalOut tx = tx.vout.foldl (fun a o => a + o.value) 0 := rfl

/-- Output sums of txs with non-negative outputs are non-negative
(the `bad-txns-vout-negative` precondition, TXV-004). -/
theorem totalOut_nonneg (tx : Tx) (h : ∀ o ∈ tx.vout, 0 ≤ o.value) : 0 ≤ totalOut tx := by
  have key : ∀ (l : List TxOut) (acc : Amount), (∀ o ∈ l, 0 ≤ o.value) → 0 ≤ acc →
      0 ≤ l.foldl (fun a o => a + o.value) acc := by
    intro l
    induction l with
    | nil => intro acc _ hacc; exact hacc
    | cons o l ih =>
        intro acc hmem hacc
        rw [List.foldl_cons]
        refine ih (acc + o.value) ?_ (intAddNonneg acc o.value hacc (hmem o List.mem_cons_self))
        intro m hm
        exact hmem m (List.mem_cons_of_mem _ hm)
  rw [totalOut_eq_fold]
  exact key tx.vout 0 h (Int.natCast_nonneg 0)

/-! ## Subsidy schedule (THM-015/016, validation.cpp:1833-1844) -/

/-- The subsidy on `Nat`: `50·COIN >> min halvings 64` as exact division —
Core's early return `if (halvings >= 64) return 0` coincides with the
quotient's saturation. -/
def subsidyNat (halvings : Nat) : Nat := 5000000000 / 2 ^ (min halvings 64)

/-- Link to the frozen interface function. -/
theorem blockSubsidy_eq (height : UInt32) :
    blockSubsidy height = ((subsidyNat (halvingsAt height) : Nat) : Amount) := rfl

/-- THM-016 (the 32-epoch subtlety, general form): the schedule is exactly
zero from halving 33 onward — Core's 50·COIN mantissa is exhausted. -/
theorem subsidyNat_zero_ge33 (k : Nat) (h : 33 ≤ k) : subsidyNat k = 0 := by
  have hmin : 33 ≤ min k 64 := by omega
  have hpow : (2 : Nat) ^ 33 ≤ 2 ^ (min k 64) := Nat.pow_le_pow_right (by decide) hmin
  have h33 : (2 : Nat) ^ 33 = 8589934592 := by decide
  have hlt : (5000000000 : Nat) < 2 ^ (min k 64) := by omega
  exact Nat.div_eq_of_lt hlt

/-- THM-015: the subsidy never exceeds the initial 50·COIN. -/
theorem subsidyNat_le_max (k : Nat) : subsidyNat k ≤ 5000000000 :=
  Nat.div_le_self _ _

/-- THM-015 companion: epochs 0..31 each pay at least one satoshi. -/
theorem subsidyNat_pos_le31 (k : Nat) (h : k ≤ 31) : 0 < subsidyNat k := by
  have hmin : min k 64 ≤ 31 := by omega
  have hpow : 2 ^ (min k 64) ≤ 2 ^ 31 := Nat.pow_le_pow_right (by decide) hmin
  have h31 : (2 : Nat) ^ 31 = 2147483648 := by decide
  exact Nat.div_pos (by omega) (Nat.two_pow_pos _)

/-- THM-015, interface level: `0 ≤ blockSubsidy h ≤ 50·COIN`. -/
theorem subsidy_le_max (height : UInt32) : blockSubsidy height ≤ 5000000000 := by
  rw [blockSubsidy_eq]
  exact Int.ofNat_le.mpr (subsidyNat_le_max _)

/-- Epochs 0..31 pay at least one satoshi (interface level). -/
theorem subsidy_pos (height : UInt32) (h : halvingsAt height ≤ 31) :
    0 < blockSubsidy height := by
  rw [blockSubsidy_eq]
  exact Int.ofNat_lt.mpr (subsidyNat_pos_le31 _ h)

/-- The subsidy is at most `MAX_MONEY` (needed for the coinbase reward). -/
theorem subsidy_le_MAX_MONEY (height : UInt32) : blockSubsidy height ≤ MAX_MONEY := by
  have h := subsidy_le_max height
  have h2 : (5000000000 : Amount) ≤ MAX_MONEY := by decide
  exact Int.le_trans h h2

/-- The subsidy alone is in MoneyRange (used by the coinbase reward law). -/
theorem subsidy_moneyRange (height : UInt32) : MoneyRange (blockSubsidy height) = true := by
  have h1 : 0 ≤ blockSubsidy height := Int.natCast_nonneg _
  exact (moneyRange_eq_true_iff _).mpr ⟨h1, subsidy_le_MAX_MONEY height⟩

/-! ## Issuance and the 21M cap (THM-039, schedule tier) -/

/-- Emission of epoch `k`: 210,000 blocks at the epoch's subsidy. -/
def epochEmission (k : Nat) : Nat := 210000 * subsidyNat k

/-- Issuance through the end of epoch `n-1`: `Σ_{k<n} epochEmission k`. -/
def issuanceThrough (n : Nat) : Nat := (List.range n).foldl (fun acc k => acc + epochEmission k) 0

/-- One-step unfolding of the issuance fold. -/
theorem issuance_step (n : Nat) :
    issuanceThrough (n + 1) = issuanceThrough n + epochEmission n := by
  unfold issuanceThrough epochEmission
  rw [List.range_succ, List.foldl_append, List.foldl_cons]
  rfl

/-- Issuance is monotone in the epoch bound. -/
theorem issuance_mono (n m : Nat) (h : n ≤ m) : issuanceThrough n ≤ issuanceThrough m := by
  induction m with
  | zero =>
      have : n = 0 := by omega
      subst this
      exact Nat.le_refl _
  | succ m ih =>
      rcases Nat.lt_or_ge n (m + 1) with hlt | hge
      · have hnm : n ≤ m := by omega
        have h1 := ih hnm
        rw [issuance_step]
        exact Nat.le_trans h1 (Nat.le_add_right _ _)
      · have : n = m + 1 := by omega
        subst this
        exact Nat.le_refl _

/-- The schedule is flat from epoch 33 on: no further issuance, ever. -/
theorem issuance_flat : ∀ (n : Nat), 33 ≤ n → issuanceThrough n = issuanceThrough 33 := by
  intro n
  induction n with
  | zero => intro h; exact absurd h (by omega)
  | succ n ih =>
      intro h
      rcases Nat.lt_or_ge n 33 with hlt | hge
      · have hn : n = 32 := by omega
        subst hn
        rfl
      · rw [issuance_step]
        have hz : epochEmission n = 0 := by
          unfold epochEmission
          rw [subsidyNat_zero_ge33 n hge, Nat.mul_zero]
        rw [hz, ih hge, Nat.add_zero]

/-- The total money supply: `Σ_{k<33} 210000 · (50·COIN >> k)`.
Epochs ≥ 33 contribute nothing (`subsidyNat_zero_ge33`), so this is the
full infinite geometric sum (C4 THM-039's schedule tier). -/
def totalIssuance : Nat := issuanceThrough 33

/-- The exact supply: 2,099,999,997,690,000 sats = 20,999,999.9769 BTC
(cross-checked against `Conservation/reference.py`). -/
theorem totalIssuance_exact : totalIssuance = 2099999997690000 := by
  decide

/-- THM-039: the total supply is under the 21M cap with 2,310,000 sats to
spare — the "geometric bookkeeping" bound. -/
theorem totalIssuance_le_cap : totalIssuance ≤ 21000000 * 100000000 := by
  decide

/-- ... and under `MAX_MONEY` as an `Amount`. -/
theorem totalIssuance_lt_MAX_MONEY : ((totalIssuance : Nat) : Amount) < MAX_MONEY := by
  decide

/-- Any epoch bound whatsoever caps at the total supply. -/
theorem issuance_le_totalIssuance (n : Nat) : issuanceThrough n ≤ totalIssuance := by
  rcases Nat.lt_or_ge n 33 with hlt | hge
  · exact issuance_mono n 33 (by omega)
  · rw [issuance_flat n hge]
    exact Nat.le_refl _

/-! ## Supply at a height (THM-040, schedule tier) -/

/-- Blocks of the current epoch mined up to and including `height`. -/
def blocksIntoEpoch (height : UInt32) : Nat := height.toNat % 210000 + 1

/-- Total supply issued at consensus height `height`: all completed epochs
plus the partial one. -/
def supplyAt (height : UInt32) : Nat :=
  issuanceThrough (halvingsAt height) + blocksIntoEpoch height * subsidyNat (halvingsAt height)

/-- THM-040 (cap form): the supply at ANY height is at most the total
schedule issuance — the 21M cap at consensus granularity. -/
theorem supplyAt_le_cap (height : UInt32) : supplyAt height ≤ totalIssuance := by
  unfold supplyAt
  rcases Nat.lt_or_ge (halvingsAt height) 33 with hlt | hge
  · -- partial epoch: at most 210000 blocks at the epoch's subsidy
    have hm : blocksIntoEpoch height ≤ 210000 := by
      unfold blocksIntoEpoch
      omega
    have hstep : issuanceThrough (halvingsAt height) + 210000 * subsidyNat (halvingsAt height)
        = issuanceThrough (halvingsAt height + 1) := by
      rw [issuance_step]
      rfl
    have hmul : blocksIntoEpoch height * subsidyNat (halvingsAt height)
        ≤ 210000 * subsidyNat (halvingsAt height) :=
      Nat.mul_le_mul hm (Nat.le_refl _)
    calc issuanceThrough (halvingsAt height)
        + blocksIntoEpoch height * subsidyNat (halvingsAt height)
      ≤ issuanceThrough (halvingsAt height)
        + 210000 * subsidyNat (halvingsAt height) := Nat.add_le_add_left hmul _
    _ = issuanceThrough (halvingsAt height + 1) := hstep
    _ ≤ issuanceThrough 33 := issuance_mono _ _ (by omega)
  · -- epoch ≥ 33: subsidy is 0, supply is the flat total
    rw [subsidyNat_zero_ge33 _ hge]
    unfold blocksIntoEpoch
    rw [Nat.mul_zero, Nat.add_zero, issuance_flat _ hge]
    exact Nat.le_refl _

/-! ## Coinbase value bound (THM-038, arithmetic tier) -/

/-- Core `ConnectBlock`'s block reward (validation.cpp:2608-2616): the
new coin (`blockSubsidy`) plus the recycled coin (`fees`). -/
def blockReward (height : UInt32) (fees : Amount) : Amount := blockSubsidy height + fees

/-- The block reward is in MoneyRange whenever the accumulated fee is. -/
theorem reward_moneyRange (height : UInt32) (fees : Amount)
    (hf : MoneyRange fees = true)
    (h : blockSubsidy height + fees ≤ MAX_MONEY) :
    MoneyRange (blockReward height fees) = true :=
  moneyRange_add _ _ (subsidy_moneyRange height) hf h

/-- Core's coinbase check (`bad-cb-amount`): the coinbase pays out at most
the block reward. Explicit `decide` form (the `Amount`-α `≤` goal is fed to
`decide`, never to `omega`). -/
def coinbaseAmountOk (height : UInt32) (fees : Amount) (cb : Tx) : Bool :=
  decide (totalOut cb ≤ blockReward height fees)

/-- THM-038: a coinbase claiming exactly subsidy + fees passes the check.
(The full "no inflation" statement — that Σfees really is the recyclable
surplus of the block's txs — is C4 THM-037 and lands with W12's
`updateCoins` fold; handed off, not sorry-carried.) -/
theorem coinbase_cap_exact (cb : Tx) (height : UInt32) (fees : Amount)
    (_hfees : 0 ≤ fees)
    (h : totalOut cb = blockReward height fees) :
    coinbaseAmountOk height fees cb = true := by
  refine decide_eq_true ?_
  rw [h]
  exact Int.le_refl _

end BitcoinProofs.Conservation
