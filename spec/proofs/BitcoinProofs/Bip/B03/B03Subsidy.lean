import Bitcoin

/-!
# BitcoinProofs.Bip.B03.Subsidy — BIP-42 coverage audit module

BIP-42 "A finite monetary supply for Bitcoin" (Pieter Wuille, 2014).
BIP text license: **PD** (public domain) — every clause quoted below is
redistributable without restriction. Status: Deployed (soft fork).

Ground truth (VERIFIED):
* Bitcoin Core `src/validation.cpp:1833–1844 @ cce32b168` (fetched copy:
  `validation.cpp`), mainnet `nSubsidyHalvingInterval
  = 210000`, `COIN = 10^8`, `MAX_MONEY = 21·10^6·COIN`.
* Python cross-check: an independent reference implementation
  (11/11 clause checks pass, 20 pinned heights). Every `example` below is
  kernel-`decide`/`rfl` and every `theorem` is sorry-free.

## Consensus clauses extracted from the BIP text

* **C1 (pre-epoch-33 positivity)**: the subsidy is `50·COIN >> h/210000`;
  with exact (non-UB) shift semantics it is ≥ 1 satoshi for every height
  `h < 33·210000 = 6_930_000` — the subsidy never reaches zero before
  epoch 33.
* **C2 (halving arithmetic)**: `halvings = ⌊h / 210000⌋`; subsidy halves
  exactly at each 210_000-block epoch edge.
* **C3 (epoch 32 = last satoshi)**: epoch 32 (`6_720_000 ≤ h < 6_930_000`)
  pays exactly 1 satoshi; epoch 33 pays 0.
* **C4 (the BIP-42 guard itself)**: `if halvings ≥ 64 then 0` — the
  consensus replacement for C++'s undefined `int64 >> 64` behavior. This is
  what makes the supply *finite*: without it (x86 shift-mod-64) the subsidy
  would wrap back to 50 BTC at height 13_440_000.
* **C5 (cap exactness)**: total supply over all heights =
  `Σ_{k<33} 210000 · (50·COIN >> k) = 2_099_999_997_690_000 sats`
  = 21M − 2_310_000 sats, strictly below `MAX_MONEY = 2_100_000_000_000_000`.

Traceability: rules.yaml rows `INV-033` (bip_cve "BIP42") and `BLK-090`
(duplicate, bip_cve "—"), both `status: implemented` with `lean_target:
Bitcoin.Conservation.blockSubsidy` (commit 029488a filled the def —
exact-Nat `/ 2 ^ min halvings 64` form), but `test_vector_ids: []` on
both rows (F-B03-002).
-/

namespace BitcoinProofs.Bip.B03

/-! ## Reference implementation (mirror of validation.cpp:1833–1844 @ cce32b168) -/

/-- `halvings = nHeight / nSubsidyHalvingInterval` (mainnet interval 210000).
Nat-level twin of the tree's `Bitcoin.Conservation.halvingsAt` (UInt32). -/
def halvingsAt (height : Nat) : Nat := height / 210000

/-- `GetBlockSubsidy` (validation.cpp:1833–1844 @ cce32b168), exact-Nat mirror:
`50·COIN >> halvings`, with the BIP-42 guard `halvings ≥ 64 → 0`. -/
def getBlockSubsidy (height : Nat) : Nat :=
  if 64 ≤ halvingsAt height then 0 else 5000000000 >>> halvingsAt height

/-! ## Bridge to the tree's existing (implemented) pieces -/

/-- The tree's `Bitcoin.Conservation.halvingsAt` (UInt32) agrees with this
module's Nat-level halvings on representative heights. -/
example : Bitcoin.Conservation.halvingsAt 0 = halvingsAt 0 := by
  unfold Bitcoin.Conservation.halvingsAt halvingsAt; decide
example : Bitcoin.Conservation.halvingsAt 840000 = halvingsAt 840000 := by
  unfold Bitcoin.Conservation.halvingsAt halvingsAt; decide
example : Bitcoin.Conservation.halvingsAt 13440000 = halvingsAt 13440000 := by
  unfold Bitcoin.Conservation.halvingsAt halvingsAt; decide

/-- The tree's money constants (amount.h): `COIN = 10^8`,
`MAX_MONEY = 21·10^6·COIN = 2_100_000_000_000_000`. -/
example : Bitcoin.Data.COIN = 100000000 := by rfl
example : Bitcoin.Data.MAX_MONEY = 2100000000000000 := by rfl

/-! ## Pinned point values (python-cross-checked) -/

example : getBlockSubsidy 0 = 5000000000 := by rfl            -- genesis: 50 BTC
example : getBlockSubsidy 1 = 5000000000 := by rfl
example : getBlockSubsidy 209999 = 5000000000 := by rfl       -- last of epoch 0
example : getBlockSubsidy 210000 = 2500000000 := by rfl       -- first halving
example : getBlockSubsidy 419999 = 2500000000 := by rfl
example : getBlockSubsidy 420000 = 1250000000 := by rfl
example : getBlockSubsidy 629999 = 1250000000 := by rfl
example : getBlockSubsidy 840000 = 312500000 := by rfl        -- 4th halving 2024: 3.125 BTC
example : getBlockSubsidy 1049999 = 312500000 := by rfl
example : getBlockSubsidy 2099999 = 9765625 := by rfl         -- last of epoch 9
example : getBlockSubsidy 6299999 = 9 := by rfl               -- last of epoch 29
example : getBlockSubsidy 6300000 = 4 := by rfl               -- first of epoch 30
example : getBlockSubsidy 6719999 = 2 := by rfl               -- last of epoch 31
example : getBlockSubsidy 6720000 = 1 := by rfl               -- first of epoch 32: 1 sat
example : getBlockSubsidy 6929999 = 1 := by rfl               -- last 1-sat block
example : getBlockSubsidy 6930000 = 0 := by rfl               -- FIRST zero block (epoch 33)
example : getBlockSubsidy 13439999 = 0 := by rfl              -- last of epoch 63
example : getBlockSubsidy 13440000 = 0 := by rfl              -- BIP42 guard fires here
example : getBlockSubsidy 2147483647 = 0 := by rfl            -- int32-max height
example : getBlockSubsidy 4000000000 = 0 := by rfl            -- far future

/-! ## Helper shift laws (Nat, exact — the non-UB semantics BIP-42 mandates) -/

theorem two32_le_subsidy_seed : 2 ^ 32 ≤ 5000000000 := by decide

theorem one_le_shift_of_le_32 : ∀ k ≤ 32, 1 ≤ 5000000000 >>> k := by
  intro k hk
  rw [Nat.shiftRight_eq_div_pow]
  apply Nat.div_pos
  · calc 2 ^ k ≤ 2 ^ 32 := Nat.pow_le_pow_right (by decide) hk
      _ ≤ 5000000000 := two32_le_subsidy_seed
  · exact Nat.pow_pos (by decide)

theorem shift_zero_of_ge_33 : ∀ k ≥ 33, 5000000000 >>> k = 0 := by
  intro k hk
  rw [Nat.shiftRight_eq_div_pow]
  apply Nat.div_eq_of_lt
  have h33 : 5000000000 < 2 ^ 33 := by decide
  have hmono : 2 ^ 33 ≤ 2 ^ k := Nat.pow_le_pow_right (by decide) hk
  exact Nat.lt_of_lt_of_le h33 hmono

/-- Shift antitonicity along an exponent increment. -/
theorem shift_antitone_add (k j : Nat) :
    5000000000 >>> (k + j) ≤ 5000000000 >>> k := by
  rw [Nat.shiftRight_eq_div_pow, Nat.shiftRight_eq_div_pow, Nat.pow_add,
    ← Nat.div_div_eq_div_mul]
  exact Nat.div_le_self _ _

/-! ## The two behaviour branches of GetBlockSubsidy -/

theorem subsidy_eq_shift (h : Nat) (hlt : halvingsAt h < 64) :
    getBlockSubsidy h = 5000000000 >>> halvingsAt h := by
  unfold getBlockSubsidy
  have hnle : ¬(64 ≤ halvingsAt h) := by omega
  rw [if_neg hnle]

theorem subsidy_eq_zero (h : Nat) (hge : 64 ≤ halvingsAt h) :
    getBlockSubsidy h = 0 := by
  unfold getBlockSubsidy
  rw [if_pos hge]

/-! ## C1 — the subsidy never reaches zero before epoch 33 -/

theorem subsidy_pos_of_lt_epoch33 : ∀ h < 33 * 210000, 1 ≤ getBlockSubsidy h := by
  intro h hh
  have hle : halvingsAt h ≤ 32 := by unfold halvingsAt; omega
  have hlt : halvingsAt h < 64 := Nat.lt_of_le_of_lt hle (by decide)
  rw [subsidy_eq_shift h hlt]
  exact one_le_shift_of_le_32 _ hle

theorem subsidy_zero_of_ge_epoch33 : ∀ h ≥ 33 * 210000, getBlockSubsidy h = 0 := by
  intro h hh
  have hge : 33 ≤ halvingsAt h := by unfold halvingsAt; omega
  rcases Nat.lt_or_ge (halvingsAt h) 64 with hlt | hguard
  · rw [subsidy_eq_shift h hlt]
    exact shift_zero_of_ge_33 _ hge
  · exact subsidy_eq_zero h hguard

/-- C1 as an iff: positive exactly before epoch 33. -/
theorem subsidy_pos_iff_lt_epoch33 (h : Nat) :
    0 < getBlockSubsidy h ↔ h < 33 * 210000 := by
  constructor
  · intro hpos
    apply Nat.lt_of_not_ge
    intro hge
    have h0 := subsidy_zero_of_ge_epoch33 h hge
    omega
  · exact fun hh => subsidy_pos_of_lt_epoch33 h hh

/-! ## C2 — halving arithmetic at every epoch edge (k = 0..32) -/

theorem subsidy_halving_edges : ∀ k < 33,
    getBlockSubsidy (k * 210000) = 5000000000 >>> k := by
  intro k hk
  have hhalv : halvingsAt (k * 210000) = k := by unfold halvingsAt; omega
  have hlt : halvingsAt (k * 210000) < 64 := by
    unfold halvingsAt at hhalv ⊢; omega
  rw [subsidy_eq_shift _ hlt, hhalv]

/-! ## C3 — epoch 32 pays the last satoshi; epoch 33 pays nothing -/

theorem subsidy_epoch32_one : ∀ h, halvingsAt h = 32 → getBlockSubsidy h = 1 := by
  intro h hh
  rw [subsidy_eq_shift h (by unfold halvingsAt at hh ⊢; omega), hh]
  rw [Nat.shiftRight_eq_div_pow]

theorem subsidy_epoch33_zero : ∀ h, halvingsAt h = 33 → getBlockSubsidy h = 0 := by
  intro h hh
  rw [subsidy_eq_shift h (by unfold halvingsAt at hh ⊢; omega), hh]
  rw [Nat.shiftRight_eq_div_pow]

/-! ## C4 — the BIP-42 guard: `halvings ≥ 64 → 0`, and the UB-mutant it kills -/

/-- C4 (verbatim BIP-42/Core guard): beyond halving 63 the subsidy is 0.
The supply is already finite at epoch 33 (`shift_zero_of_ge_33`); this guard
closes the shift-count corner. -/
theorem subsidy_zero_of_guard : ∀ h, 64 ≤ halvingsAt h → getBlockSubsidy h = 0 :=
  subsidy_eq_zero

/-- The x86 UB model (shift count taken mod 64) that BIP-42 replaces: at
halving 64 it would wrap the subsidy back to 50 BTC. -/
def subsidyWrapMutant (height : Nat) : Nat :=
  5000000000 >>> (halvingsAt height % 64)

/-- Mutant killer: at height 13_440_000 (first block of epoch 64) the BIP-42
guard pays 0 while the UB-wraparound model pays 5_000_000_000. A missing
`halvings ≥ 64` guard is thus detectable by this single pin. -/
theorem guard_mutant_killed :
    getBlockSubsidy 13440000 = 0 ∧ subsidyWrapMutant 13440000 = 5000000000 := by
  constructor <;> rfl

/-- And the models diverge across the whole of epoch 64: BIP-42 pays 0, the
UB-wraparound model would pay 50 BTC on every one of those 210_000 blocks. -/
theorem guard_epoch64_all : ∀ h, 13440000 ≤ h ∧ h < 13650000 →
    getBlockSubsidy h = 0 ∧ 0 < subsidyWrapMutant h := by
  intro h hh
  have h64 : halvingsAt h = 64 := by unfold halvingsAt; omega
  refine ⟨?_, ?_⟩
  · rw [subsidy_eq_zero h (by unfold halvingsAt at h64 ⊢; omega)]
  · unfold subsidyWrapMutant
    rw [h64]
    have hm : 64 % 64 = 0 := by decide
    rw [hm]
    decide

/-! ## C5 — cap 21M exactness -/

/-- Subsidy paid across one whole epoch `k` (210_000 blocks, constant rate). -/
def epochSubsidyTotal (k : Nat) : Nat := 210000 * (5000000000 >>> k)

/-- Total money creation over all heights: epochs 0..32 (from epoch 33 on the
subsidy is 0, C1/C4). -/
def totalSupply : Nat :=
  (List.range 33).foldr (fun k acc => epochSubsidyTotal k + acc) 0

/-- C5 (exact): total supply = 2_099_999_997_690_000 sats = 20_999_999.9769 BTC. -/
theorem totalSupply_exact : totalSupply = 2099999997690000 := by decide

/-- C5 (cap): exactly 2_310_000 sats short of 21M — the cap is approached,
never reached. -/
theorem totalSupply_shortfall : totalSupply + 2310000 = 2100000000000000 := by
  rw [totalSupply_exact]

/-- C5 (cap): total supply is strictly below the tree's `MAX_MONEY`. -/
theorem totalSupply_lt_MAX_MONEY : (totalSupply : Int) < Bitcoin.Data.MAX_MONEY := by
  unfold Bitcoin.Data.MAX_MONEY Bitcoin.Data.COIN
  rw [totalSupply_exact]
  decide

/-- C5 (component): the 33 nonzero-epoch per-block subsidies sum to
10^10 − 11 sats (the truncation loss of 33 halvings). -/
theorem shiftSum_0_32 :
    (List.range 33).foldr (fun k acc => (5000000000 >>> k) + acc) 0
      = 9999999989 := by decide

/-- C5 (sanity): epoch 0 is the largest epoch payout: 1_050_000_000_000_000. -/
theorem epoch0_max : epochSubsidyTotal 0 = 1050000000000000 := by rfl

/-- C5 (range): every nonzero epoch's total payout stays ≤ MAX_MONEY. -/
theorem epochSubsidyTotal_le_MAX_MONEY : ∀ k < 33,
    (epochSubsidyTotal k : Int) ≤ Bitcoin.Data.MAX_MONEY := by
  intro k _
  unfold Bitcoin.Data.MAX_MONEY Bitcoin.Data.COIN
  unfold epochSubsidyTotal
  have hshift : 5000000000 >>> k ≤ 5000000000 := by
    rw [Nat.shiftRight_eq_div_pow]
    exact Nat.div_le_self _ _
  have hmono : 210000 * (5000000000 >>> k) ≤ 210000 * 5000000000 :=
    Nat.mul_le_mul_left _ hshift
  have hval : 210000 * 5000000000 = 1050000000000000 := by decide
  rw [hval] at hmono
  omega

/-! ## C8 — monotonicity: the subsidy schedule never inflates -/

theorem subsidy_antitone : ∀ a b, a ≤ b → getBlockSubsidy b ≤ getBlockSubsidy a := by
  intro a b bab
  rcases Nat.lt_or_ge (halvingsAt b) 64 with hb | hb
  · -- b in a positive epoch; a ≤ b → halvings a ≤ halvings b < 64
    have hha : halvingsAt a ≤ halvingsAt b := by unfold halvingsAt; omega
    have haa : halvingsAt a < 64 := Nat.lt_of_le_of_lt hha hb
    rw [subsidy_eq_shift a haa, subsidy_eq_shift b hb]
    -- halvingsAt b = halvingsAt a + j
    have hj : halvingsAt b = halvingsAt a + (halvingsAt b - halvingsAt a) := by omega
    rw [hj]
    exact shift_antitone_add _ _
  · -- b at halvings ≥ 64: subsidy 0
    rw [subsidy_eq_zero b hb]
    exact Nat.zero_le _

end BitcoinProofs.Bip.B03
