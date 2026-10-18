import Bitcoin.Crypto.EcdsaDeep.EntryWired

/-!
# FuelDischarge — discharging the structural mirror's `hE`/`hN` fuel-completion hypotheses (the discharge layer)

the structural mirror's crown (`VerifyStruct.verifyStructG_eq_verifyImpl`, commit 6aee3e9)
reduces `verifyStruct = verifyImpl` to two universal-completion
hypotheses at the fixed fuel list `FL := zeros 600`:

* `hE : ∀ d < P, egcdLDone FL P d = true`,
* `hN : ∀ s < n, egcdLDone FL n s = true`.

This file DISCHARGES both, unconditionally, and lands the resulting
unconditional crowns (nothing in the structural-mirror, alternate-entry, verification-equation, and Schnorr-equation layers edited):

* `egcdLDone_zeros_even` — Lamé two-step halving: `0 < b < 2^j` ⇒
  `egcdLDone (zeros (2*j+2)) a b = true` (NO primality, general in `a`;
  every two cons cells the `b`-value at-least-halves).
* `egcdLDone_FL_of_lt` — any `m < 2^256`, `d < m`: fuel `FL` suffices
  (slot `j = 299`: `2*299+2 = 600`; `2^256 < 2^299` by kernel `decide`).
* `hE_uncond` / `hN_uncond` — the two hypotheses, discharged
  (`P < 2^256` and `n_lt_two256`, both kernel `decide` literals).
* `verifyStruct_eq_verifyImpl` — THE UNCONDITIONAL CROWN.
* `verifyStructEq'_uncond`, `ecdsaEntryWired_eq_uncond`,
  `txCheckerWiredOf_eq_uncond` — the alternate-entry layer's `EntryWired` slot and its two
  production-equality instantiations, no hypotheses left.

VERIFIED: this file is sorry-free and every theorem's axiom footprint is
⊆ `[propext, Classical.choice, Quot.sound]` (pinned footprints,
`spec/core`, zero `sorryAx`, zero custom axioms; the no-axiom policy clean:
no `native_decide`, the only kernel computation is literal `decide` on
`P`/`n`/`2^299` bounds). PROPOSED-NOT-HERE: nothing — the structural-mirror interface
is closed. Production may still keep the compiled `verifyImpl` seam; the
deep lane is now an equality, not a hypothesis.
-/

set_option exponentiation.threshold 300

namespace Bitcoin.Crypto.EcdsaDeep.FuelDischarge

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Curve.Mod
open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Seam.Der
open Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.EcdsaDeep.EntryWired
open Bitcoin.Crypto.EcdsaDeep.VerifyStruct

/-- `egcdLDone` on a zero divisor is `true` at any fuel. -/
theorem egcdLDone_zero (fs : List Nat) (a : Nat) : egcdLDone fs a 0 = true := by
  cases fs with
  | nil => simp [egcdLDone]
  | cons f fs => simp [egcdLDone]

/-- **Lamé two-step halving**: `0 < b < 2^j` ⇒ `egcdLDone` holds at
fuel `zeros (2*j+2)`. The pair `(a,b) → (b,a%b) → (a%b,b%(a%b))`
satisfies `b % (a%b) ≤ b/2` (either `a%b ≤ b/2` and the remainder is
smaller, or `b/(a%b) = 1` and it is `b - a%b`), so every two cons cells
the `b`-value at-least-halves: `2j` cells cover `b < 2^j`, `+2` the
final zero step. No primality, no `a`-`b` relation. -/
theorem egcdLDone_zeros_even : ∀ (j a b : Nat), b < 2 ^ j → 0 < b →
    egcdLDone (zeros (2 * j + 2)) a b = true := by
  intro j
  induction j with
  | zero =>
    intro a b hb h0
    have h1 : (2 : Nat) ^ 0 = 1 := Nat.pow_zero 2
    rw [h1] at hb
    omega
  | succ j ih =>
    intro a b hb h0
    have hke : 2 * (j + 1) + 2 = 2 * j + 4 := by omega
    rw [hke]
    have hbne' : b ≠ 0 := by
      intro hh
      rw [hh] at h0
      exact absurd h0 (by omega)
    obtain ⟨c, hc⟩ : ∃ c : Nat, a % b = c := ⟨_, rfl⟩
    have hclt : c < b := by
      have hm := Nat.mod_lt a h0
      rw [hc] at hm
      exact hm
    -- two cons cells: `(b==0) || ((a%b==0) || egcdLDone (zeros (2*j+2)) ...)`
    show ((b == 0) || ((a % b == 0)
      || egcdLDone (zeros (2 * j + 2)) (a % b) (b % (a % b)))) = true
    have hbF : (b == 0) = false := by
      cases hbb : (b == 0) with
      | true  => exact absurd (Nat.beq_eq.mp hbb) hbne'
      | false => rfl
    rw [hbF]
    simp only [Bool.false_or]
    cases hc0 : (a % b == 0) with
    | true => simp
    | false =>
      have hcne : a % b ≠ 0 := fun hh => by rw [hh] at hc0; exact absurd hc0 (by decide)
      simp only [Bool.false_or]
      obtain ⟨d, hd⟩ : ∃ d : Nat, b % (a % b) = d := ⟨_, rfl⟩
      rw [hd]
      -- `d = b % c ≤ b/2` under `c = a % b ≠ 0`
      have hdlt : d ≤ b / 2 := by
        obtain ⟨q, r, hq, hr, hqr⟩ :
            ∃ q r : Nat, b / (a % b) = q ∧ b % (a % b) = r ∧ (a % b) * q + r = b :=
          ⟨_, _, rfl, rfl, Nat.div_add_mod b (a % b)⟩
        rw [hd] at hr
        rw [hc] at hq hqr
        have hdltc : d < c := by
          have hm := Nat.mod_lt b (Nat.pos_of_ne_zero hcne)
          rw [hd, hc] at hm
          exact hm
        by_cases hcb : c ≤ b / 2
        · omega
        · have h2c : 2 * c > b := by omega
          have hge : 1 ≤ q := by
            by_cases hqge : 1 ≤ q
            · exact hqge
            · have hq0 : q = 0 := by omega
              rw [hq0] at hqr
              omega
          have hle : q ≤ 1 := by
            by_cases hqle : q ≤ 1
            · exact hqle
            · have hq2 : 2 * c ≤ c * q := by
                simpa [Nat.mul_comm q c] using
                  Nat.mul_le_mul (by omega : 2 ≤ q) (Nat.le_refl c)
              omega
          have hq1 : q = 1 := by omega
          rw [hq1] at hqr
          omega
      by_cases hdz : d = 0
      · rw [hdz]
        exact egcdLDone_zero _ _
      · have hdpos : 0 < d := by omega
        have hd2j : d < 2 ^ j := by
          have hbb : b ≤ 2 * 2 ^ j - 1 := by omega
          have hd2 : 2 * d ≤ b := by omega
          omega
        exact ih (a % b) d hd2j hdpos

/-- `2^256 < 2^299` (the `j = 299` fuel slot: `2*299+2 = 600 = fuelLN`). -/
theorem two256_lt_two299 : (2 : Nat) ^ 256 < 2 ^ 299 :=
  Nat.pow_lt_pow_right (by decide) (by decide)

/-- The universal fuel completion at `FL = zeros 600`. -/
theorem egcdLDone_FL_of_lt {m d : Nat} (h : d < m) (hm : m < 2 ^ 256) :
    egcdLDone FL m d = true := by
  by_cases h0 : d = 0
  · subst h0
    exact egcdLDone_zero _ _
  · have hd : d < 2 ^ 299 := Nat.lt_trans (Nat.lt_trans h hm) two256_lt_two299
    have := egcdLDone_zeros_even 299 m d hd (Nat.pos_of_ne_zero h0)
    simpa [FL, fuelLN] using this

/-- The field prime fits in 256 bits (kernel `decide` on the literal). -/
theorem P_lt_two256 : P < 2 ^ 256 := by decide

/-- **the discharge layer `hE` DISCHARGED** (the structural mirror's crown hypothesis shape verbatim). -/
theorem hE_uncond : ∀ d : Nat, d < P → egcdLDone FL P d = true := by
  intro d hd
  exact egcdLDone_FL_of_lt hd P_lt_two256

/-- **the discharge layer `hN` DISCHARGED** (mod-`n` analogue). -/
theorem hN_uncond : ∀ s : Nat, s < n → egcdLDone FL n s = true := by
  intro s hs
  exact egcdLDone_FL_of_lt hs n_lt_two256

/-- **THE UNCONDITIONAL CROWN**: the structural mirror IS the production
verifier (the structural mirror's `verifyStructG_eq_verifyImpl` with `hE`/`hN` discharged). -/
theorem verifyStruct_eq_verifyImpl :
    Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl := by
  funext sig pk msg
  exact verifyStructG_eq_verifyImpl FL hE_uncond hN_uncond sig pk msg

/-- the alternate-entry layer `EntryWired.lean`'s `verifyStructEq'` slot, unconditionally. -/
theorem verifyStructEq'_uncond :
    Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl :=
  verifyStruct_eq_verifyImpl

/-- The wired alternate ECDSA entry IS the production entry. -/
theorem ecdsaEntryWired_eq_uncond
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool) :
    Bitcoin.Crypto.EcdsaDeep.EntryWired.ecdsaEntryWired sighash hasAmount
      = ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount :=
  Bitcoin.Crypto.EcdsaDeep.EntryWired.ecdsaEntryWired_eq sighash hasAmount
    verifyStructEq'_uncond

/-- The wired smart constructor IS the production assembly. -/
theorem txCheckerWiredOf_eq_uncond
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray) :
    Bitcoin.Crypto.EcdsaDeep.EntryWired.txCheckerWiredOf sighash hasAmount
        verifySchnorr sighashSchnorr
      = txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount
          verifySchnorr sighashSchnorr :=
  Bitcoin.Crypto.EcdsaDeep.EntryWired.txCheckerWiredOf_eq sighash hasAmount
    verifySchnorr sighashSchnorr verifyStructEq'_uncond

section AxiomPins

-- the discharge layer axiom pins: every discharge/crown theorem ⊆ the standard trio
-- [propext, Classical.choice, Quot.sound]; NO sorryAx, NO custom axiom.

/-- info: 'Bitcoin.Crypto.EcdsaDeep.FuelDischarge.egcdLDone_zeros_even' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms egcdLDone_zeros_even

/-- info: 'Bitcoin.Crypto.EcdsaDeep.FuelDischarge.hE_uncond' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms hE_uncond

/-- info: 'Bitcoin.Crypto.EcdsaDeep.FuelDischarge.hN_uncond' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms hN_uncond

/-- info: 'Bitcoin.Crypto.EcdsaDeep.FuelDischarge.verifyStruct_eq_verifyImpl' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyStruct_eq_verifyImpl

/-- info: 'Bitcoin.Crypto.EcdsaDeep.FuelDischarge.ecdsaEntryWired_eq_uncond' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryWired_eq_uncond

/-- info: 'Bitcoin.Crypto.EcdsaDeep.FuelDischarge.txCheckerWiredOf_eq_uncond' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms txCheckerWiredOf_eq_uncond

end AxiomPins

end Bitcoin.Crypto.EcdsaDeep.FuelDischarge
